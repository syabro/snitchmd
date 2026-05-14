# Tasks

Backlog of QoL ideas to consider.

- [ ] SMD-001 Batch URLs from stdin or argv #batch #cli !high
  Currently each `docker run` has ~2s startup overhead, so fetching
  N URLs costs N × 2s on top of actual work. Reuse one container and
  one browser instance for many URLs.

  - `cat urls.txt | snitchmd -` reads URLs line-by-line from stdin
  - `snitchmd https://a.com https://b.com https://c.com` accepts multiple positional args
  - Output: concatenated Markdown with `\n\n---\n\n` separators, or one JSON object per URL when `--json` is set
  - Browser launched once, pages opened sequentially (or with a small concurrency, e.g. 3)

- [ ] SMD-002 Persistent login profile for auth-walled sites #auth #profile !high
  Anti-bot bypass already works, but content behind a login (X/Twitter,
  LinkedIn, Patreon, Substack paywalls) is still inaccessible. A reusable
  Chromium profile lets the user log in once and have all subsequent
  fetches inherit the cookies.

  - `snitchmd --login https://x.com` opens headful Chromium under Xvfb so the user can sign in
  - Profile persisted to `${XDG_CACHE_HOME:-~/.cache}/snitchmd/profile/` via volume mount
  - Subsequent runs reuse the profile transparently (no flag needed)
  - Document in README how to wipe the profile

- [ ] SMD-003 `--save` with auto-slugified filename #cli #ergonomics
  Most common manual step today is `snitchmd … > some-name.md`. Replace
  with a flag that picks a sensible filename automatically.

  - `snitchmd --save URL` writes to `./<slug>.md` (or `~/Downloads/<slug>.md`?)
  - Slug source: page `<title>` if available, else URL path
  - Decide: overwrite vs. suffix collisions (`-1`, `-2`)

- [ ] SMD-004 Print token estimate in stderr #ergonomics
  After fetching, the stderr summary line shows title/quality/chars.
  Add an approximate token count so the user immediately knows whether
  the output fits a context window without piping into another tool.

  - Add `tiktoken` (or a lightweight estimator) and emit `≈4200 tokens`
  - Picks a reasonable default encoding (e.g. cl100k_base)
  - One extra line in stderr, no impact on stdout

- [ ] SMD-007 Execute a Playwright script before extraction #playwright #automation
  Some pages need interaction before the content is in the DOM — click
  "Show more", dismiss cookie modals, navigate inside a SPA, wait for a
  specific text. Currently `--wait` and `--wait-for-selector` are the
  only escape hatches; expose the full Playwright API.

  - `--script "await page.getByText('Show more').click(); await page.waitForTimeout(2000)"` runs arbitrary JS with `page` in scope after `goto`, before extraction
  - `--script-file ./pre.js` reads the script from disk
  - Document common recipes (click by text, wait for text, dismiss banner)
  - Optional shortcuts later: `--click-text "Show more"`, `--wait-for-text "…"`

- [ ] SMD-006 Auto-prepend `https://` for URLs without a scheme #cli #ergonomics !high
  `snitchmd google.com` currently crashes with `Protocol error … Cannot
  navigate to invalid URL` because Playwright requires a full URL.
  Pre-process `args.url`: if it has no scheme, prepend `https://`.
  Optionally fall back to `http://` if HTTPS fails (probably overkill —
  just default to https).

- [ ] SMD-005 Optional YAML front-matter in Markdown output #ergonomics #notes
  Make output drop-in for Obsidian / Bear / Logseq by prepending YAML
  front-matter when requested.

  - `--frontmatter` flag prepends `---\nurl: …\ntitle: …\nfetched: …\nquality: …\n---\n`
  - Off by default to keep stdout clean
  - Could also expose `--frontmatter-fields title,url` for selective fields

- [ ] SMD-008 Document exit code 1 accurately in SKILL.md and README #docs
  Both SKILL.md:23 and README.md:112 describe exit code 1 as
  "runtime error (browser, network)" — but `snitchmd.py:180`
  catches any Exception (extractor crashes, I/O, anything bubbling
  up), not just browser/network. Surfaced by a fresh-eyes review.

  - Broaden the description in both files to match what the code
    actually does, e.g. "uncaught runtime error — full message on stderr"

- [ ] SMD-009 Evaluate `feder-cr/invisible_playwright` as CloakBrowser replacement #browser #infra
  - Run CloakBrowser's test suite against `invisible_playwright` — do the
    same anti-bot sites pass?
  - Measure Docker image size diff: current build vs. invisible_playwright
    + standard Playwright Chromium
  - Decision: switch, keep, or gate behind a flag
