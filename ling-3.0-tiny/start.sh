#!/usr/bin/env bash
# ============================================================
# start.sh — 用 llama.cpp 启动 Ling-3.0-Tiny (GGUF)
#
# 用法:
#   ./start.sh           启动 OpenAI 兼容 HTTP 服务 (llama-server)
#   ./start.sh cli       启动交互式命令行对话 (llama-cli)
#   ./start.sh bench     跑推理性能基准 (llama-bench)
#
# 依赖:
#   - llama.cpp 二进制目录: llama-b10752/  (含 llama-server/llama-cli/llama-bench)
#   - GGUF 模型:           Ling-3.0-tiny-Q4_K_M.gguf (与 start.sh 同目录)
#
# 注意: 原目录下的 Ling-3.0-tiny 是 MLX 格式(safetensors), llama.cpp 无法加载,
#       必须使用本脚本指向的 GGUF 文件。
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_DIR="$SCRIPT_DIR/llama-b10752"            # llama.cpp 可执行文件目录
MODEL="$SCRIPT_DIR/Ling-3.0-tiny-Q4_K_M.gguf"   # GGUF 模型路径
ALIAS="${ALIAS:-Ling-3.0-Tiny}"                  # API 响应里的 model 名
MCP_CONFIG="${MCP_CONFIG:-$SCRIPT_DIR/mcp-servers.json}"  # MCP 服务器配置 (Cursor格式)
TOOLS="${TOOLS:-}"                               # 内置工具: 留空=关闭, all=全部, 或逗号分隔列表

HOST="127.0.0.1"
PORT="${PORT:-1234}"
CTX="${CTX:-64000}"          # 上下文长度, 可用环境变量覆盖: CTX=16384 ./start.sh
NGL="${NGL:-99}"            # 卸载到 GPU(Metal) 的层数, 99=全部
NCMOE="${NCMOE:-0}"        # 保留在 CPU 的 MoE 专家层数 (0=全上GPU, 24=专家全留CPU, 省GPU工作集)
FA="${FA:-on}"              # Flash Attention, on/off
PARALLEL="${PARALLEL:-1}"   # 并行槽位 (16G 内存有限: 1=单客户端最稳, 2=两个并发)
CTKV="${CTKV:-q8_0}"            # K/V缓存类型: 空=f16, q8_0=省内存 (Ling用MLA, K/V必须一致, 只设V会报错)
REA="${REA:-}"              # 思考模式: 空=auto(模板), off=关闭(更快/省token), on=强制
API_KEY="${API_KEY:-}"      # API 鉴权 key, 非空则启用 (局域网暴露时必设)

cd "$SCRIPT_DIR"

if [ ! -x "$LLAMA_DIR/llama-server" ]; then
    echo "[ERROR] 找不到 $LLAMA_DIR/llama-server" >&2
    echo "       请确认 llama.cpp 已解压到 $LLAMA_DIR" >&2
    exit 1
fi

if [ ! -f "$MODEL" ]; then
    echo "[ERROR] 找不到模型: $MODEL" >&2
    echo "       请先下载(国内镜像):" >&2
    echo "       curl -L -C - -o \"$MODEL\" \\" >&2
    echo "         \"https://hf-mirror.com/bloomer010/Ling-3.0-tiny-GGUF/resolve/main/Ling-3.0-tiny-Q4_K_M.gguf\"" >&2
    exit 1
fi

FA_ARGS=()
[ "$FA" = "on" ] && FA_ARGS+=("-fa" "on")

# MoE 专家权重放 CPU (省 GPU 工作集预算)
NCMOE_ARGS=()
if [ -n "$NCMOE" ] && [ "$NCMOE" != "0" ]; then
    NCMOE_ARGS+=("-ncmoe" "$NCMOE")
fi

# 并行槽位 (内存紧张时收紧)
PARALLEL_ARGS=()
if [ -n "$PARALLEL" ] && [ "$PARALLEL" != "0" ]; then
    PARALLEL_ARGS+=("-np" "$PARALLEL")
fi

# K/V 缓存精度 (q8_0 省内存; MLA 模型 K/V 必须同类型)
CTKV_ARGS=()
[ -n "$CTKV" ] && CTKV_ARGS+=("-ctk" "$CTKV" "-ctv" "$CTKV")

# 思考模式
REA_ARGS=()
[ -n "$REA" ] && REA_ARGS+=("-rea" "$REA")

# API 鉴权
API_KEY_ARGS=()
[ -n "$API_KEY" ] && API_KEY_ARGS+=("--api-key" "$API_KEY")

# MCP / 内置工具参数
MCP_ARGS=()
if [ -n "$MCP_CONFIG" ] && [ -f "$MCP_CONFIG" ]; then
    MCP_ARGS+=("--mcp-servers-config" "$MCP_CONFIG")
fi
TOOLS_ARGS=()
if [ -n "$TOOLS" ]; then
    TOOLS_ARGS+=("--tools" "$TOOLS")
fi

case "${1:-server}" in
    server)
        echo ">>> 启动 OpenAI 兼容服务: http://$HOST:$PORT"
        echo ">>> 接口示例: curl http://$HOST:$PORT/v1/chat/completions"
        [ ${#MCP_ARGS[@]} -gt 0 ] && echo ">>> 已加载 MCP 配置: $MCP_CONFIG"
        [ ${#TOOLS_ARGS[@]} -gt 0 ] && echo ">>> 已启用内置工具: $TOOLS"
        [ ${#NCMOE_ARGS[@]} -gt 0 ] && echo ">>> MoE 专家留 CPU 层数: $NCMOE (释放 GPU 工作集)"
        [ ${#PARALLEL_ARGS[@]} -gt 0 ] && echo ">>> 并行槽位: $PARALLEL"
        [ ${#CTKV_ARGS[@]} -gt 0 ] && echo ">>> K/V 缓存精度: $CTKV"
        [ ${#REA_ARGS[@]} -gt 0 ] && echo ">>> 思考模式: $REA"
        [ ${#API_KEY_ARGS[@]} -gt 0 ] && echo ">>> API 鉴权已启用"
        exec "$LLAMA_DIR/llama-server" \
            -m "$MODEL" \
            --host "$HOST" --port "$PORT" \
            -c "$CTX" -ngl "$NGL" \
            -a "$ALIAS" \
            ${NCMOE_ARGS[@]+"${NCMOE_ARGS[@]}"} \
            ${PARALLEL_ARGS[@]+"${PARALLEL_ARGS[@]}"} \
            ${CTKV_ARGS[@]+"${CTKV_ARGS[@]}"} \
            ${REA_ARGS[@]+"${REA_ARGS[@]}"} \
            ${API_KEY_ARGS[@]+"${API_KEY_ARGS[@]}"} \
            ${MCP_ARGS[@]+"${MCP_ARGS[@]}"} \
            ${TOOLS_ARGS[@]+"${TOOLS_ARGS[@]}"} \
            ${FA_ARGS[@]+"${FA_ARGS[@]}"}
        ;;
    cli)
        echo ">>> 交互式对话 (输入 /exit 退出, /reset 清空上下文)"
        exec "$LLAMA_DIR/llama-cli" \
            -m "$MODEL" -c "$CTX" -ngl "$NGL" \
            ${NCMOE_ARGS[@]+"${NCMOE_ARGS[@]}"} \
            ${PARALLEL_ARGS[@]+"${PARALLEL_ARGS[@]}"} \
            ${CTKV_ARGS[@]+"${CTKV_ARGS[@]}"} \
            ${REA_ARGS[@]+"${REA_ARGS[@]}"} \
            ${FA_ARGS[@]+"${FA_ARGS[@]}"} \
            -p "你好"
        ;;
    bench)
        echo ">>> 推理性能基准 (提示64token / 生成128token)"
        exec "$LLAMA_DIR/llama-bench" \
            -m "$MODEL" -ngl "$NGL" ${NCMOE_ARGS[@]+"${NCMOE_ARGS[@]}"} -p 64 -n 128
        ;;
    *)
        echo "用法: $0 [server|cli|bench]" >&2
        exit 1
        ;;
esac
