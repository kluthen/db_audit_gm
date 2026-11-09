#!/bin/sh
# CA4 end to end (cold-storage-archive, purpose 14; vet-machinery-domain.md,
# "cold-storage-archive"; cold-storage.md 2): every day written since the
# judged moment (its local end after it), of each type, whose shipping night
# has passed (06:00 local the night after the window, the window read from
# the settings) appears in the vault from its source with rows received equal
# to rows declared, and no partition whose shipping night has passed stays on
# site. Judges the round trip end to end (T220 the shipping stalled, T222 the
# window wrong, any of T219 to T226 that keeps a day from the vault).
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
INVARIANT=CA4
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

# Per type: the days judged (written since the judged moment, their night
# passed), the days still to come, and the partitions left past their night.
days() {   # days <db> <parent> <settings> <type>
    q "$NODE" "$1" -v parent="$2" -v type="$4" <<SQL
WITH s AS (SELECT utc_offset_hours AS o, window_days AS w,
                  ((now() AT TIME ZONE 'UTC') + make_interval(hours => utc_offset_hours))::date AS today
             FROM $3),
d AS (SELECT g::date AS day, s.o, s.w,
             ((g::date + s.w + 1)::timestamp + interval '6 hours' - make_interval(hours => s.o)) AT TIME ZONE 'UTC'
               AS night
        FROM s, generate_series(((:'since'::timestamptz AT TIME ZONE 'UTC') + make_interval(hours => s.o))::date,
                                s.today, interval '1 day') AS g)
SELECT 'judged|' || :'type' || '-' || to_char(day, 'YYYYMMDD') FROM d WHERE night <= now()
UNION ALL
SELECT 'later|' || ceil(extract(epoch FROM min(night) - now()))::int FROM d WHERE night > now() HAVING count(*) > 0
UNION ALL
SELECT 'left|' || c.relname
  FROM pg_catalog.pg_inherits i JOIN pg_catalog.pg_class c ON c.oid = i.inhrelid, s
 WHERE i.inhparent = :'parent'::regclass AND c.relname ~ ('^' || :'parent' || '_[0-9]{8}$')
   AND ((to_date(right(c.relname, 8), 'YYYYMMDD') + s.w + 1)::timestamp + interval '6 hours'
        - make_interval(hours => s.o)) AT TIME ZONE 'UTC' <= now()
SQL
}
v=$(days "$VITALS" mach_vitals mach_vitals_settings vitals) || cannot "reading $NODE/$VITALS: $v"
b=$(days "$BIOMED" mach_readings mach_settings machine-readings) || cannot "reading $NODE/$BIOMED: $b"
all=$(printf '%s\n%s\n' "$v" "$b" | sed '/^$/d')
left=$(printf '%s\n' "$all" | sed -n 's/^left|//p')
if [ -n "$left" ]; then
    echo "$INVARIANT present: partition $(printf '%s\n' "$left" | head -n 1) still on site past its shipping" \
         "night ($(printf '%s\n' "$left" | wc -l | tr -d ' ') partitions)"
    exit 1
fi
list=$(printf '%s\n' "$all" | sed -n 's/^judged|//p' | tr '\n' ',' | sed 's/,$//')
if [ -n "$list" ]; then
    bad=$(q - "$PARTNERS" -v list="$list" -v source="$SOURCE" <<'SQL'
SELECT x.id || ': ' || CASE WHEN m.shipment_id IS NULL THEN 'not in the vault'
                            ELSE 'received ' || m.rows_received || ' of ' || m.rows_declared || ' rows' END
  FROM unnest(string_to_array(:'list', ',')) AS x (id)
  LEFT JOIN coldstore.manifests m ON m.source = :'source' AND m.shipment_id = x.id
 WHERE m.shipment_id IS NULL OR m.rows_received <> m.rows_declared
 ORDER BY x.id
SQL
) || cannot "reading $PARTNERS: $bad"
    n=$(printf '%s\n' "$list" | tr ',' '\n' | wc -l | tr -d ' ')
    if [ -n "$bad" ]; then
        echo "$INVARIANT present: $(printf '%s\n' "$bad" | head -n 1) past its shipping night" \
             "($(printf '%s\n' "$bad" | wc -l | tr -d ' ') of $n type-days written since $since)"
        exit 1
    fi
    echo "$INVARIANT fixed: $n type-days written since $since in the vault, every row received, none left on site"
    exit 0
fi
later=$(printf '%s\n' "$all" | sed -n 's/^later|//p' | sort -n | head -n 1)
echo "remaining=${later:-3600} no day written since $since has passed its shipping night"
exit 3
