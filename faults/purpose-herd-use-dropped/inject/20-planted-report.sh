#!/bin/sh
# Plants purpose-herd-use-dropped's past (capture W5 item 3 of
# specs/versions/v0.5/wave-log.md; spec D459): run on the node holding the
# purpose's target (FAULT_TARGET_NODE, the clinic's records), as root,
# querying as postgres over the local socket, every session unseen
# (statement logging, pg_stat_statements and pgaudit off, as load-data's).
#
# The seed change (the feeder's query, an inner join on animals) is in place
# from T0; this script makes the planted past agree with it: from the first
# day of the year last reported (amu_reports' latest year) to the last day
# the feeder wrote, each antimicrobial_use row of the target is rewritten as
# the faulty query would have written it (the herd treatments, dispensed to a
# herd with no animal, fallen out: their dispensings, quantity and herds
# gone; a row holding nothing else removed), each feeder run's counts with
# it; then last year's report (its lines summed again from those days, as the
# report job sums them) and its copy in regulatory_submissions, the reference
# and its form (AMU<year>-NNNN) kept, the report run's rows read with it. The
# report is short of the cattle's herd use, its rerun the players' to
# recommend (spec D277).
#
# Reads the record (FAULT_SOURCE, <node>/<database>, on this same node) with
# the faulty query's own computation and streams the result into the target
# (FAULT_TARGET) in one transaction. Idempotent: the rows are set to what the
# faulty query computes, so a second run changes nothing. Fails, changing
# nothing, when the source or the target is not on this node, or the target
# holds no report.
set -eu

fail() { echo "purpose-herd-use-dropped: $*" >&2; exit 1; }

SOURCE=${FAULT_SOURCE:-records/clinic}
TARGET=${FAULT_TARGET:-records/office}
JOB=${FAULT_JOB:-feed-antimicrobial-use}
HERE=$(cat /proc/sys/kernel/hostname)
for loc in "$SOURCE" "$TARGET"; do
    case $loc in
        */*/*|/*|*/) fail "$loc is not <node>/<database>" ;;
        */*) ;;
        *) fail "$loc is not <node>/<database>" ;;
    esac
done
case ${SOURCE#*/}${TARGET#*/}$JOB in *[!a-z0-9_-]*) fail "a database or job name with an unexpected character" ;; esac
[ "${SOURCE%%/*}" = "$HERE" ] && [ "${TARGET%%/*}" = "$HERE" ] \
    || fail "the source ($SOURCE) and the target ($TARGET) must both be on this node ($HERE)"
SDB=${SOURCE#*/}
TDB=${TARGET#*/}

UNSEEN="SET log_statement = 'none';
SET log_min_duration_statement = -1;
SET log_min_error_statement = 'panic';
SET log_temp_files = -1;
SET pg_stat_statements.track = 'none';
SET pgaudit.log = 'none';
SET client_min_messages = warning;"
pg() { runuser -u postgres -- psql -X -q -A -t -v ON_ERROR_STOP=1 "$@"; }

# The year last reported and the feeder's last day, in the target.
span=$( { printf '%s\n' "$UNSEEN"; cat <<'SQL'; } | pg -d "$TDB"
SELECT coalesce(max(r.year)::text, '-') || ' ' || coalesce((SELECT max(day)::text FROM antimicrobial_use), '-')
  FROM amu_reports r
SQL
) || fail "cannot read $TARGET"
YEAR=${span%% *}
LAST=${span#* }
[ "$YEAR" != - ] || fail "$TARGET holds no antimicrobial-use report to plant short"
[ "$LAST" != - ] || fail "$TARGET holds no antimicrobial use"

# The faulty query's days, from the source, into a root-only file removed on
# exit, then streamed as COPY data into the target's one transaction.
umask 077
days=$(mktemp) || fail "cannot create a temporary file"
trap 'rm -f "$days"' EXIT
{ printf '%s\n' "$UNSEEN"; cat <<'SQL'; } | pg -d "$SDB" -v year="$YEAR" -v last="$LAST" > "$days" \
    || fail "cannot read $SOURCE"
COPY (
  WITH s AS (SELECT timezone AS tz FROM business_settings),
  herd_species AS (SELECT herd_id, min(species) AS species FROM animals WHERE herd_id IS NOT NULL GROUP BY herd_id),
  uses AS (
    SELECT (a.given_at AT TIME ZONE s.tz)::date AS day, an.species, m.atcvet_code, 'administration' AS use,
           a.quantity, a.animal_id, NULL::integer AS herd_id
      FROM s, administrations a
      JOIN medicines m ON m.id = a.medicine_id
      JOIN animals an ON an.id = a.animal_id
     WHERE m.antimicrobial AND a.state = 'given'
       AND a.given_at >= (:'year'::date)::timestamp AT TIME ZONE s.tz
       AND a.given_at < (:'last'::date + 1)::timestamp AT TIME ZONE s.tz
    UNION ALL
    SELECT (d.dispensed_at AT TIME ZONE s.tz)::date, coalesce(an.species, hs.species), m.atcvet_code, 'dispensing',
           d.quantity, p.animal_id, p.herd_id
      FROM s, dispensings d
      JOIN prescription_lines l ON l.id = d.prescription_line_id
      JOIN prescriptions p ON p.id = l.prescription_id
      JOIN medicines m ON m.id = l.medicine_id
      JOIN animals an ON an.id = p.animal_id
      LEFT JOIN herd_species hs ON hs.herd_id = p.herd_id
     WHERE m.antimicrobial
       AND d.dispensed_at >= (:'year'::date)::timestamp AT TIME ZONE s.tz
       AND d.dispensed_at < (:'last'::date + 1)::timestamp AT TIME ZONE s.tz)
  SELECT day, species, atcvet_code, count(*) FILTER (WHERE use = 'administration'),
         count(*) FILTER (WHERE use = 'dispensing'), sum(quantity), count(DISTINCT animal_id),
         count(DISTINCT herd_id)
    FROM uses GROUP BY day, species, atcvet_code
) TO STDOUT;
SQL
{
    printf '%s\n' "$UNSEEN"
    cat <<'SQL'
BEGIN;
CREATE TEMP TABLE h_faulty (day date, species text, atcvet_code text, administrations integer, dispensings integer,
                            quantity numeric(12,2), animals_treated integer, herds_treated integer) ON COMMIT DROP;
COPY h_faulty FROM STDIN;
SQL
    cat "$days"
    printf '%s\n' '\.'
    cat <<'SQL'
CREATE TEMP TABLE h_touched ON COMMIT DROP AS
SELECT DISTINCT u.run_id FROM antimicrobial_use u JOIN runs r ON r.id = u.run_id
 WHERE u.day >= :'year'::date AND u.day <= :'last'::date AND r.job = :'job';
WITH changed AS (
  UPDATE antimicrobial_use u
     SET administrations = f.administrations, dispensings = f.dispensings, quantity = f.quantity,
         animals_treated = f.animals_treated, herds_treated = f.herds_treated
    FROM h_faulty f
   WHERE u.day = f.day AND u.species = f.species AND u.atcvet_code = f.atcvet_code
     AND u.run_id IN (SELECT run_id FROM h_touched)
     AND (u.administrations, u.dispensings, u.quantity, u.animals_treated, u.herds_treated)
         IS DISTINCT FROM (f.administrations, f.dispensings, f.quantity, f.animals_treated, f.herds_treated)
  RETURNING 1)
SELECT count(*) AS changed FROM changed \gset
WITH gone AS (
  DELETE FROM antimicrobial_use u
   WHERE u.run_id IN (SELECT run_id FROM h_touched)
     AND NOT EXISTS (SELECT 1 FROM h_faulty f
                      WHERE f.day = u.day AND f.species = u.species AND f.atcvet_code = u.atcvet_code)
  RETURNING 1)
SELECT count(*) AS removed FROM gone \gset
UPDATE runs r SET rows_read = n.n, rows_written = n.n
  FROM (SELECT t.run_id, (SELECT count(*) FROM antimicrobial_use u WHERE u.run_id = t.run_id)::integer AS n
          FROM h_touched t) n
 WHERE r.id = n.run_id AND (r.rows_read, r.rows_written) IS DISTINCT FROM (n.n, n.n);

-- Last year's report, summed again from its days as the report job sums
-- them; its copy as sent; the reference kept.
UPDATE amu_reports r
   SET payload = jsonb_set(r.payload, '{lines}', coalesce((
         SELECT jsonb_agg(jsonb_build_object('atcvet_code', a.atcvet_code, 'administrations', a.administrations,
                                             'dispensings', a.dispensings, 'quantity', a.quantity,
                                             'animals_treated', a.animals_treated, 'herds_treated', a.herds_treated)
                          ORDER BY a.atcvet_code)
           FROM (SELECT atcvet_code, sum(administrations) AS administrations, sum(dispensings) AS dispensings,
                        sum(quantity)::float8 AS quantity, sum(animals_treated) AS animals_treated,
                        sum(herds_treated) AS herds_treated
                   FROM antimicrobial_use
                  WHERE species = r.species AND day >= r.year AND day < (r.year + interval '1 year')::date
                  GROUP BY atcvet_code) a), '[]'::jsonb))
 WHERE r.year = :'year'::date;
UPDATE regulatory_submissions s SET payload = r.payload
  FROM amu_reports r
 WHERE r.year = :'year'::date AND s.kind = 'amu-report' AND s.ref = r.payload->>'report_key'
   AND s.payload IS DISTINCT FROM r.payload;
UPDATE runs x SET rows_read = n.n
  FROM (SELECT r.run_id, sum((SELECT count(*) FROM antimicrobial_use u
                               WHERE u.species = r.species AND u.day >= r.year
                                 AND u.day < (r.year + interval '1 year')::date))::integer AS n
          FROM amu_reports r WHERE r.year = :'year'::date GROUP BY r.run_id) n
 WHERE x.id = n.run_id;
SELECT string_agg(r.species || ' ' || r.reference || ' herds ' ||
                  (SELECT coalesce(sum((l->>'herds_treated')::integer), 0) FROM jsonb_array_elements(r.payload->'lines') l),
                  ', ' ORDER BY r.species) AS report
  FROM amu_reports r WHERE r.year = :'year'::date \gset
COMMIT;
\echo antimicrobial use from :year to :last planted as the faulty query writes it: :changed rows rewritten, :removed removed; the :year report: :report
SQL
} | pg -d "$TDB" -v year="$YEAR" -v last="$LAST" -v job="$JOB"
