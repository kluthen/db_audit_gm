#!/bin/sh
# Extracts members of the shop's real-aging reference (v0.6 master spec
# 12.3, spec D519; capture W1 item 3) into the untracked working
# directory extracted/ beside this script, and checks each against
# MANIFEST.sha256. The archive is kept outside git: see README.md here.
#
# Usage: sh tools/fake_aging/reference/extract.sh [--archive <path>] <member>...
#   <member>: a path from MANIFEST.sha256 (relative to results/); a folder
#     ending `/` takes every file under it; a quoted shell pattern
#     ('calibrate-r-*-20261115.txt') every manifest path it matches.
#     A member matching nothing is an error.
#   --archive <path>: another archive (default: the reference's, below);
#     its checksum is read from <path>.sha256.
#   e.g. sh tools/fake_aging/reference/extract.sh 'calibrate-r-*-20261115.txt'
#
# Checks the archive against its .sha256 once a run, extracts what is not
# already in extracted/ and matching the manifest, checks each extracted
# file against the manifest, then prints every member file's absolute
# path, one a line, on standard output; messages go to standard error.
#
# Exit status: 0 done; 1 a check failed (the archive's checksum, a file's
# manifest line, an unknown member) or the extraction failed; 2 usage;
# 77 skip: the archive is absent (automake's skip status; a Python test
# calls skipTest with the message, a shell test prints SKIP and counts no
# failure). Only absence skips: a checksum mismatch fails.

ARCHIVE_DEFAULT=/home/bastien/archive/db_audit_gm/fake-aging-shop-reference/results-20261115.tar.zst

usage() {
    echo "usage: sh tools/fake_aging/reference/extract.sh [--archive <path>] <member>..." >&2
}

fail() {
    echo "extract.sh: $*" >&2
    exit 1
}

here=$(cd "$(dirname "$0")" && pwd) || fail "cannot find the script's directory"
manifest=$here/MANIFEST.sha256
extracted=$here/extracted
archive=$ARCHIVE_DEFAULT

# Members, one a line (no manifest path holds a newline).
members=
while [ $# -gt 0 ]; do
    case $1 in
        --archive)
            [ $# -ge 2 ] && [ -n "$2" ] || { usage; exit 2; }
            archive=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "extract.sh: unknown option $1" >&2
            usage
            exit 2
            ;;
        *)
            break
            ;;
    esac
done
for m in "$@"; do
    [ -n "$m" ] || { usage; exit 2; }
    members="$members$m
"
done
[ -n "$members" ] || { usage; exit 2; }

[ -f "$manifest" ] || fail "the manifest $manifest is missing"

tmp=$(mktemp -d) || fail "cannot create a temporary directory"
trap 'rm -rf "$tmp"' EXIT
trap 'exit 1' HUP INT TERM

# Resolve the members against the manifest: <hash>  <path> lines.
: > "$tmp/wanted"
while IFS= read -r m; do
    [ -n "$m" ] || continue
    found=0
    while read -r hash path; do
        case $m in
            */)
                case $path in "$m"*) ;; *) continue ;; esac
                ;;
            *[*?[]*)
                # Unquoted on purpose: the member is a shell pattern.
                # shellcheck disable=SC2254
                case $path in $m) ;; *) continue ;; esac
                ;;
            *)
                [ "$path" = "$m" ] || continue
                ;;
        esac
        printf '%s  %s\n' "$hash" "$path" >> "$tmp/wanted"
        found=1
    done < "$manifest"
    [ "$found" = 1 ] || fail "no file in the reference matches $m (see $manifest)"
done <<EOF
$members
EOF
LC_ALL=C sort -u -k2 "$tmp/wanted" > "$tmp/wanted.sorted" || fail "cannot sort the members"

if [ ! -e "$archive" ]; then
    echo "extract.sh: SKIP: the reference archive $archive is absent (kept outside git, spec D519; see tools/fake_aging/reference/README.md)" >&2
    exit 77
fi

[ -f "$archive.sha256" ] || fail "the archive's checksum file $archive.sha256 is missing"
expected=$(cut -d ' ' -f 1 < "$archive.sha256")
actual=$(sha256sum < "$archive" | cut -d ' ' -f 1) || fail "cannot read $archive"
[ -n "$expected" ] && [ "$expected" = "$actual" ] ||
    fail "the archive $archive does not match its checksum $archive.sha256 (expected $expected, got $actual)"

mkdir -p "$extracted" || fail "cannot create $extracted"

# What is not already there and matching the manifest.
: > "$tmp/needed"
while read -r hash path; do
    if [ -f "$extracted/$path" ]; then
        have=$(sha256sum < "$extracted/$path" | cut -d ' ' -f 1)
        [ "$have" = "$hash" ] && continue
    fi
    printf '%s  %s\n' "$hash" "$path" >> "$tmp/needed"
done < "$tmp/wanted.sorted"

if [ -s "$tmp/needed" ]; then
    while read -r hash path; do
        printf 'results/%s\n' "$path"
    done < "$tmp/needed" > "$tmp/names"
    echo "extract.sh: extracting $(wc -l < "$tmp/needed") file(s) from $archive" >&2
    tar --zstd -xf "$archive" -C "$extracted" --strip-components=1 \
        --no-wildcards --verbatim-files-from -T "$tmp/names" ||
        fail "the extraction from $archive failed"
    (cd "$extracted" && sha256sum -c --quiet "$tmp/needed") >&2 ||
        fail "an extracted file does not match its line in $manifest"
fi

while read -r hash path; do
    printf '%s\n' "$extracted/$path"
done < "$tmp/wanted.sorted"
exit 0
