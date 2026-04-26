# cloak2md

Render Cloudflare-heavy pages with CloakBrowser and convert the rendered HTML to Markdown with `rs-trafilatura`.

## Build

```bash
docker build -t cloak2md:local .
```

## Use

```bash
docker run --rm cloak2md:local https://example.com
```

Write output to a mounted directory:

```bash
docker run --rm -v "$PWD/out:/out" cloak2md:local https://example.com -o /out/page.md
```

Useful options:

```bash
--json                  output metadata + markdown as JSON
--html-output file      save rendered HTML too
--wait 5                wait after page load
--wait-for-selector css wait until a selector appears
--headful               run headed Chromium under Xvfb
--humanize              enable CloakBrowser human-like behavior
--proxy URL             use HTTP/SOCKS proxy
--include-links         preserve links where possible
--favor-precision       reduce boilerplate
--favor-recall          keep more content
```
