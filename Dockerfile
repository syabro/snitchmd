###############################################################################
# Stage 1 — build rs-trafilatura extract_stdin CLI
###############################################################################
FROM rust:slim AS trafilatura-builder
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN git clone --depth 1 https://github.com/Murrough-Foley/rs-trafilatura.git . \
 && rm -f rust-toolchain.toml \
 && cargo build --release --bin extract_stdin \
 && strip target/release/extract_stdin

###############################################################################
# Stage 2 — install bun + npm deps + pre-download chrome
###############################################################################
FROM oven/bun:1-debian AS bun-builder
WORKDIR /app
COPY runtime/package.json ./package.json
COPY snitchmd.ts ./
RUN bun install --production
# Pre-download CloakBrowser's Chromium binary + trim fat in same layer so the
# bloat (Windows variant chromium, locales, chromedriver) never makes it
# into the COPY --from in the final stage.
RUN bun -e "import('cloakbrowser').then(m => m.ensureBinary()).then(p => console.log('downloaded to', p))" \
 && PLATFORM_ID=$(cat /root/.cloakbrowser/latest_version_linux-* | head -1) \
 && KEEP="/root/.cloakbrowser/chromium-${PLATFORM_ID}" \
 && for d in /root/.cloakbrowser/chromium-*; do [ "$d" = "$KEEP" ] || rm -rf "$d"; done \
 && find "$KEEP/locales" -type f ! -name 'en.pak' ! -name 'en-US.pak' -delete \
 && rm -f "$KEEP/chromedriver" \
 && touch /root/.cloakbrowser/.welcome_shown

###############################################################################
# Stage 3 — final slim runtime
###############################################################################
FROM debian:bookworm-slim
ENV DEBIAN_FRONTEND=noninteractive

# Chromium runtime libs (subset of what cloakhq/cloakbrowser:latest installs)
RUN apt-get update && apt-get install -y --no-install-recommends \
        libnss3 libnspr4 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
        libdbus-1-3 libdrm2 libxkbcommon0 libatspi2.0-0 libxcomposite1 \
        libxdamage1 libxfixes3 libxrandr2 libgbm1 libpango-1.0-0 \
        libcairo2 libasound2 libx11-xcb1 libfontconfig1 libx11-6 \
        libxcb1 libxext6 libxshmfence1 \
        libglib2.0-0 libgtk-3-0 libpangocairo-1.0-0 libcairo-gobject2 \
        libgdk-pixbuf-2.0-0 libxss1 libxtst6 fonts-liberation \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && find /usr/lib -maxdepth 3 \( \
            -name 'libLLVM.so.*' \
         -o -name 'libgallium-*.so' \
         -o -name 'libz3.so.*' \
       \) -delete \
    && find /usr/lib -maxdepth 4 -path '*/dri/*.so' -delete

# bun runtime
COPY --from=bun-builder /usr/local/bin/bun /usr/local/bin/bun

# rs-trafilatura CLI
COPY --from=trafilatura-builder /build/target/release/extract_stdin /usr/local/bin/extract_stdin

# app + node_modules + pre-downloaded chrome
COPY --from=bun-builder /app /app
COPY --from=bun-builder /root/.cloakbrowser /root/.cloakbrowser


WORKDIR /app
ENTRYPOINT ["bun", "run", "snitchmd.ts"]
CMD ["--help"]
