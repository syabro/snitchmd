#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["tiktoken"]
# ///
"""Compare raw curl HTML size with snitchmd Markdown size in tokens."""

from __future__ import annotations

import subprocess
from pathlib import Path

import tiktoken


URLS = [
    "https://www.cloudflare.com/learning/bots/what-is-a-bot/",
    "https://docs.docker.com/engine/install/",
    "https://en.wikipedia.org/wiki/LLM",
    "https://github.com/anthropics/anthropic-sdk-python",
    "https://corrode.dev/blog/bugs-rust-wont-catch/",
]

RAW_HTML_PATH = Path("/tmp/raw.html")
encoding = tiktoken.get_encoding("cl100k_base")


def count_tokens(text: str) -> int:
    return len(encoding.encode(text))


def format_tokens(tokens: int) -> str:
    return f"{tokens / 1000:.1f}k"


def format_url(url: str) -> str:
    return url


def curl_url(url: str) -> tuple[str, int]:
    result = subprocess.run(
        ["curl", "-sL", "-o", str(RAW_HTML_PATH), "-w", "%{http_code}", url],
        check=False,
        capture_output=True,
        text=True,
    )
    http_code = result.stdout.strip() or "000"
    raw_html = RAW_HTML_PATH.read_text(encoding="utf-8", errors="replace")
    return http_code, count_tokens(raw_html)


def snitchmd_url(url: str) -> int:
    result = subprocess.run(
        ["snitchmd", url],
        check=False,
        capture_output=True,
        text=True,
    )
    return count_tokens(result.stdout)


def format_curl_cell(http_code: str, raw_tokens: int) -> str:
    if http_code != "200":
        return f"❌ HTTP {http_code}"
    return format_tokens(raw_tokens)


def format_reduction_cell(http_code: str, raw_tokens: int, md_tokens: int) -> str:
    if http_code != "200" or raw_tokens == 0:
        return "—"

    reduced_percent = round((1 - md_tokens / raw_tokens) * 100)
    return f"{reduced_percent}%"


def main() -> int:
    print("| URL | curl | snitchmd | reduction |")
    print("|----------------------------------------------------------------|--------|----------|-----------|")

    for url in URLS:
        http_code, raw_tokens = curl_url(url)
        md_tokens = snitchmd_url(url)
        print(
            f"| {format_url(url)} | "
            f"{format_curl_cell(http_code, raw_tokens)} | "
            f"{format_tokens(md_tokens)} | "
            f"{format_reduction_cell(http_code, raw_tokens, md_tokens)} |"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
