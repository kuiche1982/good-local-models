# LFM2.5-2.6B · llama.cpp

用 llama.cpp（b10752, macOS arm64, Metal 后端）启动 LiquidAI **LFM2.5-2.6B**（GGUF Q5_K_M，1.8 GB）。轻量日常模型：简单问答、摘要、轻量工具调用。

## 安装 / Install

```bash
# 1. 获取 llama.cpp b10752（macOS arm64 二进制包，解压出 llama-server/llama-cli/llama-bench）
#    或从官方 releases 自行构建： https://github.com/ggml-org/llama.cpp/releases
mkdir llama-b10752 && tar -xzf llama-b10752-bin-macos-arm64.tar.gz -C llama-b10752

# 2. 下载 GGUF（LiquidAI 官方 LFM2.5-2.6B-GGUF 仓库，Q5_K_M）
#    国内镜像示例：curl -L -C - -o LFM2.5-2.6B-Q5_K_M.gguf "<官方或 hf-mirror 地址>"
```

## 启动 / Run

```bash
./start_lfm.sh               # 默认：服务模式（关思考，秒回）→ http://127.0.0.1:1234
./start_lfm.sh cli           # 终端交互对话
./start_lfm.sh bench         # 推理性能基准
./start_lfm_thinking.sh      # 开思考模式（--reasoning-budget 2048）
```

## 环境变量 / Env vars

| 变量 | 默认 | 说明 |
|---|---|---|
| `PORT` | `1234` | 服务端口 |
| `CTX` | `120000` | 上下文长度（16G 内存友好） |
| `NGL` | `99` | 卸载到 Metal 的层数（99=全部） |
| `FA` | `on` | Flash Attention |
| `CTKV` | `q8_0` | K/V 缓存量化（MLA 模型 K/V 必须同类型） |
| `PARALLEL` | `1` | 并行槽位（16G 建议 1–2） |
| `REA` | 空=auto | 思考模式 on/off |
| `ALIAS` | `lfm2.5-2.6b` | API 响应的 model 名 |
| `API_KEY` | 空 | 非 localhost 暴露时必设 |
| `MCP_CONFIG` | `./mcp-servers.json` | 可选：MCP 服务器配置（Cursor 格式，文件存在才加载） |

## 关键注意 / Gotchas

- **LFM 关闭思考是启动参数**，禁止放 API body：`--chat-template-kwargs '{"enable_thinking":false}' --reasoning-budget 0`（start_lfm.sh 已内置）。把 `chat_template_kwargs` 写进 POST JSON body 会返回 400。
- curl 调用必须显式 `-X POST`，否则 content-type 被篡改成表单导致 400。
- 与 Ling 的差异：Ling 的 `enable_thinking` 放 **API body**；LFM 的放**启动参数**。

## 接口示例 / API example

```bash
curl -X POST http://127.0.0.1:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"lfm2.5-2.6b","messages":[{"role":"user","content":"你好"}]}'
```

## 参考 / References

- 官方 llama.cpp releases：[ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp/releases)
- 模型：LiquidAI `LFM2.5-2.6B-GGUF`（LM Studio 默认目录 `~/.lmstudio/models/LiquidAI/`）
