version := "0.1.3"
image := "syabro/snitchmd"
local_image := "snitchmd:local"
platforms := "linux/amd64,linux/arm64"

_default:
    @just --list

# Build linux/amd64 + linux/arm64 on whichever host runs `just build`.
# Host arch builds natively; the other arch goes through qemu emulation
# (slow but works without a remote builder). Both images load into the
# local docker daemon as `snitchmd:local-{amd64,arm64}`, plus a
# `snitchmd:local` alias pointed at the host-native one for convenience.
build:
    docker buildx build --platform linux/arm64 --load --tag {{local_image}}-arm64 .
    docker buildx build --platform linux/amd64 --load --tag {{local_image}}-amd64 .
    @arch=$(uname -m); \
     if [ "$arch" = "arm64" ] || [ "$arch" = "aarch64" ]; then \
        docker tag {{local_image}}-arm64 {{local_image}}; \
     else \
        docker tag {{local_image}}-amd64 {{local_image}}; \
     fi
    @echo "→ {{local_image}}-amd64, {{local_image}}-arm64, {{local_image}}"

# Same multi-arch build, but offloaded to pc.local over SSH. Syncthing
# keeps the working tree mirrored, so we just `ssh && docker buildx`
# there. amd64 builds natively on pc, arm64 via qemu on pc. Images
# live on pc.local's docker daemon — not loaded back here.
build-pc-local:
    ssh pc.local 'cd ~/code/labs/snitchmd && docker buildx build --platform linux/amd64 --load --tag {{local_image}}-amd64 .'
    ssh pc.local 'cd ~/code/labs/snitchmd && docker buildx build --platform linux/arm64 --load --tag {{local_image}}-arm64 .'
    ssh pc.local 'docker tag {{local_image}}-amd64 {{local_image}}'
    @echo "→ pc.local: {{local_image}}-amd64, {{local_image}}-arm64, {{local_image}}"

# Build + push a multi-arch manifest (linux/amd64 + linux/arm64).
# buildx --push streams images straight to the registry; nothing is
# loaded locally because docker can't --load two architectures at once.
push:
    docker buildx build \
        --platform {{platforms}} \
        --tag {{image}}:{{version}} \
        --tag {{image}}:latest \
        --push \
        .

publish: push

bump new_version:
    scripts/bump-version {{new_version}}

release new_version:
    @test -z "$(git status --porcelain)" || (echo "Working tree must be clean before release" >&2; exit 1)
    scripts/bump-version {{new_version}}
    just update-usage-from-help
    git add Justfile skills/snitchmd/SKILL.md
    git commit -m "CHORE: bump snitchmd to {{new_version}}"
    git tag v{{new_version}}
    just publish
    git push
    git push origin v{{new_version}}

update-usage-from-help: build
    docker run --rm {{local_image}} --help | scripts/update-skill-help

run url="https://example.com": build
    docker run --rm {{local_image}} {{url}}

run-published url="https://example.com":
    docker run --rm {{image}} {{url}}

login:
    docker login

print-image:
    @echo {{image}}

render-snitchmd-flow:
    rm -rf /tmp/chromium-snitchmd
    -timeout 5 chromium --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
        --no-first-run --no-default-browser-check \
        --disable-background-networking --disable-extensions \
        --user-data-dir=/tmp/chromium-snitchmd \
        --remote-debugging-port=0 \
        --virtual-time-budget=5000 \
        --force-device-scale-factor=2 \
        --window-size=1200,1500 \
        --screenshot=/tmp/snitchmd-flow.png \
        file://{{justfile_directory()}}/assets/snitchmd-flow.html
    magick /tmp/snitchmd-flow.png -trim +repage -bordercolor white -border 80 assets/snitchmd-flow.webp
    @rm /tmp/snitchmd-flow.png
    @rm -rf /tmp/chromium-snitchmd
    @echo "rendered → assets/snitchmd-flow.webp"
