#!/bin/sh
# Unit tests of the api brick's library gm_api (v0.5 build plan, chunk 5),
# run in the image so the host needs neither FastAPI nor psycopg: builds the
# Dockerfile's `unit-test` stage (the library and G6's set as the node
# installs them, plus Debian's PostgreSQL), then runs tests/unit/ in a
# throwaway container, removed at the end. About a minute.
#
# Needs Docker. On the build host, run it under the host lock:
#   flock /tmp/dbagm-docker.lock sh bricks/api/tests/run-unit-tests.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
BRICK=$(cd "$HERE/.." && pwd)
TAG=dbagm-test/api-unit:0.1.0
NAME=gmtest-api-unit

docker rm -f "$NAME" >/dev/null 2>&1 || true
docker build -q --target unit-test -t "$TAG" "$BRICK" >/dev/null
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT
docker run --rm --name "$NAME" --memory 512m "$TAG"
