# Release binaries are built by GitHub Actions (.github/workflows/release.yml).

_default:
    @just --list

# Build dist/snitchmd for this machine (~8 min).
build:
    ./build.sh

# Tag VERSION and push it; GitHub Actions builds the binaries and publishes the release.
release version:
    @test -z "$(git status --porcelain)" || (echo "Working tree must be clean before release" >&2; exit 1)
    git tag v{{version}}
    git push
    git push origin v{{version}}
