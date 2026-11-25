# snitchmd

URL → clean Markdown, one binary, no Docker, no Chromium.

The engine is [Lightpanda](https://github.com/lightpanda-io/browser) patched to:

- connect with Safari's network fingerprint (TLS and HTTP/2) using
  [curl-impersonate](https://github.com/lexiforest/curl-impersonate)'s curl and BoringSSL patches;
- send Safari's User-Agent and JS identity (`navigator.vendor`, no `userAgentData`);
- extract the main content with [rs-trafilatura](https://github.com/Murrough-Foley/rs-trafilatura);
- print Markdown by default: `snitchmd URL` needs no flags.

The previous Docker + CloakBrowser version lives on the `v1` branch.

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/syabro/snitchmd/master/install.sh | bash
```

Prebuilt for macOS arm64, Linux x86_64 (glibc 2.35+) and Linux arm64 (glibc 2.38+). Uninstall:
`curl -fsSL https://raw.githubusercontent.com/syabro/snitchmd/master/install.sh | bash -s -- --uninstall`.

For an agent:

```text
read https://github.com/syabro/snitchmd/blob/master/README.md, install https://raw.githubusercontent.com/syabro/snitchmd/master/skills/snitchmd/SKILL.md, then show me a couple of usage examples.
```

## Build

Needs Zig 0.17, Rust (cargo), git, curl, make.

```sh
./build.sh            # fetch pinned sources, patch, build → dist/snitchmd (~8 min)
./build.sh prepare    # fetch and patch into build/ without building
```

To change Lightpanda:

```sh
just prepare    # pinned sources + patches into 3rdparty/ (not in git)
# edit 3rdparty/lightpanda
just dev        # build it → dist/snitchmd
just test       # Lightpanda's tests; just test NAME filters
just patch      # write the edits back to patches/lightpanda.patch, then commit that
```

Releases are built by GitHub Actions: `just release VERSION` tags and pushes, the workflow builds
macOS arm64, Linux x86_64 and Linux arm64 and publishes them with notes from CHANGELOG.md.

Pinned versions are in `versions.env`. Patches:

- curl: curl-impersonate `patches/curl.patch`, unchanged.

- BoringSSL: curl-impersonate `patches/boringssl.patch`, unchanged.

- boringssl-zig: `patches/boringssl-zig.patch`. It uses the local BoringSSL. Its source list is
  fixed for `BORINGSSL_REV` from versions.env.

- Lightpanda: `patches/lightpanda.patch`.

## Run

```sh
snitchmd https://paulgraham.com/greatwork.html            # Markdown to stdout
snitchmd https://paulgraham.com/greatwork.html > page.md  # save it
snitchmd --json https://paulgraham.com/greatwork.html     # Markdown with metadata
```

stderr prints a single summary line: title, extraction quality (0–1), character count, and
`(cached)` on cache hits.

**Exit codes.** `0` success; `1` error (network, browser, invalid option, or bot challenge; message
on stderr); `2` no main content found (loading shell, wall, or empty page); `22` HTTP status 400 or
higher.

### Options

Every `lightpanda fetch` option works (`snitchmd help fetch`). Most used:

- `--json`: prints `{url, final_url, title, page_title, page_type, quality, chars, markdown}`.

- `--no-cache`: fetches again instead of answering from the cache.

- `--html-output FILE`: also saves the rendered HTML.

- `--include-images`: keeps image references.

- `--favor-precision`: cuts more boilerplate.

- `--favor-recall`: keeps more content.

- `--dump-selector CSS`: extracts only from the first matching element.

- `--wait-selector CSS`: waits for an element before extracting.

- `--script JS`, `--script-file PATH`: run JS in the page before extracting, e.g. click "Show
  more".

- `--wait-ms N`: wait cap in ms. Default 30000.

- `--dump-max-bytes N`: cuts the Markdown at N bytes and ends it with `[truncated]`.

- `--http-proxy URL`: proxy.

- `--locale TAG`, `--timezone IANA`: browser locale and time zone.

- `--dump html`: prints the rendered HTML instead of Markdown.

### Cache

A successful Markdown fetch is cached by URL and options. Repeating the command answers from
disk without opening the page.

- Not cached: errors, and extractions with quality below 0.5 (such as login walls or 200-OK error
  pages); stderr notes `(not cached: low quality)`.
- Location: `$SNITCHMD_CACHE_DIR`, or `${XDG_CACHE_HOME:-$HOME/.cache}/snitchmd`.
- `--json`, `--no-cache`, `--html-output`, and `--dump-max-bytes` do not alter the cache key.
- `--no-cache` refreshes one URL; `rm -rf ~/.cache/snitchmd` wipes everything.

### Built into the binary

- Safari 27.0 TLS and HTTP/2 fingerprint, Safari User-Agent.
- Two scripts run in every page (`src/browser/snitchmd/` in `patches/lightpanda.patch`): `safari.js`
  (Safari JS identity) and `style-index.js` (indexed access to inline styles missing in
  Lightpanda; prevents crashes on React sites, e.g. Substack).
- Telemetry is off.

### Not carried over from v1

`--headful` and `--humanize` were Chromium features; Lightpanda has neither.
