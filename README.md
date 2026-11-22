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
dist/snitchmd https://paulgraham.com/greatwork.html
```

Accepts every `lightpanda fetch` option (`dist/snitchmd help fetch`). Two scripts run in
every page (source in `patches/lightpanda.patch`, `src/browser/snitchmd/`): `safari.js` (Safari JS identity)
and `style-index.js` (indexed access to inline styles missing in Lightpanda; prevents
crashes on React sites, e.g. Substack).
