# Spark-X2.5-1.7B · llama.cpp (Spark2_5 fork)

用 Spark2_5 定制 fork 的 llama.cpp 启动讯飞 **Spark-X2.5-1.7B**（GGUF，BF16 1.708B = 3.2 GB）。架构含 Gated Attention、GEGLU 并行 FFN、ISWA 滑动窗口 KV（滑窗 512），原生上下文 1M。

## 安装 / Install

```bash
# 1. 获取 llama.cpp Spark2_5 定制 fork（XHToken/llama.cpp，实测 0.1.2-dev / build 10512）
git clone https://github.com/XHToken/llama.cpp

# 2. 编译（Metal + Accelerate 自动启用；产物在 llama.cpp/build/bin/）
./compile.sh          # 等价: cmake -S llama.cpp -B llama.cpp/build -DCMAKE_BUILD_TYPE=Release && cmake --build llama.cpp/build

# 3. GGUF 模型：Spark-X2.5-1.7B-GGUF/Spark-X2.5-1.7B.gguf
#    （fork 内 conversion/spark2_5.py 负责 HF→GGUF 转换；BF16 权重转出即本文件）
```

## 启动 / Run

```bash
./start.sh            # OpenAI 兼容服务 → http://127.0.0.1:1234
./start.sh cli        # 终端交互对话
./start.sh bench      # 推理性能基准
```

## 环境变量 / Env vars

| 变量 | 默认 | 说明 |
|---|---|---|
| `PORT` | `1234` | 服务端口 |
| `CTX` | `64000` | 上下文长度（16G：32K 舒适 / 129K 上限；原生 1M 的 KV≈60GB 跑不了） |
| `NGL` | `99` | 卸载到 Metal 的层数（99=全部） |
| `FA` | `on` | Flash Attention |
| `KVQ` | `on` | KV 缓存 q8_0（on=减半省内存；off=f16 精度） |
| `THINK` | `off` | 深度思考模式（off=秒回；on=先思考再答） |
| `ALIAS` | `Spark-X2.5-1.7B` | API 响应的 model 名 |

## 关键注意 / Gotchas

- **工具调用**：默认请求不带 `tools` 字段时模型会直接输出代码；需传 OpenAI 格式 `tools` 数组 + system prompt 硬规则（如"生成代码必须调用 write_file"）才触发 `tool_calls`（实测 406 tokens / 20.4 t/s）。
- 16G 内存跑 1M 上下文不可能（KV≈60 GB），32K 舒适、129K 上限（滑窗 512 使实际生效 KV 低于全量）。

## 接口示例 / API example

```bash
curl http://127.0.0.1:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Spark-X2.5-1.7B","messages":[{"role":"user","content":"你好"}]}'
```

## 实测 / Verified (M2 16G)

- 全层 Metal + FlashAttention：预填充 **130 t/s**、生成 **24.6 t/s**
- 权重 3.2 GB，理论带宽墙约 29 t/s，decode 已贴墙

## 参考 / References

- 定制 fork：[XHToken/llama.cpp](https://github.com/XHToken/llama.cpp)（Spark2_5 架构，上游 ggml-org/llama.cpp）
- 架构转换：fork 内 `conversion/spark2_5.py`
