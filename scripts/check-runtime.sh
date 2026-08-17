#!/usr/bin/env bash
set -euo pipefail

echo "== Ollama =="
curl --fail --silent http://127.0.0.1:11434/api/version
echo

echo "== Loaded models =="
ollama ps

echo
echo "== GPU utilization =="
nvidia-smi --query-compute-apps=process_name,used_memory --format=csv,noheader
