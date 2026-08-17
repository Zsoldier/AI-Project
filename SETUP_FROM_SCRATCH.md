# RTX 5090 AI Home Lab: Setup From Scratch

This is the reproducible procedure used to reach the current working setup. It
keeps Ollama and model weights inside the WSL Linux filesystem, runs Ollama as a
systemd user service, and uses the Python client in this repository to switch
between installed models.

The commands below are the successful setup path. Failed diagnostic attempts
from the original session are intentionally omitted because they are not
required to reproduce the result.

## Resulting environment

The system used for this guide reported:

- Windows 11 Home, build `10.0.26200`
- NVIDIA GeForce RTX 5090 with `32607 MiB` VRAM
- NVIDIA driver `610.88` visible in WSL
- CUDA compute capability `12.0`
- 64 GB host RAM and 32 logical processors
- WSL 2 with Ubuntu 26.04 LTS
- WSL kernel `6.18.33.2-microsoft-standard-WSL2`
- About 1 TB of WSL storage
- Ollama `0.32.13`
- `gpt-oss:20b`, 13 GB on disk and about 12 GB loaded
- `qwen3-coder:30b`, 18 GB on disk and about 21 GB loaded
- `llama3.3:70b`, 42 GB on disk and about 45 GB loaded
- `deepseek-r1:70b`, 42 GB on disk and about 45 GB loaded
- `qwen2.5:72b`, 47 GB on disk and about 50 GB loaded
- The 20B and 30B models were verified at `100% GPU`
- The 70B-class models were verified with CPU offload at an 8,192-token context

## 1. Install or confirm WSL 2

Open PowerShell. If Ubuntu is not installed yet, run:

```powershell
wsl --install -d Ubuntu
```

Restart Windows if requested, open Ubuntu, and finish creating the Linux user.
The user in the original setup was named `ironman`, but any username works.

Confirm WSL is using version 2:

```powershell
wsl --status
wsl --list --verbose
```

Expected shape:

```text
Default Distribution: Ubuntu
Default Version: 2

  NAME      STATE           VERSION
* Ubuntu    Running         2
```

If Ubuntu is listed as version 1, convert it:

```powershell
wsl --set-version Ubuntu 2
```

## 2. Install the NVIDIA Windows driver

Install a current NVIDIA GeForce driver that supports the RTX 5090 and WSL
CUDA. Do not install a separate Linux NVIDIA kernel driver inside WSL; WSL uses
the Windows host driver.

Confirm the Windows adapter and driver:

```powershell
Get-CimInstance Win32_VideoController |
  Select-Object Name, AdapterRAM, DriverVersion |
  Format-Table -AutoSize
```

Confirm GPU passthrough from WSL:

```powershell
wsl -e bash -lc "nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap --format=csv,noheader"
```

Expected on this machine:

```text
NVIDIA GeForce RTX 5090, 32607 MiB, 610.88, 12.0
```

Stop here and fix the Windows NVIDIA driver if `nvidia-smi` is missing or does
not show the GPU inside WSL.

## 3. Confirm host and WSL resources

In PowerShell:

```powershell
Get-CimInstance Win32_ComputerSystem |
  Select-Object TotalPhysicalMemory, NumberOfLogicalProcessors

wsl -e lsb_release -ds
wsl -e uname -r
wsl -e df -h / /mnt/c
wsl -e free -h
```

The original WSL environment initially saw about 30 GB RAM and 8 GB swap even
though the host had 64 GB RAM. This is enough for the two GPU-resident models in
this guide. The optional memory increase in step 12 is useful for CPU-offloaded
70B-class models but was not applied during the verified setup.

## 4. Enable systemd in Ubuntu

The Ollama user service requires systemd. In Ubuntu, inspect the configuration:

```bash
cat /etc/wsl.conf
```

It must contain at least:

```ini
[boot]
systemd=true

[user]
default=YOUR_LINUX_USERNAME
```

If it does not, edit it:

```bash
sudo nano /etc/wsl.conf
```

Then return to PowerShell and restart WSL:

```powershell
wsl --shutdown
```

Reopen Ubuntu and verify:

```bash
systemctl is-system-running
systemctl --user is-system-running
```

Both should report `running` or a usable systemd state.

## 5. Open the project from Ubuntu

The project used in this setup is located at:

```text
C:\Users\zsold\OneDrive\Documents\Github\AI Project
```

From Ubuntu, the same directory is:

```bash
cd "/mnt/c/Users/zsold/OneDrive/Documents/Github/AI Project"
```

For a different Windows username or project location, translate the path under
`/mnt/c`. Keep model weights in the Linux home directory, not in OneDrive. The
installer does this automatically by using `~/.ollama/models`.

Confirm the required base commands:

```bash
command -v git
command -v curl
command -v python3
python3 --version
```

This setup used Python `3.14.4`. The project client uses only the Python standard
library, so it does not require a virtual environment or pip packages.

## 6. Validate the GPU from the project

Run:

```bash
bash scripts/check-gpu.sh
```

The important output is the RTX 5090, about 32 GB VRAM, and compute capability
12.0. The script also prints WSL memory, swap, and Linux filesystem capacity.

## 7. Install Ollama without sudo

Run the repository installer:

```bash
bash scripts/install-ollama.sh
```

The installer performs these exact operations:

1. Creates `~/.local`.
2. Downloads `https://ollama.com/download/ollama-linux-amd64.tar.zst`.
3. Extracts Ollama under `~/.local`.
4. Uses `unzstd` when available, or Python 3.14's `compression.zstd` module.
5. Creates `~/.config/systemd/user/ollama.service`.
6. Configures model storage at `~/.ollama/models`.
7. Enables and starts the user service.

Expected final output resembles:

```text
Installed ollama version is 0.32.13
Service status: active
```

If both `unzstd` and Python's `compression.zstd` module are unavailable, install
the decompressor and rerun the installer:

```bash
sudo apt update
sudo apt install -y zstd
bash scripts/install-ollama.sh
```

Confirm the service directly:

```bash
curl --fail --silent http://127.0.0.1:11434/api/version
systemctl --user is-active ollama.service
```

Expected:

```text
{"version":"0.32.13"}
active
```

If a newly installed `ollama` command is not found in the current shell, either
open a new Ubuntu shell or run:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 8. Download the models

Download the general reasoning model:

```bash
ollama pull gpt-oss:20b
```

Download the coding model:

```bash
ollama pull qwen3-coder:30b
```

Download the three larger models:

```bash
ollama pull llama3.3:70b
ollama pull deepseek-r1:70b
ollama pull qwen2.5:72b
```

These downloads use approximately 162 GB total in `~/.ollama`. Confirm them:

```bash
ollama list
du -sh "$HOME/.ollama"
```

Expected model list:

```text
NAME               SIZE
qwen2.5:72b        47 GB
deepseek-r1:70b    42 GB
llama3.3:70b       42 GB
qwen3-coder:30b    18 GB
gpt-oss:20b        13 GB
```

## 9. Validate local inference

The default model is configured in `config.toml`:

```toml
host = "http://127.0.0.1:11434"
model = "gpt-oss:20b"
context_length = 8192
```

Run a one-shot test:

```bash
python3 chat.py "Reply with exactly: RTX 5090 AI lab ready"
```

Expected response:

```text
RTX 5090 AI lab ready
```

Run the project diagnostics while the model is still loaded:

```bash
bash scripts/check-runtime.sh
```

The critical `ollama ps` fields should resemble:

```text
NAME           SIZE     PROCESSOR    CONTEXT
gpt-oss:20b    12 GB    100% GPU     32768
```

You can also inspect the service's CUDA and offload decisions:

```bash
journalctl --user -u ollama.service --since "10 minutes ago" --no-pager |
  grep -E "library|compute|offload|VRAM|runner"
```

The verified GPT-OSS load reported CUDA compute 12.0 and `offloaded 25/25 layers
to GPU`.

## 10. Use and switch models

Start interactive chat:

```bash
python3 chat.py
```

At the `you>` prompt, list installed models:

```text
/models
```

Switch to the coding model:

```text
/model qwen3-coder:30b
```

Switch back to the reasoning model:

```text
/model gpt-oss:20b
```

Exit with `/quit`, `/exit`, or Ctrl-D. Switching models intentionally clears the
conversation so one model does not inherit another model's chat history.

Select a model when launching the client:

```bash
python3 chat.py --list-models
python3 chat.py --model qwen3-coder:30b
python3 chat.py --model gpt-oss:20b "Explain mixture-of-experts models."
python3 chat.py --model llama3.3:70b --context-length 8192
```

Use an environment variable for a one-time override:

```bash
OLLAMA_MODEL=qwen3-coder:30b python3 chat.py
```

For a persistent default, change the `model` value in `config.toml`. The
`context_length` setting defaults to 8,192 to keep the partially offloaded 70B
models within the available memory. Override it with `--context-length` or the
`OLLAMA_CONTEXT_LENGTH` environment variable.

## 11. Verify the coding model uses the GPU

Generate once, then immediately inspect the loaded runner:

```bash
python3 chat.py --model qwen3-coder:30b \
  "Reply exactly: coder residency test"
ollama ps
```

The verified result was:

```text
NAME               SIZE     PROCESSOR    CONTEXT
qwen3-coder:30b    21 GB    100% GPU     32768
```

Ollama unloads idle models after several minutes, so `ollama ps` may be empty if
you wait too long after generation. That is normal; generate again and rerun the
check immediately.

## 12. Optional: increase WSL memory for larger offloaded models

This step was prepared but not applied to the verified 20B and 30B setup. It is
not needed for those models. For 70B-class experiments, create this file in
Windows:

```text
%UserProfile%\.wslconfig
```

Use:

```ini
[wsl2]
memory=56GB
processors=28
swap=24GB
localhostForwarding=true

[experimental]
autoMemoryReclaim=gradual
sparseVhd=true
```

Apply it from PowerShell:

```powershell
wsl --shutdown
```

Reopen Ubuntu and confirm:

```bash
free -h
```

This reserves some host CPU and RAM for Windows instead of assigning the entire
machine to WSL.

## 13. Verify the 70B-class models

Run one large model at a time with an 8K context, then inspect its split:

```bash
python3 chat.py --model llama3.3:70b --context-length 8192 \
  "Reply exactly: llama 70b ready"
ollama ps

python3 chat.py --model deepseek-r1:70b --context-length 8192 \
  "Reply exactly: deepseek 70b ready"
ollama ps

python3 chat.py --model qwen2.5:72b --context-length 8192 \
  "Reply exactly: qwen 72b ready"
ollama ps
```

The measured results on the RTX 5090 were:

| Model | Loaded size | Processor split | Context |
| --- | ---: | --- | ---: |
| `llama3.3:70b` | 45 GB | 32% CPU / 68% GPU | 8192 |
| `deepseek-r1:70b` | 45 GB | 32% CPU / 68% GPU | 8192 |
| `qwen2.5:72b` | 50 GB | 39% CPU / 61% GPU | 8192 |

These models are slower than the fully GPU-resident 20B and 30B models. Small
swap usage during model changes is normal in this configuration. Ollama evicts
the previous large model when another one needs its memory.

## Service and model maintenance

Check service status and logs:

```bash
systemctl --user status ollama.service
journalctl --user -u ollama.service -n 100 --no-pager
```

Restart the model server:

```bash
systemctl --user restart ollama.service
```

List, add, or remove models:

```bash
ollama list
ollama pull MODEL_NAME
ollama rm MODEL_NAME
```

Watch GPU usage during generation:

```bash
watch -n 1 nvidia-smi
```

Check the API without the Python client:

```bash
curl --fail --silent http://127.0.0.1:11434/api/version
curl --fail --silent http://127.0.0.1:11434/api/tags
curl --fail --silent http://127.0.0.1:11434/api/ps
```

## Final verification checklist

- `nvidia-smi` works inside WSL and identifies the RTX 5090.
- `systemctl --user is-active ollama.service` prints `active`.
- `ollama list` shows all five downloaded models.
- `python3 chat.py --list-models` shows all five models.
- A prompt sent to each model returns a response.
- `ollama ps` reports `100% GPU` for the 20B and 30B models.
- `ollama ps` reports the documented CPU/GPU split for each 70B-class model.
- Model files are under `~/.ollama`, not the OneDrive project directory.
