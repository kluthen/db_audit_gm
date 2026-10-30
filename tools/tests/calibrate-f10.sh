#!/bin/sh
# f10's early calibration (v0.4 build plan chunk 9; master spec 16.3, 13.3,
# 18 item 5; spec D209, D213, D218): can the out-of-memory incident be had
# as designed? The backfill must need more than twice `reporting`'s memory
# limit (Docker gives a Swarm service a swap equal to its limit) and a normal
# run less than half of it, within a window the restored history allows.
#
# On armenelos only, never on a shared host, every other swarm node drained
# (13.3): the script refuses otherwise and never changes a node. It deploys
# its own stack (tools/tests/fixtures/calibrate-f10/stack.yml):
#   db         the shop's instance, `postgres` 0.4.0, loaded with the shop
#              domain's data (domains/shop/data, chunk 5) as load-data would;
#   reporting  the agency's instance at the scenario's starting limit and
#              reservation (16.1: 512M / 256M) and the fixture's
#              shared_buffers, holding the fixture's data file: the foreign
#              server and tables, the draft of rpt.sales_detail_rollup(), its
#              backfill request table, and postgres's crontab calling it as
#              bi_etl at 03:00.
# Then, for each setting:
#   swap     reporting as a Swarm service (swap equal to its limit);
#   noswap   reporting replaced by a one-off calibration container outside
#            Swarm on the same network, its swap disabled for it alone
#            (docker run --memory=<limit> --memory-swap=<limit>, D218); the
#            host keeps its swap;
# it measures a normal run (the window since the last finished run: one day
# on the first), then backfills of growing windows (CALIBRATE_WINDOWS days),
# stopping at the first kill. No fake time and nobody triggers the job
# (master spec 8.4): each run is caused as the spec designs it, a backfill
# request row (the state change gmctl inject would plant) and the crontab
# entry's time moved to the next minutes through gm-crontab, which cron
# reloads; the procedure is never called by hand.
#
# Around each run, from the host: the container cgroup's memory.peak,
# memory.swap.peak and memory.events (oom_kill) before and after, and every
# CALIBRATE_SAMPLE seconds memory.current, memory.swap.current, anon, shmem
# (shared_buffers is charged as shmem) and file (the page cache: temporary
# files, WAL, table writes) and the host's MemAvailable. A cgroup's
# memory.peak only grows and only root may reset it, so a run's own peak is
# memory.peak after it when that rose during it, else the sampled maximum;
# it counts the page cache, which the kernel reclaims before it swaps or
# kills, so the run's need is also given without it: the sampled maximum of
# anon + shmem (+ swap), and the backend's own peak resident size, which
# PostgreSQL logs for bi_etl's statements (log_statement_stats, set on the
# role by the GM at setup: a measurement, not part of the fixture). A kill
# is oom_kill rising; then the recovery (PostgreSQL's four log lines, the
# seconds until it accepts connections, the postmaster, s6, sshd and cron
# keeping their pids). The window's size is counted on db, so the count
# leaves reporting's cgroup alone. The figures go to $OUT/figures.tsv and
# the end of the output, with G10's answer read from them (build plan G10):
# a normal run's need (anon + shmem, at most the cgroup's baseline plus the
# backend's peak) under half the limit, and a window the history allows
# killed with a swap equal to the limit.
#
# The host stays awake for the whole run (systemd-inhibit, sleep, idle and
# the lid switch). Run it alone on the host, under the docker lock:
#   flock /tmp/dbagm-docker.lock sh tools/tests/calibrate-f10.sh
# Needs: a swarm manager on the local engine named armenelos, the image
# 127.0.0.1:5000/dbagm/postgres:0.4.0 built, about 2.5 GiB of memory
# available.
# Environment:
#   CALIBRATE_LIMIT        reporting's memory limit (default 512M)
#   CALIBRATE_RESERVATION  its reservation (default 256M)
#   CALIBRATE_WINDOWS      the backfills' windows in days, growing (default
#                          "2 4 6 8 10 12 15"; the restored history holds
#                          fifteen, so a longer window reads the same rows)
#   CALIBRATE_SETTINGS     "swap noswap" (default), or one of them
#   CALIBRATE_AFTER_KILL   stop (default): no larger window after a kill;
#                          continue: every window
#   CALIBRATE_RUN_TIMEOUT  seconds a run may take before it is cancelled
#                          (default 1800)
#   CALIBRATE_SAMPLE       the sampling period in seconds (default 0.1)
#   CALIBRATE_OUT          where the samples and figures go (default: a new
#                          directory under $TMPDIR, kept)
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/../.." && pwd)
FIX=$HERE/fixtures/calibrate-f10
SHOP=$REPO/domains/shop/data
IMAGE=127.0.0.1:5000/dbagm/postgres:0.4.0
STACK=gmtest-f10
NET=${STACK}_net
CAL=${STACK}-reporting               # the noswap setting's one-off container
LABEL=dbagm.test=calibrate-f10
MACHINE=armenelos                    # master spec 13.3: f10 runs here only
CUSTOMER_TZ=Etc/GMT-2                # load-data's psql variables (8.5)
CUSTOMER_OFFSET=2
LIMIT=${CALIBRATE_LIMIT:-512M}
RESERVATION=${CALIBRATE_RESERVATION:-256M}
WINDOWS=${CALIBRATE_WINDOWS:-2 4 6 8 10 12 15}
SETTINGS=${CALIBRATE_SETTINGS:-swap noswap}
AFTER_KILL=${CALIBRATE_AFTER_KILL:-stop}
RUN_TIMEOUT=${CALIBRATE_RUN_TIMEOUT:-1800}
SAMPLE=${CALIBRATE_SAMPLE:-0.1}
CONFIGS="db_postgresql_conf db_pg_hba_conf reporting_postgresql_conf reporting_pg_hba_conf reporting_crontab"
SECRETS="player_ssh_pubkey dba_password monitoring_password gm_check_password role_bi_etl_password"
VOLS="pgdata pgconf home gmstate pglog run cronspool"
CAP_ADD="AUDIT_WRITE CHOWN DAC_OVERRIDE FOWNER KILL NET_BIND_SERVICE SETGID SETUID SYS_CHROOT"
# PostgreSQL's lines of a backend killed and the recovery (16.3, step 4).
KILL_LINE='was terminated by signal 9: Killed'
RECOVERY_LINES='terminating any other active server processes|all server processes terminated; reinitializing|database system was not properly shut down; automatic recovery in progress'

info() { printf '....  %s\n' "$*"; }
die() { printf 'calibrate-f10: %s\n' "$*" >&2; exit 2; }
bytes() {  # bytes <size>: 512M, 1G or a number of bytes, in bytes
    case $1 in
        *[Gg]) echo $((${1%?} * 1073741824)) ;;
        *[Mm]) echo $((${1%?} * 1048576)) ;;
        *) echo "$1" ;;
    esac
}
mib() { awk -v b="$1" 'BEGIN { if (b == "" || b == "-") print "-"; else printf "%.0f", b / 1048576 }'; }
now() { date +%s; }

# --- refusals: the machine, the other nodes, the image, our names -----------
for c in docker awk flock; do command -v "$c" >/dev/null || die "$c not found"; done
[ "$(docker info --format '{{.Name}}' 2>/dev/null)" = "$MACHINE" ] \
    || die "f10's calibration runs on $MACHINE only (master spec 13.3); this engine is $(docker info --format '{{.Name}}' 2>/dev/null)"
[ "$(docker info --format '{{.Swarm.ControlAvailable}}')" = true ] || die "the local engine is not a swarm manager"
NODE=$(docker info --format '{{.Swarm.NodeID}}')
others=$(docker node ls --format '{{.Self}} {{.Hostname}} {{.Availability}}' | awk '$1 != "true" && $3 != "Drain" { print $2 " (" $3 ")" }')
[ -z "$others" ] || die "every other swarm node must be drained, none changed by this script: $others"
NODES_AT_START=$(docker node ls --format '{{.Hostname}} {{.Status}} {{.Availability}}' | tr '\n' ';')
docker image inspect "$IMAGE" >/dev/null 2>&1 || die "image $IMAGE not built"
[ -z "$(docker stack ls --format '{{.Name}}' | grep -x "$STACK" || true)" ] || die "stack $STACK exists; remove it first"
[ -z "$(docker ps -aq -f "name=^${CAL}\$")" ] || die "container $CAL exists; remove it first"
avail=$(awk '$1 == "MemAvailable:" { print int($2 / 1024) }' /proc/meminfo)
[ "$avail" -ge 2560 ] || die "only $avail MiB of memory available; the calibration wants 2560"
case $AFTER_KILL in stop|continue) ;; *) die "CALIBRATE_AFTER_KILL: stop or continue" ;; esac
for s in $SETTINGS; do case $s in swap|noswap) ;; *) die "CALIBRATE_SETTINGS: swap and/or noswap" ;; esac; done
LIMIT_B=$(bytes "$LIMIT")

if [ -z "${CALIBRATE_OUT:-}" ]; then
    OUT=$(mktemp -d "${TMPDIR:-/tmp}/calibrate-f10.XXXXXX")
else
    OUT=$CALIBRATE_OUT
    mkdir -p "$OUT"
fi
tmp=$(mktemp -d "${TMPDIR:-/tmp}/calibrate-f10-tmp.XXXXXX")
SAMPLER=
INHIBIT=

cleanup() {
    set +e
    [ -n "$SAMPLER" ] && kill "$SAMPLER" 2>/dev/null
    info "teardown"
    docker rm -f "$CAL" >/dev/null 2>&1
    docker stack rm "$STACK" >/dev/null 2>&1
    i=0
    while [ "$i" -lt 90 ] && [ -n "$(docker ps -aq -f "label=com.docker.stack.namespace=$STACK")" ]; do
        sleep 1; i=$((i + 1))
    done
    i=0
    while [ "$i" -lt 30 ] && docker network inspect "$NET" >/dev/null 2>&1; do
        sleep 1; i=$((i + 1))
    done
    for v in $VOLS; do
        for name in "${STACK}_db_$v" "${STACK}_rp_$v" "${CAL}_$v"; do
            j=0
            while docker volume inspect "$name" >/dev/null 2>&1 && [ "$j" -lt 20 ]; do
                docker volume rm "$name" >/dev/null 2>&1 || sleep 1
                j=$((j + 1))
            done
        done
    done
    for c in $CONFIGS; do docker config rm "${STACK}_$c" >/dev/null 2>&1; done
    for s in $SECRETS; do docker secret rm "${STACK}_$s" >/dev/null 2>&1; done
    rm -rf "${tmp:?}"
    left="$(docker ps -aq -f "name=$STACK")$(docker service ls -q -f "name=$STACK")"
    left="$left$(docker volume ls -q -f "name=$STACK")$(docker network ls -q -f "name=$STACK")"
    left="$left$(docker config ls -q -f "name=$STACK")$(docker secret ls -q -f "name=$STACK")"
    if [ -n "$left" ]; then
        echo "WARNING: teardown left objects behind: $left"
    else
        info "teardown complete: no container, service, volume, network, config or secret of $STACK left"
    fi
    info "nodes at the end: $(docker node ls --format '{{.Hostname}} {{.Status}} {{.Availability}}' | tr '\n' ';')"
    [ -n "$INHIBIT" ] && kill "$INHIBIT" 2>/dev/null
    info "samples and figures kept in $OUT"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# The host stays awake for the whole run (master spec 18; build plan deltas).
if command -v systemd-inhibit >/dev/null; then
    systemd-inhibit --what=sleep:idle:handle-lid-switch --who=calibrate-f10 --mode=block \
        --why="db_audit_gm f10 calibration: the host stays up" sleep 86400 >/dev/null 2>&1 &
    INHIBIT=$!
    sleep 1
    kill -0 "$INHIBIT" 2>/dev/null || { INHIBIT=; info "WARNING: could not inhibit sleep; keep the host awake"; }
fi
info "machine $MACHINE, node $NODE; nodes at the start: $NODES_AT_START"
info "output in $OUT"

# --- per-run material, as gmctl deploy would create it ----------------------
ssh-keygen -q -t ed25519 -N '' -C gmtest-f10 -f "$tmp/id"
pw() { head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n'; }   # hex: no quoting needed
SEC=$tmp/secrets                      # also the noswap container's /opt/gm/secrets
mkdir -m 0755 "$SEC"
cp "$tmp/id.pub" "$SEC/player_ssh_pubkey"
for s in dba_password monitoring_password gm_check_password role_bi_etl_password; do
    pw > "$SEC/$s"
done
chmod 0644 "$SEC"/*
BI_PW=$(cat "$SEC/role_bi_etl_password")
ETL_PW=$(pw)                          # shop_etl's secret: the user mapping's password

docker config create -l "$LABEL" "${STACK}_db_postgresql_conf" "$FIX/db/postgresql.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_db_pg_hba_conf" "$FIX/db/pg_hba.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_reporting_postgresql_conf" "$FIX/reporting/postgresql.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_reporting_pg_hba_conf" "$FIX/reporting/pg_hba.conf" >/dev/null
docker config create -l "$LABEL" "${STACK}_reporting_crontab" "$FIX/reporting/crontab" >/dev/null
for s in $SECRETS; do
    docker secret create -l "$LABEL" "${STACK}_$s" "$SEC/$s" >/dev/null
done

replicas=0
case " $SETTINGS " in *" swap "*) replicas=1 ;; esac
info "deploying stack $STACK (reporting: limit $LIMIT, reservation $RESERVATION)"
CALIBRATE_NODE=$NODE REPORTING_LIMIT=$LIMIT REPORTING_RESERVATION=$RESERVATION REPORTING_REPLICAS=$replicas \
    docker stack deploy --resolve-image never -c "$FIX/stack.yml" "$STACK" >/dev/null

service_container() { docker ps -q -f "label=com.docker.swarm.service.name=$1" -f status=running | head -n 1; }
wait_healthy() {  # wait_healthy service <name> | container <name>: prints the healthy container's id
    i=0
    while [ "$i" -lt 240 ]; do
        if [ "$1" = service ]; then c=$(service_container "$2"); else c=$(docker ps -q -f "name=^$2\$" -f status=running); fi
        if [ -n "$c" ] && [ "$(docker inspect -f '{{.State.Health.Status}}' "$c" 2>/dev/null)" = healthy ]; then
            docker inspect -f '{{.Id}}' "$c"
            return 0
        fi
        sleep 2; i=$((i + 2))
    done
    return 1
}
psql_in() {  # psql_in <container> <database>: the SQL on stdin, as postgres
    docker exec -i -u postgres "$1" psql -X -q -At -v ON_ERROR_STOP=1 -d "$2"
}
sql() { printf '%s\n' "$3" | psql_in "$1" "$2"; }

DB=$(wait_healthy service "${STACK}_db") || die "db did not become healthy"
info "db healthy; loading the shop domain's data (schema.sql, load.sql) as load-data would"
t0=$(now)
cat "$SHOP/schema.sql" "$SHOP/load.sql" \
    | docker exec -i -u postgres "$DB" psql -X -q -v ON_ERROR_STOP=1 \
          -v customer_timezone="$CUSTOMER_TZ" -v customer_utc_offset="$CUSTOMER_OFFSET" -d postgres >/dev/null
printf "ALTER ROLE shop_etl PASSWORD '%s';\n" "$ETL_PW" | psql_in "$DB" postgres
info "shop data loaded in $(($(now) - t0)) s: $(sql "$DB" shop "SELECT count(*) || ' orders, ' || (SELECT count(*) FROM order_lines) || ' lines' FROM orders")"
HISTORY_DAYS=$(sql "$DB" shop "SELECT round(extract(epoch FROM now() - min(updated_at)) / 86400, 1) FROM orders")
info "the restored history: orders changed over the last $HISTORY_DAYS days"

# --- reporting --------------------------------------------------------------
setup_reporting() {  # setup_reporting <container>: its data file and load-data's passwords
    psql_in "$1" postgres < "$FIX/reporting/reporting.sql" >/dev/null
    printf "ALTER ROLE bi_etl PASSWORD '%s';\n\\\\connect reporting\nALTER USER MAPPING FOR bi_etl SERVER shop OPTIONS (ADD password '%s');\n" \
        "$BI_PW" "$ETL_PW" | psql_in "$1" postgres >/dev/null
    # The measurement: the backend's peak resident size in the log (GM side).
    sql "$1" postgres "ALTER ROLE bi_etl SET log_statement_stats = on" >/dev/null
    n=$(sql "$1" reporting "SET ROLE bi_etl; SELECT count(*) FROM src.products")
    [ "$n" = 2000 ] || die "reporting cannot read the shop through its user mapping (src.products: $n)"
    docker exec "$1" /usr/local/sbin/gm-crontab -l | grep -q 'CALL rpt.sales_detail_rollup()' \
        || die "reporting's crontab does not hold the roll-up's entry"
    docker exec "$1" test -s /run/gm-cron/pgpass || die "reporting has no crontab password file"
}
cgroup_of() {  # cgroup_of <container id>: its cgroup directory on the host
    cgd=/sys/fs/cgroup/system.slice/docker-$1.scope
    [ -d "$cgd" ] || cgd=$(find /sys/fs/cgroup -maxdepth 4 -type d -name "*$1*" 2>/dev/null | head -n 1)
    [ -n "$cgd" ] && [ -r "$cgd/memory.peak" ] || die "no readable cgroup with memory.peak for container $1"
    echo "$cgd"
}
memstat() { awk -v k="$2" '$1 == k { print $2 }' "$1/memory.stat"; }
oom_kills() { awk '$1 == "oom_kill" { print $2 }' "$1/memory.events"; }
logcount() {  # logcount <container> <extended regex>: matching lines in PostgreSQL's logs
    docker exec "$1" sh -c 'cat /var/log/postgresql/postgresql-*.log 2>/dev/null' | grep -Ec "$2" || true
}
pids() {  # pids <container>: "postmaster=<pid> s6-svscan=<pid> sshd=<pid> cron=<pid>"
    docker top "$1" -eo pid,ppid,comm | awk '
        NR > 1 { comm[$1] = $3; parent[$1] = $2 }
        END {
            for (p in comm) {
                if (comm[p] == "postgres" && comm[parent[p]] == "s6-supervise") pm = p
                if (comm[p] == "s6-svscan") sv = p
                if (comm[p] == "sshd" && comm[parent[p]] == "s6-supervise") sd = p
                if (comm[p] == "cron" && comm[parent[p]] == "s6-supervise") cr = p
            }
            printf "postmaster=%s s6-svscan=%s sshd=%s cron=%s", pm, sv, sd, cr
        }'
}
maxrss() {  # maxrss <container>: "<count> <kB>": bi_etl's logged peak resident sizes, the last
    docker exec "$1" sh -c 'cat /var/log/postgresql/postgresql-*.log 2>/dev/null' \
        | sed -n 's/.*[^0-9]\([0-9][0-9]*\) kB max resident size.*/\1/p' \
        | awk '{ n++; v = $1 } END { print n + 0, v + 0 }'
}
job_running() { docker top "$1" -eo pid,args 2>/dev/null | grep -q 'sales_detail_rollup'; }
sampler() {  # sampler <cgroup dir> <file>: one line per period until the cgroup goes
    while [ -d "$1" ]; do
        awk -v t="$(date +%s.%N)" '
            FILENAME ~ /memory\.current$/ { c = $1 }
            FILENAME ~ /memory\.swap\.current$/ { s = $1 }
            FILENAME ~ /memory\.stat$/ && $1 == "anon" { a = $2 }
            FILENAME ~ /memory\.stat$/ && $1 == "shmem" { sh = $2 }
            FILENAME ~ /memory\.stat$/ && $1 == "file" { f = $2 }
            FILENAME == "/proc/meminfo" && $1 == "MemAvailable:" { m = $2 * 1024 }
            END { print t, c, s, a, sh, m, f }' \
            "$1/memory.current" "$1/memory.swap.current" "$1/memory.stat" /proc/meminfo >> "$2" 2>/dev/null || true
        sleep "$SAMPLE"
    done
}
move_entry() {  # move_entry <container> <epoch>: the entry's time moved to that minute (UTC)
    m=$(date -u -d "@$2" +%-M); h=$(date -u -d "@$2" +%-H)
    sed "s/^0 3 \* \* \* /$m $h * * * /" "$FIX/reporting/crontab" \
        | docker exec -i -u player "$1" sh -c 'cat > /home/player/f10.cron'
    docker exec "$1" /usr/local/sbin/gm-crontab /home/player/f10.cron >/dev/null
    docker exec "$1" /usr/local/sbin/gm-crontab -l | grep -q "^$m $h \* \* \* psql" \
        || die "gm-crontab did not install the moved entry ($m $h)"
}

printf 'machine\tdate\tsetting\tlimit\tswap_max\tshared_buffers\trun\twindow_days\torders\tlines\toutcome\tseconds\tpeak_before\tpeak_after\trun_peak\tswap_peak_after\tmax_current\tmax_swap\tmax_anon\tmax_shmem\tmax_anon_shmem_swap\tmax_file\tbaseline\tbaseline_anon_shmem\tbackend_maxrss\tneed\tdocument\toom_kill\trecovery_s\tlog_lines\tpids_kept\thost_min_available\n' > "$OUT/figures.tsv"

KILLED_SWAP=; KILLED_NOSWAP=; NORMAL_SWAP=; NORMAL_NOSWAP=; RAW_SWAP=; RAW_NOSWAP=
LARGEST_OK_SWAP=; LARGEST_OK_NOSWAP=

measure() {  # measure <setting> <container id> <run label> <days, 0 for the normal run>
    setting=$1 C=$2 label=$3 days=$4
    CG=$(cgroup_of "$C")
    swap_max=$(cat "$CG/memory.swap.max")
    sb=$(sql "$C" reporting "SHOW shared_buffers")
    if [ "$days" -gt 0 ]; then
        since="now() - make_interval(days => $days)"
    else
        since="coalesce((SELECT max(watermark) FROM rpt.etl_runs WHERE job = 'sales-detail-rollup' AND finished_at IS NOT NULL), now() - interval '1 day')"
    fi
    # The window's size, read by the GM on db before the run (not the job).
    since_ts=$(sql "$C" reporting "SELECT $since")
    size=$(sql "$DB" shop "SELECT count(DISTINCT o.id) || ' ' || count(*) FROM orders o JOIN order_lines l ON l.order_id = o.id WHERE o.updated_at >= '$since_ts'")
    w_orders=${size% *}; w_lines=${size#* }
    wdays=$(sql "$C" reporting "SELECT round(extract(epoch FROM now() - '$since_ts'::timestamptz) / 86400, 2)")
    last=$(sql "$C" reporting "SELECT coalesce(max(id), 0) FROM rpt.etl_runs")
    if [ "$days" -gt 0 ]; then
        # The backfill request: the state change gmctl inject --at plants.
        sql "$C" reporting "INSERT INTO rpt.sales_detail_backfills (days, reason) VALUES ($days, 'calibration: recompute the last $days days')"
    fi
    kills0=$(logcount "$C" "$KILL_LINE"); rec0=$(logcount "$C" "$RECOVERY_LINES")
    pids0=$(pids "$C"); rss0=$(maxrss "$C")
    sleep 3
    peak0=$(cat "$CG/memory.peak"); oom0=$(oom_kills "$CG"); base=$(cat "$CG/memory.current")
    base_as=$(( $(memstat "$CG" anon) + $(memstat "$CG" shmem) ))
    # The entry's time moved to a minute at least 80 s ahead; cron reloads it.
    t=$(now); slot=$(( (t + 80 + 59) / 60 * 60 ))
    move_entry "$C" "$slot"
    info "[$setting] $label: window $wdays days ($w_orders orders, $w_lines lines); entry moved to $(date -u -d "@$slot" +%H:%M)Z"
    samples=$OUT/$setting-$label.samples
    : > "$samples"
    sampler "$CG" "$samples" &
    SAMPLER=$!
    started=; t_start=
    while [ "$(now)" -lt $((slot + 150)) ]; do
        if job_running "$C"; then started=yes; t_start=$(now); break; fi
        if [ "$(now)" -gt $((slot + 20)) ] \
           && [ "$(sql "$C" reporting "SELECT count(*) FROM rpt.etl_runs WHERE id > $last" 2>/dev/null)" != 0 ]; then
            started=yes; t_start=$slot; break
        fi
        sleep 1
    done
    [ -n "$started" ] || { kill "$SAMPLER"; SAMPLER=; die "[$setting] $label: cron did not run the moved entry"; }
    outcome=; cancelled=
    while job_running "$C"; do
        if [ "$(($(now) - t_start))" -gt "$RUN_TIMEOUT" ] && [ -z "$cancelled" ]; then
            info "[$setting] $label: still running after $RUN_TIMEOUT s; cancelling it"
            sql "$C" reporting "SELECT pg_cancel_backend(pid) FROM pg_stat_activity WHERE query LIKE 'CALL rpt.sales_detail_rollup%'" >/dev/null 2>&1 || true
            cancelled=yes
        fi
        sleep 1
    done
    t_end=$(now)
    oom1=$(oom_kills "$CG")
    recovery=-
    if [ "$oom1" -gt "$oom0" ]; then
        i=0
        until docker exec "$C" pg_isready -q -h /run/postgresql -p 5432 -t 2 2>/dev/null; do
            i=$((i + 1)); [ "$i" -lt 180 ] || break
            sleep 1
        done
        recovery=$(($(now) - t_end))
    fi
    sleep 3
    kill "$SAMPLER" 2>/dev/null; wait "$SAMPLER" 2>/dev/null || true; SAMPLER=
    peak1=$(cat "$CG/memory.peak"); swpeak1=$(cat "$CG/memory.swap.peak")
    finished=$(sql "$C" reporting "SELECT count(*) FROM rpt.etl_runs WHERE id > $last AND finished_at IS NOT NULL" 2>/dev/null || echo '?')
    if [ "$oom1" -gt "$oom0" ]; then outcome=killed
    elif [ "$finished" = 1 ]; then outcome=completed
    elif [ -n "$cancelled" ]; then outcome=timeout
    else outcome=error
    fi
    kills1=$(logcount "$C" "$KILL_LINE"); rec1=$(logcount "$C" "$RECOVERY_LINES")
    pids1=$(pids "$C"); rss1=$(maxrss "$C")
    [ "$pids0" = "$pids1" ] && kept=yes || kept="no ($pids0 -> $pids1)"
    # The backend's peak resident size, logged when its CALL ended (none if killed).
    if [ "${rss1% *}" -gt "${rss0% *}" ]; then backend=$(( ${rss1#* } * 1024 )); else backend=; fi
    document=-
    if [ "$finished" = 1 ]; then
        doc=$(sql "$C" reporting "SELECT orders || ' ' || lines || ' ' || pg_column_size(document) FROM rpt.sales_detail WHERE run_id > $last ORDER BY run_id DESC LIMIT 1")
        set -- $doc
        w_orders=$1 w_lines=$2 document=$(mib "$3")
    fi
    maxes=$(awk 'NF >= 7 {
                    if ($2 > c) c = $2; if ($3 > s) s = $3; if ($4 > a) a = $4; if ($5 > sh) sh = $5
                    if ($4 + $5 > as) as = $4 + $5
                    if ($4 + $5 + $3 > t) t = $4 + $5 + $3
                    if ($7 > f) f = $7
                    if (m == "" || $6 < m) m = $6 }
                 END { print c + 0, s + 0, a + 0, sh + 0, t + 0, m + 0, f + 0, as + 0 }' "$samples")
    set -- $maxes
    max_c=$1 max_s=$2 max_a=$3 max_sh=$4 max_t=$5 host_min=$6 max_f=$7 max_as=$8
    if [ "$peak1" -gt "$peak0" ]; then run_peak=$peak1; else run_peak=$max_c; fi
    # The run's need without the page cache: the sampled anon + shmem (+ swap),
    # or the baseline's plus the backend's logged peak when that is larger.
    need=$max_t
    [ -n "$backend" ] && [ $((base_as + backend)) -gt "$need" ] && need=$((base_as + backend))
    loglines="kill+$((kills1 - kills0)) recovery+$((rec1 - rec0))"
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$MACHINE" "$(date -u -d "@$t_start" +%Y-%m-%dT%H:%M:%SZ)" "$setting" "$LIMIT" "$swap_max" "$sb" "$label" "$wdays" \
        "$w_orders" "$w_lines" "$outcome" "$((t_end - t_start))" "$(mib "$peak0")" "$(mib "$peak1")" "$(mib "$run_peak")" \
        "$(mib "$swpeak1")" "$(mib "$max_c")" "$(mib "$max_s")" "$(mib "$max_a")" "$(mib "$max_sh")" "$(mib "$max_t")" \
        "$(mib "$max_f")" "$(mib "$base")" "$(mib "$base_as")" "$(mib "${backend:-}")" "$(mib "$need")" "$document" \
        "$((oom1 - oom0))" "$recovery" "$loglines" "$kept" "$(mib "$host_min")" >> "$OUT/figures.tsv"
    info "[$setting] $label: $outcome after $((t_end - t_start)) s; memory.peak $(mib "$peak0") -> $(mib "$peak1") MiB (run peak $(mib "$run_peak")), swap.peak $(mib "$swpeak1") MiB, max anon $(mib "$max_a") + shmem $(mib "$max_sh") MiB, file $(mib "$max_f") MiB, backend peak RSS $(mib "${backend:-}") MiB, need $(mib "$need") MiB, document $document MiB, oom_kill +$((oom1 - oom0)), recovery ${recovery} s, log lines $loglines, pids kept: $kept"
    if [ "$outcome" = killed ]; then
        info "[$setting] $label: the job's log: $(docker exec "$C" tail -n 2 /var/log/postgresql/cron/sales-detail-rollup.log | tr '\n' ' ')"
    elif [ "$outcome" != completed ]; then
        info "[$setting] $label: the job's log: $(docker exec "$C" tail -n 5 /var/log/postgresql/cron/sales-detail-rollup.log | tr '\n' ' ')"
    fi
    LAST_OUTCOME=$outcome LAST_PEAK=$run_peak LAST_NEED=$need
}

run_setting() {  # run_setting <setting> <container id>
    s=$1 C=$2
    measure "$s" "$C" normal 0
    if [ "$s" = swap ]; then NORMAL_SWAP=$LAST_NEED RAW_SWAP=$LAST_PEAK; else NORMAL_NOSWAP=$LAST_NEED RAW_NOSWAP=$LAST_PEAK; fi
    for d in $WINDOWS; do
        measure "$s" "$C" "backfill-${d}d" "$d"
        if [ "$LAST_OUTCOME" = killed ]; then
            if [ "$s" = swap ]; then KILLED_SWAP=${KILLED_SWAP:-$d}; else KILLED_NOSWAP=${KILLED_NOSWAP:-$d}; fi
            [ "$AFTER_KILL" = stop ] && break
        elif [ "$LAST_OUTCOME" = completed ]; then
            if [ "$s" = swap ]; then LARGEST_OK_SWAP=$d; else LARGEST_OK_NOSWAP=$d; fi
        else
            info "[$s] backfill-${d}d ended $LAST_OUTCOME: no larger window"
            break
        fi
        sleep 5
    done
}

for setting in $SETTINGS; do
    if [ "$setting" = swap ]; then
        R=$(wait_healthy service "${STACK}_reporting") || die "reporting (Swarm) did not become healthy"
        info "[swap] reporting as a Swarm service ($R), memory.max $(cat "$(cgroup_of "$R")/memory.max"), memory.swap.max $(cat "$(cgroup_of "$R")/memory.swap.max")"
        setup_reporting "$R"
        run_setting swap "$R"
        [ "$(docker inspect -f '{{.Id}}' "$(service_container "${STACK}_reporting")" 2>/dev/null)" = "$R" ] \
            || info "[swap] WARNING: Swarm replaced reporting's container during the runs"
        docker service rm "${STACK}_reporting" >/dev/null
        i=0
        while [ "$i" -lt 60 ] && [ -n "$(service_container "${STACK}_reporting")" ]; do sleep 1; i=$((i + 1)); done
    else
        set --
        for c in $CAP_ADD; do set -- "$@" --cap-add "$c"; done
        for v in $VOLS; do
            case $v in
                pgdata) t=/var/lib/postgresql/18/data ;; pgconf) t=/etc/postgresql ;; home) t=/home/player ;;
                gmstate) t=/var/lib/gm-state ;; pglog) t=/var/log/postgresql ;; run) t=/run ;;
                cronspool) t=/var/spool/cron/crontabs ;;
            esac
            set -- "$@" --mount "type=volume,src=${CAL}_$v,dst=$t"
        done
        docker run -d --name "$CAL" --hostname reporting --network "$NET" --label "$LABEL" \
            --memory "$LIMIT" --memory-swap "$LIMIT" --memory-reservation "$RESERVATION" --cpus 1 \
            --read-only --cap-drop ALL "$@" \
            --mount "type=bind,src=$FIX/reporting/postgresql.conf,dst=/opt/gm/seed/postgresql.conf,readonly" \
            --mount "type=bind,src=$FIX/reporting/pg_hba.conf,dst=/opt/gm/seed/pg_hba.conf,readonly" \
            --mount "type=bind,src=$FIX/reporting/crontab,dst=/opt/gm/seed/crontab,readonly" \
            --mount "type=bind,src=$SEC,dst=/opt/gm/secrets,readonly" \
            --health-cmd /usr/local/lib/gm/healthcheck --health-interval 10s --health-timeout 5s \
            --health-retries 5 --health-start-period 60s \
            "$IMAGE" >/dev/null
        R=$(wait_healthy container "$CAL") || die "the calibration container did not become healthy"
        info "[noswap] reporting as a one-off container outside Swarm ($R), memory.max $(cat "$(cgroup_of "$R")/memory.max"), memory.swap.max $(cat "$(cgroup_of "$R")/memory.swap.max")"
        setup_reporting "$R"
        run_setting noswap "$R"
        docker rm -f "$CAL" >/dev/null
    fi
done

# --- the figures and G10's answer -------------------------------------------
echo
echo "f10 calibration figures ($OUT/figures.tsv; sizes in MiB):"
column -t -s "$(printf '\t')" "$OUT/figures.tsv" 2>/dev/null || cat "$OUT/figures.tsv"
echo
half=$((LIMIT_B / 2))
answer=yes; why=
case " $SETTINGS " in *" swap "*) ;; *) answer=undecided; why="the swap setting was not measured" ;; esac
if [ "$answer" = yes ]; then
    for n in "$NORMAL_SWAP" "$NORMAL_NOSWAP"; do
        [ -z "$n" ] && continue
        [ "$n" -lt "$half" ] || { answer=no; why="a normal run needed $(mib "$n") MiB without the page cache, not under half the limit ($(mib "$half") MiB)"; }
    done
fi
if [ "$answer" = yes ]; then
    if [ -z "$KILLED_SWAP" ]; then
        answer=no; why="no backfill window up to $(echo "$WINDOWS" | awk '{ print $NF }') days (history $HISTORY_DAYS days) was killed with a swap equal to the limit: none needed twice the limit"
    else
        noswap="without swap not measured"
        case " $SETTINGS " in *" noswap "*)
            noswap="without swap the normal run needed $(mib "$NORMAL_NOSWAP") MiB (memory.peak $(mib "$RAW_NOSWAP") MiB), the smallest window killed ${KILLED_NOSWAP:-none} days, the largest completed ${LARGEST_OK_NOSWAP:-none}" ;;
        esac
        why="with swap (2 x $LIMIT) the normal run needed $(mib "$NORMAL_SWAP") MiB without the page cache, under half the limit ($(mib "$half") MiB; memory.peak with the page cache: $(mib "$RAW_SWAP") MiB), and the smallest window killed is $KILLED_SWAP days, the largest completed ${LARGEST_OK_SWAP:-none}; $noswap; the history holds $HISTORY_DAYS days"
    fi
fi
echo "G10 (spec D213): $answer: $why"
