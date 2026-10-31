# governance.sh: the governance check set G1 to G4 (v0.4 master spec 11.6,
# 11.7, 12.6; capture W3-a of specs/versions/v0.4/wave-log.md; spec D230,
# D231). POSIX shell defining functions only: nothing runs or is set at its
# top level. `gmctl check` sends this file, a newline, then a sealed check
# calling it (tools/gm/governance.py, checks.check_plan), with the
# scenario's `governance:` and classification in CHECK_GOVERNANCE.
#
#   out=$(check_governance G1 G3); rc=$?
#
# One or more of G1 G2 G3 G4, each once, run in the order given. It
# returns (never exits its caller) and writes standard output only:
#   0  every rule named holds;
#   1  one is broken;
#   2  it cannot judge (no or bad CHECK_GOVERNANCE, an unknown or repeated
#      rule, a rule this node cannot run, a node unreachable, G4 without
#      CHECK_SINCE, the mapping-roles function or gm_check_read gone);
#   3  G4 only: nothing broken, but an outbox with no row since CHECK_SINCE.
# Combined as gmctl check does: 2, else 1, else 3, else 0. The first line
# is one sentence a caller may reuse as its own (the first breach, the
# rules holding, or `governance: cannot judge: <why>`); then one line per
# breach, `<rule> <node>/<database> <object>: <why>`, at most 20 per rule.
#
# Where: G1, G2, G3's catalog paths and G4 on a `database` node, over every
# database (datallowconn, not a template) of every database node, through
# check-psql as gm_check (`--node <node>` for the other nodes); G3's
# transformer-job path on a `transformer` node, its connections' roles
# judged through check-sql. The node knows itself by its hostname.
#
# Readings (W3-a item 4, D230):
# - Every walk leaves out pg_catalog, information_schema, the toast and
#   temporary schemas, extensions' own schemas and objects (cron), and the
#   game's own schemas gm_check and gm_pgbouncer.
# - A column's class: a foreign table's column the class of the remote
#   column it maps, `<server's dbname>.<table_name, else its own
#   name>.<column_name, else its own>` when schema_name is public or unset;
#   any other column the class of a classified column with the same table
#   and column names, in any schema or database, the strictest on a clash.
# - G1's probe: personal only, in the databases it may not live in, the
#   text-typed columns of tables and materialized views not already classed
#   personal; one value shaped like an e-mail address is enough.
# - G1's separation (spec D253): for a class with `separation: instance`,
#   on each node holding one of its locations, every database walked but
#   postgres not among them is a breach, `G1 <node>/<database> database:`,
#   whatever it holds. A class without the field is judged as before.
# - G2: every login role but the game's own (CHECK_GOVERNANCE's own_roles)
#   and pg_*, on the instance holding the column; "may read" is CONNECT on
#   the database, USAGE on the schema and SELECT on the column, through
#   membership and PUBLIC (a superuser reads everything).
# - G3: a path's role is judged whoever it is (D230), the game's own roles
#   included: a user mapping's remote role on its server's database (a
#   mapping for PUBLIC, or one naming no remote role, reaching every
#   classed column there); a foreign table by its server's mappings, on the
#   table it maps; a SECURITY DEFINER function's owner and a pg_cron job's
#   username in their own database; a transformer job's connection role on
#   its database, toward each other database the job connects to. A
#   superuser reaches every classed column of the database it acts in.
#   Breach: a class reached that the reaching location may not hold.
# - G4: per outbox, the rows whose sent_at is after CHECK_SINCE, the
#   top-level keys of their payload against the union of the fields of the
#   flows naming that outbox (D231).
#
# Needs root (check-psql and check-sql are root's). Every command reading
# standard input is given its own: this file arrives on `sh -s`'s.

check_governance() (
    set +eu
    _gov_tmp=$(mktemp -d /tmp/gm-governance.XXXXXX 2>/dev/null) || {
        echo "governance: cannot judge: no temporary directory"
        return 2
    }
    trap 'rm -rf "$_gov_tmp"' EXIT
    _gov_main "$@"
)

# _gov_own_roles_sql: the game's own roles, skipped as readers (G2) and
# never anywhere else (D230). The one place they are named in a rule.
_gov_own_roles_sql() {
    printf '%s' "(SELECT jsonb_array_elements_text(gov.g -> 'own_roles') FROM gov)"
}

_gov_cannot() {   # _gov_cannot <why>: record why the set cannot judge
    [ -s "$_gov_tmp/cannot" ] || printf '%s\n' "$*" > "$_gov_tmp/cannot"
}

_gov_main() {
    _gov_rules=
    [ $# -ge 1 ] || { _gov_cannot "no rule named (G1, G2, G3, G4)"; _gov_report; return; }
    for _gov_r in "$@"; do
        case $_gov_r in
            G1|G2|G3|G4) ;;
            *) _gov_cannot "$_gov_r is not a rule (G1, G2, G3, G4)"; _gov_report; return ;;
        esac
        case " $_gov_rules " in
            *" $_gov_r "*) _gov_cannot "$_gov_r named twice"; _gov_report; return ;;
        esac
        _gov_rules="${_gov_rules:+$_gov_rules }$_gov_r"
    done
    if [ -z "${CHECK_GOVERNANCE:-}" ]; then
        _gov_cannot "no CHECK_GOVERNANCE (gmctl check sets it for a scenario with governance:)"
        _gov_report; return
    fi
    _gov_self=$(uname -n)
    if [ -x /usr/local/lib/gm/check-psql ]; then
        _gov_database_node
    elif [ -x /usr/local/lib/gm/check-sql ]; then
        _gov_transformer_node
    else
        _gov_cannot "node $_gov_self is neither a database node nor a transformer node"
    fi
    _gov_report
}

# --- the result ----------------------------------------------------------------

_gov_report() {
    if [ -s "$_gov_tmp/cannot" ]; then
        printf 'governance: cannot judge: %s\n' "$(cat "$_gov_tmp/cannot")"
        return 2
    fi
    _gov_first=
    for _gov_r in $_gov_rules; do
        if [ -s "$_gov_tmp/$_gov_r" ]; then
            _gov_first=$_gov_r
            break
        fi
    done
    if [ -n "$_gov_first" ]; then
        IFS='|' read -r _gov_l _gov_o _gov_w < "$_gov_tmp/$_gov_first"
        printf '%s: %s %s %s\n' "$_gov_first" "$_gov_l" "$_gov_o" "$_gov_w"
        for _gov_r in $_gov_rules; do
            [ -s "$_gov_tmp/$_gov_r" ] || continue
            head -n 20 "$_gov_tmp/$_gov_r" | while IFS='|' read -r _gov_l _gov_o _gov_w; do
                printf '%s %s %s: %s\n' "$_gov_r" "$_gov_l" "$_gov_o" "$_gov_w"
            done
        done
        return 1
    fi
    if [ -s "$_gov_tmp/G4.none" ]; then
        printf 'G4: nothing to judge yet: %s\n' "$(cat "$_gov_tmp/G4.none")"
        return 3
    fi
    _gov_names=$(printf '%s' "$_gov_rules" | sed 's/ /, /g')
    case $_gov_rules in *" "*) _gov_verb=hold ;; *) _gov_verb=holds ;; esac
    if [ -s "$_gov_tmp/jobs" ]; then
        printf '%s %s on transformer %s, %s job(s) joining databases\n' "$_gov_names" \
            "$_gov_verb" "$_gov_self" "$(cat "$_gov_tmp/jobs")"
    else
        printf '%s %s on %s database nodes, %s databases\n' "$_gov_names" "$_gov_verb" \
            "$(wc -l < "$_gov_tmp/nodes" | tr -d ' ')" "$(wc -l < "$_gov_tmp/dbs" | tr -d ' ')"
    fi
    return 0
}

_gov_breach() {   # _gov_breach <rule> <location> <object> <why>
    printf '%s|%s|%s\n' "$2" "$3" "$4" >> "$_gov_tmp/$1"
}

# --- psql on a database node ---------------------------------------------------

# _gov_psql <node> <database> [psql options]: the SQL on standard input, as
# gm_check, unaligned and tuples only, stopping at the first error; on
# failure the set cannot judge, with psql's first error line.
_gov_psql() {
    _gov_pn=$1 _gov_pd=$2
    shift 2
    if [ "$_gov_pn" = "$_gov_self" ]; then
        set -- /usr/local/lib/gm/check-psql -d "$_gov_pd" -Atq -v ON_ERROR_STOP=1 "$@"
    else
        set -- /usr/local/lib/gm/check-psql --node "$_gov_pn" -d "$_gov_pd" -Atq \
            -v ON_ERROR_STOP=1 "$@"
    fi
    "$@" -v gov="$CHECK_GOVERNANCE" 2> "$_gov_tmp/psql.err"
    _gov_prc=$?
    if [ "$_gov_prc" -ne 0 ]; then
        _gov_perr=$(grep -m 1 -E 'ERROR|FATAL|error|could not|failed' "$_gov_tmp/psql.err")
        [ -n "$_gov_perr" ] || _gov_perr=$(head -n 1 "$_gov_tmp/psql.err")
        _gov_cannot "$_gov_pn/$_gov_pd: check-psql exit $_gov_prc${_gov_perr:+: $_gov_perr}"
    fi
    return "$_gov_prc"
}

_gov_database_node() {
    # CHECK_GOVERNANCE read by PostgreSQL: its shape first, then the
    # database nodes, the outboxes (each with its receivers and the union
    # of the fields of the flows naming it) and each location of a class
    # with separation: instance.
    _gov_psql "$_gov_self" postgres > "$_gov_tmp/conf.x" <<'SQL' || return
WITH gov AS (SELECT :'gov'::jsonb AS g)
SELECT CASE
         WHEN jsonb_typeof(g) IS DISTINCT FROM 'object' THEN 'CHECK_GOVERNANCE is not a JSON object'
         WHEN jsonb_typeof(g -> 'classes') IS DISTINCT FROM 'object' THEN 'CHECK_GOVERNANCE has no classes'
         WHEN jsonb_typeof(g -> 'columns') IS DISTINCT FROM 'object' THEN 'CHECK_GOVERNANCE has no columns'
         WHEN jsonb_typeof(g -> 'database_nodes') IS DISTINCT FROM 'array' THEN 'CHECK_GOVERNANCE has no database_nodes'
         WHEN jsonb_typeof(g -> 'transformer_nodes') IS DISTINCT FROM 'array' THEN 'CHECK_GOVERNANCE has no transformer_nodes'
         WHEN jsonb_typeof(g -> 'own_roles') IS DISTINCT FROM 'array' THEN 'CHECK_GOVERNANCE has no own_roles'
       END
  FROM gov;
SQL
    if [ -n "$(cat "$_gov_tmp/conf.x")" ]; then
        _gov_cannot "$(cat "$_gov_tmp/conf.x")"
        return
    fi
    _gov_psql "$_gov_self" postgres > "$_gov_tmp/conf" <<'SQL' || return
WITH gov AS (SELECT :'gov'::jsonb AS g)
SELECT 'N|' || n FROM gov, jsonb_array_elements_text(g -> 'database_nodes') n;
WITH gov AS (SELECT :'gov'::jsonb AS g),
flows AS (SELECT f FROM gov, jsonb_each(g -> 'classes') c,
                 jsonb_array_elements(CASE WHEN jsonb_typeof(c.value -> 'outbound') = 'array'
                                           THEN c.value -> 'outbound' ELSE '[]' END) f)
SELECT 'O|' || a.ob || '|' || a.tos || '|' || b.flds
  FROM (SELECT f ->> 'outbox' AS ob, string_agg(DISTINCT f ->> 'to', ', ') AS tos
          FROM flows WHERE f ->> 'outbox' IS NOT NULL GROUP BY 1) a
 CROSS JOIN LATERAL (
       SELECT coalesce(jsonb_agg(DISTINCT x), '[]'::jsonb)::text AS flds
         FROM flows f2, jsonb_array_elements_text(
              CASE WHEN jsonb_typeof(f2.f -> 'fields') = 'array' THEN f2.f -> 'fields' ELSE '[]' END) x
        WHERE f2.f ->> 'outbox' = a.ob) b
 ORDER BY 1;
WITH gov AS (SELECT :'gov'::jsonb AS g)
SELECT 'I|' || c.key || '|' || l
  FROM gov, jsonb_each(g -> 'classes') c,
       jsonb_array_elements_text(CASE WHEN jsonb_typeof(c.value -> 'locations') = 'array'
                                      THEN c.value -> 'locations' ELSE '[]' END) l
 WHERE c.value ->> 'separation' = 'instance'
 ORDER BY 1;
SQL
    sed -n 's/^N|//p' "$_gov_tmp/conf" > "$_gov_tmp/nodes"
    if ! grep -qx -e "$_gov_self" "$_gov_tmp/nodes"; then
        _gov_cannot "node $_gov_self is not one of the scenario's database nodes"
        return
    fi
    # Every database of every database node.
    : > "$_gov_tmp/dbs"
    while read -r _gov_n; do
        _gov_psql "$_gov_n" postgres > "$_gov_tmp/dbs.one" <<'SQL' || return
SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname;
SQL
        sed "s#^#$_gov_n/#" "$_gov_tmp/dbs.one" >> "$_gov_tmp/dbs"
    done < "$_gov_tmp/nodes"
    for _gov_r in $_gov_rules; do
        case $_gov_r in
            G1) _gov_g1 ;;
            G2) _gov_g2 ;;
            G3) _gov_g3 ;;
            G4) _gov_g4 ;;
        esac
        [ -s "$_gov_tmp/cannot" ] && return
    done
}

# --- the classed columns of a database --------------------------------------------

# _gov_cte: a WITH list naming, in the database it runs in, `gov` (the
# JSON), `cols` (the classification's entries), `rules` (each class's
# rules, `allowed` at :'loc'), `att` (every column walked) and `classed`
# (each column with a class other than internal, its source key and why).
# Written with psql variables (:'gov', :'loc'); no percent sign, so the
# transformer path binds the same text through check-sql.
_gov_cte() {
    cat <<'SQL'
WITH gov AS (SELECT CAST(:'gov' AS jsonb) AS g),
cols AS (SELECT e.key AS k, e.value #>> '{}' AS cls,
                CASE e.value #>> '{}' WHEN 'personal' THEN 2 WHEN 'customer-linked' THEN 1 ELSE 0 END AS rank
           FROM gov, jsonb_each(gov.g -> 'columns') e),
rules AS (SELECT e.key AS cls, e.value AS r,
                 coalesce(e.value -> 'locations' = '"any"'::jsonb
                          OR (jsonb_typeof(e.value -> 'locations') = 'array'
                              AND e.value -> 'locations' ? CAST(:'loc' AS text)), false) AS allowed,
                 coalesce((SELECT string_agg(x, ', ') FROM jsonb_array_elements_text(
                     CASE WHEN jsonb_typeof(e.value -> 'locations') = 'array'
                          THEN e.value -> 'locations' ELSE '[]' END) x), 'nowhere') AS txt,
                 coalesce((SELECT string_agg(x, ', ') FROM jsonb_array_elements_text(
                     CASE WHEN jsonb_typeof(e.value -> 'readers') = 'array'
                          THEN e.value -> 'readers' ELSE '[]' END) x), 'none') AS readers
            FROM gov, jsonb_each(gov.g -> 'classes') e),
rel AS (SELECT c.oid, c.relnamespace AS nsp, n.nspname, c.relname, c.relkind, c.relispopulated
          FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
         WHERE c.relkind IN ('r', 'p', 'v', 'm', 'f')
           AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'gm_check', 'gm_pgbouncer')
           AND n.nspname !~ '^pg_(toast|temp_)'
           AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.deptype = 'e'
                             AND ((d.classid = 'pg_namespace'::regclass AND d.objid = n.oid)
                               OR (d.classid = 'pg_class'::regclass AND d.objid = c.oid)))),
att AS (SELECT r.oid, r.nsp, r.nspname, r.relname, r.relkind, r.relispopulated,
               a.attnum, a.attname, a.atttypid,
               (SELECT o.option_value FROM pg_options_to_table(a.attfdwoptions) o
                 WHERE o.option_name = 'column_name') AS fcol
          FROM rel r JOIN pg_attribute a ON a.attrelid = r.oid
         WHERE a.attnum > 0 AND NOT a.attisdropped),
fkey AS (SELECT ft.ftrelid AS oid,
                (SELECT o.option_value FROM pg_options_to_table(s.srvoptions) o
                  WHERE o.option_name = 'dbname') AS rdb,
                (SELECT o.option_value FROM pg_options_to_table(ft.ftoptions) o
                  WHERE o.option_name = 'schema_name') AS rschema,
                (SELECT o.option_value FROM pg_options_to_table(ft.ftoptions) o
                  WHERE o.option_name = 'table_name') AS rtable
           FROM pg_foreign_table ft JOIN pg_foreign_server s ON s.oid = ft.ftserver),
classed AS (
  SELECT a.*, m.cls, m.k AS src,
         CASE WHEN a.relkind = 'f' THEN 'remote ' ELSE 'as ' END || m.k AS why
    FROM att a LEFT JOIN fkey f ON f.oid = a.oid
    CROSS JOIN LATERAL (
      SELECT c.cls, c.k FROM cols c
       WHERE c.rank > 0
         AND CASE WHEN a.relkind = 'f'
                  THEN coalesce(f.rschema, 'public') = 'public'
                       AND c.k = f.rdb || '.' || coalesce(f.rtable, a.relname) || '.'
                                 || coalesce(a.fcol, a.attname)
                  ELSE split_part(c.k, '.', 2) = a.relname AND split_part(c.k, '.', 3) = a.attname
             END
       ORDER BY c.rank DESC, c.k LIMIT 1) m)
SQL
}

# _gov_each_db <function>: <function> <node> <database> for every database.
_gov_each_db() {
    while IFS=/ read -r _gov_en _gov_ed; do
        "$1" "$_gov_en" "$_gov_ed" || return
    done < "$_gov_tmp/dbs"
}

# _gov_collect <rule> <file>: the rows `<rule>|<location>|<object>|<why>` as breaches.
_gov_collect() {
    while IFS='|' read -r _gov_cr _gov_cl _gov_co _gov_cw; do
        [ "$_gov_cr" = "$1" ] && _gov_breach "$1" "$_gov_cl" "$_gov_co" "$_gov_cw"
    done < "$2"
    return 0
}

# --- G1 location -----------------------------------------------------------------

_gov_g1() { _gov_each_db _gov_g1_db && _gov_g1_separation; }

# _gov_g1_separation: for each class with separation: instance (11.6, spec
# D253), on each node holding one of its locations, every database walked
# but postgres is one of them; any other is a breach, whatever it holds.
_gov_g1_separation() {
    sed -n 's/^I|//p' "$_gov_tmp/conf" > "$_gov_tmp/sep"
    cut -d'|' -f1 "$_gov_tmp/sep" | uniq > "$_gov_tmp/sep.classes"
    while read -r _gov_sc; do
        grep -F -e "$_gov_sc|" "$_gov_tmp/sep" | while IFS='|' read -r _gov_x _gov_sl; do
            [ "$_gov_x" = "$_gov_sc" ] && printf '%s\n' "$_gov_sl"
        done > "$_gov_tmp/sep.locs"
        while IFS=/ read -r _gov_en _gov_ed; do
            [ "$_gov_ed" = postgres ] && continue
            grep -Fqx -e "$_gov_en/$_gov_ed" "$_gov_tmp/sep.locs" && continue
            _gov_shared=
            while read -r _gov_sl; do
                [ "${_gov_sl%%/*}" = "$_gov_en" ] \
                    && _gov_shared="${_gov_shared:+$_gov_shared, }$_gov_sl"
            done < "$_gov_tmp/sep.locs"
            [ -n "$_gov_shared" ] || continue
            _gov_breach G1 "$_gov_en/$_gov_ed" database \
                "shares the instance of $_gov_shared, where $_gov_sc data lives (separation: instance)"
        done < "$_gov_tmp/dbs"
    done < "$_gov_tmp/sep.classes"
    return 0
}

_gov_g1_db() {
    { _gov_cte; cat <<'SQL'
SELECT 'G1', :'loc', c.nspname || '.' || c.relname || '.' || c.attname,
       'holds ' || c.cls || ' data (' || c.why || '), allowed only in ' || r.txt
  FROM classed c JOIN rules r ON r.cls = c.cls
 WHERE NOT r.allowed
 ORDER BY c.nspname, c.relname, c.attnum;
SQL
      _gov_cte; cat <<'SQL'
SELECT format('SELECT %L, %L, %L, %L WHERE EXISTS (SELECT 1 FROM %I.%I WHERE btrim(%I::text) ~ %L)',
              'G1', :'loc', a.nspname || '.' || a.relname || '.' || a.attname,
              'holds values shaped like e-mail addresses (personal data), allowed only in ' || r.txt,
              a.nspname, a.relname, a.attname, '^[^@[:space:]]+@[^@[:space:]]+[.][^@[:space:]]+$')
  FROM att a JOIN pg_type t ON t.oid = a.atttypid CROSS JOIN rules r
 WHERE r.cls = 'personal' AND NOT r.allowed
   AND a.relkind IN ('r', 'm') AND a.relispopulated AND t.typcategory = 'S'
   AND NOT EXISTS (SELECT 1 FROM classed c WHERE c.oid = a.oid AND c.attnum = a.attnum
                                             AND c.cls = 'personal')
 ORDER BY a.nspname, a.relname, a.attnum
\gexec
SQL
    } | _gov_psql "$1" "$2" -v loc="$1/$2" > "$_gov_tmp/g1.out" || return
    _gov_collect G1 "$_gov_tmp/g1.out"
}

# --- G2 readers ----------------------------------------------------------------------

_gov_g2() { _gov_each_db _gov_g2_db; }

_gov_g2_db() {
    { _gov_cte; cat <<SQL
, logins AS (SELECT rolname FROM pg_roles
              WHERE rolcanlogin AND rolname !~ '^pg_'
                AND rolname NOT IN $(_gov_own_roles_sql))
SELECT 'G2', :'loc', c.nspname || '.' || c.relname,
       l.rolname || ' may read ' || c.cls || ' data ('
       || string_agg(c.attname, ', ' ORDER BY c.attnum) || '), not one of its readers ('
       || r.readers || ')'
  FROM classed c JOIN rules r ON r.cls = c.cls CROSS JOIN logins l
 WHERE r.r -> 'locations' IS DISTINCT FROM '"any"'::jsonb
   AND NOT coalesce(jsonb_typeof(r.r -> 'readers') = 'array' AND r.r -> 'readers' ? l.rolname, false)
   AND has_database_privilege(l.rolname, current_database(), 'CONNECT')
   AND has_schema_privilege(l.rolname, c.nsp, 'USAGE')
   AND has_column_privilege(l.rolname, c.oid, c.attnum, 'SELECT')
 GROUP BY c.nspname, c.relname, l.rolname, c.cls, r.readers
 ORDER BY c.nspname, c.relname, l.rolname, c.cls;
SQL
    } | _gov_psql "$1" "$2" -v loc="$1/$2" > "$_gov_tmp/g2.out" || return
    _gov_collect G2 "$_gov_tmp/g2.out"
}

# --- G3 reach: the catalog paths --------------------------------------------------------

# _gov_reach_sql: the classed columns of the database it runs in that the
# role :'role' may read ('*': every one), restricted to the relation
# :'tbl' unless it is empty, whose class the location :'loc' may not
# hold: one row per class, `<class>|<column>|<allowed locations>`. Shared
# with the transformer path (check-sql), so no percent sign.
_gov_reach_sql() {
    _gov_cte
    cat <<'SQL'
SELECT DISTINCT ON (c.cls) c.cls, c.nspname || '.' || c.relname || '.' || c.attname, r.txt
  FROM classed c JOIN rules r ON r.cls = c.cls
 WHERE NOT r.allowed
   AND (CAST(:'tbl' AS text) = '' OR c.nspname || '.' || c.relname = CAST(:'tbl' AS text))
   AND CASE WHEN CAST(:'role' AS text) = '*' THEN true
            WHEN NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = CAST(:'role' AS name)) THEN false
            ELSE has_database_privilege(CAST(:'role' AS name), current_database()::text, 'CONNECT')
                 AND has_schema_privilege(CAST(:'role' AS name), c.nsp, 'USAGE')
                 AND has_column_privilege(CAST(:'role' AS name), c.oid, c.attnum, 'SELECT')
       END
 ORDER BY c.cls, c.nspname, c.relname, c.attnum;
SQL
}

# _gov_reach <node> <database> <role|*> <judged location> [<schema.table>]:
# _gov_reach_sql's rows there, into $_gov_tmp/reach (cached per call).
_gov_reach() {
    : > "$_gov_tmp/reach"
    grep -qx -e "$1/$2" "$_gov_tmp/dbs" || return 0      # a path to no database reaches nothing
    _gov_key=$(printf '%s|%s|%s|%s|%s' "$1" "$2" "$3" "$4" "${5:-}" | cksum | cut -d' ' -f1)
    if [ ! -f "$_gov_tmp/reach.$_gov_key" ]; then
        _gov_reach_sql | _gov_psql "$1" "$2" -v loc="$4" -v role="$3" -v tbl="${5:-}" \
            > "$_gov_tmp/reach.$_gov_key" || return
    fi
    cp "$_gov_tmp/reach.$_gov_key" "$_gov_tmp/reach"
}

# _gov_location_of <node> <host> <dbname> <remote role>: a server's
# database as <node>/<database> in _gov_sloc; the set cannot judge a host
# that is not a database node of the game. An empty dbname is libpq's
# default, the remote role's name.
_gov_location_of() {
    _gov_sn=
    case $2 in
        ''|localhost|127.0.0.1|::1|/*) _gov_sn=$1 ;;
        *) grep -qx -e "$2" "$_gov_tmp/nodes" && _gov_sn=$2 ;;
    esac
    if [ -z "$_gov_sn" ]; then
        _gov_cannot "$1: a foreign server's host $2 is not a database node of the game"
        return 1
    fi
    _gov_sloc=$_gov_sn/${3:-$4}
}

_gov_g3() {
    : > "$_gov_tmp/facts"
    _gov_each_db _gov_g3_facts || return
    while IFS='|' read -r _gov_fn _gov_fd _gov_k _gov_a _gov_b _gov_c _gov_d; do
        _gov_loc=$_gov_fn/$_gov_fd
        case $_gov_k in
            M)  # a user mapping: server, local role, remote role
                _gov_server "$_gov_fn" "$_gov_fd" "$_gov_a" || return
                _gov_rr=$_gov_c
                [ "$_gov_b" = public ] || [ -z "$_gov_rr" ] && _gov_rr='*'
                _gov_reach "${_gov_sloc%%/*}" "${_gov_sloc#*/}" "$_gov_rr" "$_gov_loc" || return
                _gov_reached "$_gov_loc" "server $_gov_a mapping for $(_gov_for "$_gov_b")" \
                    "$(_gov_as "$_gov_b" "$_gov_c")" "at $_gov_sloc"
                ;;
            F)  # a foreign table: name, server, remote schema.table
                _gov_server "$_gov_fn" "$_gov_fd" "$_gov_b" || return
                grep "^$_gov_fn|$_gov_fd|M|$_gov_b|" "$_gov_tmp/facts" > "$_gov_tmp/maps"
                while IFS='|' read -r _gov_x _gov_x _gov_x _gov_x _gov_ml _gov_mr _gov_x; do
                    _gov_rr=$_gov_mr
                    [ "$_gov_ml" = public ] || [ -z "$_gov_rr" ] && _gov_rr='*'
                    _gov_reach "${_gov_sloc%%/*}" "${_gov_sloc#*/}" "$_gov_rr" "$_gov_loc" \
                        "$_gov_c" || return
                    _gov_reached "$_gov_loc" "$_gov_a (foreign table, server $_gov_b)" \
                        "$(_gov_as "$_gov_ml" "$_gov_mr")" "at $_gov_sloc"
                done < "$_gov_tmp/maps"
                ;;
            D)  # a SECURITY DEFINER function: signature, owner
                _gov_reach "$_gov_fn" "$_gov_fd" "$_gov_b" "$_gov_loc" || return
                _gov_reached "$_gov_loc" "function $_gov_a (SECURITY DEFINER)" \
                    "owner $_gov_b" "in its database"
                ;;
            J)  # a pg_cron job: name, database, username, active
                _gov_jloc=$_gov_fn/$_gov_b
                _gov_reach "$_gov_fn" "$_gov_b" "$_gov_c" "$_gov_jloc" || return
                _gov_state=
                [ "$_gov_d" = t ] || _gov_state=", inactive"
                _gov_reached "$_gov_jloc" "pg_cron job $_gov_a (scheduled in $_gov_fd$_gov_state)" \
                    "username $_gov_c" "in its database"
                ;;
        esac
    done < "$_gov_tmp/facts"
}

_gov_for() {   # _gov_for <local role>: a mapping's local role as \deu+ shows it
    if [ "$1" = public ]; then echo PUBLIC; else echo "$1"; fi
}

_gov_as() {   # _gov_as <local role> <remote role>: who a mapping connects as
    if [ "$1" = public ]; then
        echo "any local role, remote role ${2:-unset}"
    elif [ -z "$2" ]; then
        echo "remote role unset"
    else
        echo "remote role $2"
    fi
}

# _gov_server <node> <database> <server>: the server's location in _gov_sloc.
_gov_server() {
    _gov_line=$(grep -m 1 "^$1|$2|S|$3|" "$_gov_tmp/facts")
    _gov_sh=$(printf '%s' "$_gov_line" | cut -d'|' -f5)
    _gov_sd=$(printf '%s' "$_gov_line" | cut -d'|' -f6)
    _gov_su=$(grep -m 1 "^$1|$2|M|$3|" "$_gov_tmp/facts" | cut -d'|' -f6)
    _gov_location_of "$1" "$_gov_sh" "$_gov_sd" "$_gov_su"
}

# _gov_reached <location> <object> <as> <where>: a G3 breach per class in
# $_gov_tmp/reach.
_gov_reached() {
    while IFS='|' read -r _gov_rc _gov_rcol _gov_rtxt; do
        _gov_breach G3 "$1" "$2" \
            "$3 reaches $_gov_rc data $4 ($_gov_rcol), allowed only in $_gov_rtxt"
    done < "$_gov_tmp/reach"
    return 0
}

# _gov_g3_facts <node> <database>: the paths starting in it, as lines
# `<node>|<database>|<kind>|...`: S server|host|dbname; M server|local
# role|remote role; F table|server|remote schema.table; D function|owner;
# J job|database|username|active.
_gov_g3_facts() {
    _gov_psql "$1" "$2" > "$_gov_tmp/g3.out" <<'SQL' || return
SELECT EXISTS (SELECT 1 FROM pg_foreign_server) AS gov_srv,
       to_regprocedure('gm_check.user_mapping_roles()') IS NOT NULL AS gov_fn,
       EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') AS gov_cron,
       EXISTS (SELECT 1 FROM pg_policies WHERE schemaname = 'cron' AND tablename = 'job'
                                           AND policyname = 'gm_check_read') AS gov_pol
\gset
SELECT 'S', s.srvname,
       coalesce((SELECT option_value FROM pg_options_to_table(s.srvoptions) WHERE option_name = 'host'), ''),
       coalesce((SELECT option_value FROM pg_options_to_table(s.srvoptions) WHERE option_name = 'dbname'), '')
  FROM pg_foreign_server s ORDER BY 2;
\if :gov_srv
\if :gov_fn
SELECT 'M', server_name, local_role, coalesce(remote_role, '') FROM gm_check.user_mapping_roles();
\else
SELECT 'E', 'the mapping-roles function gm_check.user_mapping_roles() is gone';
\endif
\endif
SELECT 'F', n.nspname || '.' || c.relname, s.srvname,
       coalesce((SELECT option_value FROM pg_options_to_table(ft.ftoptions) WHERE option_name = 'schema_name'), n.nspname)
       || '.' ||
       coalesce((SELECT option_value FROM pg_options_to_table(ft.ftoptions) WHERE option_name = 'table_name'), c.relname)
  FROM pg_foreign_table ft JOIN pg_class c ON c.oid = ft.ftrelid
  JOIN pg_namespace n ON n.oid = c.relnamespace JOIN pg_foreign_server s ON s.oid = ft.ftserver
 WHERE n.nspname NOT IN ('gm_check', 'gm_pgbouncer')
   AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.deptype = 'e'
                     AND d.classid = 'pg_class'::regclass AND d.objid = c.oid)
 ORDER BY 2;
SELECT 'D', p.oid::regprocedure::text, pg_get_userbyid(p.proowner)
  FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
 WHERE p.prosecdef
   AND n.nspname NOT IN ('pg_catalog', 'information_schema', 'gm_check', 'gm_pgbouncer')
   AND n.nspname !~ '^pg_(toast|temp_)'
   AND NOT EXISTS (SELECT 1 FROM pg_depend d WHERE d.deptype = 'e'
                     AND ((d.classid = 'pg_namespace'::regclass AND d.objid = n.oid)
                       OR (d.classid = 'pg_proc'::regclass AND d.objid = p.oid)))
 ORDER BY 2;
\if :gov_cron
\if :gov_pol
SELECT 'J', coalesce(jobname, jobid::text), database, username, active FROM cron.job ORDER BY jobid;
\else
SELECT 'E', 'the read policy gm_check_read on cron.job is gone';
\endif
\endif
SQL
    _gov_perr=$(sed -n 's/^E|//p' "$_gov_tmp/g3.out" | head -n 1)
    if [ -n "$_gov_perr" ]; then
        _gov_cannot "$1/$2: $_gov_perr"
        return 1
    fi
    sed "s#^#$1|$2|#" "$_gov_tmp/g3.out" >> "$_gov_tmp/facts"
}

# --- G4 outbound ---------------------------------------------------------------------------

_gov_g4() {
    _gov_since=${CHECK_SINCE:-}
    case $_gov_since in
        [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z) ;;
        '') _gov_cannot "G4 needs CHECK_SINCE (the judged moment)"; return ;;
        *) _gov_cannot "CHECK_SINCE $_gov_since is not YYYY-MM-DDTHH:MM:SSZ"; return ;;
    esac
    sed -n 's/^O|//p' "$_gov_tmp/conf" > "$_gov_tmp/outboxes"
    while IFS='|' read -r _gov_ob _gov_to _gov_fields; do
        _gov_on=${_gov_ob%%/*}
        _gov_rest=${_gov_ob#*/}
        _gov_od=${_gov_rest%%/*}
        _gov_ot=${_gov_rest#*/}
        case $_gov_ot in
            ''|*[!a-z0-9_]*|[0-9]*) _gov_cannot "outbox $_gov_ob is not <node>/<database>/<table>"
                                    return ;;
        esac
        if ! grep -qx -e "$_gov_on/$_gov_od" "$_gov_tmp/dbs"; then
            _gov_cannot "outbox $_gov_ob: no database $_gov_od on database node $_gov_on"
            return
        fi
        _gov_psql "$_gov_on" "$_gov_od" -v since="$_gov_since" -v tbl="$_gov_ot" \
            -v fields="$_gov_fields" > "$_gov_tmp/g4.out" <<'SQL' || return
SELECT to_regclass(format('public.%I', :'tbl')) IS NOT NULL AS gov_t
\gset
\if :gov_t
SELECT 'C', count(*) FROM public.:"tbl" WHERE sent_at > :'since'::timestamptz;
SELECT 'B', k, count(*) FROM public.:"tbl" o
       CROSS JOIN LATERAL jsonb_object_keys(CASE WHEN jsonb_typeof(o.payload::jsonb) = 'object'
                                                 THEN o.payload::jsonb ELSE '{}' END) k
 WHERE o.sent_at > :'since'::timestamptz AND NOT (:'fields'::jsonb ? k)
 GROUP BY k ORDER BY k;
SELECT 'B', '(a payload not a JSON object)', count(*) FROM public.:"tbl" o
 WHERE o.sent_at > :'since'::timestamptz AND jsonb_typeof(o.payload::jsonb) <> 'object'
HAVING count(*) > 0;
SELECT 'L', coalesce(string_agg(x, ', ' ORDER BY x), 'none')
  FROM jsonb_array_elements_text(:'fields'::jsonb) x;
\else
SELECT 'E', 'the outbox table public.' || :'tbl' || ' is missing';
\endif
SQL
        _gov_perr=$(sed -n 's/^E|//p' "$_gov_tmp/g4.out" | head -n 1)
        if [ -n "$_gov_perr" ]; then
            _gov_cannot "$_gov_on/$_gov_od: $_gov_perr"
            return
        fi
        _gov_list=$(sed -n 's/^L|//p' "$_gov_tmp/g4.out")
        if [ "$(sed -n 's/^C|//p' "$_gov_tmp/g4.out")" = 0 ]; then
            printf '%s%s' "$([ -s "$_gov_tmp/G4.none" ] && echo ', ')" \
                "no row in $_gov_ob since $_gov_since" >> "$_gov_tmp/G4.none"
        fi
        sed -n 's/^B|//p' "$_gov_tmp/g4.out" | while IFS='|' read -r _gov_bk _gov_bn; do
            _gov_breach G4 "$_gov_on/$_gov_od" "public.$_gov_ot" \
                "payload key $_gov_bk on $_gov_bn row(s) sent since $_gov_since, not one of the fields to $_gov_to ($_gov_list)"
        done
    done < "$_gov_tmp/outboxes"
}

# --- G3 on a transformer node: its jobs' connections --------------------------------------

_gov_transformer_node() {
    for _gov_r in $_gov_rules; do
        if [ "$_gov_r" != G3 ]; then
            _gov_cannot "$_gov_r runs on a database node, not on transformer node $_gov_self"
            return
        fi
    done
    _GOV_SQL=$(_gov_reach_sql | sed "s/:'gov'/%(gov)s/g; s/:'loc'/%(loc)s/g; s/:'role'/%(role)s/g; s/:'tbl'/%(tbl)s/g") \
    _GOV_SELF=$_gov_self python3 -I -c "$(_gov_transformer_py)" > "$_gov_tmp/t.out" \
        2> "$_gov_tmp/t.err" < /dev/null
    _gov_trc=$?
    _gov_perr=$(sed -n 's/^E|//p' "$_gov_tmp/t.out" | head -n 1)
    if [ -n "$_gov_perr" ]; then
        _gov_cannot "$_gov_perr"
        return
    fi
    if [ "$_gov_trc" -ne 0 ]; then
        _gov_cannot "the transformer path failed (python3 exit $_gov_trc): $(tail -n 1 "$_gov_tmp/t.err")"
        return
    fi
    sed -n 's/^J|//p' "$_gov_tmp/t.out" > "$_gov_tmp/jobs"
    [ -s "$_gov_tmp/jobs" ] || echo 0 > "$_gov_tmp/jobs"
    _gov_collect G3 "$_gov_tmp/t.out"
}

_gov_transformer_py() {
    cat <<'PY'
import json, os, subprocess, sys
import yaml

def out(*fields):
    print("|".join(str(f).replace("|", "/").replace("\n", " ") for f in fields))

def stop(why):
    out("E", why)
    sys.exit(0)

self_node = os.environ["_GOV_SELF"]
try:
    gov = json.loads(os.environ["CHECK_GOVERNANCE"])
    database_nodes = list(gov["database_nodes"])
    transformer_nodes = list(gov["transformer_nodes"])
except (ValueError, KeyError, TypeError) as exc:
    stop(f"CHECK_GOVERNANCE is not the set's JSON: {exc}")
if self_node not in transformer_nodes:
    stop(f"node {self_node} is not one of the scenario's transformer nodes")
try:
    with open("/etc/scheduler/scheduler.yaml", encoding="utf-8") as fh:
        conf = yaml.safe_load(fh) or {}
    with open(conf["jobs"], encoding="utf-8") as fh:
        jobs = (yaml.safe_load(fh) or {}).get("jobs") or []
    with open(conf["schedule_seed"], encoding="utf-8") as fh:
        connections = (yaml.safe_load(fh) or {}).get("connections") or {}
except (OSError, KeyError, yaml.YAMLError, AttributeError) as exc:
    stop(f"{self_node}: cannot read the runner's jobs.yaml and schedule: "
         f"{' '.join(str(exc).split())}")

def location(job, name, conn):
    spec = connections.get(conn) if isinstance(connections, dict) else None
    if not isinstance(spec, dict):
        stop(f"{self_node}: job {job}: connection {conn} is not one of the schedule's")
    target, role = str(spec.get("target") or ""), str(spec.get("role") or "")
    hostport, _, database = target.partition("/")
    host, _, port = hostport.partition(":")
    if host not in database_nodes or not database or not role:
        stop(f"{self_node}: job {job}: connection {conn} targets {target or 'nothing'}, "
             "not a database node's database")
    return {"name": name, "conn": conn, "host": host, "port": port or "5432",
            "db": database, "role": role, "loc": f"{host}/{database}"}

cache = {}
def reach(src, judged):
    key = (src["loc"], src["port"], src["role"], judged)
    if key not in cache:
        proc = subprocess.run(
            ["/usr/local/lib/gm/check-sql", "-h", src["host"], "-p", src["port"],
             "-d", src["db"], "-v", f"gov={os.environ['CHECK_GOVERNANCE']}",
             "-v", f"loc={judged}", "-v", f"role={src['role']}", "-v", "tbl="],
            input=os.environ["_GOV_SQL"], capture_output=True, text=True)
        if proc.returncode != 0:
            err = (proc.stderr.strip().splitlines() or [f"exit {proc.returncode}"])[-1]
            stop(f"{src['loc']}: check-sql exit {proc.returncode}: {err}")
        cache[key] = [line.split("|", 2) for line in proc.stdout.splitlines() if line]
    return cache[key]

joining = 0
for job in jobs if isinstance(jobs, list) else []:
    if not isinstance(job, dict) or not isinstance(job.get("connections"), dict):
        continue
    name = job.get("name")
    conns = [location(name, n, c) for n, c in job["connections"].items()]
    if len({c["loc"] for c in conns}) < 2:
        continue
    joining += 1
    for src in conns:
        for dst in conns:
            if dst["loc"] == src["loc"]:
                continue
            for cls, column, allowed in reach(src, dst["loc"]):
                out("G3", self_node, f"jobs.yaml job {name}",
                    f"connection {src['name']} ({src['conn']}) as {src['role']} reaches {cls} "
                    f"data at {src['loc']} ({column}), joined to {dst['loc']} (connection "
                    f"{dst['name']}), allowed only in {allowed}")
out("J", joining)
PY
}
