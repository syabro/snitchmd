# Design

Why snitchmd v2 is built the way it is. Evidence comes from the 2026-11-22
comparison runs (35 sites, 6 bot detectors, one home IP); sites are listed in
[test-sites.md](test-sites.md).

## How it works

`snitchmd URL` is Lightpanda's `fetch` with patches:

1. **Network: Safari 27.** curl-impersonate's curl and BoringSSL patches, profile
   `safari270`, set on every connection. TLS (JA3/JA4) and HTTP/2 (SETTINGS,
   WINDOW_UPDATE, pseudo-header order) match real Safari. Lightpanda sends its own
   headers; curl-impersonate's header list is off.
2. **Identity: Safari.** `fetch` defaults to the Safari 27 User-Agent and sends no
   `Sec-Ch-Ua*` (Safari doesn't). `safari.js` runs in every page before its own
   scripts: removes `navigator.userAgentData`, sets `navigator.vendor` to Apple.
3. **Page: Lightpanda's engine.** V8, no rendering. Waits until the page settles
   (`--wait-until done`, up to 30 s), so JS challenges get time to finish.
   `style-index.js` patches a Lightpanda gap React sites trip on.
4. **Extraction: rs-trafilatura.** The rendered DOM goes to rs-trafilatura, which
   returns the main content as Markdown plus a quality score (0–1).
5. **Around it (`src/snitchmd.zig`):** result cache, stderr summary, `--json`,
   exit codes (2 no content, 22 HTTP 400+, 1 bot challenge or other error),
   no cache for quality < 0.5.

Only `fetch` gets steps 2–5. `mcp` and `serve` get the Safari network fingerprint
but not the identity or the extraction.

## Decisions

### Lightpanda instead of Chromium (CloakBrowser)

- v1 (CloakBrowser 0.3.31, Chromium 146) passed most detectors but its network
  fingerprint is Chromium 146, which Reddit sends straight to a captcha (5 of 5),
  before any JS runs. JS-level stealth can't fix that.
- Current CloakBrowser (0.7.x, Chromium 156) needs a license key.
- Chromium means Docker, ~1 GB image, slow start. Lightpanda is one ~75 MB
  binary.
- Plain Lightpanda 1.0.5 with a long wait already got 28 ✓ / 2 ◐ / 5 × on 35
  sites, against v1's 27 / 1 / 5 on 33.

Cost: no rendering, so detectors that check WebGL, canvas or plugins see a
non-browser (sannysoft 7 failed). Sites that need those will fail.

### Safari, not Chrome, as the network fingerprint

On the first request, with no JS (curl_cffi 0.17, same IP):

| Profile | FT | Quora | Reddit |
|---|---|---|---|
| Safari | ✓ | ✓ | JS challenge |
| Chrome 152 | block | ✓ | JS challenge |
| Firefox | block | block | JS challenge |

Mixing network and headers showed the network layer decides; User-Agent and
headers don't. Safari also skips `Sec-Ch-Ua`/`userAgentData`, so Lightpanda has
fewer Chrome-specific APIs to fake. With Safari added, the prototype went from
28 / 2 / 3 to 30 / 2 / 1 on 33 sites (FT and Quora opened).

### Patch Lightpanda, don't wrap it

Lightpanda refuses any User-Agent containing "Mozilla" and always sends
`Sec-Ch-Ua: "Lightpanda"`; neither is a flag. TLS and HTTP/2 settings need a
patched libcurl. So it's a source patch and our own build, which AGPL-3.0 allows
as long as the patches are published (they are, in `patches/`).

### rs-trafilatura for Markdown

Lightpanda's own `--dump markdown` keeps the whole page (2–5× bigger, menus and
footers). `--strip-mode clutter` is close in size but lost MDN's title, barely
cleaned Goodreads, and runs paragraphs together. rs-trafilatura keeps the main
text, reports a quality score, and is a Rust crate that links into the binary
(no Python). Lightpanda's converter stays as `--dump markdown_full`.

### Wait for the page to settle

Lightpanda passes the Cloudflare, AWS WAF and Tumblr JS challenges on
StackOverflow, IMDb, Tumblr and Quora by itself, given time: with
`--wait-until networkalmostidle --wait-ms 12000` they were blocks, with
`--wait-until done --wait-ms 30000` they opened. Hence the 30 s default.

## Alternatives

| Tool | Result on 35 sites | Why not |
|---|---|---|
| headless Chromium under chrome-cli (AppleScript, no CDP) | 32 ✓ / 2 ◐ / 1 × — best; passes all 6 detectors | macOS only, needs the GUI app, one instance per bundle id |
| Obscura 0.2.7 `--stealth` (Rust + V8, Chrome 145 network) | 25 / 3 / 5 | doesn't pass Cloudflare/AWS WAF/Tumblr JS challenges even after 35 s; stalls in Turnstile iframe |
| Firecrawl Local, `--browser always`, no cloud | 25 / 2 / 5 (+1 error) of 33 | plain automated Chromium (`webdriver: true`, CDP); real anti-bot work is in their cloud |
| snitchmd v1 (CloakBrowser) | 27 / 1 / 5 of 33 | see above; also cut stdout at 64 KB |
| curl_cffi `safari`, no JS | 13 content of 33 | no JS: challenges and JS-built pages fail |
| Real Firefox 160 headless | FT, Quora, Reddit ✓ (spot check) | needs Firefox; curl_cffi's Firefox profile is worse than the real one |
| Lightpanda with UA `OpenAI File Downloader` (the tweet's trick) | 18 / 6 / 11 | worse than default; doesn't reproduce from this IP |

## Open questions

- v2 hasn't been run over all of test-sites.md; the numbers above are the
  prototype's.
- DataDome (NYTimes, The Athletic, WSJ): blocks depended on IP reputation that
  day; whether Safari network + Lightpanda passes from a clean IP is unknown.
- Reddit's captcha rule (which part of HTTP/2) isn't pinned down; fresh
  sessions without cookies are treated worse.
- Login walls and soft blocks served with 200 are only caught by the quality
  score.
- Flickr emoji panic, Wikipedia table bloat (rs-trafilatura).
- Identity in `mcp`/`serve` and trafilatura in MCP's `markdown` tool: not done.
