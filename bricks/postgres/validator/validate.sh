#!/bin/sh
# Public validator of the db_audit_gm PostgreSQL node (master spec 9.1, 8.1).
# DO NOT TAMPER. Root-owned, read-only. Run as `postgres`:
#   players:  sudo gm-validate
#   GM:       /opt/gm/validator/validate.sh, executed as postgres
#
# Rules:
#   - the server accepts connections;
#   - pg_hba.conf holds the GM's line `local all postgres peer`;
#   - every knob in the envelope file is within its envelope, both the value
#     in effect (pg_settings) and the value pending in the configuration
#     files (pg_file_settings, the entry a reload or restart would apply).
#
# Envelope file (default /opt/gm/protected/envelopes.conf), one rule a line,
# `#` comments and blank lines ignored:
#   <setting> range <min> <max>     bounds as PostgreSQL accepts them
#                                   (128MB, 30s, 100), or - for unbounded
#   <setting> enum <v1>,<v2>,...
# Values are compared in the setting's base unit, as PostgreSQL computes it.
#
# Output and exit code:
#   0  green: one line `GREEN: ...`
#   1  red:   one line `RED <rule>: ...` per broken rule
#   2  error: `ERROR: ...` (unreadable or malformed envelope file, unexpected
#      query failure); the result is unknown
set -u
set -f   # no globbing when splitting envelope lines
PATH=/usr/bin:/bin:/usr/sbin:/sbin
export PATH
LC_ALL=C.UTF-8
export LC_ALL

ENVELOPES=${1:-/opt/gm/protected/envelopes.conf}
HBA=/etc/postgresql/pg_hba.conf
SOCKET_DIR=/run/postgresql
PORT=5432
PGCONNECT_TIMEOUT=5
PGAPPNAME=gm-validate
export PGCONNECT_TIMEOUT PGAPPNAME

red=0
say_red() { red=$((red + 1)); printf 'RED %s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*"; exit 2; }

# --- envelope file -------------------------------------------------------
[ -r "$ENVELOPES" ] || fail "envelope file $ENVELOPES is missing or unreadable"

token_ok() {  # a bound or an allowed value: no quotes, no spaces
    printf '%s' "$1" | grep -Eq '^[A-Za-z0-9_.+-]+$'
}

rules_sql=""   # VALUES rows: (id, line, name, kind)
vals_sql=""    # VALUES rows: (id, which, raw)
nrules=0
lineno=0
while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno + 1))
    line=${line%%#*}
    # shellcheck disable=SC2086
    set -- $line
    [ "$#" -eq 0 ] && continue
    name=$1
    kind=${2:-}
    printf '%s' "$name" | grep -Eq '^[a-z_][a-z0-9_.]*$' \
        || fail "$ENVELOPES line $lineno: bad setting name '$name'"
    nrules=$((nrules + 1))
    case $kind in
        range)
            [ "$#" -eq 4 ] || fail "$ENVELOPES line $lineno: expected '<setting> range <min> <max>'"
            token_ok "$3" && token_ok "$4" || fail "$ENVELOPES line $lineno: bad bound"
            vals_sql="$vals_sql${vals_sql:+,}($nrules,'lo','$3'),($nrules,'hi','$4')"
            ;;
        enum)
            [ "$#" -eq 3 ] || fail "$ENVELOPES line $lineno: expected '<setting> enum <v1>,<v2>,...'"
            old_ifs=$IFS
            IFS=,
            # shellcheck disable=SC2086
            set -- $3
            IFS=$old_ifs
            [ "$#" -gt 0 ] || fail "$ENVELOPES line $lineno: empty enum"
            for v in "$@"; do
                token_ok "$v" || fail "$ENVELOPES line $lineno: bad allowed value '$v'"
                vals_sql="$vals_sql${vals_sql:+,}($nrules,'allowed','$v')"
            done
            ;;
        *)
            fail "$ENVELOPES line $lineno: unknown rule kind '$kind' (range or enum)"
            ;;
    esac
    rules_sql="$rules_sql${rules_sql:+,}($nrules,$lineno,'$name','$kind')"
done < "$ENVELOPES"

# --- the GM's pg_hba.conf line ---------------------------------------------
if [ ! -r "$HBA" ]; then
    say_red "pg_hba: $HBA is missing or unreadable by postgres"
elif ! grep -Eq '^[[:space:]]*local[[:space:]]+all[[:space:]]+postgres[[:space:]]+peer([[:space:]]|#|$)' "$HBA"; then
    say_red "pg_hba: the GM's line 'local all postgres peer' is missing from $HBA (DO NOT TAMPER)"
fi

# --- server ------------------------------------------------------------------
psql_q() {  # psql_q <db>: SQL on stdin, unaligned, `|`-separated
    psql -X -w -q -A -t -F '|' -v ON_ERROR_STOP=1 -h "$SOCKET_DIR" -p "$PORT" -U postgres -d "$1" -f -
}

connected=""
if ! pg_isready -q -h "$SOCKET_DIR" -p "$PORT" -t 5; then
    say_red "server: PostgreSQL is not accepting connections on $SOCKET_DIR port $PORT"
else
    for db in postgres template1; do
        if out=$(echo 'SELECT 1' | psql_q "$db" 2>&1); then
            connected=$db
            break
        fi
    done
    if [ -z "$connected" ]; then
        say_red "server: postgres cannot connect over the local socket ($(printf '%s' "$out" | head -n 1))"
    fi
fi

# --- knobs -------------------------------------------------------------------
if [ "$nrules" -gt 0 ] && [ -z "$connected" ]; then
    say_red "knobs: $nrules envelope rule(s) not checked, the server cannot be queried"
elif [ "$nrules" -gt 0 ]; then
    sql="
WITH rules(id, line, name, kind) AS (VALUES $rules_sql),
vals(id, which, raw) AS (VALUES $vals_sql),
pending AS (
  SELECT DISTINCT ON (name) name, setting, sourcefile, sourceline
    FROM pg_catalog.pg_file_settings
   ORDER BY name, seqno DESC
),
cur AS (
  SELECT r.id, r.line, r.name, r.kind, s.vartype, s.unit, s.enumvals,
         s.setting AS eff_raw, pg_catalog.current_setting(r.name, true) AS eff_shown,
         p.setting AS pend_raw, p.sourcefile, p.sourceline
    FROM rules r
    LEFT JOIN pg_catalog.pg_settings s ON s.name = r.name
    LEFT JOIN pending p ON p.name = r.name
),
allv AS (
  SELECT c.id, v.which, v.raw, c.vartype, c.unit, c.enumvals FROM cur c JOIN vals v ON v.id = c.id
  UNION ALL SELECT id, 'eff', eff_raw, vartype, unit, enumvals FROM cur WHERE eff_raw IS NOT NULL
  UNION ALL SELECT id, 'pend', pend_raw, vartype, unit, enumvals FROM cur WHERE pend_raw IS NOT NULL
),
norm0 AS (
  SELECT id, which, raw, vartype, enumvals,
    CASE WHEN vartype IN ('integer', 'real') THEN
      CASE
        WHEN raw ~ '^\s*[-+]?([0-9]+\.?[0-9]*|\.[0-9]+)([eE][-+]?[0-9]+)?\s*$'
          THEN raw::numeric
        WHEN unit ~ '^[0-9]*(B|kB|MB|GB|TB)$'
             AND raw ~ '^\s*([0-9]+\.?[0-9]*|\.[0-9]+)\s*(B|kB|MB|GB|TB)\s*$'
          THEN pg_catalog.pg_size_bytes(raw)::numeric
               / pg_catalog.pg_size_bytes(regexp_replace(unit, '^([A-Za-z])', '1\1'))
        WHEN unit IN ('us', 'ms', 's', 'min')
             AND raw ~ '^\s*([0-9]+\.?[0-9]*|\.[0-9]+)\s*(us|ms|s|min|h|d)\s*$'
          THEN extract(epoch FROM raw::interval)
               / CASE unit WHEN 'us' THEN 0.000001 WHEN 'ms' THEN 0.001 WHEN 's' THEN 1 ELSE 60 END
      END
    END AS n,
    CASE
      WHEN vartype = 'bool' THEN
        CASE WHEN lower(trim(raw)) IN ('on', 'true', 'yes', '1', 't', 'tr', 'tru', 'y', 'ye') THEN 'on'
             WHEN lower(trim(raw)) IN ('off', 'false', 'no', '0', 'f', 'fa', 'fal', 'fals', 'n', 'of') THEN 'off'
        END
      WHEN vartype = 'enum' THEN lower(trim(raw))
      ELSE raw
    END AS t
  FROM allv
),
norm AS (
  SELECT id, which, raw, n, t,
    CASE WHEN vartype IN ('integer', 'real') THEN n IS NOT NULL
         WHEN vartype = 'bool' THEN t IS NOT NULL
         WHEN vartype = 'enum' THEN t = ANY (SELECT lower(x) FROM unnest(enumvals) x)
         ELSE true
    END AS valid
  FROM norm0
),
judged AS (
  SELECT c.*,
    lo.raw AS lo_raw, lo.n AS lo_n, hi.raw AS hi_raw, hi.n AS hi_n,
    e.n AS eff_n, e.t AS eff_t, pd.n AS pend_n, pd.t AS pend_t, pd.valid AS pend_valid,
    (SELECT string_agg(a.raw, ',' ORDER BY a.raw) FROM norm a WHERE a.id = c.id AND a.which = 'allowed') AS allowed_raw,
    (SELECT bool_or(NOT a.valid) FROM norm a WHERE a.id = c.id AND a.which = 'allowed') AS allowed_bad
  FROM cur c
  LEFT JOIN norm lo ON lo.id = c.id AND lo.which = 'lo'
  LEFT JOIN norm hi ON hi.id = c.id AND hi.which = 'hi'
  LEFT JOIN norm e  ON e.id = c.id AND e.which = 'eff'
  LEFT JOIN norm pd ON pd.id = c.id AND pd.which = 'pend'
),
verdict AS (
  SELECT j.*,
    CASE
      WHEN j.vartype IS NULL THEN 'err|line ' || j.line || ': unknown setting ' || j.name
      WHEN j.kind = 'range' AND j.vartype NOT IN ('integer', 'real')
        THEN 'err|line ' || j.line || ': ' || j.name || ' is not numeric, use enum'
      WHEN j.kind = 'range' AND ((j.lo_raw <> '-' AND j.lo_n IS NULL) OR (j.hi_raw <> '-' AND j.hi_n IS NULL))
        THEN 'err|line ' || j.line || ': a bound is not a valid value for ' || j.name
      WHEN j.kind = 'enum' AND j.allowed_bad
        THEN 'err|line ' || j.line || ': an allowed value is not valid for ' || j.name
    END AS rule_error
  FROM judged j
),
checks AS (
  SELECT v.*,
    CASE WHEN v.kind = 'range' THEN
           v.eff_n IS NULL
           OR (v.lo_raw <> '-' AND v.eff_n < v.lo_n) OR (v.hi_raw <> '-' AND v.eff_n > v.hi_n)
         ELSE NOT EXISTS (SELECT 1 FROM norm a WHERE a.id = v.id AND a.which = 'allowed'
                            AND (CASE WHEN v.vartype IN ('integer', 'real') THEN a.n = v.eff_n ELSE a.t = v.eff_t END))
    END AS eff_out,
    CASE WHEN v.pend_raw IS NULL THEN false
         WHEN v.kind = 'range' THEN
           NOT v.pend_valid
           OR (v.lo_raw <> '-' AND v.pend_n < v.lo_n) OR (v.hi_raw <> '-' AND v.pend_n > v.hi_n)
         ELSE NOT v.pend_valid
           OR NOT EXISTS (SELECT 1 FROM norm a WHERE a.id = v.id AND a.which = 'allowed'
                            AND (CASE WHEN v.vartype IN ('integer', 'real') THEN a.n = v.pend_n ELSE a.t = v.pend_t END))
    END AS pend_out,
    CASE WHEN v.kind = 'range' THEN v.lo_raw || '..' || v.hi_raw ELSE '{' || v.allowed_raw || '}' END AS envelope
  FROM verdict v
)
SELECT CASE
  WHEN rule_error IS NOT NULL THEN rule_error
  WHEN eff_out OR pend_out THEN
    'red|' || name || ': '
    || CASE WHEN eff_out THEN 'in effect ' || coalesce(eff_shown, eff_raw) ELSE '' END
    || CASE WHEN eff_out AND pend_out THEN '; ' ELSE '' END
    || CASE WHEN pend_out THEN 'pending ' || pend_raw || ' (' || sourcefile || ':' || sourceline || ')'
                               || CASE WHEN NOT pend_valid THEN ', not a valid value' ELSE '' END
            ELSE '' END
    || '; envelope ' || envelope
  END
FROM checks
WHERE rule_error IS NOT NULL OR eff_out OR pend_out
ORDER BY line;
"
    if ! out=$(printf '%s\n' "$sql" | psql_q "$connected" 2>&1); then
        fail "knob query failed: $(printf '%s' "$out" | head -n 1)"
    fi
    errors=$(printf '%s\n' "$out" | sed -n 's/^err|//p')
    [ -z "$errors" ] || fail "$ENVELOPES $(printf '%s' "$errors" | head -n 1)"
    reds=$(printf '%s\n' "$out" | sed -n 's/^red|//p')
    if [ -n "$reds" ]; then
        printf '%s\n' "$reds" | while IFS= read -r r; do printf 'RED %s\n' "$r"; done
        red=$((red + $(printf '%s\n' "$reds" | wc -l)))
    fi
fi

if [ "$red" -gt 0 ]; then
    exit 1
fi
printf 'GREEN: server up, GM pg_hba line present, %s knob envelope rule(s) respected\n' "$nrules"
exit 0
