#!/bin/sh
# Unit tests of the scheduler program (v0.3 build plan, chunk 3), run in the
# image so the host needs no psycopg: builds the Dockerfile's `unit-test`
# stage (the program as the node installs it, plus Debian's PostgreSQL),
# then runs tests/unit/ in a throwaway container, removed at the end. The
# tests use real time: about two minutes.
#
# Needs Docker. On the build host, run it under the host lock:
#   flock /tmp/dbagm-docker.lock sh bricks/scheduler/tests/run-unit-tests.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
BRICK=$(cd "$HERE/.." && pwd)
TAG=dbagm-test/scheduler-unit:0.1.0
NAME=gmtest-scheduler-unit

docker rm -f "$NAME" >/dev/null 2>&1 || true
docker build -q --target unit-test -t "$TAG" "$BRICK" >/dev/null
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT
docker run --rm --name "$NAME" --memory 512m "$TAG"
