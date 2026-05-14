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
Usage: snitchmd URL [options]

Render a web page with CloakBrowser, then convert the HTML to Markdown.

Options:
  --json                       Output JSON with metadata and markdown
  --html-output FILE           Also save rendered HTML to this file
  --no-cache                   Bypass the on-disk cache (forces a fresh fetch)
  --timeout SECONDS            Page load timeout (default: 45)
  --wait SECONDS               Extra wait after page load (default: 0)
  --wait-until STATE           Playwright goto wait condition; one of
                               commit | domcontentloaded | load | networkidle
                               (default: domcontentloaded)
  --wait-for-selector CSS      Wait for a CSS selector before extraction
  --headful                    Run headed Chromium under Xvfb instead of headless
  --humanize                   Enable CloakBrowser human-like mouse/keyboard/scroll
  --proxy URL                  Proxy URL (http://user:pass@host:8080 or socks5://...)
  --timezone IANA              IANA timezone fingerprint (e.g. Europe/Berlin)
  --locale TAG                 Browser locale (e.g. en-US)
  --include-links              Preserve links in extracted Markdown
  --include-images             Include image references in extracted Markdown
  --favor-precision            Prefer less boilerplate, even if some content is lost
                               (mutually exclusive with --favor-recall)
  --favor-recall               Prefer more content, even if some boilerplate remains
                               (mutually exclusive with --favor-precision)
  --max-chars N                Truncate Markdown output to at most N characters
                               (appends "\n\n[truncated]"). Default: no limit.
  -h, --help                   Show this message and exit
```
<!-- END: snitchmd --help -->

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/syabro/snitchmd/master/install.sh | bash
```

Requires Docker. If install or runtime is broken, see [README troubleshooting](https://github.com/syabro/snitchmd/blob/master/README.md#troubleshooting).
