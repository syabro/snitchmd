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
