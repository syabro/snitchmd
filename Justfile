# Release binaries are built by GitHub Actions (.github/workflows/release.yml).
# Lightpanda is edited in 3rdparty/lightpanda (not in git); patches/lightpanda.patch is the source of truth.

lightpanda := "3rdparty/lightpanda"

_default:
    @just --list

# Build dist/snitchmd from clean sources and patches (~8 min).
build:
    ./build.sh

# Fetch pinned sources into 3rdparty/ and apply the patches, for editing Lightpanda.
prepare:
    @test ! -e 3rdparty || (echo "3rdparty/ exists; run 'just patch' to keep your edits, then remove it" >&2; exit 1)
    BUILD_DIR="$PWD/3rdparty" ./build.sh prepare

# Write the edits in 3rdparty/lightpanda back to patches/lightpanda.patch.
patch:
    . ./versions.env && git -C {{lightpanda}} add -A && git -C {{lightpanda}} diff --cached --full-index "$LIGHTPANDA_REV" > patches/lightpanda.patch

# Build 3rdparty/lightpanda as edited into dist/snitchmd.
dev:
    cd {{lightpanda}} && make download-v8 && make build
    cp {{lightpanda}}/zig-out/bin/lightpanda dist/snitchmd

# Run Lightpanda's tests in 3rdparty/lightpanda; F filters by test name.
test F="":
    cd {{lightpanda}} && make test F="{{F}}"

# Tag VERSION and push it; GitHub Actions builds the binaries and publishes the release.
release version:
    @test -z "$(git status --porcelain)" || (echo "Working tree must be clean before release" >&2; exit 1)
    git tag v{{version}}
    git push
    git push origin v{{version}}
