#!/usr/bin/env bash
# ============================================================
# start.sh — 用 llama.cpp 启动 Spark-X2.5-1.7B (GGUF)
#
# 用法:
#   ./start.sh           启动 OpenAI 兼容 HTTP 服务 (llama-server)
#   ./start.sh cli       启动交互式命令行对话 (llama-cli)
#   ./start.sh bench     跑推理性能基准 (llama-bench)
#
# 依赖:
#   - llama.cpp 二进制目录: llama.cpp/build/bin/ (本仓库 CMake 编译产物)
#   - GGUF 模型:           Spark-X2.5-1.7B-GGUF/Spark-X2.5-1.7B.gguf
#
# 可覆盖环境变量: PORT / CTX / NGL / FA / KVQ / THINK / ALIAS
#   例: PORT=9000 CTX=16384 ./start.sh
#   例: KVQ=off ./start.sh          # 关闭 KV 减半 (KV 用 f16)
#   例: THINK=on ./start.sh         # 开启模型深度思考模式 (默认 off, 秒回)
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_DIR="$SCRIPT_DIR/llama-bsparkx25"               # llama.cpp 可执行文件目录
MODEL="$SCRIPT_DIR/Spark-X2.5-1.7B-GGUF/Spark-X2.5-1.7B.gguf"
ALIAS="${ALIAS:-Spark-X2.5-1.7B}"                          # API 响应里的 model 名

HOST="127.0.0.1"
PORT="${PORT:-1234}"
CTX="${CTX:-64000}"          # 上下文长度, 可用环境变量覆盖: CTX=16384 ./start.sh
NGL="${NGL:-99}"            # 卸载到 GPU(Metal) 的层数, 99=全部
FA="${FA:-on}"              # Flash Attention, on/off
KVQ="${KVQ:-on}"            # KV 缓存量化 q8_0 (on=减半省内存, off=f16 精度), on/off
THINK="${THINK:-off}"       # 模型深度思考 on/off (off=秒回, on=先思考再答)

cd "$SCRIPT_DIR"

if [ ! -x "$LLAMA_DIR/llama-server" ]; then
    echo "[ERROR] 找不到 $LLAMA_DIR/llama-server" >&2
    echo "       请先在 llama.cpp 下编译:" >&2
    echo "       cmake -B llama.cpp/build -DCMAKE_BUILD_TYPE=Release && cmake --build llama.cpp/build" >&2
    exit 1
fi

if [ ! -f "$MODEL" ]; then
    echo "[ERROR] 找不到模型: $MODEL" >&2
    echo "       请确认 Spark-X2.5-1.7B-GGUF/Spark-X2.5-1.7B.gguf 已就位" >&2
    exit 1
fi

FA_ARGS=()
[ "$FA" = "on" ] && FA_ARGS+=("-fa" "on")

KVQ_ARGS=()
[ "$KVQ" = "on" ] && KVQ_ARGS+=("-ctk" "q8_0" "-ctv" "q8_0")

case "${1:-server}" in
    server)
        echo ">>> 启动 OpenAI 兼容服务: http://$HOST:$PORT"
        echo ">>> 接口示例: curl http://$HOST:$PORT/v1/chat/completions"
        exec "$LLAMA_DIR/llama-server" \
            -m "$MODEL" \
            --host "$HOST" --port "$PORT" \
            -c "$CTX" -ngl "$NGL" \
            -a "$ALIAS" \
            -np 1 \
            --reasoning "$THINK" \
            "${FA_ARGS[@]}" \
            "${KVQ_ARGS[@]}"
        ;;
    cli)
        echo ">>> 交互式对话 (输入 /exit 退出, /reset 清空上下文)"
        exec "$LLAMA_DIR/llama-cli" \
            -m "$MODEL" -c "$CTX" -ngl "$NGL" \
            --reasoning "$THINK" \
            "${FA_ARGS[@]}" \
            "${KVQ_ARGS[@]}" \
            -cnv -p "你好"
        ;;
    bench)
        echo ">>> 推理性能基准 (提示64token / 生成128token)"
        exec "$LLAMA_DIR/llama-bench" \
            -m "$MODEL" -ngl "$NGL" -p 64 -n 128 \
            "${FA_ARGS[@]}" \
            "${KVQ_ARGS[@]}"
        ;;
    *)
        echo "用法: $0 [server|cli|bench]" >&2
        exit 1
        ;;
esac
