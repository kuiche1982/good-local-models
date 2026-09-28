#!/usr/bin/env bash
# ============================================================
# start.sh — 用 mtplx 启动 MTPLX 优化模型 (Apple Silicon, MTP 投机解码)
#
# 用法:
#   ./start.sh               启动 OpenAI/Anthropic 兼容 HTTP 服务 (mtplx serve)
#   ./start.sh chat          跑一次原生 MTP 对话冒烟测试 (mtplx chat)
#   ./start.sh tune          自动探测本机最优 MTP depth (mtplx tune, AR vs D1-D8)
#   ./start.sh status        检查安装 / 模型 / 服务健康状态 (mtplx status)
#
# 依赖:
#   - venv:  .venv/  (Python 3.12, 已安装 mtplx)
#   - 模型:  $MODEL (HF repo id), 缓存在 $CACHE_DIR (默认 ./models, 项目目录内)
#
# 环境变量覆盖(默认值见下):
#   MODEL=<HF id 或本地路径>  CACHE_DIR=  HOST=127.0.0.1  PORT=1234
#   DEPTH=<MTP 深度>  CTX=16384(16G 内存友好)  MAX_TOKENS=  API_KEY=
#   HF_ENDPOINT=https://hf-mirror.com  (国内拉取镜像)
#   SESSION_BANK_MAX=1G  (RAM 会话银行上限, 降内存大头; 调大可加速多轮)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MTPLX="${MTPLX:-$SCRIPT_DIR/.venv/bin/mtplx}"
CACHE_DIR="${CACHE_DIR:-$SCRIPT_DIR/models}"
MODEL="${MODEL:-Youssofal/Qwen3.5-4B-MTPLX-Optimized-Speed}"  # 默认: 4-bit, ~2.6GB, 峰值内存 ~2.9GiB (备选: Qwen3.5-9B-MTPLX-Optimized-Speed)
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-1234}"
AGENT="${AGENT:-on}"
## D2 还在吗？—— 在，且正在生效

# 表格

# | 检查 | 结果 |
# | --- | --- |
# | `~/.mtplx/tuning.json` | depth=2，29.6 tok/s，1.133x AR，sustained 档 ✅ |
# | 运行中 96K 服务 | `depth = 2` ✅ |
# | 进程命令行 | `--depth 2` ✅ |

# **改 CTX 不影响 tune 结论**：tuning 记录的 key 只含模型 + 硬件 + 采样参数（temperature/top_p/top_k），不含上下文窗口，所以 D2 稳定有效。
DEPTH="${DEPTH:-2}"            # MTP 深度: 空=auto(用 tune 保存的最优深度), 或 1-8, 
CTX="${CTX:-64000}"           # 上下文窗口 token 数 (默认 96K; 模型原生上限 262144, 服务上限 184320)
# ── 上下文 ↔ KV 内存对照 (Qwen3.5-4B, 每 token 32KiB, 仅 8 层 full-attn 随上下文增长) ──
#   上下文   KV满量   +权重2.6G   16G 评价
#   32K  →   1.0G     3.6G       轻松
#   64K  →   2.0G     4.6G       推荐平衡
#   96K  →   3.0G     5.6G       ← 默认(长文档够用且稳)
#   128K →   4.0G     6.6G       填满偏紧
#   160K →   5.0G     7.6G       更紧
#   184K →   5.6G     8.2G       服务上限(易触发内存压力)
#   262K →   8.0G     10.6G      模型原生上限(16G 跑不动)
#   注: KV 分页动态分配, 短对话实际占用远小于满量; 只有灌满长文才按上表吃内存
MAX_TOKENS="${MAX_TOKENS:-}"  # 响应 token 上限, 空=模型默认
API_KEY="${API_KEY:-}"        # API 鉴权 key: 非 localhost 绑定时必填, 否则忽略
HF_ENDPOINT="${HF_ENDPOINT:-https://hf-mirror.com}"
# KV 缓存量化: off/q8/q4; 16G 内存默认开 q8 省内存(howto §6), 可 KVQ=off 覆盖
KVQ="${KVQ:-q8}"
# RAM 会话银行(多轮 warm-prefix 缓存)上限: 默认自动按内存放大到 ~6.6G, 16G 机器压到 1G 大幅降内存
SESSION_BANK_MAX="${SESSION_BANK_MAX:-1G}"
SESSION_BANK_PER_SESSION="${SESSION_BANK_PER_SESSION:-1G}"

cd "$SCRIPT_DIR"

# ---------- 依赖检查 ----------
if [ ! -x "$MTPLX" ]; then
    echo "[ERROR] 找不到 mtplx: $MTPLX" >&2
    echo "       请先创建 venv 并安装:" >&2
    echo "       python3.12 -m venv .venv && .venv/bin/pip install mtplx" >&2
    exit 1
fi

if [ ! -d "$CACHE_DIR" ] || [ -z "$(ls -A "$CACHE_DIR" 2>/dev/null)" ]; then
    echo "[ERROR] 模型缓存为空: $CACHE_DIR" >&2
    echo "       请先拉取模型(国内镜像):" >&2
    echo "       HF_ENDPOINT=$HF_ENDPOINT \"$MTPLX\" pull \"$MODEL\" --cache-dir \"$CACHE_DIR\"" >&2
    exit 1
fi

# ---------- 自动应用 tune 保存的最优 MTP 深度 ----------
# 若未显式指定 DEPTH, 则从 ~/.mtplx/tuning.json 读取当前模型已保存的最优深度
# (仅 serve/chat 生效; tune 是测量命令, 保持显式)
if [ -z "$DEPTH" ] && [ -f "$HOME/.mtplx/tuning.json" ]; then
    TUNED_DEPTH="$("$SCRIPT_DIR/.venv/bin/python" - "$MODEL" "$CACHE_DIR" <<'PY'
import json, os, sys
model, cache = sys.argv[1], sys.argv[2]
m = model if os.path.isabs(model) else os.path.abspath(os.path.join(cache, model.replace('/', '--')))
try:
    data = json.load(open(os.path.expanduser('~/.mtplx/tuning.json')))
except Exception:
    sys.exit(0)
for rec in (data.get('records') or {}).values():
    km = rec.get('key_material') or {}
    if km.get('model') == m:
        best = (rec.get('payload') or {}).get('best') or {}
        d = best.get('depth')
        if isinstance(d, int):
            print(d)
        break
PY
)"
    if [ -n "$TUNED_DEPTH" ]; then
        DEPTH="$TUNED_DEPTH"
        echo ">>> 已应用 tune 保存的最优 MTP 深度: D$DEPTH"
    fi
fi

# ---------- 公共参数 ----------
BASE_ARGS=(--model "$MODEL" --cache-dir "$CACHE_DIR")
[ -n "$DEPTH" ] && BASE_ARGS+=(--depth "$DEPTH")
[ -n "$CTX" ] && BASE_ARGS+=(--context-window "$CTX")
[ -n "$KVQ" ] && BASE_ARGS+=(--paged-kv-quantization "$KVQ")
[ -n "$MAX_TOKENS" ] && BASE_ARGS+=(--max-tokens "$MAX_TOKENS")
[ -n "$API_KEY" ] && BASE_ARGS+=(--api-key "$API_KEY")
[ -n "$AGENT" ] && BASE_ARGS+=(--reasoning off  --batching-preset agent)


case "${1:-server}" in
    server)
        echo ">>> 启动 mtplx 服务: http://$HOST:$PORT"
        echo ">>> 模型: $MODEL"
        echo ">>> 接口示例: curl http://$HOST:$PORT/v1/chat/completions"
        [ -n "$DEPTH" ] && echo ">>> MTP depth: $DEPTH"
        [ -n "$CTX" ] && echo ">>> 上下文窗口: $CTX"
        [ -n "$AGENT" ] && echo ">>> AGENT优化打开： --reasoning off  --batching-preset agent --profile sustained --paged-kv-quantization q8"
        if [ -n "$API_KEY" ]; then
            echo ">>> API 鉴权已启用"
        elif [ "$HOST" != "127.0.0.1" ] && [ "$HOST" != "localhost" ]; then
            echo "[ERROR] 绑定非 localhost 时必须设置 API_KEY (mtplx 强制要求)" >&2
            exit 1
        fi
        export HF_ENDPOINT
        export MTPLX_SESSION_BANK_MAX_BYTES="$SESSION_BANK_MAX"
        export MTPLX_SESSION_BANK_PER_SESSION_BYTES="$SESSION_BANK_PER_SESSION"
        exec "$MTPLX" serve "${BASE_ARGS[@]}" --host "$HOST" --port "$PORT"
        ;;
    chat)
        echo ">>> 原生 MTP 对话冒烟测试 (--yes 跳过交互确认)"
        export HF_ENDPOINT
        exec "$MTPLX" chat "${BASE_ARGS[@]}" --yes --prompt "你好，请用一句话介绍你自己。"
        ;;
    tune)
        echo ">>> 自动探测本机最优 MTP depth (AR vs D1-D8, --retune 忽略已保存结果)"
        export HF_ENDPOINT
        exec "$MTPLX" tune "${BASE_ARGS[@]}" --yes --retune
        ;;
    status)
        exec "$MTPLX" status --project-root "$SCRIPT_DIR" --model-cache "$CACHE_DIR"
        ;;
    *)
        echo "用法: $0 [server|chat|tune|status]" >&2
        exit 1
        ;;
esac
