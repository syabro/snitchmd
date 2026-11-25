---
name: snitchmd
description: Use instead of curl, wget or WebFetch to read a web page's text: prints only the main content as Markdown, without scripts, styles and navigation that waste context in raw HTML. Also gets pages where a plain fetch returns a bot block or an empty JavaScript shell.
allowed-tools: Bash(snitchmd:*)
user-invocable: false
---

# snitchmd

Converts any URL to clean Markdown. One command, stdout, ready for an LLM prompt or a note.

## Pipeline

A single binary: [Lightpanda](https://github.com/lightpanda-io/browser), a headless browser patched
to replicate Safari 27 (TLS, HTTP/2, User-Agent, JS identity). It executes page JavaScript, waits
for the DOM to settle (up to 30 s), and extracts main content via
[rs-trafilatura](https://github.com/Murrough-Foley/rs-trafilatura), stripping navigation, footers,
and banners.

**Output.** Markdown to **stdout**; one summary line to **stderr**: title, extraction quality (0–1),
character count, and `(cached)` for a cache hit.

**Cache.** Successful fetches are cached on disk by URL + options. `--no-cache` fetches again.
Results with quality below 0.5 are printed but not cached (`(not cached: low quality)` on stderr).
`--json`, `--html-output` and `--dump-max-bytes` share the cache entry.

**Exit codes.** `0` success, `1` error (network, browser, bad option, bot challenge; message on stderr),
`2` no main content (a loading shell, a wall, or an empty page), `22` HTTP status 400 or higher.

**Limits.** Passive bot checks (TLS fingerprint, User-Agent, JS identity) pass. Interactive
CAPTCHAs are not solved; a bot challenge that does not pass by itself ends with exit code `1`.

## Usage

```bash
snitchmd https://example.com            # Markdown to stdout
snitchmd https://example.com > page.md  # save to file
snitchmd --json https://example.com     # {url, final_url, title, page_title, page_type, quality, chars, markdown}
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

## Fixes for wrong output

- Exit 2 or a near-empty result: `--wait-selector` for the content element, or a larger
  `--wait-ms`.

- Content behind a "Show more" button:
  `--script "document.querySelector('button.more').click()"`.

- Wrong block extracted: `--dump-selector` with the article's CSS selector, or `--dump markdown_full`
  for the whole page (needed on X profiles and Facebook pages).

- Too much boilerplate: `--favor-precision`.

- Content missing: `--favor-recall`.

- Stale result: `--no-cache`.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/syabro/snitchmd/master/install.sh | bash
```
