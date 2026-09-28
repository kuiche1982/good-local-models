#!/usr/bin/env bash
# ============================================================
# compile.sh — 编译 llama.cpp (Spark-X2.5-1.7B 定制 fork)
#
# 用法:
#   ./compile.sh          配置并编译 (默认, 等价于 all)
#   ./compile.sh config   仅执行 CMake 配置
#   ./compile.sh clean    删除 build 目录后重新编译
#   ./compile.sh help     显示用法
#
# 环境:
#   macOS arm64 + Xcode CLT, 自动启用 Metal / Accelerate(BLAS) / dotprod+i8mm
#   编译线程数默认取 CPU 核心数, 可用 JOBS=8 ./compile.sh 覆盖
#
# 产物:
#   llama.cpp/build/bin/ 下的
#   llama-cli / llama-server / llama-quantize / llama-bench / llama-perplexity
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMA_SRC="$SCRIPT_DIR/llama.cpp"
BUILD_DIR="$LLAMA_SRC/build"

# 编译目标
TARGETS=(llama-cli llama-server llama-quantize llama-bench llama-perplexity)
JOBS="${JOBS:-$(sysctl -n hw.ncpu 2>/dev/null || echo 4)}"

cmake_config() {
    cmake -S "$LLAMA_SRC" -B "$BUILD_DIR" -DCMAKE_BUILD_TYPE=Release
}

cmake_build() {
    cmake --build "$BUILD_DIR" --config Release -j "$JOBS" --target "${TARGETS[@]}"
}

case "${1:-all}" in
    all|build)
        echo ">>> [1/2] CMake 配置: $BUILD_DIR (Release)"
        cmake_config
        echo ">>> [2/2] 编译 (JOBS=$JOBS): ${TARGETS[*]}"
        cmake_build
        echo ">>> 编译完成, 产物位于: $BUILD_DIR/bin/"
        ;;
    config)
        cmake_config
        echo ">>> 配置完成: $BUILD_DIR"
        ;;
    clean)
        rm -rf "$BUILD_DIR"
        echo ">>> 已删除 $BUILD_DIR"
        ;;
    help|-h|--help)
        echo "用法: $0 [all|config|clean|help]"
        echo "  默认 all: 配置并编译"
        ;;
    *)
        echo "未知参数: $1" >&2
        echo "用法: $0 [all|config|clean|help]" >&2
        exit 1
        ;;
esac
