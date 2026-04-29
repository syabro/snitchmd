version := "0.1.3"
image := "syabro/snitchmd"
local_image := "snitchmd:local"

_default:
    @just --list

build:
    docker build -t {{local_image}} .

push: build
    docker tag {{local_image}} {{image}}:{{version}}
    docker tag {{local_image}} {{image}}:latest
    docker push {{image}}:{{version}}
    docker push {{image}}:latest

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
