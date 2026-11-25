# Design

Evidence comes from the 2026-11-22 comparison runs (35 sites, 6 bot detectors, one home IP); the sites are listed in [test-sites.md](test-sites.md).

## Terms

- **v1**: the previous snitchmd, a Docker image with CloakBrowser (patched Chromium).
- **prototype**: the Lightpanda build tested on 2026-11-22, before release.
- **v2**: released snitchmd 2.0.0.

Exit codes: 0 success; 1 error, including bot challenge; 2 no main content; 22 HTTP status 400 or higher.

## How it works

`snitchmd URL` is Lightpanda's `fetch` command with patches:

1. **Network: Safari 27.** curl-impersonate's curl and BoringSSL patches, profile `safari270`, set on every connection. TLS (JA3/JA4) and HTTP/2 (SETTINGS, WINDOW_UPDATE, pseudo-header order) match real Safari. Headers come from Lightpanda; curl-impersonate's built-in browser header list is turned off.
2. **Identity: Safari.** `fetch` defaults to the Safari 27 User-Agent and sends no `Sec-Ch-Ua*` headers, because Safari doesn't send them. `safari.js` runs in every page before the page's own scripts. It removes `navigator.userAgentData` and sets `navigator.vendor` to Apple.
3. **Page: Lightpanda's engine.** V8, no rendering. It waits until the page settles (`--wait-until done`, up to 30 s), so JS challenges have time to finish. `style-index.js` patches a Lightpanda gap that React sites hit.
4. **Extraction: rs-trafilatura.** The rendered DOM goes to rs-trafilatura, which returns the main content as Markdown and a quality score (0–1).
5. **Around it (`src/snitchmd.zig`):** result cache, stderr summary, `--json`, exit codes. Results with quality < 0.5 are not cached.

Only `fetch` gets steps 2–5. `mcp` and `serve` get the Safari network fingerprint but not the identity or the extraction.

## Decisions

### Lightpanda instead of Chromium (CloakBrowser)

- v1 (CloakBrowser 0.3.31, Chromium 146) passed most detectors, but its network fingerprint is Chromium 146. Reddit sends that straight to a captcha (5 of 5), before any JS runs. JS-level stealth can't fix this.
- Current CloakBrowser (0.7.x, Chromium 156) needs a license key.
- Chromium means Docker, a ~1 GB image, and a slow start. Lightpanda is one ~75 MB binary.
- Plain Lightpanda 1.0.5 with a long wait already got 28 ✓ / 2 ◐ / 5 × on 35 sites, against v1's 27 / 1 / 5 on 33.

Trade-off: there is no rendering, so detectors that check WebGL, canvas, or plugins see a non-browser (sannysoft: 7 failed). Sites that need those checks will fail.

### Safari, not Chrome, as the network fingerprint

First request, no JS (curl_cffi 0.17, same IP):

| Profile    | FT    | Quora | Reddit       |
| ---------- | ----- | ----- | ------------ |
| Safari     | ✓     | ✓     | JS challenge |
| Chrome 152 | block | ✓     | JS challenge |
| Firefox    | block | block | JS challenge |

In a test that varied network settings and headers separately, only the network settings changed the outcome; User-Agent and headers did not. Safari also skips `Sec-Ch-Ua` and `userAgentData`, so Lightpanda has fewer Chrome-specific APIs to fake. With Safari added, the prototype went from 28 / 2 / 3 to 30 / 2 / 1 on 33 sites (2026-11-22; FT and Quora opened).

### Patch Lightpanda, don't wrap it

Neither behavior is configurable by a flag. Lightpanda rejects any User-Agent containing "Mozilla" and always sends `Sec-Ch-Ua: "Lightpanda"`. TLS and HTTP/2 settings need a patched libcurl. So we ship a source patch and our own build. AGPL-3.0 allows this as long as the patches are published (they are, in `patches/`).

### rs-trafilatura for Markdown

Lightpanda's own `--dump markdown` keeps the whole page (2–5× bigger, with menus and footers). `--strip-mode clutter` is close in size, but it lost MDN's title, barely cleaned Goodreads, and ran paragraphs together. rs-trafilatura keeps the main text, reports a quality score, and is a Rust crate that links into the binary (no Python). Lightpanda's converter stays available as `--dump markdown_full`.

### Wait for the page to settle

Given time, Lightpanda passes the Cloudflare, AWS WAF, and Tumblr JS challenges on StackOverflow, IMDb, Tumblr, and Quora by itself. With `--wait-until networkalmostidle --wait-ms 12000` they were blocked. With `--wait-until done --wait-ms 30000` they opened. So the default is `done` with a 30 s wait.

## Alternatives

| Tool                                                            | Result on 35 sites                              | Why not                                                                                          |
| --------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| headless Chromium under chrome-cli (AppleScript, no CDP)        | 32 ✓ / 2 ◐ / 1 × — best; passes all 6 detectors | macOS only, needs the GUI app, one instance per bundle id                                        |
| Obscura 0.2.7 `--stealth` (Rust + V8, Chrome 145 network)       | 25 / 3 / 5                                      | doesn't pass Cloudflare/AWS WAF/Tumblr JS challenges even after 35 s; stalls in Turnstile iframe |
| Firecrawl Local, `--browser always`, no cloud                   | 25 / 2 / 5 (+1 error) of 33                     | plain automated Chromium (`webdriver: true`, CDP); real anti-bot work is in their cloud          |
| snitchmd v1 (CloakBrowser)                                      | 27 / 1 / 5 of 33                                | see above; also truncated stdout at 64 KB                                                        |
| curl_cffi `safari`, no JS                                       | 13 content of 33                                | no JS: challenges and JS-built pages fail                                                        |
| Real Firefox 160 headless                                       | FT, Quora, Reddit ✓ (spot check)                | needs Firefox; curl_cffi's Firefox profile is worse than the real one                            |
| Lightpanda with UA `OpenAI File Downloader` (the tweet's trick) | 18 / 6 / 11                                     | worse than default; doesn't reproduce from this IP                                               |

## Open questions

- v2 has not been run over the full lists in test-sites.md. The only v2 results are two spot checks on 2026-11-24 (WSJ, Quora). The numbers above are the prototype's.
- DataDome (NYTimes, The Athletic, WSJ): blocks depended on IP reputation that day. It is unknown whether the Safari network + Lightpanda setup passes from a clean IP.
- Which part of HTTP/2 triggers Reddit's captcha rule is not pinned down. Fresh sessions without cookies get worse treatment.
- Only the quality score catches login walls and soft blocks served with HTTP 200.
- Open bugs: Flickr emoji panic; Wikipedia table bloat (rs-trafilatura).
- Not done: identity in `mcp`/`serve`, and trafilatura in MCP's `markdown` tool.
