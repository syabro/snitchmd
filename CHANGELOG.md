# Changelog

All notable changes to snitchmd are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [SemVer](https://semver.org/spec/v2.0.0.html).

## [2.1.0] — 2026-11-25

### Added

- `snitchmd version` prints `snitchmd X.Y.Z (Lightpanda …)`; `version --check` compares it with the
  latest snitchmd release on GitHub.
- `mcp`, `serve` and `agent` present themselves as Safari too: Safari User-Agent by default and the
  built-in Safari JS identity.
- MCP `markdown` tool and `mcp://page/markdown` extract the page's main content via
  rs-trafilatura; a page without main content (forms, search, login) is rendered whole, while a
  `selector` subtree is rendered as is.
- MCP `goto` (and other MCP tools accepting `url`) gives a bot challenge page up to 30 s more to
  pass itself, or the rest of the call's `timeout`, instead of reporting the challenge right after
  load. `agent` scripts don't wait this way.
- `scripts/test-sites` runs snitchmd over `docs/sites.md`.

### Changed

- The built-in Safari scripts run only with a browser User-Agent (`Mozilla/...`), so
  `--user-agent-suffix` keeps Lightpanda's identity consistent.

## [2.0.1] — 2026-11-25

### Fixed

- Flags may come before the URL: `snitchmd --json URL` works like `snitchmd URL --json`.

## [2.0.0] — 2026-11-24

One binary instead of a Docker image: patched Lightpanda in place of CloakBrowser (Chromium).

### Changed

- Engine: [Lightpanda](https://github.com/lightpanda-io/browser) with Safari 27's TLS and HTTP/2
  fingerprint (curl-impersonate), Safari User-Agent and JS identity; rs-trafilatura built in.
- Install: a prebuilt binary (macOS arm64, Linux x86_64 with glibc 2.35+, Linux arm64 with glibc 2.38+); no Docker.
- Options are Lightpanda's `fetch` options: `--wait-selector` (was `--wait-for-selector`),
  `--dump-selector` (was `--content-selector`), `--dump-max-bytes` in bytes (was `--max-chars`),
  `--http-proxy` (was `--proxy`), `--wait-ms` (was `--timeout` and `--wait`); `--wait-until`
  takes Lightpanda's values.

### Added

- `--script JS` / `--script-file PATH`: JavaScript run once in the page before extraction,
  e.g. clicking "Show more"; the page then settles again.
- Exit code 22 when the server answers with status 400 or higher; such pages are not cached.
- Results with extraction quality below 0.5 are printed but not cached.

### Kept

- Result cache and `--no-cache`, stderr summary, `--json` fields, `--html-output`,
  `--include-images`, `--favor-precision`, `--favor-recall`, exit code 2 for no main content.

### Removed

- `--headful`, `--humanize`: Chromium features.
- `--include-links`: links were always kept in Markdown output.

## [0.2.1] — 2026-06-07

### Added

- `--content-selector CSS` — limit extraction to the matched element's
  subtree. Useful when trafilatura's main-content heuristic picks the wrong
  block (e.g. a comment sidebar on a list page). Snitchmd waits for the
  selector before extracting and fails clearly if it never appears.

## [0.2.0] — 2026-06-07

Major runtime migration. Container size drops from **1.65 GB → ~835 MB** (-49%).

### Fixed

- Disabled cloakbrowser's runtime auto-update (`CLOAKBROWSER_AUTO_UPDATE=false`
  in the final image). The library was checking for a newer Chromium on every
  container start and downloading ~200 MB in the background, defeating the
  whole point of baking a pinned Chromium into stage 2.

### Changed

- **Runtime is now Bun + JS CloakBrowser** instead of Python + pip CloakBrowser.
  The container's `ENTRYPOINT` is `bun run snitchmd.ts`. Public CLI surface is
  unchanged; existing scripts that call `docker run syabro/snitchmd ...` keep
  working.
- **`rs-trafilatura` extraction now goes through a custom CLI** at
  `tools/extract_stdin/`, a small Rust binary that depends on
  `rs-trafilatura` at a pinned commit. The upstream `extract_stdin` example
  CLI doesn't expose `--favor-precision` / `--favor-recall` /
  `--include-images` / `--include-links`; our fork does and snitchmd forwards
  all four.
- **Docker image is published as a multi-arch manifest** (`linux/amd64` +
  `linux/arm64`). `docker pull` picks the right arch automatically; no more
  `--platform linux/amd64` hint needed on Apple Silicon.
- **Dockerfile is multi-stage**: rust → bun → debian-slim final. Aggressive
  trim of unused Chromium locales, mesa/LLVM transitive libs left behind by
  `libgbm1`, and the cross-platform Windows-variant chromium that the
  cloakbrowser npm package pulls.

### Added

- `--max-chars N` — Markdown truncation directly in the CLI (appends
  `\n\n[truncated]`). In `--json` mode adds `truncated: true` and
  `full_chars`. Excluded from the cache key — same fetch/extract result
  is reused.
- Better argument validation: `--timeout` / `--wait` / `--max-chars` reject
  non-integer and negative values; `--wait-until` validates against the
  enum; `--favor-precision` / `--favor-recall` are mutually exclusive.
- Real `--help` output (was a stub previously).
- `just build` and `just build-pc-local` recipes: each builds both arches
  locally (host-native + qemu/Rosetta for the other). `just push` publishes
  the multi-arch manifest.

### Removed

- `pi-extensions/web-fetch-snitchmd.ts` and its `@earendil-works/*` peer
  dependencies. The extension's only real value-add (max-chars truncation)
  is now built into the CLI. The Pi-side keeps the markdown skill in
  `skills/`.
- `snitchmd.py` — replaced by `snitchmd.ts`.

## [0.1.3] — 2026-04-29

### Added

- Release workflow: `just release <version>` bumps, tags, publishes, and
  pushes in one shot. `scripts/bump-version` for the version-edit step.

## [0.1.2] — 2026-04

### Fixed

- Anti-bot challenge wording in README and SKILL.

## [0.1.1] — 2026-04

### Added

- `install.sh` + host-side `snitchmd` wrapper script (writes to
  `~/.local/bin` or `/usr/local/bin`).
- MIT license file.
- Shell-alias install option.
- Pi-side `cloak2md` (later `snitchmd`) integration: `pi-extensions/` +
  `skills/`.
- On-disk URL cache with `--no-cache` bypass.

### Changed

- Renamed `cloak2md` → `snitchmd`.
- Suppressed CloakBrowser's first-launch welcome banner.

## [0.1.0] — 2026-04

Initial release. Python CLI (`snitchmd.py`) that drives CloakBrowser via the
Python wrapper, pipes rendered HTML through `rs-trafilatura`, and prints
Markdown to stdout. Packaged as a Docker image based on
`cloakhq/cloakbrowser:latest`.
