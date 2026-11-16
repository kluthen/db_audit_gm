#!/bin/sh
# check-base.sh: a brick's `base:` against its image's /etc/os-release
# (v0.6 master spec 6.4; capture W1 item 1 of specs/versions/v0.6/wave-log.md).
#
# Reads `base:` ({os, version}) from <brick-dir>/brick.yaml with python3 and
# PyYAML, reads /etc/os-release from <image> in a throwaway container (no
# network), and compares NAME with `os` and VERSION_ID with `version`, as
# strings. Prints one line. Every brick's stack test calls it once, after its
# image check; the wave gate runs it alone over the ten bricks.
#
# Exit: 0 both match, 1 a difference, 2 either side can't be read (no
# brick.yaml, no or a malformed `base:`, the image absent, no os-release or
# no NAME or VERSION_ID in it).
# Usage: sh tools/tests/check-base.sh <brick-dir> <image>
set -u

if [ "$#" -ne 2 ]; then
    echo "usage: sh tools/tests/check-base.sh <brick-dir> <image>" >&2
    exit 2
fi
brick_dir=$1
image=$2

base=$(python3 -I - "$brick_dir/brick.yaml" <<'EOF' 2>&1
import sys
import yaml
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        base = (yaml.safe_load(f) or {}).get("base")
except (OSError, yaml.YAMLError) as e:
    sys.exit(f"{sys.argv[1]} unreadable: {e}")
if not isinstance(base, dict) or set(base) != {"os", "version"} or \
        not all(isinstance(base[k], str) and base[k] for k in ("os", "version")):
    sys.exit(f"{sys.argv[1]}: base is not {{os, version}}, two non-empty strings: {base!r}")
print(f"{base['os']}\t{base['version']}")
EOF
) || { echo "base: $base"; exit 2; }
want_os=$(printf '%s\n' "$base" | cut -f1)
want_version=$(printf '%s\n' "$base" | cut -f2)

release=$(docker run --rm --pull never --network none --entrypoint cat "$image" /etc/os-release 2>&1) || {
    echo "base: cannot read /etc/os-release from $image: $(printf '%s\n' "$release" | head -n 1)"
    exit 2
}
# os-release(5): KEY=value, the value optionally in double or single quotes
field() {
    printf '%s\n' "$release" | sed -n "s/^$1=//p" | head -n 1 | sed -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/"
}
got_os=$(field NAME)
got_version=$(field VERSION_ID)
if [ -z "$got_os" ] || [ -z "$got_version" ]; then
    echo "base: $image's /etc/os-release has no NAME or VERSION_ID"
    exit 2
fi

if [ "$got_os" = "$want_os" ] && [ "$got_version" = "$want_version" ]; then
    echo "base: $want_os $want_version matches $image's /etc/os-release"
    exit 0
fi
echo "base: brick.yaml says $want_os $want_version, $image's /etc/os-release says $got_os $got_version"
exit 1
