version := "0.1.1"
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
