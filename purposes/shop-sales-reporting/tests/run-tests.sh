#!/bin/sh
# Tests of the sales reporting purpose (v0.4 build plan chunk 10) in the
# scheduler's unit-test harness: builds the scheduler brick's `unit-test`
# stage (bricks/scheduler/tests/run-unit-tests.sh's image: the program,
# Debian's PostgreSQL, and tests/unit/run-in-image.sh, which starts a
# throwaway PostgreSQL with the roles shop_etl and bi_etl), then runs it with
# test_shop_sales_reporting.py mounted beside the brick's own unit tests, the
# purpose, the shop domain and the brick's check helpers mounted read-only,
# and the scenario's node names db and reporting resolving to the throwaway
# server. The brick's unit tests run too. Real time: about fifteen minutes
# (the jobs run at their moved times).
#
# Needs Docker. On the build host, under the host lock and a sleep inhibitor:
#   flock /tmp/dbagm-docker.lock systemd-inhibit --what=sleep:idle:handle-lid-switch \
#       sh purposes/shop-sales-reporting/tests/run-tests.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
PURPOSE=$(cd "$HERE/.." && pwd)
REPO=$(cd "$PURPOSE/../.." && pwd)
BRICK=$REPO/bricks/scheduler
TAG=dbagm-test/scheduler-unit:0.2.0
NAME=gmtest-shop-sales-reporting

docker rm -f "$NAME" >/dev/null 2>&1 || true
docker build -q --target unit-test -t "$TAG" "$BRICK" >/dev/null
trap 'docker rm -f "$NAME" >/dev/null 2>&1 || true' EXIT
docker run --rm --name "$NAME" --memory 768m \
    --add-host db:127.0.0.1 --add-host reporting:127.0.0.1 \
    -v "$HERE/test_shop_sales_reporting.py:/opt/gm-test/unit/test_shop_sales_reporting.py:ro" \
    -v "$PURPOSE:/opt/gm-test/purpose:ro" \
    -v "$REPO/domains/shop:/opt/gm-test/domain:ro" \
    -v "$BRICK/rootfs/usr/local/lib/gm:/usr/local/lib/gm:ro" \
    "$TAG"
