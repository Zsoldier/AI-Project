#!/usr/bin/env bash
set -euo pipefail

install_root="${HOME}/.local"
archive="$(mktemp --suffix=.tar.zst)"
trap 'rm -f "$archive"' EXIT
mkdir -p "$install_root"
export PATH="${install_root}/bin:${PATH}"

echo "Downloading Ollama..."
curl --fail --location --progress-bar \
  https://ollama.com/download/ollama-linux-amd64.tar.zst \
  --output "$archive"
if command -v unzstd >/dev/null; then
  tar --extract --use-compress-program=unzstd --file="$archive" \
    --directory="$install_root"
else
  python3 -c 'import shutil, sys; from compression import zstd; source = zstd.open(sys.argv[1], "rb"); shutil.copyfileobj(source, sys.stdout.buffer)' \
    "$archive" | tar --extract --file=- --directory="$install_root"
fi

mkdir -p "${HOME}/.config/systemd/user"
cat > "${HOME}/.config/systemd/user/ollama.service" <<EOF
[Unit]
Description=Ollama local model server
After=network-online.target

[Service]
ExecStart=${install_root}/bin/ollama serve
Environment=OLLAMA_HOST=127.0.0.1:11434
Environment=OLLAMA_MODELS=${HOME}/.ollama/models
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now ollama.service
echo "Installed $(ollama --version)"
echo "Service status: $(systemctl --user is-active ollama.service)"
