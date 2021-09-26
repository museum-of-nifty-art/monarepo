#/bin/sh
docker run -v "$PWD":/tmp/project -w /tmp/project --rm -it node:alpine sh
