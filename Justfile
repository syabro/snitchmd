image := "syabro/cloak2md:latest"
local_image := "cloak2md:local"

_default:
    @just --list

build:
    docker build -t {{local_image}} .

push: build
    docker tag {{local_image}} {{image}}
    docker push {{image}}

publish: push

run url="https://example.com": build
    docker run --rm {{local_image}} {{url}}

run-published url="https://example.com":
    docker run --rm {{image}} {{url}}

login:
    docker login

print-image:
    @echo {{image}}

render-cloak2md-flow:
    rm -rf /tmp/chromium-cloak2md
    -timeout 5 chromium --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
        --no-first-run --no-default-browser-check \
        --disable-background-networking --disable-extensions \
        --user-data-dir=/tmp/chromium-cloak2md \
        --remote-debugging-port=0 \
        --virtual-time-budget=5000 \
        --force-device-scale-factor=2 \
        --window-size=1200,1500 \
        --screenshot=/tmp/cloak2md-flow.png \
        file://{{justfile_directory()}}/assets/cloak2md-flow.html
    magick /tmp/cloak2md-flow.png -trim +repage assets/cloak2md-flow.webp
    @rm /tmp/cloak2md-flow.png
    @rm -rf /tmp/chromium-cloak2md
    @echo "rendered → assets/cloak2md-flow.webp"
