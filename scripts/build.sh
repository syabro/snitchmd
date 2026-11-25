#!/bin/sh
# Fetches pinned Lightpanda, BoringSSL, boringssl-zig, curl, and curl-impersonate,
# applies patches, and builds dist/snitchmd.
# `build.sh prepare` stops after patching.
# BUILD_DIR (default build/) is where sources are fetched; `just prepare` uses 3rdparty/.
set -eu

ROOT="$(cd "$(dirname "$0")" && pwd)"
. "$ROOT/versions.env"
BUILD="${BUILD_DIR:-$ROOT/build}"

mkdir -p "$BUILD/dl"
export ZIG_GLOBAL_CACHE_DIR="$BUILD/zig-global"

# Checks out <url> at <rev> into $BUILD/<name>, discarding earlier patches;
# keeps ignored files (build caches).
checkout() {
  name=$1 url=$2 rev=$3
  dir="$BUILD/$name"

  if [ ! -d "$dir/.git" ]; then
    git init -q "$dir"
    git -C "$dir" remote add origin "$url"
  fi

  git -C "$dir" fetch -q --depth 1 origin "$rev"
  git -C "$dir" checkout -q -f FETCH_HEAD
  git -C "$dir" clean -q -fd
}

# Fixed names: patches reference ../boringssl and ../boringssl-zig.
checkout curl-impersonate "$CURL_IMPERSONATE_URL" "$CURL_IMPERSONATE_REV"
checkout boringssl "$BORINGSSL_URL" "$BORINGSSL_REV"
checkout boringssl-zig "$BORINGSSL_ZIG_URL" "$BORINGSSL_ZIG_REV"
checkout lightpanda "$LIGHTPANDA_URL" "$LIGHTPANDA_REV"

# Fixed name: patches/lightpanda.patch references ../curl.
curl_dir="$BUILD/curl"
tarball="$BUILD/dl/curl-$CURL_VERSION.tar.gz"
curl_version_tag=$(echo "$CURL_VERSION" | tr . _)
curl_tag="curl-$curl_version_tag"
if [ ! -f "$tarball" ]; then
  curl -fsSL -o "$tarball" "https://github.com/curl/curl/releases/download/$curl_tag/curl-$CURL_VERSION.tar.gz"
fi

rm -rf "$curl_dir"
mkdir -p "$curl_dir"
tar -xzf "$tarball" -C "$curl_dir" --strip-components=1

# Separate git repo so git apply resolves paths here, not against the parent checkout.
git init -q "$curl_dir"

# curl-impersonate's curl.patch targets the git tree: curlver.h differs in the
# release tarball and scripts/singleuse.pl is not shipped.
git -C "$curl_dir" apply \
  --exclude=include/curl/curlver.h --exclude=scripts/singleuse.pl \
  "$BUILD/curl-impersonate/patches/curl.patch"

git -C "$BUILD/boringssl" apply "$BUILD/curl-impersonate/patches/boringssl.patch"
git -C "$BUILD/boringssl-zig" apply "$ROOT/patches/boringssl-zig.patch"
git -C "$BUILD/lightpanda" apply "$ROOT/patches/lightpanda.patch"

# prepare: stop after patching to allow inspecting or modifying build/.
if [ "${1:-}" = prepare ]; then
  echo "prepared: $BUILD"
  exit 0
fi

(cd "$BUILD/lightpanda" && make download-v8 && make build)

mkdir -p "$ROOT/dist"
cp "$BUILD/lightpanda/zig-out/bin/lightpanda" "$ROOT/dist/snitchmd"
echo "built: $ROOT/dist/snitchmd"
