---
name: snitchmd
description: Converts any web page URL to LLM-ready Markdown via a headless browser. Bypasses passive anti-bot fingerprinting and JavaScript rendering, then strips navigation, footers, scripts, and cookie banners. Triggered by URLs that need the actual readable page content.
allowed-tools: Bash(snitchmd:*)
user-invocable: false
---

# snitchmd

Converts any URL to clean Markdown. One command, stdout, ready for an LLM prompt or a note.

## Pipeline

One binary: [Lightpanda](https://github.com/lightpanda-io/browser), a headless browser, patched to
connect like Safari 27 (TLS, HTTP/2, User-Agent, JS identity). It runs the page's JavaScript, waits
until the page settles (30 s cap), then [rs-trafilatura](https://github.com/Murrough-Foley/rs-trafilatura)
extracts the main content as Markdown, without navigation, footers and banners.

**Output.** Markdown to **stdout**; one summary line to **stderr**: title, extraction quality (0–1),
character count, and `(cached)` for a cache hit.

**Cache.** Successful fetches are cached on disk by URL + options. `--no-cache` fetches again.
Results with quality below 0.5 are printed but not cached (`(not cached: low quality)` on stderr).
`--json`, `--html-output` and `--dump-max-bytes` share the cache entry.

**Exit codes.** `0` success, `1` error (network, browser, bad option, bot challenge; message on stderr),
`2` no main content (a loading shell, a wall, or an empty page), `22` HTTP status 400 or higher.

**Limits.** Passive bot checks (TLS fingerprint, User-Agent, JS identity) pass. Interactive
CAPTCHAs are not solved; a Cloudflare "Just a moment..." page comes back as the content.

## Usage

```bash
snitchmd https://example.com            # Markdown to stdout
snitchmd https://example.com > page.md  # save to file
snitchmd https://example.com --json     # {url, final_url, title, page_title, page_type, quality, chars, markdown}
```

Options (all `lightpanda fetch` options work; full list: `snitchmd help fetch`):

```text
  --json                    Markdown with metadata as JSON
  --no-cache                Fetch again instead of answering from the cache
  --html-output FILE        Also save the rendered HTML
  --include-images          Keep image references
  --favor-precision         Cut more boilerplate, even if some content is lost
  --favor-recall            Keep more content, even if some boilerplate remains
  --dump-selector CSS       Extract only from the first matching element
  --wait-selector CSS       Wait for an element before extracting
  --script JS               Run JS in the page before extracting (e.g. click "Show more")
  --script-file PATH        Same, script read from a file
  --wait-ms N               Wait cap in ms (default 30000)
  --dump-max-bytes N        Cut the Markdown at N bytes, ending with [truncated]
  --http-proxy URL          Proxy
  --locale TAG              Browser locale, e.g. en-US
  --timezone IANA           Time zone, e.g. Europe/Berlin
  --dump html               Rendered HTML instead of Markdown
```

## When the output is wrong

| Symptom | Try |
|---|---|
| Exit 2 or a near-empty result | `--wait-selector` for the content element, or a larger `--wait-ms` |
| Content behind a "Show more" button | `--script "document.querySelector('button.more').click()"` |
| Wrong block extracted | `--dump-selector` with the article's CSS selector |
| Too much boilerplate | `--favor-precision` |
| Content missing | `--favor-recall` |
| Stale result | `--no-cache` |

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/syabro/snitchmd/master/install.sh | bash
```

Prebuilt for macOS arm64, Linux x86_64 (glibc 2.35+) and Linux arm64 (glibc 2.38+).
