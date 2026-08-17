# AI Home Lab

Local AI experiments sized for an NVIDIA GeForce RTX 5090 (32 GB VRAM), WSL 2,
and Ubuntu.

For the complete reproducible installation procedure, see
[`SETUP_FROM_SCRATCH.md`](SETUP_FROM_SCRATCH.md).

## What this machine can run

| Workload | Good starting point | Notes |
| --- | --- | --- |
| General reasoning and tools | `gpt-oss:20b` | Fits comfortably in VRAM; default profile |
| Coding | `qwen3-coder:30b` | Strong coding model; verify context size and GPU residency |
| Vision | `gemma3:27b` | Image and text input |
| General 70B | `llama3.3:70b` | 68% GPU at 8K context; slower |
| Reasoning 70B | `deepseek-r1:70b` | 68% GPU at 8K context; slower |
| Multilingual 72B | `qwen2.5:72b` | 61% GPU at 8K context; slower |

Model names and availability change over time. Use `ollama search` or the Ollama
library to confirm a tag before downloading it.

## Quick start

Run these commands in Ubuntu, from this repository:

```bash
bash scripts/check-gpu.sh
bash scripts/install-ollama.sh
ollama pull gpt-oss:20b
python3 chat.py "Explain tensor parallelism for a single-GPU learner."
bash scripts/check-runtime.sh
```

The installer is user-local: it puts Ollama under `~/.local`, model data under
`~/.ollama`, and starts a systemd user service. Model weights stay on the native
Linux filesystem instead of `/mnt/c` for better I/O performance.

For an interactive chat, omit the prompt:

```bash
python3 chat.py
```

Inside chat, list installed models and switch between them:

```text
you> /models
you> /model qwen3-coder:30b
```

Switching models clears the current conversation. You can also list or select a
model when launching the client:

```bash
python3 chat.py --list-models
python3 chat.py --model gemma3:27b "Describe this model's strengths."
```

For a persistent default, edit `config.toml`. Environment variables take
precedence over that file.

Models remain loaded for 30 minutes after a request by default, avoiding repeated
cold-load delays during a session. Override this with `--keep-alive 5m` or the
`OLLAMA_KEEP_ALIVE` environment variable. A loaded model continues using RAM and
VRAM until it expires, another model displaces it, or `ollama stop MODEL` is run.

## WSL memory tuning

WSL currently sees about 30 GB of the host's 64 GB RAM. The default model does
not need more, but CPU-offloaded 70B models do. Copy the values from
`config/wslconfig.example` into `%UserProfile%\.wslconfig`, then run this in
PowerShell:

```powershell
wsl --shutdown
```

Reopen Ubuntu and confirm with `free -h`. Leave several GB for Windows; do not
assign all host RAM to WSL.

## Useful checks

```bash
nvidia-smi
ollama ps
watch -n 1 nvidia-smi
```

`ollama ps` should report `100% GPU` for the default model after a prompt. If it
does not, reduce context size or choose a smaller quantization/model.
