# Release binaries: macOS arm64 is built here, Linux x86_64 on pc.local.
linux_host := "pc.local"
remote_dir := "code/labs/snitchmd"

_default:
    @just --list

# Build dist/snitchmd for this machine (~8 min).
build:
    ./build.sh

# Build the Linux x86_64 binary on pc.local into dist/snitchmd-linux-x86_64 (~10 min).
build-linux:
    rsync -a --exclude .git/worktrees --exclude node_modules --exclude .venv --exclude /build --exclude /dist --exclude log.md ./ {{linux_host}}:{{remote_dir}}/
    ssh {{linux_host}} 'cd {{remote_dir}} && ./build.sh && strip -o dist/snitchmd-linux-x86_64 dist/snitchmd'
    scp {{linux_host}}:{{remote_dir}}/dist/snitchmd-linux-x86_64 dist/

# Tag VERSION, build both binaries and publish them as a GitHub release.
release version:
    @test -z "$(git status --porcelain)" || (echo "Working tree must be clean before release" >&2; exit 1)
    just build
    strip -o dist/snitchmd-darwin-arm64 dist/snitchmd
    just build-linux
    git tag v{{version}}
    git push
    git push origin v{{version}}
    scripts/changelog-notes {{version}} | gh release create v{{version}} --title v{{version}} --notes-file - dist/snitchmd-darwin-arm64 dist/snitchmd-linux-x86_64
