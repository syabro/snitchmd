# Changelog

All notable changes to snitchmd are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project uses [SemVer](https://semver.org/spec/v2.0.0.html).

## [Unreleased] — bun-slim branch

Major runtime migration. Container size drops from **1.65 GB → ~835 MB** (-49%).

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
