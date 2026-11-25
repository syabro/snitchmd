# Sites

Test pages for snitchmd, grouped by test target. `scripts/test-sites.sh` checks tls.peet.ws from section 1
and runs section 3.
Results are from snitchmd 2.1 (a CI build before release) on 2026-11-25, from one home IP.

Run tests with `--no-cache` and default options (`--wait-until done`, 30 s). Because DataDome flags
IPs after ~25 daily requests to the same domain, space out test runs accordingly.

## 1. Network fingerprint

Must match curl-impersonate's Safari 27 profile
(`3rdparty/curl-impersonate/tests/signatures/safari270.yaml`).

- https://tls.peet.ws/api/all — `ja4`, `akamai_fingerprint_hash`.
  Expected: `t13d2013h2_a09f3c656075_7f0f34a4126d`, `c52879e43202aeb92740be6e8c86ea96`.
- https://tls.browserleaks.com/json — JA3/JA4, used by curl-impersonate's tests.
  Expected: same as Safari 27.
- https://httpbin.org/headers — headers as sent.
  Expected: Safari User-Agent, no `Sec-Ch-Ua*`.

Command: `snitchmd --no-cache --dump html https://tls.peet.ws/api/all`.

## 2. Bot detectors

Test suite from CloakBrowser's `tests/test_stealth.py`. Detector pages run checks inside iframes and
Web Workers, so their verdicts only render when using `--load-resources iframe --load-resources
worker --with-frames`.

- https://bot.sannysoft.com
  - Checks: classic headless signs.
  - Result: 6 failed. No `window.chrome`, no plugins (length 0, not a `PluginArray`), no WebGL
    (vendor and renderer), fpscanner `CHR_MEMORY`.

- https://bot.incolumitas.com
  - Checks: fpscanner and behaviour.
  - Result: 4 FAIL: `webDriverAdvanced`, `pluginsLength`, `pluginArray`, `CHR_MEMORY`.

- https://www.browserscan.net/bot-detection
  - Checks: WebDriver, CDP, User-Agent, headless.
  - Result: overall Robot. The check behind the verdict is not shown in the HTML, even though all
    17 individual checks listed on the page (WebDriver, Selenium, Headless Chrome, CDP, etc.) report
    Normal.

- https://deviceandbrowserinfo.com/are_you_a_bot
  - Checks: `isBot` and its flags.
  - Result: "You are human!", `isBot: false`.

- https://demo.fingerprint.com/web-scraping
  - Checks: FingerprintJS. The verdict needs a click on Search (`--script`).
  - Result: no verdict. After the scripted click the page shows neither flights nor an error.

- https://recaptcha-demo.appspot.com/recaptcha-v3-request-scores.php
  - Checks: reCAPTCHA v3 score.
  - Result: not run (see below).

The reCAPTCHA v3 demo does not validate evasion: its API key has exceeded the free quota and
returns a static 0.9 score to all clients.

## 3. Real sites

The 33 sites are taken from can1357's test list (https://x.com/can1357/status/2090837707069014224,
domain names only; URLs chosen for this test). Result markers: ✓ content extracted, ◐ page loaded
without target content, × blocked.

| URL                                                                                 | Protection    | Result |
| ----------------------------------------------------------------------------------- | ------------- | ------ |
| https://www.nytimes.com/                                                            | DataDome      | ✓      |
| https://www.newyorker.com/                                                          |               | ✓      |
| https://www.theatlantic.com/                                                        | Cloudflare    | ✓      |
| https://www.bloomberg.com/                                                          | PerimeterX    | ✓      |
| https://www.washingtonpost.com/                                                     |               | ✓      |
| https://www.wsj.com/                                                                | DataDome      | ✓      |
| https://www.ft.com/                                                                 | Cloudflare    | ✓      |
| https://medium.com/                                                                 |               | ✓      |
| https://www.wired.com/                                                              |               | ✓      |
| https://www.nytimes.com/athletic/7810763/2026/11/25/nfl-news-rumors-latest-updates/ | DataDome      | ✓      |
| https://en.wikipedia.org/wiki/Web_scraping                                          |               | ✓      |
| https://x.com/can1357/status/2090837707069014224                                    |               | ✓      |
| https://x.com/can1357                                                               |               | ◐ [1]  |
| https://www.facebook.com/facebook/posts/1733195668852446                            |               | ✓      |
| https://www.threads.com/@zuck                                                       |               | ✓      |
| https://www.instagram.com/instagram/                                                |               | ✓      |
| https://www.linkedin.com/company/microsoft/                                         | Cloudflare    | ✓      |
| https://www.pinterest.com/pinterest/                                                |               | ✓      |
| https://www.imdb.com/title/tt0111161/                                               | AWS WAF       | ✓      |
| https://www.quora.com/What-is-the-best-programing-language-for-beginners            | Cloudflare    | ✓      |
| https://stackoverflow.com/questions/11227809                                        | Cloudflare    | ✓      |
| https://www.reddit.com/r/programming/                                               | own, HTTP/2   | ✓      |
| https://www.twitch.tv/twitch                                                        |               | ✓      |
| https://github.com/lightpanda-io/browser                                            |               | ✓      |
| https://news.ycombinator.com/                                                       | IP rate limit | ✓      |
| https://on.substack.com/                                                            |               | ✓      |
| https://staff.tumblr.com/                                                           | own JS check  | ✓      |
| https://bsky.app/profile/bsky.app                                                   |               | ✓      |
| https://mastodon.social/@Mastodon                                                   |               | ✓      |
| https://www.goodreads.com/book/show/5470.1984                                       |               | ✓      |
| https://soundcloud.com/soundcloud                                                   |               | ✓      |
| https://www.flickr.com/explore                                                      |               | ✓      |
| https://imgur.com/                                                                  |               | ✓      |

Notes:

1. X profile: the page title repeated, 216 characters. The posts are in the page
   (`--dump markdown_full`); rs-trafilatura picks the title block.

Totals: 32 ✓ / 1 ◐ / 0 × on 33 sites.

## 4. Extraction quality

Benchmark runs on 2026-11-22. Expected output for the eight target pages: main content retained,
navigation stripped, no truncated sections.

- https://en.wikipedia.org/wiki/Web_scraping
- https://stackoverflow.com/questions/11227809
- https://github.com/lightpanda-io/browser
- https://www.imdb.com/title/tt0111161/
- https://www.goodreads.com/book/show/5470.1984
- https://paulgraham.com/greatwork.html
- https://www.theatlantic.com/
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/User-Agent

Known test cases:

- https://en.wikipedia.org/wiki/Red_panda — known issue: outputs 11.8 MB of padded navigation
  tables.
- [scrapinghub/article-extraction-benchmark](https://github.com/scrapinghub/article-extraction-benchmark)
  — 181 articles with reference text ground truth; rs-trafilatura scores F1 0.966.
- [Web Content Extraction
  Benchmark](https://github.com/Murrough-Foley/web-content-extraction-benchmark) — 1,497 pages
  across 7 page types; rs-trafilatura scores F1 0.859.

Both benchmarks run against local HTML with reference text and evaluate rs-trafilatura alone, not
network fetching.

## 5. Lightpanda engine

- https://demo-browser.lightpanda.io/ — live target tested by Lightpanda's CI fetch job
  (`.github/workflows/agent-regression.yml`).
- https://demo-browser.lightpanda.io/campfire-commerce/ — client-rendered store page.

# Tasks

- [ ] SMD-010 X profile posts in the Markdown		#extraction
  `snitchmd https://x.com/<user>` returns the profile's posts as the main content.

  On https://x.com/can1357 the page has the posts (`--dump markdown_full`), but rs-trafilatura
  picks the title block: the result is the title repeated, 216 characters, quality 0.50.

  User decision: fixed by a separate rs-trafilatura patch.

  DoD: `snitchmd https://x.com/can1357` returns the pinned and recent posts.

- [ ] SMD-011 Facebook page posts in the Markdown		#extraction
  `snitchmd https://www.facebook.com/<page>` returns the page's posts as the main content.

  On https://www.facebook.com/facebook the page has the posts (`--dump markdown_full`), but
  rs-trafilatura picks the page header: quality 0.20.

  User decision: fixed by a separate rs-trafilatura patch.

  DoD: `snitchmd https://www.facebook.com/facebook` returns the page's posts.
