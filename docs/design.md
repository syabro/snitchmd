# Design

Evidence comes from the 2026-11-22 comparison runs across 35 sites and 6 bot detectors from one home IP. The sites are listed in [test-sites.md](test-sites.md).

## Terms

- **v1**: the previous snitchmd, a Docker image with CloakBrowser (patched Chromium).
- **prototype**: the Lightpanda build tested on 2026-11-22, before release.
- **v2**: released snitchmd 2.0.0.

Exit codes: 0 success; 1 error, including bot challenge; 2 no main content; 22 HTTP status 400 or higher.

## How it works

`snitchmd URL` runs Lightpanda's `fetch` command with patches:

1. **Network: Safari 27.** curl-impersonate's curl and BoringSSL patches, profile `safari270`, apply to every connection. TLS (JA3/JA4) and HTTP/2 (SETTINGS, WINDOW_UPDATE, pseudo-header order) match real Safari. Lightpanda builds the request headers itself; curl-impersonate's built-in Safari headers are disabled so headers are not sent twice.
2. **Identity: Safari.** `fetch` defaults to the Safari 27 User-Agent and sends no `Sec-Ch-Ua*` headers, because Safari omits them. `safari.js` runs in every page before the page scripts run. It removes `navigator.userAgentData` and sets `navigator.vendor` to Apple.
3. **Page: Lightpanda's engine.** V8, no rendering. It waits until the page settles (`--wait-until done`, up to 30 s) so JS challenges finish. `style-index.js` patches a Lightpanda bug that React sites hit.
4. **Extraction: rs-trafilatura.** The rendered DOM passes to rs-trafilatura, which returns the main content as Markdown and a quality score (0–1).
5. **Wrapper (`src/snitchmd.zig`):** handles the result cache, stderr summary, `--json`, and exit codes. Results with quality < 0.5 are not cached.

Only `fetch` runs steps 2–5. `mcp` and `serve` use the Safari network fingerprint without the identity or extraction steps.

## Decisions

### Lightpanda instead of Chromium (CloakBrowser)

- v1 (CloakBrowser 0.3.31, Chromium 146) passed most detectors, but its network fingerprint is Chromium 146. Reddit redirects that fingerprint directly to a captcha (5 of 5) before JS runs. JS-level stealth does not bypass this check.
- CloakBrowser 0.7.x (Chromium 156) requires a license key.
- Chromium requires Docker, a ~1 GB image, and has a slow startup. Lightpanda is a single ~75 MB binary.
- Unpatched Lightpanda 1.0.5 with a long wait scored 28 ✓ / 2 ◐ / 5 × on 35 sites, compared to v1's 27 / 1 / 5 on 33 sites.

Trade-off: Lightpanda lacks rendering, so detectors that check WebGL, canvas, or plugins identify a non-browser environment (sannysoft: 7 failed). Sites that enforce those checks will fail.

### Safari, not Chrome, as the network fingerprint

First request without JS (curl_cffi 0.17, same IP):

| Profile    | FT    | Quora | Reddit       |
| ---------- | ----- | ----- | ------------ |
| Safari     | ✓     | ✓     | JS challenge |
| Chrome 152 | block | ✓     | JS challenge |
| Firefox    | block | block | JS challenge |

In a test that varied network settings and headers separately, only network settings changed the outcome; User-Agent and headers did not. Safari also omits `Sec-Ch-Ua` and `userAgentData`, so Lightpanda does not need to emulate those Chrome-specific APIs. Adding the Safari fingerprint changed prototype results from 28 / 2 / 3 to 30 / 2 / 1 on 33 sites (2026-11-22; FT and Quora opened).

### Patch Lightpanda instead of wrapping it

Neither behavior is configurable by CLI flags. Lightpanda rejects any User-Agent containing "Mozilla" and always sends `Sec-Ch-Ua: "Lightpanda"`. TLS and HTTP/2 settings require a patched libcurl. snitchmd ships a source patch and a custom build. AGPL-3.0 permits this because the patches are published in `patches/`.

### rs-trafilatura for Markdown

Lightpanda's `--dump markdown` outputs the full page, including menus and footers (2–5× larger output). Lightpanda's `--strip-mode clutter` produces similar sizes, but it dropped MDN's title, barely reduced Goodreads, and merged paragraphs. rs-trafilatura extracts the main text, outputs a quality score, and links directly as a Rust crate without a Python runtime. Lightpanda's converter remains available under `--dump markdown_full`.

### Wait for the page to settle

Lightpanda passes Cloudflare, AWS WAF, and Tumblr JS challenges on StackOverflow, IMDb, Tumblr, and Quora if given enough execution time. With `--wait-until networkalmostidle --wait-ms 12000`, the sites blocked the requests. With `--wait-until done --wait-ms 30000`, the pages loaded. The default is therefore `--wait-until done` with a 30 s wait.

## Alternatives

| Tool                                                            | Result on 35 sites                              | Why rejected                                                                                     |
| --------------------------------------------------------------- | ----------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| headless Chromium under chrome-cli (AppleScript, no CDP)        | 32 ✓ / 2 ◐ / 1 × — best; passes all 6 detectors | macOS only; requires GUI app; one instance per bundle id                                         |
| Obscura 0.2.7 `--stealth` (Rust + V8, Chrome 145 network)       | 25 / 3 / 5                                      | fails Cloudflare, AWS WAF, and Tumblr JS challenges after 35 s; stalls in Turnstile iframe       |
| Firecrawl Local, `--browser always`, no cloud                   | 25 / 2 / 5 (+1 error) of 33                     | standard automated Chromium (`webdriver: true`, CDP); anti-bot features run only in their cloud |
| snitchmd v1 (CloakBrowser)                                      | 27 / 1 / 5 of 33                                | see above; also truncated stdout at 64 KB                                                        |
| curl_cffi `safari`, no JS                                       | 13 content of 33                                | lacks JS engine: challenges and client-rendered pages fail                                       |
| Real Firefox 160 headless                                       | FT, Quora, Reddit ✓ (spot check)                | spot check only; requires Firefox; produces no DOM or Markdown; network profile alone failed     |
| Lightpanda with UA `OpenAI File Downloader` (the tweet's trick) | 18 / 6 / 11                                     | worse than default; failed to reproduce from this test IP                                       |

## Open questions

- v2 has not been tested against the full lists in test-sites.md. Only two spot checks exist for v2 from 2026-11-24 (WSJ, Quora). The numbers above come from prototype runs.
- DataDome (NYTimes, The Athletic, WSJ): blocks correlated with IP reputation during the test run. It is unconfirmed whether Safari network impersonation with Lightpanda passes DataDome from a clean IP.
- The specific HTTP/2 frame or setting that triggers Reddit's captcha rule remains unidentified. Fresh sessions without cookies receive more captcha challenges.
- Only the quality score flags login walls and soft blocks returned with HTTP status 200.
- Open bugs: Flickr emoji panic; Wikipedia table bloat in rs-trafilatura.
- Incomplete features: Safari identity in `mcp` and `serve`; trafilatura extraction in the MCP `markdown` tool.
