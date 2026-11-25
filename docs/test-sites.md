# Test sites

Pages to check snitchmd against, by what they test. "Last result" is the
2026-11-22 run of the prototype that became v2 (Lightpanda + Safari network
fingerprint + Safari User-Agent and JS identity), unless noted. v2 itself has not
been run over these lists yet.

Run with `--no-cache` and the defaults (`--wait-until done`, 30 s). One IP gets
flagged after ~25 requests a day to the same DataDome site; spread runs out.

## 1. Network fingerprint

Must match curl-impersonate's Safari 27 profile
(`3rdparty/curl-impersonate/tests/signatures/safari270.yaml`).

| URL                               | Check                                     | Expected                                                                   |
| --------------------------------- | ----------------------------------------- | -------------------------------------------------------------------------- |
| https://tls.peet.ws/api/all       | `ja4`, `akamai_fingerprint_hash`          | `t13d2013h2_a09f3c656075_7f0f34a4126d`, `c52879e43202aeb92740be6e8c86ea96` |
| https://tls.browserleaks.com/json | JA3/JA4, used by curl-impersonate's tests | same as Safari 27                                                          |
| https://httpbin.org/headers       | headers as sent                           | Safari User-Agent, no `Sec-Ch-Ua*`                                         |

Command: `snitchmd https://tls.peet.ws/api/all --no-cache --dump html`.

## 2. Bot detectors

From CloakBrowser's `tests/test_stealth.py`. snitchmd v1 (CloakBrowser 0.3.31)
and plain Lightpanda 1.0.5 results are from 2026-11-22; v2 was not run.

| URL                                                                | What it shows                                       | v1                                                  | Lightpanda 1.0.5                              |
| ------------------------------------------------------------------ | --------------------------------------------------- | --------------------------------------------------- | --------------------------------------------- |
| https://bot.sannysoft.com                                          | classic headless checks                             | all passed                                          | 7 failed (no `window.chrome`, plugins, WebGL) |
| https://bot.incolumitas.com                                        | fpscanner + behaviour                               | 1 FAIL (WEBDRIVER, false positive for every Chrome) | 4 FAIL                                        |
| https://www.browserscan.net/bot-detection                          | WebDriver / CDP / UA / headless                     | Normal                                              | Robot (UA `Lightpanda/1.0`)                   |
| https://deviceandbrowserinfo.com/are_you_a_bot                     | isBot + flags                                       | bot (`hasInconsistentTimingResolution`)             | human                                         |
| https://demo.fingerprint.com/web-scraping                          | FingerprintJS; needs a click on Search (`--script`) | not checked                                         | "bad request"                                 |
| https://recaptcha-demo.appspot.com/recaptcha-v3-request-scores.php | reCAPTCHA v3 score                                  | 0.9                                                 | 0.9                                           |

reCAPTCHA v3 demo is useless: the key is over its free quota and returns a static
0.9 to everyone. Detector checks need `--load-resources iframe --load-resources
worker --with-frames` for the verdict to render.

## 3. Real sites

The 35 sites from can1357's table (https://x.com/can1357/status/2090837707069014224,
names only; URLs chosen by us). ✓ content, ◐ shell without data, × block.

| Site            | URL                                              | Protection                                    | Last result                                           |
| --------------- | ------------------------------------------------ | --------------------------------------------- | ----------------------------------------------------- |
| NYTimes         | https://www.nytimes.com/                         | DataDome                                      | not run (IP flagged)                                  |
| New Yorker      | https://www.newyorker.com/                       |                                               | ✓                                                     |
| The Atlantic    | https://www.theatlantic.com/                     | Cloudflare                                    | ✓                                                     |
| Bloomberg       | https://www.bloomberg.com/                       | PerimeterX, random blocks                     | ✓ (random)                                            |
| Washington Post | https://www.washingtonpost.com/                  |                                               | ✓                                                     |
| WSJ             | https://www.wsj.com/                             | DataDome                                      | × 401 (IP flagged); v2 on 2026-11-24 ✓                |
| FT              | https://www.ft.com/                              | Cloudflare, network fingerprint               | ✓                                                     |
| Medium          | https://medium.com/                              |                                               | ✓ (landing)                                           |
| Wired           | https://www.wired.com/                           |                                               | ✓                                                     |
| The Athletic    | https://www.nytimes.com/athletic/                | DataDome                                      | not run (IP flagged)                                  |
| Wikipedia       | https://en.wikipedia.org/wiki/Web_scraping       |                                               | ✓                                                     |
| X — tweet       | https://x.com/can1357/status/2090837707069014224 |                                               | ✓                                                     |
| X — profile     | https://x.com/can1357                            |                                               | ✓                                                     |
| Facebook        | https://www.facebook.com/facebook                | login wall                                    | ◐                                                     |
| Threads         | https://www.threads.com/@zuck                    |                                               | ✓ (less text than with UA `Lightpanda/1.0`)           |
| Instagram       | https://www.instagram.com/instagram/             |                                               | ✓                                                     |
| LinkedIn        | https://www.linkedin.com/company/microsoft/      | Cloudflare                                    | ✓                                                     |
| Pinterest       | https://www.pinterest.com/pinterest/             |                                               | ✓                                                     |
| IMDb            | https://www.imdb.com/title/tt0111161/            | AWS WAF JS challenge                          | ✓                                                     |
| Quora           | https://www.quora.com/                           | Cloudflare                                    | ✓ landing; v2 on 2026-11-24: login wall, quality 0.15 |
| StackOverflow   | https://stackoverflow.com/questions/11227809     | Cloudflare JS challenge                       | ✓                                                     |
| Reddit          | https://www.reddit.com/r/programming/            | JS challenge or captcha by HTTP/2 fingerprint | ✓                                                     |
| TikTok          | https://www.tiktok.com/@tiktok                   |                                               | ◐ "Please wait..."                                    |
| YouTube         | https://www.youtube.com/watch?v=dQw4w9WgXcQ      |                                               | ✓                                                     |
| Twitch          | https://www.twitch.tv/twitch                     |                                               | ✓                                                     |
| GitHub          | https://github.com/lightpanda-io/browser         |                                               | ✓                                                     |
| HN              | https://news.ycombinator.com/                    | rate limit by IP                              | ✓                                                     |
| Substack        | https://on.substack.com/                         |                                               | ✓ (needs `style-index.js`)                            |
| Tumblr          | https://staff.tumblr.com/                        | own JS challenge                              | ✓                                                     |
| Bluesky         | https://bsky.app/profile/bsky.app                |                                               | ✓                                                     |
| Mastodon        | https://mastodon.social/@Mastodon                |                                               | ✓                                                     |
| Goodreads       | https://www.goodreads.com/book/show/5470.1984    |                                               | ✓                                                     |
| SoundCloud      | https://soundcloud.com/soundcloud                |                                               | ✓                                                     |
| Flickr          | https://www.flickr.com/explore                   |                                               | ✓ (v2 once panicked on an emoji)                      |
| Imgur           | https://imgur.com/                               |                                               | ✓                                                     |

Prototype on 33 sites (NYTimes and The Athletic left out): 30 ✓ / 2 ◐ / 1 ×.

## 4. Extraction quality

| Source                                                                                                                                                                                                                       | What                                                            |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| The 8 pages compared on 2026-11-22: Wikipedia (Web scraping), StackOverflow 11227809, GitHub lightpanda-io/browser, IMDb tt0111161, Goodreads 1984, https://paulgraham.com/greatwork.html, The Atlantic home, MDN User-Agent | main text kept, navigation dropped, nothing cut off             |
| https://en.wikipedia.org/wiki/Red_panda                                                                                                                                                                                      | known: 11.8 MB of padded navigation tables                      |
| [scrapinghub/article-extraction-benchmark](https://github.com/scrapinghub/article-extraction-benchmark)                                                                                                                      | 181 articles with ground truth; rs-trafilatura reports F1 0.966 |
| [Web Content Extraction Benchmark](https://github.com/Murrough-Foley/web-content-extraction-benchmark)                                                                                                                       | 1,497 pages of 7 page types; rs-trafilatura reports F1 0.859    |

The two benchmarks are offline HTML with ground truth: they test rs-trafilatura,
not fetching.

## 5. Lightpanda engine

| URL                                                   | What                                                                          |
| ----------------------------------------------------- | ----------------------------------------------------------------------------- |
| https://demo-browser.lightpanda.io/                   | Lightpanda's own end-to-end target (`.github/workflows/agent-regression.yml`) |
| https://demo-browser.lightpanda.io/campfire-commerce/ | JS-rendered shop page                                                         |
