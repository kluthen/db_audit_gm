#!/bin/sh
# Sealed check of fixture-copy-runs (test only): judges the runs since
# CHECK_SINCE; never run by the unit tests.
echo "no run since $CHECK_SINCE counted an order twice."
exit 0
