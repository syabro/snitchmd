# Design

Evidence comes from the 2026-11-22 comparison runs across 33 sites and 6 bot detectors from one home
IP. The sites are listed in [sites.md](sites.md).

## Terms

- **prototype**: the pre-release Lightpanda build tested on 2026-11-22.

Exit codes: 0 success; 1 error (including bot challenges); 2 no main content; 22 HTTP status 400 or
higher.

## Pipeline

`snitchmd URL` runs Lightpanda's `fetch` command with patches:

1. **Network: Safari 27.** curl-impersonate's curl and BoringSSL patches, profile `safari270`, apply
   to every connection. TLS (JA3/JA4) and HTTP/2 (SETTINGS, WINDOW_UPDATE, pseudo-header order)
   match real Safari. Lightpanda builds the request headers itself; curl-impersonate's built-in
   Safari headers are disabled so headers are not sent twice.
2. **Identity: Safari.** `fetch` defaults to the Safari 27 User-Agent and omits `Sec-Ch-Ua*`
   headers, matching Safari's behavior. `safari.js` injects into every page before page scripts
   run, removing `navigator.userAgentData` and setting `navigator.vendor` to Apple.
3. **Page: Lightpanda's engine.** V8, no rendering. It waits until the page settles (`--wait-until
   done`, up to 30 s) so JS challenges finish. `style-index.js` patches a Lightpanda bug that React
   sites hit.
4. **Extraction: rs-trafilatura.** The rendered DOM passes to rs-trafilatura, which returns the main
   content as Markdown and a quality score (0–1).
5. **Wrapper (`src/snitchmd.zig`):** handles the result cache, stderr summary, `--json`, and exit
   codes. Results with quality < 0.5 are not cached.

`mcp`, `serve` and `agent` also run steps 1 and 2. MCP's `markdown` tool runs step 4. MCP `goto`
waits up to 30 s for a bot challenge to pass.

## Decisions

### Lightpanda instead of Chromium (CloakBrowser)

- CloakBrowser 0.3.31 (Chromium 146) passes most detectors, but its network fingerprint is
  Chromium 146. Reddit redirects that fingerprint directly to a captcha (5 of 5) before JS runs.
  JS-level stealth does not bypass this check.
- CloakBrowser 0.7.x (Chromium 156) requires a license key.
- Chromium requires Docker, a ~1 GB image, and has a slow startup. Lightpanda is a single ~75 MB
  binary.
- Unpatched Lightpanda 1.0.5 with a long wait scored 27 ✓ / 1 ◐ / 5 × on 33 sites.

Trade-off: Lightpanda lacks rendering, so detectors that check WebGL, canvas, or plugins identify a
non-browser environment (sannysoft: 6 failed). Sites that enforce those checks will fail.

### Safari, not Chrome, as the network fingerprint

First request without JS (curl_cffi 0.17, same IP):

| Profile    | FT    | Quora | Reddit       |
| ---------- | ----- | ----- | ------------ |
| Safari     | ✓     | ✓     | JS challenge |
| Chrome 152 | block | ✓     | JS challenge |
| Firefox    | block | block | JS challenge |

In a test that varied network settings and headers separately, only network settings changed the
outcome; User-Agent and headers did not. Safari also omits `Sec-Ch-Ua` and `userAgentData`, so
Lightpanda does not need to emulate those Chrome-specific APIs. Adding the Safari fingerprint
changed prototype results from 28 / 2 / 3 to 30 / 2 / 1 on 33 sites (2026-11-22; FT and Quora
opened).

### Patch Lightpanda instead of wrapping it

Neither behavior is configurable by CLI flags. Lightpanda rejects any User-Agent containing
"Mozilla" and always sends `Sec-Ch-Ua: "Lightpanda"`. TLS and HTTP/2 settings require a patched
libcurl. snitchmd ships a source patch and a custom build. AGPL-3.0 permits this because the patches
are published in `patches/`.

### rs-trafilatura for Markdown

Lightpanda's `--dump markdown` outputs the full page, including menus and footers (2–5× larger
output). Lightpanda's `--strip-mode clutter` produces similar sizes, but it dropped MDN's title,
barely reduced Goodreads, and merged paragraphs. rs-trafilatura extracts the main text, outputs a
quality score, and links directly as a Rust crate without a Python runtime. Lightpanda's converter
remains available under `--dump markdown_full`.

### Wait for the page to settle

Lightpanda passes Cloudflare, AWS WAF, and Tumblr JS challenges on StackOverflow, IMDb, Tumblr, and
Quora if given enough execution time. With `--wait-until networkalmostidle --wait-ms 12000`, the
sites blocked the requests. With `--wait-until done --wait-ms 30000`, the pages loaded. The default
is therefore `--wait-until done` with a 30 s wait.

## Findings

### Fingerprint gaps left

TLS (JA3, JA4, peetprint) and HTTP/2 (akamai) match Safari 27 exactly (tls.peet.ws). Headers still
differ from real Safari: snitchmd sends `sec-fetch-user: ?1`, does not send `priority`, and orders
`accept-encoding` differently. No site in the tests was seen to block on these.

### Reddit

- Reddit decides on the first request, before JS: either an 8 KB page with a trivial JS challenge
  (Lightpanda solves it) or a 167 KB "Prove your humanity" page with reCAPTCHA.
- The HTTP/2 layer decides: curl_cffi `chrome146` and `chrome151` receive the captcha over HTTP/2
  and the JS challenge over HTTP/1.1. Safari, Firefox, and `chrome152` profiles receive the JS
  challenge.
- Cookies `csv` and `edgebucket` from a solved JS challenge prevent the captcha fallback. Every
  snitchmd run starts as a fresh visitor without cookies; use `--cookie` to pass saved ones.

### DataDome (NYTimes, The Athletic, WSJ)

- NYTimes and The Athletic block at the initial request. Tests with curl_cffi showed that both TLS
  and headers must match simultaneously. Safari was not tested here.
  - Chrome TLS/HTTP2 with User-Agent `Lightpanda/1.0`: 403
  - Plain curl TLS with Chrome User-Agent and headers: 403
  - Chrome TLS/HTTP2 with Chrome User-Agent: 200
- After ~25 daily requests to nytimes.com from a single IP, DataDome blocked all traffic, including
  real Chromium.
- snitchmd 2.1 on 2026-11-25 opened NYTimes and WSJ. The Athletic answered with HTTP status 400 or
  higher.

### The IP

The test home IP is shared via CGNAT (two routers; traceroute routes through the ISP's 10.x network).
Reputation is shared: WSJ, HN, and Bloomberg results varied by time of day rather than client tool.
Bloomberg (PerimeterX) blocked intermittently regardless of client.

### Things that did not help

- `--http-version 1.1` on FT and Quora: 0 of 2 on both.
- User-Agent `OpenAI File Downloader` (claimed by can1357 at
  x.com/can1357/status/2090837707069014224 to bypass anti-bot blocks): opened nothing new, closed X
  and The Atlantic.
- curl_cffi's Firefox profile: blocked on FT and Quora, where real Firefox 160 passes.

### Lightpanda capabilities and behavior

- `fetch --json` reports `bot_challenge` (`cloudflare`, `aws_waf`, `vercel`) and `page_status`
  (JS errors, skipped resources, missing APIs).
- In its default mode (extracting Markdown without scripts, selectors, or injected code), `snitchmd
  URL` requests Markdown directly (`Accept: text/markdown`). If the server returns Markdown (such as
  cloudflare.com), snitchmd passes it through as is.
- No `window.chrome`, plugins, WebGL, service workers, `navigator.getBattery`, `getUserMedia`.

## Alternatives

Results on the test sites from [sites.md](sites.md), one home IP. snitchmd 2.1 ran on
2026-11-25, the other tools on 2026-11-22.

| Tool                                    | Sites | Content | Empty page | Blocked |
| --------------------------------------- | ----- | ------- | ---------- | ------- |
| snitchmd 2.1                            | 33    | 29      | 3          | 1       |
| CloakBrowser 0.3.31                     | 31    | 25      | 1          | 5       |
| Lightpanda 1.0.5, long wait             | 33    | 27      | 1          | 5       |
| Obscura 0.2.7 `--stealth`               | 33    | 24      | 2          | 5       |
| Firecrawl Local, no cloud               | 31    | 24      | 1          | 5       |
| Lightpanda, UA `OpenAI File Downloader` | 33    | 18      | 4          | 11      |

- Content: the page's content was extracted.
- Empty page: the page loaded, but without the content (a loading shell, a login wall).
- CloakBrowser and Firecrawl Local did not run NYTimes and The Athletic, so they have 31 sites.
- Obscura's 33 sites include NYTimes and The Athletic without a reliable result.
- Firecrawl Local also failed once with an empty response.
- curl_cffi `safari` (one request, no JS) got content on 13 of 33 sites.
- Real Firefox 160 headless was spot-checked only: FT, Quora and Reddit open.

- **Obscura 0.2.7 `--stealth`**
  - Engine: Rust and V8, network fingerprint of Chrome 145.
  - Drawback: does not pass the Cloudflare, AWS WAF and Tumblr JS challenges, even with a 35-second
    wait. Stops inside the Turnstile iframe.

- **Firecrawl Local**
  - Mode: `--browser always`, cloud off.
  - Drawback: plain automated Chromium, `webdriver: true`, CDP visible. The anti-bot part runs in
    their cloud.
  - Privacy: by default (`FIRECRAWL_CLOUD=auto`) URLs are sent to that cloud.

- **CloakBrowser 0.3.31**
  - Engine: patched Chromium 146.
  - Drawback: Reddit gives a captcha by network fingerprint. Needs Docker.

- **curl_cffi, `safari` profile**
  - Engine: none, one HTTP request.
  - Drawback: no JS, so JS challenges and pages built by JS fail.

- **Real Firefox 160, headless**
  - Drawback: needs Firefox. Gives no DOM and no Markdown in that setup.

- **Lightpanda with User-Agent `OpenAI File Downloader`**
  - Source: can1357's claim (x.com/can1357/status/2090837707069014224) that this User-Agent bypasses
    bot detection.
  - Drawback: the claimed bypass did not reproduce from this IP.

## Open questions

- DataDome: snitchmd 2.1 opened NYTimes and WSJ, but The Athletic blocked it. It is unconfirmed
  whether The Athletic blocks snitchmd itself or this IP's reputation.
- The specific HTTP/2 frame or setting that triggers Reddit's captcha rule remains unidentified.
  Fresh sessions without cookies receive more captcha challenges.
- Only the quality score flags login walls and soft blocks returned with HTTP status 200.
- Open bugs: Flickr emoji panic (not seen on 2026-11-25); Wikipedia table bloat in rs-trafilatura.
- rs-trafilatura on X profiles and Facebook pages: a separate patch is planned. It picks the title
  block on X, on Facebook the page header. The posts are in the page on both
  (`--dump markdown_full`).

# Tasks

- [ ] SMD-002 Log in once and fetch auth-walled pages		#auth !high
  Pages behind a login (X, LinkedIn, Patreon, Substack paywalls) come back with their content.

  `--cookie` and `--cookie-jar` already load and save cookies, but snitchmd has no window to log in
  through, so there is no way to get those cookies.

  DoD: a documented way to log in to a site once, after which `snitchmd --cookie <file> URL` returns
  the logged-in page.
