# Ling-3.0-Tiny · llama.cpp

用 llama.cpp（b10752, macOS arm64, Metal 后端）启动 MiniMax **Ling-3.0-Tiny**（GGUF Q4_K_M，4.5 GB）。BailingMoE3 架构（KDA + MLA + MoE-FFN，128 experts，7.9B 总参 / 1.3B 激活），综合能力上限最高，适合复杂 Agent / 数学 / 中等代码。

## 安装 / Install

```bash
# 1. 获取 llama.cpp b10752（macOS arm64 二进制包）或从官方 releases 构建
#    https://github.com/ggml-org/llama.cpp/releases
#    （官方 llama.cpp b104xx+ 已原生支持 BailingMoE3 / Ling-3.0-tiny）

# 2. 下载 GGUF（Q4_K_M, 4.5 GB）——注意：原版 Ling-3.0-tiny 是 MLX 格式（safetensors），llama.cpp 无法加载，必须用 GGUF
curl -L -C - -o Ling-3.0-tiny-Q4_K_M.gguf \
  "https://hf-mirror.com/bloomer010/Ling-3.0-tiny-GGUF/resolve/main/Ling-3.0-tiny-Q4_K_M.gguf"
#    魔搭官方镜像：inclusionAI/Ling-3.0-tiny-GGUF（modelscope.cn）
```

## 启动 / Run

```bash
./start.sh            # OpenAI 兼容服务 → http://127.0.0.1:1234
./start.sh cli        # 终端交互对话（含思考模式）
./start.sh bench      # 推理性能基准
```

## 环境变量 / Env vars

| 变量 | 默认 | 说明 |
|---|---|---|
| `PORT` | `1234` | 服务端口 |
| `CTX` | `64000` | 上下文长度（官方原生 256K；16G 推荐 ≤128K） |
| `NGL` | `99` | 卸载到 Metal 的层数（24 层全卸） |
| `NCMOE` | `0` | 留 CPU 的 MoE 专家层数（内存紧张可设，如 24） |
| `FA` | `on` | Flash Attention |
| `CTKV` | `q8_0` | K/V 缓存量化（**MLA 模型 K/V 必须同类型**，只设 V 会报错） |
| `PARALLEL` | `1` | 并行槽位（16G 建议 1–2） |
| `REA` | 空=auto | 思考模式（模型默认开） |
| `ALIAS` | `Ling-3.0-Tiny` | API 响应的 model 名 |
| `API_KEY` | 空 | 非 localhost 暴露时必设 |

## 关键注意 / Gotchas

- **思考模式默认开启**：token 预算先花在 `reasoning_content`，`max_tokens` 不够时 `content` 为空——不是 bug。关闭方式：API body 传 `"chat_template_kwargs":{"enable_thinking":false}`（**Ling 放 body，与 LFM 相反**）。
- Tool calling 实测正常（`finish_reason: "tool_calls"` 可出）。
- 长上下文（>30K）偶发输出异常，属 KDA 长程预期行为。

## 接口示例 / API example

```bash
curl http://127.0.0.1:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Ling-3.0-Tiny","messages":[{"role":"user","content":"你好"}],"max_tokens":400,"chat_template_kwargs":{"enable_thinking":false}}'
```

## 实测 / Verified (M2 16G)

- 解码 40–52 tok/s（短 prompt）；推荐运行上下文 ≤128K，总内存约 10–12 GB
- 授权 MIT

## 参考 / References

- 官方 llama.cpp releases：[ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp/releases)
- 模型镜像：[魔搭 inclusionAI/Ling-3.0-tiny-GGUF](https://modelscope.cn/models/inclusionAI/Ling-3.0-tiny-GGUF)
