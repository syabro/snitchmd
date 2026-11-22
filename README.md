# snitchmd

URL → clean Markdown, one binary, no Docker, no Chromium.

The engine is [Lightpanda](https://github.com/lightpanda-io/browser) patched to:

- connect with Safari's network fingerprint (TLS and HTTP/2) using
  [curl-impersonate](https://github.com/lexiforest/curl-impersonate)'s curl and BoringSSL patches;
- send Safari's User-Agent and JS identity (`navigator.vendor`, no `userAgentData`);
- extract the main content with [rs-trafilatura](https://github.com/Murrough-Foley/rs-trafilatura);
- print Markdown by default: `snitchmd URL` needs no flags.

The previous Docker + CloakBrowser version lives on the `v1` branch.

## Build

Needs Zig 0.17, Rust (cargo), git, curl, make.

```sh
./build.sh            # fetch pinned sources, patch, build → dist/snitchmd (~8 min)
./build.sh prepare    # fetch and patch into build/ without building
```

Pinned versions are in `versions.env`. Patches:

| Source | Patch |
|---|---|
| curl | curl-impersonate `patches/curl.patch`, unchanged |
| BoringSSL | curl-impersonate `patches/boringssl.patch`, unchanged |
| boringssl-zig | `patches/boringssl-zig.patch` (local BoringSSL; source list fixed for BORINGSSL_REV, see versions.env) |
| Lightpanda | `patches/lightpanda.patch` |

## Run

```sh
snitchmd https://paulgraham.com/greatwork.html            # Markdown to stdout
snitchmd https://paulgraham.com/greatwork.html > page.md  # save it
snitchmd https://paulgraham.com/greatwork.html --json     # Markdown with metadata
```

stderr gets one summary line: title, extraction quality (0–1), character count, and `(cached)` for a cache hit.

**Exit codes.** `0` success; `1` error (network, browser, bad option; message on stderr);
`2` the page has no main content (a loading shell, a wall, or an empty page).

### Options

Every `lightpanda fetch` option works (`snitchmd help fetch`). Most used:

| Option | Effect |
|---|---|
| `--json` | `{url, final_url, title, page_title, page_type, quality, chars, markdown}` |
| `--no-cache` | fetch again instead of answering from the cache |
| `--html-output FILE` | also save the rendered HTML |
| `--include-images` | keep image references |
| `--favor-precision` / `--favor-recall` | cut more boilerplate / keep more content |
| `--dump-selector CSS` | extract only from the first matching element |
| `--wait-selector CSS` | wait for an element before extracting |
| `--wait-ms N` | wait cap in ms (default 30000) |
| `--dump-max-bytes N` | cut the Markdown at N bytes, ending with `[truncated]` |
| `--http-proxy URL` | proxy |
| `--locale TAG`, `--timezone IANA` | browser locale and time zone |
| `--dump html` | the rendered HTML instead of Markdown |

### Cache

A successful Markdown fetch is cached by URL and options. Repeating the command answers from
disk without opening the page.

- Location: `$SNITCHMD_CACHE_DIR`, else `${XDG_CACHE_HOME:-$HOME/.cache}/snitchmd`.
- `--json`, `--no-cache`, `--html-output` and `--dump-max-bytes` don't change the cache key.
- `--no-cache` refreshes one URL; `rm -rf ~/.cache/snitchmd` wipes everything.

### Built into the binary

- Safari 27.0 TLS and HTTP/2 fingerprint, Safari User-Agent.
- Two scripts run in every page (`src/browser/snitchmd/` in `patches/lightpanda.patch`): `safari.js`
  (Safari JS identity) and `style-index.js` (indexed access to inline styles missing in
  Lightpanda; prevents crashes on React sites, e.g. Substack).
- Telemetry is off.

### Not carried over from v1

`--headful` and `--humanize` were Chromium features; Lightpanda has neither.
