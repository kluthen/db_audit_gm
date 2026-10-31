# g3-transformer-source: the copy's transformer bi's job sync-nightly reads
# the shop through shop_wide (as shop_app, the policy's reader) instead of
# shop (as shop_etl), joined to reporting: G3's job path, on bi. Run as root
# on bi with plant or revert as its first argument; jobs.yaml only, no
# reload (G3 reads the live file; the copy's load never starts).
# node: bi
# expect: G3=1
f=/srv/scheduler/jobs/jobs.yaml
case $1 in
    plant) from=shop to=shop_wide ;;
    revert) from=shop_wide to=shop ;;
    *) echo "usage: plant|revert" >&2; exit 2 ;;
esac
# Render writes the file again: any indentation.
grep -q "^ *source: $from\$" "$f" || { echo "no source: $from in $f" >&2; exit 1; }
sed -i "s/^\( *source: \)$from\$/\1$to/" "$f"
grep -q "^ *source: $to\$" "$f" || { echo "source: $to not written in $f" >&2; exit 1; }
