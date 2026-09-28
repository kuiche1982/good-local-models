# Good Local Models

在 Apple Silicon（M2, 16GB 统一内存）上实测可用的本地大模型组合，每个模型一个目录，含可直接运行的启动脚本。
Tested local LLM setups on Apple Silicon (M2, 16GB unified memory). Each model lives in its own directory with a ready-to-use launcher script.

## 模型一览 / Models

| 模型 Model | 运行器 Runtime | 量化 Quant | 磁盘 Disk | 实测性能 Perf (M2 16G) | 定位 Role |
|---|---|---|---|---|---|
| [Qwen3.5-4B/9B (MTP)](qwen3.6-7b-mtplx/) | mtplx | 4-bit / 6-bit | 2.6 / 8.7 GB | ~30 tok/s（MTP depth 2, 1.13x AR） | 主力编码 / Main workhorse |
| [LFM2.5-2.6B](lfm2.5-2.6b/) | llama.cpp b10752 | Q5_K_M | 1.8 GB | — | 轻量日常 / Lightweight daily |
| [Ling-3.0-Tiny](ling-3.0-tiny/) | llama.cpp b10752 | Q4_K_M | 4.5 GB | 40–52 tok/s | 复杂 Agent / Complex agent tasks |
| [Spark-X2.5-1.7B](spark-x2.5-1.7b/) | llama.cpp fork | BF16 | 3.2 GB | prefill 130 / decode 24.6 tok/s | 长上下文 / Long context |

## 快速开始 / Quick Start

1. Apple Silicon Mac（macOS 14+），16GB 内存为实测基准
2. 进入各模型目录，按其中 README 安装依赖、下载 GGUF 模型
3. 启动：`./start.sh`（默认 OpenAI 兼容服务 `http://127.0.0.1:1234`）

| 目录 | 依赖 | 模型来源 |
|---|---|---|
| `qwen3.6-7b-mtplx/` | `pip install mtplx` | `Youssofal/Qwen3.5-4B-MTPLX-Optimized-Speed` (HF) |
| `lfm2.5-2.6b/` | llama.cpp b10752 二进制 | LiquidAI `LFM2.5-2.6B-GGUF` |
| `ling-3.0-tiny/` | llama.cpp b10752 二进制 | inclusionAI `Ling-3.0-tiny-GGUF`（魔搭镜像） |
| `spark-x2.5-1.7b/` | Spark2_5 fork 源码编译 | Spark-X2.5-1.7B GGUF（fork 内转换脚本） |

## 注意事项 / Notes

- **无凭据、无个人路径**：本仓库不含任何 token / API key / 绝对路径，脚本统一使用 `$SCRIPT_DIR` / `~`。
- **安全**：服务默认只绑 `127.0.0.1`；需要局域网暴露时必须设置 `API_KEY`。
- 版本口径均为本地实测时点（2026-09），上游更新请以官方发布为准。

## License

MIT
