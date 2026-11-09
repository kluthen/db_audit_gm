#!/bin/sh
# CA1 no partition dropped without a full receipt (cold-storage-archive,
# purpose 14; vet-machinery-domain.md, "cold-storage-archive"; cold-storage.md
# 2): every shipment whose partition was dropped since the judged moment
# (ops.shipments' dropped_at, in vitals and biomed) has its manifest in the
# vault, from its source, with rows declared and rows received equal to the
# rows it sent. Judges runs (T219: a partition dropped on any answer, the
# count unchecked, or on a timeout).
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), the judged moment
# as given (W4 item 0: a check needing a partner's side runs there and judges
# runs from ops.runs): the vault's manifests in partners through check-psql,
# the machinery's vitals and biomed through check-psql --node machines, as
# gm_check; no job is ever run. POSIX sh (the postgres image has no python3).
# Exit 0 fixed (with its witness, 12.3), 1 present, 2 cannot judge, 3 too
# soon (remaining=, until the job's next run at 40 past the hours 00 to 05,
# the customer's time: the GM adapts it when the job is moved). Written for
# the clinic's names (the constants below); the GM adapts them as it copies
# the purpose.
INVARIANT=CA1
PARTNERS=partners                    # the target part's database, on this node
NODE=machines                        # the source parts' node
VITALS=vitals                        # the source part's database
BIOMED=biomed                        # the source_biomed part's database
SOURCE=machines                      # the manifests' source (Shipment-Source, D381)
PURPOSE=cold-storage-archive
PSQL=/usr/local/lib/gm/check-psql

cannot() { echo "$INVARIANT cannot be judged: $*"; exit 2; }

since=${CHECK_SINCE:-}
case $since in
    [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
    *) cannot "CHECK_SINCE ($since) is not YYYY-MM-DDTHH:MM:SSZ" ;;
esac

# q <node|-> <database> [psql -v ...]: the statement on standard input, its
# rows on standard output (columns joined by |); 2 on any failure.
q() {
    where=$1 db=$2
    shift 2
    if [ "$where" = - ]; then
        "$PSQL" -d "$db" -Atq -F '|' -v ON_ERROR_STOP=1 -v since="$since" "$@" 2>&1
    else
        "$PSQL" --node "$where" -d "$db" -Atq -F '|' -v ON_ERROR_STOP=1 -v since="$since" "$@" 2>&1
    fi
}

# The seconds until the job's next run, 40 past the hours 00 to 05 local
# (the offset of vitals' settings).
next_run() {
    q "$NODE" "$VITALS" <<'SQL'
SELECT ceil(extract(epoch FROM min(t) - now()))::int
  FROM (SELECT date_trunc('hour', now()) + make_interval(hours => h) + interval '40 minutes' AS t
          FROM generate_series(0, 48) AS h) AS x, mach_vitals_settings s
 WHERE t > now()
   AND extract(hour FROM (t AT TIME ZONE 'UTC') + make_interval(hours => s.utc_offset_hours)) BETWEEN 0 AND 5
SQL
}

too_soon() {
    left=$(next_run) || cannot "reading $NODE/$VITALS: $left"
    echo "remaining=${left:-3600} $*"
    exit 3
}

# The runs of the purpose since the judged moment, in both databases.
runs() {
    v=$(q "$NODE" "$VITALS" <<'SQL'
SELECT count(*) FROM ops.runs WHERE purpose = 'cold-storage-archive' AND started_at > :'since'::timestamptz
SQL
) || cannot "reading $NODE/$VITALS: $v"
    b=$(q "$NODE" "$BIOMED" <<'SQL'
SELECT count(*) FROM ops.runs WHERE purpose = 'cold-storage-archive' AND started_at > :'since'::timestamptz
SQL
) || cannot "reading $NODE/$BIOMED: $b"
    echo $((v + b))
}

dropped=$( { q "$NODE" "$VITALS" <<'SQL'
SELECT shipment_id || ':' || rows_sent FROM ops.shipments WHERE dropped_at > :'since'::timestamptz ORDER BY day
SQL
} ) || cannot "reading $NODE/$VITALS: $dropped"
more=$( { q "$NODE" "$BIOMED" <<'SQL'
SELECT shipment_id || ':' || rows_sent FROM ops.shipments WHERE dropped_at > :'since'::timestamptz ORDER BY day
SQL
} ) || cannot "reading $NODE/$BIOMED: $more"
list=$(printf '%s\n%s\n' "$dropped" "$more" | sed '/^$/d' | tr '\n' ',' | sed 's/,$//')
if [ -z "$list" ]; then
    too_soon "no partition dropped since $since ($(runs) runs)"
fi
bad=$(q - "$PARTNERS" -v list="$list" -v source="$SOURCE" <<'SQL'
SELECT x.id || ': ' || CASE WHEN m.shipment_id IS NULL THEN 'no manifest in the vault'
                            ELSE 'the vault received ' || m.rows_received || ' of ' || m.rows_declared
                                 || ' declared rows' END || ', ' || x.sent || ' rows sent'
  FROM (SELECT split_part(e, ':', 1) AS id, split_part(e, ':', 2)::bigint AS sent
          FROM unnest(string_to_array(:'list', ',')) AS e) AS x
  LEFT JOIN coldstore.manifests m ON m.source = :'source' AND m.shipment_id = x.id
 WHERE m.shipment_id IS NULL OR m.rows_received <> x.sent OR m.rows_declared <> x.sent
 ORDER BY x.id
SQL
) || cannot "reading $PARTNERS: $bad"
n=$(printf '%s\n' "$list" | tr ',' '\n' | wc -l | tr -d ' ')
if [ -n "$bad" ]; then
    echo "$INVARIANT present: partition dropped without a full receipt, $(printf '%s\n' "$bad" | head -n 1)" \
         "($(printf '%s\n' "$bad" | wc -l | tr -d ' ') of $n dropped since $since)"
    exit 1
fi
echo "$INVARIANT fixed: $n partitions dropped since $since, each on a receipt counting all its rows"
exit 0
