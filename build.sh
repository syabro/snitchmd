#!/bin/sh
# Fetches pinned Lightpanda, BoringSSL, boringssl-zig, curl and curl-impersonate,
# applies the patches and builds one binary into dist/lightpanda.
# `build.sh prepare` stops after patching.
set -eu
ROOT="$(cd "$(dirname "$0")" && pwd)"
. "$ROOT/versions.env"
W="$ROOT/build"
mkdir -p "$W/dl" "$ROOT/dist"
export ZIG_GLOBAL_CACHE_DIR="$W/zig-global"

# Checkout <url> at <rev> into $W/<dir>, discarding earlier patches; ignored files
# (build caches) are kept.
checkout() {
  dir="$W/$1"
  [ -d "$dir/.git" ] || { git init -q "$dir"; git -C "$dir" remote add origin "$2"; }
  git -C "$dir" fetch -q --depth 1 origin "$3"
  git -C "$dir" checkout -q -f FETCH_HEAD
  git -C "$dir" clean -q -fd
}

checkout curl-impersonate "$CURL_IMPERSONATE_URL" "$CURL_IMPERSONATE_REV"
checkout boringssl "$BORINGSSL_URL" "$BORINGSSL_REV"
checkout boringssl-zig "$BORINGSSL_ZIG_URL" "$BORINGSSL_ZIG_REV"
checkout lightpanda "$LIGHTPANDA_URL" "$LIGHTPANDA_REV"

tarball="$W/dl/curl-$CURL_VERSION.tar.gz"
[ -f "$tarball" ] || curl -fsSL -o "$tarball" "$CURL_TARBALL"
rm -rf "$W/curl-$CURL_VERSION"
tar -xzf "$tarball" -C "$W"
# Own repo, so `git apply` does not resolve paths against an enclosing checkout.
git init -q "$W/curl-$CURL_VERSION"

# Two parts of curl-impersonate's patch target the git tree, not the release
# tarball: curlver.h differs there and scripts/singleuse.pl is not shipped.
# The rest applies as is.
git -C "$W/curl-$CURL_VERSION" apply \
  --exclude=include/curl/curlver.h --exclude=scripts/singleuse.pl \
  "$W/curl-impersonate/patches/curl.patch"
git -C "$W/boringssl" apply "$W/curl-impersonate/patches/boringssl.patch"
git -C "$W/boringssl-zig" apply "$ROOT/patches/boringssl-zig.patch"
git -C "$W/lightpanda" apply "$ROOT/patches/lightpanda.patch"

[ "${1:-}" = prepare ] && { echo "prepared: $W"; exit 0; }

(cd "$W/lightpanda" && make download-v8 && make build)
cp "$W/lightpanda/zig-out/bin/lightpanda" "$ROOT/dist/lightpanda"
echo "built: $ROOT/dist/lightpanda"
