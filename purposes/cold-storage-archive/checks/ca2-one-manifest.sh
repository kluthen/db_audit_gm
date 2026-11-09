#!/bin/sh
# CA2 one manifest per type and day (cold-storage-archive, purpose 14;
# vet-machinery-domain.md, "cold-storage-archive"; cold-storage.md 3): no day
# of a type shipped since the judged moment (its manifests from the source
# received since then) has two manifests of that type from its source.
# Judges runs (T221: a resend under a new shipment id, a day counted twice on
# the graph).
# Runs on the partners' database node (partners-db) as root, fed to `sh -s`
# by gmctl check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ), the judged moment
# as given (W4 item 0: a check needing a partner's side runs there and judges
# runs from ops.runs): the vault's manifests in partners through check-psql,
# the machinery's vitals and biomed through check-psql --node machines, as
# gm_check; no job is ever run. POSIX sh (the postgres image has no python3).
# Exit 0 fixed (with its witness, 12.3), 1 present, 2 cannot judge, 3 too
# soon (remaining=, until the job's next run: RUN_MINUTE past the hours
# RUN_FIRST_HOUR to RUN_LAST_HOUR, the customer's time, the job's cadence
# "40 0-5 * * *" as shipped; the GM adapts the three with the job when it
# moves it). Written for the clinic's names (the constants below); the GM
# adapts them as it copies the purpose.
INVARIANT=CA2
PARTNERS=partners                    # the target part's database, on this node
NODE=machines                        # the source parts' node
VITALS=vitals                        # the source part's database
BIOMED=biomed                        # the source_biomed part's database
SOURCE=machines                      # the manifests' source (Shipment-Source, D381)
RUN_MINUTE=40                        # ship-partitions' minute, local (its at:)
RUN_FIRST_HOUR=0                     # its first hour of the night, local
RUN_LAST_HOUR=5                      # its last hour, local (05:40, the last resend)
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

# The seconds until the job's next run, RUN_MINUTE past the hours
# RUN_FIRST_HOUR to RUN_LAST_HOUR local (the offset of vitals' settings).
next_run() {
    q "$NODE" "$VITALS" -v minute="$RUN_MINUTE" -v first="$RUN_FIRST_HOUR" -v last="$RUN_LAST_HOUR" <<'SQL'
SELECT ceil(extract(epoch FROM min(t) - now()))::int
  FROM (SELECT date_trunc('hour', now()) + make_interval(hours => h, mins => :minute) AS t
          FROM generate_series(0, 48) AS h) AS x, mach_vitals_settings s
 WHERE t > now()
   AND extract(hour FROM (t AT TIME ZONE 'UTC') + make_interval(hours => s.utc_offset_hours))
       BETWEEN :first AND :last
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

rows=$(q - "$PARTNERS" -v source="$SOURCE" <<'SQL'
WITH shipped AS (
    SELECT DISTINCT type, date_from FROM coldstore.manifests
     WHERE source = :'source' AND type IN ('vitals', 'machine-readings')
       AND received_at > :'since'::timestamptz)
SELECT s.type || '|' || s.date_from || '|' || count(m.*) || '|' || string_agg(m.shipment_id, ' ' ORDER BY m.received_at)
  FROM shipped s JOIN coldstore.manifests m
    ON m.source = :'source' AND m.type = s.type AND m.date_from = s.date_from
 GROUP BY s.type, s.date_from ORDER BY s.date_from, s.type
SQL
) || cannot "reading $PARTNERS: $rows"
if [ -z "$rows" ]; then
    too_soon "no manifest received from $SOURCE since $since ($(runs) runs)"
fi
twice=$(printf '%s\n' "$rows" | awk -F'|' '$3 > 1')
n=$(printf '%s\n' "$rows" | wc -l | tr -d ' ')
if [ -n "$twice" ]; then
    first=$(printf '%s\n' "$twice" | head -n 1)
    echo "$INVARIANT present: $(echo "$first" | cut -d'|' -f1) of $(echo "$first" | cut -d'|' -f2) has" \
         "$(echo "$first" | cut -d'|' -f3) manifests ($(echo "$first" | cut -d'|' -f4))," \
         "$(printf '%s\n' "$twice" | wc -l | tr -d ' ') of $n type-days shipped since $since"
    exit 1
fi
echo "$INVARIANT fixed: $n type-days shipped since $since, one manifest each"
exit 0
