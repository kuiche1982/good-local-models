# Qwen3.5-4B/9B MTP · mtplx

Apple Silicon 本地 LLM 运行器 mtplx 启动 Qwen MTP（多 token 预测投机解码）优化模型。MTP 头做投机解码，同模型约 1.1–2.2x 加速，无需第二套草稿模型（Leviathan & Chen 拒绝采样，数学精确）。

> 本目录部署 **Qwen3.5-4B-MTPLX-Optimized-Speed**（4-bit）。官方不存在 "Qwen3.6-7B" MTP 型号（Qwen3.6 家族仅 27B/35B，16G 跑不动）；9B 备选见下文。

## 安装 / Install

```bash
python3.12 -m venv .venv
.venv/bin/pip install mtplx          # 实测版本 2.10.2；仅 macOS 14+ / Apple Silicon（MLX 原生，无 CUDA 版）

# 拉取模型（国内镜像）
HF_ENDPOINT=https://hf-mirror.com .venv/bin/mtplx pull Youssofal/Qwen3.5-4B-MTPLX-Optimized-Speed --cache-dir ./models
```

默认模型 `Youssofal/Qwen3.5-4B-MTPLX-Optimized-Speed`（4-bit, 2.6 GB, 峰值 ~2.9 GiB）；备选 9B（6-bit, 8.7 GB, ~10 GiB）。

## 启动 / Run

```bash
./start.sh            # OpenAI/Anthropic 兼容服务 → http://127.0.0.1:1234
./start.sh chat       # 原生 MTP 对话冒烟测试
./start.sh tune       # 自动探测本机最优 MTP depth（AR vs D1-D8）
./start.sh status     # 安装/模型/服务健康检查
```

## 环境变量 / Env vars

| 变量 | 默认 | 说明 |
|---|---|---|
| `MODEL` | `Youssofal/Qwen3.5-4B-MTPLX-Optimized-Speed` | HF id 或本地路径 |
| `CACHE_DIR` | `./models` | 模型缓存目录 |
| `CTX` | `64000` | 上下文窗口（16G 推荐平衡点；模型上限 184K） |
| `DEPTH` | `2`（自动应用 tune 最优） | MTP 深度 1–8 |
| `KVQ` | `q8` | KV 缓存量化 off/q8/q4，16G 默认 q8 省内存 |
| `SESSION_BANK_MAX` | `1G` | RAM 会话银行上限（默认自动放大到 ~6.6G，16G 压到 1G） |
| `PORT` / `HOST` | `1234` / `127.0.0.1` | 服务地址；绑非 localhost 必须设 `API_KEY` |
| `HF_ENDPOINT` | `https://hf-mirror.com` | 模型下载镜像 |

## 实测 / Verified (M2 16G)

- tuned depth = **2**：29.6 tok/s，1.133x AR（sustained 档）
- 4B 模型 + 权重 2.6G：32K≈3.6G / 64K≈4.6G / 96K≈5.6G 总内存，16G 均轻松

## 接口示例 / API example

```bash
curl http://127.0.0.1:1234/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"Youssofal/Qwen3.5-4B-MTPLX-Optimized-Speed","messages":[{"role":"user","content":"你好"}]}'
```

## 参考 / References

- 模型：[Youssofal/Qwen3.5-4B-MTPLX-Optimized-Speed](https://huggingface.co/Youssofal/Qwen3.5-4B-MTPLX-Optimized-Speed)（HF）
- 环境依赖以 `pip show mtplx` 实际安装版本为准
