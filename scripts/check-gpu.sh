#!/usr/bin/env bash
set -euo pipefail

echo "== GPU =="
nvidia-smi --query-gpu=name,memory.total,driver_version,compute_cap \
  --format=csv,noheader

echo
echo "== WSL memory =="
free -h

echo
echo "== Storage =="
df -h / "$HOME"
