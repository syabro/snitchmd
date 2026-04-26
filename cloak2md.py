#!/usr/bin/env python3
"""Render a URL with CloakBrowser and extract clean Markdown with rs-trafilatura."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from cloakbrowser import launch
import rs_trafilatura


def positive_int(value: str) -> int:
    parsed = int(value)
    if parsed < 0:
        raise argparse.ArgumentTypeError("must be >= 0")
    return parsed


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="cloak2md",
        description="Render a web page with CloakBrowser, then convert the HTML to Markdown.",
    )
    parser.add_argument("url", help="URL to render")
    parser.add_argument("--json", action="store_true", help="Output JSON with metadata and markdown")
    parser.add_argument("--html-output", help="Also save rendered HTML to this file")
    parser.add_argument("--timeout", type=positive_int, default=45, help="Page load timeout in seconds (default: 45)")
    parser.add_argument("--wait", type=positive_int, default=0, help="Extra wait after page load in seconds")
    parser.add_argument("--wait-until", default="domcontentloaded", choices=["commit", "domcontentloaded", "load", "networkidle"], help="Playwright goto wait condition")
    parser.add_argument("--wait-for-selector", help="Wait for a CSS selector before extraction")
    parser.add_argument("--headful", action="store_true", help="Run headed Chromium under Xvfb instead of headless")
    parser.add_argument("--humanize", action="store_true", help="Enable CloakBrowser human-like mouse/keyboard/scroll patching")
    parser.add_argument("--proxy", help="Proxy URL, e.g. http://user:pass@host:8080 or socks5://host:1080")
    parser.add_argument("--timezone", help="IANA timezone fingerprint, e.g. Europe/Berlin")
    parser.add_argument("--locale", help="Browser locale, e.g. en-US")
    parser.add_argument("--include-links", action="store_true", help="Preserve links in Markdown when rs-trafilatura can")
    parser.add_argument("--include-images", action="store_true", help="Include image data when rs-trafilatura can")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--favor-precision", action="store_true", help="Prefer less boilerplate, even if some content is lost")
    mode.add_argument("--favor-recall", action="store_true", help="Prefer more content, even if some boilerplate remains")
    return parser


def render_html(args: argparse.Namespace) -> tuple[str, str, str]:
    browser = launch(
        headless=not args.headful,
        proxy=args.proxy,
        timezone=args.timezone,
        locale=args.locale,
        humanize=args.humanize,
        args=["--no-sandbox", "--disable-dev-shm-usage"],
    )
    try:
        page = browser.new_page()
        page.goto(args.url, wait_until=args.wait_until, timeout=args.timeout * 1000)
        if args.wait_for_selector:
            page.wait_for_selector(args.wait_for_selector, timeout=args.timeout * 1000)
        if args.wait:
            page.wait_for_timeout(args.wait * 1000)
        return page.content(), page.title(), page.url
    finally:
        browser.close()


def extract_markdown(html: str, url: str, args: argparse.Namespace):
    return rs_trafilatura.extract(
        html,
        url=url,
        output_markdown=True,
        include_links=args.include_links,
        include_images=args.include_images,
        favor_precision=args.favor_precision,
        favor_recall=args.favor_recall,
    )


def main() -> int:
    args = build_parser().parse_args()

    try:
        html, page_title, final_url = render_html(args)
        if args.html_output:
            Path(args.html_output).write_text(html, encoding="utf-8")

        result = extract_markdown(html, final_url, args)
        markdown = (getattr(result, "content_markdown", None) or getattr(result, "main_content", None) or "").strip()
        if not markdown:
            print("cloak2md: extraction returned empty content", file=sys.stderr)
            return 2

        payload = {
            "url": args.url,
            "final_url": final_url,
            "title": getattr(result, "title", None) or page_title,
            "page_title": page_title,
            "page_type": getattr(result, "page_type", None),
            "quality": getattr(result, "extraction_quality", None),
            "chars": len(markdown),
            "markdown": markdown,
        }

        if args.json:
            sys.stdout.write(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")
        else:
            sys.stdout.write(markdown + "\n")

        print(
            f"cloak2md: title={payload['title']!r} quality={payload['quality']} chars={payload['chars']}",
            file=sys.stderr,
        )
        return 0
    except Exception as exc:
        print(f"cloak2md: {type(exc).__name__}: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
