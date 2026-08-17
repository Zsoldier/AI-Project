#!/usr/bin/env python3
import argparse
import json
import os
import sys
import tomllib
import urllib.error
import urllib.request
from pathlib import Path


with Path(__file__).with_name("config.toml").open("rb") as config_file:
    config = tomllib.load(config_file)

HOST = os.environ.get("OLLAMA_HOST", config["host"]).rstrip("/")
DEFAULT_MODEL = os.environ.get("OLLAMA_MODEL", config["model"])
DEFAULT_CONTEXT_LENGTH = int(
    os.environ.get("OLLAMA_CONTEXT_LENGTH", config["context_length"])
)
DEFAULT_KEEP_ALIVE = os.environ.get("OLLAMA_KEEP_ALIVE", config["keep_alive"])


def list_models() -> list[str]:
    try:
        with urllib.request.urlopen(f"{HOST}/api/tags") as response:
            data = json.load(response)
    except urllib.error.URLError as error:
        raise SystemExit(
            f"Cannot reach Ollama at {HOST}: {error.reason}. "
            "Run bash scripts/install-ollama.sh first."
        ) from error
    return [model["name"] for model in data.get("models", [])]


def print_models(active_model: str) -> None:
    models = list_models()
    if not models:
        print("No models installed. Run: ollama pull <model>")
        return
    for model in models:
        marker = "*" if model == active_model else " "
        print(f"{marker} {model}")


def stream_chat(
    model: str,
    context_length: int,
    keep_alive: str,
    messages: list[dict[str, str]],
) -> str:
    payload = json.dumps(
        {
            "model": model,
            "messages": messages,
            "stream": True,
            "keep_alive": keep_alive,
            "options": {"num_ctx": context_length},
        }
    ).encode()
    request = urllib.request.Request(
        f"{HOST}/api/chat",
        data=payload,
        headers={"Content-Type": "application/json"},
    )
    response_text = []
    try:
        with urllib.request.urlopen(request) as response:
            for line in response:
                event = json.loads(line)
                content = event.get("message", {}).get("content", "")
                print(content, end="", flush=True)
                response_text.append(content)
    except urllib.error.URLError as error:
        raise SystemExit(
            f"Cannot reach Ollama at {HOST}: {error.reason}. "
            "Run bash scripts/install-ollama.sh first."
        ) from error
    print()
    return "".join(response_text)


def main() -> None:
    parser = argparse.ArgumentParser(description="Chat with local Ollama models")
    parser.add_argument("prompt", nargs="*", help="one-shot prompt")
    parser.add_argument("-m", "--model", default=DEFAULT_MODEL)
    parser.add_argument(
        "-c", "--context-length", type=int, default=DEFAULT_CONTEXT_LENGTH
    )
    parser.add_argument("--keep-alive", default=DEFAULT_KEEP_ALIVE)
    parser.add_argument(
        "--list-models", action="store_true", help="list installed models and exit"
    )
    args = parser.parse_args()

    model = args.model
    if args.list_models:
        print_models(model)
        return

    messages: list[dict[str, str]] = []
    if args.prompt:
        stream_chat(
            model,
            args.context_length,
            args.keep_alive,
            [{"role": "user", "content": " ".join(args.prompt)}],
        )
        return

    print(
        f"Model: {model}, context: {args.context_length} "
        "(/models lists models, /model NAME switches)"
    )
    while True:
        try:
            prompt = input("you> ").strip()
        except EOFError:
            print()
            break
        if prompt in {"/quit", "/exit"}:
            break
        if prompt == "/models":
            print_models(model)
            continue
        if prompt.startswith("/model "):
            requested_model = prompt.removeprefix("/model ").strip()
            if requested_model not in list_models():
                print(f"Model not installed: {requested_model}")
                continue
            model = requested_model
            messages.clear()
            print(f"Switched to {model}; conversation cleared.")
            continue
        if not prompt:
            continue
        messages.append({"role": "user", "content": prompt})
        answer = stream_chat(model, args.context_length, args.keep_alive, messages)
        messages.append({"role": "assistant", "content": answer})


if __name__ == "__main__":
    main()
