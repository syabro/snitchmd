---
name: snitchmd
description: Converts any web page URL to LLM-ready Markdown via a headless browser. Bypasses passive anti-bot fingerprinting and JavaScript rendering, then strips navigation, footers, scripts, and cookie banners. Triggered by URLs that need the actual readable page content.
allowed-tools: Bash(snitchmd:*)
user-invocable: false
---

# snitchmd

Converts any URL to clean Markdown. One command, stdout, ready for an LLM prompt or a note.

## How it works

Two-stage pipeline inside a Docker container:

1. **CloakBrowser** — headless Chromium with anti-bot patches: spoofed fingerprints, optional humanized mouse/keyboard, optional Xvfb headed mode, configurable proxy/timezone/locale. Loads the URL and waits.
2. **rs-trafilatura** — takes the rendered HTML and extracts the main content as Markdown. Boilerplate trim is tunable (favor-precision drops more, favor-recall keeps more); links and images are stripped by default.

**Output.** Markdown to **stdout**; one-line summary to **stderr** with title, extraction quality, char count, and `(cached)` if served from disk.

**Cache.** Successful fetches are cached on disk by URL + content-affecting flags. Bypass with `--no-cache`. Output-only flags (`--json`, `--html-output`) share a cache entry.

**Exit codes.** `0` success, `1` runtime error (browser, network), `2` extraction returned empty content.

**Bot detection.** Cloudflare, reCAPTCHA v3, FingerprintJS and 30+ other detectors don't flag CloakBrowser as a bot — see [test results](https://github.com/CloakHQ/CloakBrowser#test-results). Interactive "click all the traffic lights" CAPTCHAs (reCAPTCHA v2, hCaptcha) are not solved.

## Usage

```bash
snitchmd https://example.com            # Markdown to stdout
snitchmd https://example.com > page.md  # save to file
snitchmd https://example.com --json     # metadata + char count
```

<!-- BEGIN: snitchmd --help -->
```text
usage: snitchmd [-h] [--json] [--html-output HTML_OUTPUT] [--no-cache]
                [--timeout TIMEOUT] [--wait WAIT]
                [--wait-until {commit,domcontentloaded,load,networkidle}]
                [--wait-for-selector WAIT_FOR_SELECTOR] [--headful]
                [--humanize] [--proxy PROXY] [--timezone TIMEZONE]
                [--locale LOCALE] [--include-links] [--include-images]
                [--favor-precision | --favor-recall]
                url

Render a web page with CloakBrowser, then convert the HTML to Markdown.

positional arguments:
  url                   URL to render

options:
  -h, --help            show this help message and exit
  --json                Output JSON with metadata and markdown
  --html-output HTML_OUTPUT
                        Also save rendered HTML to this file
  --no-cache            Bypass the on-disk cache (forces a fresh fetch and
                        overwrites the cache)
  --timeout TIMEOUT     Page load timeout in seconds (default: 45)
  --wait WAIT           Extra wait after page load in seconds
  --wait-until {commit,domcontentloaded,load,networkidle}
                        Playwright goto wait condition
  --wait-for-selector WAIT_FOR_SELECTOR
                        Wait for a CSS selector before extraction
  --headful             Run headed Chromium under Xvfb instead of headless
  --humanize            Enable CloakBrowser human-like mouse/keyboard/scroll
                        patching
  --proxy PROXY         Proxy URL, e.g. http://user:pass@host:8080 or
                        socks5://host:1080
  --timezone TIMEZONE   IANA timezone fingerprint, e.g. Europe/Berlin
  --locale LOCALE       Browser locale, e.g. en-US
  --include-links       Preserve links in Markdown when rs-trafilatura can
  --include-images      Include image data when rs-trafilatura can
  --favor-precision     Prefer less boilerplate, even if some content is lost
  --favor-recall        Prefer more content, even if some boilerplate remains
```
<!-- END: snitchmd --help -->

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/syabro/snitchmd/master/install.sh | bash
```

Requires Docker. If install or runtime is broken, see [README troubleshooting](https://github.com/syabro/snitchmd/blob/master/README.md#troubleshooting).
