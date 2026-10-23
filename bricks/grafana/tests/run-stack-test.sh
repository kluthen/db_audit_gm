#!/bin/sh
# Stack test of the Grafana brick (v0.2 build plan, chunk 10, Done when).
#
# Deploys the brick as a Swarm stack (stack.test.yml), its five seed files
# copied from companion/ as a scenario would, with a prometheus 0.2.0 node
# for the data source; seed files and secrets are external configs and
# secrets created here. Checks, from a client container on the stack's
# network and from the GM side (docker exec, the API helper):
#   - the container becomes healthy; Grafana runs as grafana (472:472);
#   - the provisioned data source (and its health), dashboards and alert
#     rules are present through the API; no contact point is provisioned;
#     the rules are evaluated and a firing one is readable;
#   - the administrator logs in with the secret's password (API and the
#     login form); the default time zone is UTC;
#   - the UI answers under /grafana/, from another container;
#   - SSH as player; sudo allows exactly the two wrappers;
#   - edited seed files (a dashboard, the data source, an alert rule) take
#     effect through gm-reload-grafana; a broken file is refused;
#   - the validator exits 0, then 1 on a pending, broken or refused file;
#   - edits, the marker and the player's home survive a new container, and a
#     changed administrator's password is set back from the secret at start;
#   - the secret, the database and the API helper are out of player's
#     reach; read-only root, capabilities, /run a named volume.
# Never sends a wrong administrator's password: Grafana's brute-force
# protection would lock the account. Credentials go to curl on stdin
# (curl -K -), never as an argument.
# Everything it creates is removed on exit, volumes included.
#
# Needs: a swarm manager (docker swarm init), the images built locally (the
# grafana image is also the test client: it has ssh, curl and jq):
#   docker build -t 127.0.0.1:5000/dbagm/grafana:0.2.0 bricks/grafana
#   docker build -t 127.0.0.1:5000/dbagm/prometheus:0.2.0 bricks/prometheus
# Usage: sh bricks/grafana/tests/run-stack-test.sh
set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
STACK=gmtest-grafana
IMAGE=127.0.0.1:5000/dbagm/grafana:0.2.0
PROM_IMAGE=127.0.0.1:5000/dbagm/prometheus:0.2.0
SERVICE=${STACK}_grafana
PROM_SERVICE=${STACK}_prometheus
NET=${STACK}_net
CLIENT=${STACK}-client
LABEL=dbagm.test=chunk10-grafana
CONFIGS="seed_datasources_yaml seed_dashboards_yaml seed_node_health_json seed_postgresql_json seed_alert_rules_yaml seed_prometheus_yml"
SECRETS="player_ssh_pubkey tools_password"
VOLUMES="graf_data graf_conf graf_home graf_gmstate graf_run prom_data prom_conf prom_home prom_gmstate prom_run"
COMPANION=$HERE/../companion
SSH_OPTS="-i /root/id -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o LogLevel=ERROR -o ConnectTimeout=10"
PROV=/etc/grafana/provisioning
API=/usr/local/lib/gm/grafana-api

failures=0
pass() { printf 'PASS  %s\n' "$*"; }
fail() { printf 'FAIL  %s\n' "$*"; failures=$((failures + 1)); }
check() {  # check <description> <command...>: pass if the command succeeds
    d=$1; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else fail "$d"; fi
}
info() { printf '....  %s\n' "$*"; }

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gmtest-grafana.XXXXXX")
chmod 0700 "$tmp"

cleanup() {
    set +e
    info "teardown"
    docker rm -f "$CLIENT" >/dev/null 2>&1
    docker stack rm "$STACK" >/dev/null 2>&1
    i=0
    while [ "$i" -lt 60 ] && [ -n "$(docker ps -aq -f "label=com.docker.stack.namespace=$STACK")" ]; do
        sleep 1; i=$((i + 1))
    done
    i=0
    while [ "$i" -lt 30 ] && docker network inspect "$NET" >/dev/null 2>&1; do
        sleep 1; i=$((i + 1))
    done
    for v in $VOLUMES; do
        j=0
        while docker volume inspect "${STACK}_$v" >/dev/null 2>&1 && [ "$j" -lt 20 ]; do
            docker volume rm "${STACK}_$v" >/dev/null 2>&1 || sleep 1
            j=$((j + 1))
        done
    done
    for c in $CONFIGS; do docker config rm "${STACK}_$c" >/dev/null 2>&1; done
    for s in $SECRETS; do docker secret rm "${STACK}_$s" >/dev/null 2>&1; done
    rm -rf "${tmp:?}"
    left=$(docker ps -aq -f "label=com.docker.stack.namespace=$STACK")
    left="$left$(docker volume ls -q -f "name=${STACK}_")$(docker config ls -q -f "name=${STACK}_")$(docker secret ls -q -f "name=${STACK}_")"
    if [ -n "$left" ]; then
        echo "WARNING: teardown left objects behind: $left"
    else
        info "teardown complete: no container, volume, config or secret left"
    fi
}
trap cleanup EXIT
trap 'exit 130' INT TERM

for i in "$IMAGE" "$PROM_IMAGE"; do
    docker image inspect "$i" >/dev/null 2>&1 || { echo "image $i not built" >&2; exit 2; }
done
if [ -n "$(docker stack ls --format '{{.Name}}' | grep -x "$STACK" || true)" ]; then
    echo "stack $STACK already exists; remove it first" >&2
    exit 2
fi

# --- per-game material, as gmctl deploy would create it ---------------------
ssh-keygen -q -t ed25519 -N '' -C gmtest-player -f "$tmp/id"
# the tools password: 16 characters of the player alphabet, no newline
(umask 077; head -c 4096 /dev/urandom | LC_ALL=C tr -dc 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789' \
    | head -c 16 > "$tmp/tools_password")
[ "$(wc -c < "$tmp/tools_password")" -eq 16 ] || { echo "could not generate the tools password" >&2; exit 2; }
cfg() { docker config create -l "$LABEL" "${STACK}_$1" "$2" >/dev/null; }
# the five seed files: the companion's, byte for byte, as a scenario copies them
cfg seed_datasources_yaml "$COMPANION/datasources.yaml"
cfg seed_dashboards_yaml "$COMPANION/dashboards.yaml"
cfg seed_node_health_json "$COMPANION/node-health.json"
cfg seed_postgresql_json "$COMPANION/postgresql.json"
cfg seed_alert_rules_yaml "$COMPANION/alert-rules.yaml"
# prometheus: its own stack test's seed (it also lists targets that do not
# exist here, so a target-down alert fires)
cfg seed_prometheus_yml "$HERE/../../prometheus/tests/fixtures/prometheus.yml"
docker secret create -l "$LABEL" "${STACK}_player_ssh_pubkey" "$tmp/id.pub" >/dev/null
docker secret create -l "$LABEL" "${STACK}_tools_password" "$tmp/tools_password" >/dev/null

info "deploying stack $STACK"
docker stack deploy --resolve-image never -c "$HERE/stack.test.yml" "$STACK" >/dev/null 2>&1

# From here on, every check records its own result; keep going on failure.
set +e

container() { docker ps -q -f "label=com.docker.swarm.service.name=$1" -f status=running | head -n 1; }
wait_healthy() {  # wait_healthy <service> [old-container-id]: prints the healthy container id
    i=0
    while [ "$i" -lt 300 ]; do
        c=$(container "$1")
        if [ -n "$c" ] && [ "$c" != "${2:-}" ] \
           && [ "$(docker inspect -f '{{.State.Health.Status}}' "$c" 2>/dev/null)" = healthy ]; then
            echo "$c"
            return 0
        fi
        sleep 2; i=$((i + 2))
    done
    return 1
}

start=$(date +%s)
if C=$(wait_healthy "$SERVICE"); then
    pass "service deployed and container healthy after $(( $(date +%s) - start ))s ($C)"
else
    fail "container did not become healthy"
    docker service ps --no-trunc "$SERVICE" || true
    docker service logs --tail 60 "$SERVICE" 2>&1 || true
    exit 1
fi
if P=$(wait_healthy "$PROM_SERVICE"); then
    pass "prometheus node (prometheus 0.2.0) healthy ($P)"
else
    fail "prometheus node did not become healthy"
    exit 1
fi

# --- client on the stack network ---------------------------------------------
docker run -d --name "$CLIENT" --network "$NET" -v "$tmp/id:/k/id:ro" \
    --entrypoint /bin/sh "$IMAGE" -c 'cp /k/id /root/id && chmod 600 /root/id && exec sleep 3600' >/dev/null
sleep 2
pssh() { docker exec -i "$CLIENT" timeout 120 ssh $SSH_OPTS player@grafana "$@"; }
gm() { docker exec -i "$C" "$@"; }
api() { docker exec "$C" "$API" "$@"; }   # the GM's way in: exec as root, the helper
# ccurl: curl from the client container (another node of the network, as the
# web front would be); the config, with any credential, on stdin.
ccurl() { docker exec -i "$CLIENT" curl -sS -m 15 -K - "$@"; }
pw=$(cat "$tmp/tools_password")
login_config() {  # the login form's request, the password in the body
    printf 'url = "http://grafana:3000/grafana/login"\nheader = "Content-Type: application/json"\ndata = "{\\"user\\":\\"admin\\",\\"password\\":\\"%s\\"}"\n' "$pw"
}

# --- Grafana served ------------------------------------------------------------
u=$(gm ps -o user= -C grafana | sort -u | tr -d ' ')
[ "$u" = grafana ] && pass "Grafana runs as grafana" || fail "Grafana process user: [$u]"
ids=$(gm sh -c 'echo "$(id -u grafana):$(id -g grafana) $(getent group grafconf | cut -d: -f3)"')
[ "$ids" = "472:472 473" ] && pass "grafana is 472:472, grafconf 473" || fail "ids: $ids"
v=$(api GET /api/health | jq -r '.version + " " + .database')
[ "$v" = "13.2.4 ok" ] && pass "/api/health: version 13.2.4, database ok" || fail "/api/health: $v"

# --- administrator ---------------------------------------------------------------
r=$(api GET /api/user | jq -c '{login, isGrafanaAdmin}')
[ "$r" = '{"login":"admin","isGrafanaAdmin":true}' ] \
    && pass "administrator logs in with the secret's password through the helper ($r)" || fail "/api/user: $r"
s=$(login_config | ccurl -o /dev/null -w '%{http_code}')
[ "$s" = 200 ] && pass "the login form accepts admin with the tools password (POST /grafana/login: 200)" \
    || fail "POST /grafana/login: $s"
n=$(api GET '/api/users/search?perpage=100' | jq -r '.totalCount')
[ "$n" = 1 ] && pass "one Grafana user (admin)" || fail "user count: $n"

# --- provisioned content -----------------------------------------------------------
r=$(api GET /api/datasources | jq -c '[.[] | {name, uid, type, url, isDefault, readOnly}]')
[ "$r" = '[{"name":"Prometheus","uid":"prometheus","type":"prometheus","url":"http://prometheus:9090/prometheus","isDefault":true,"readOnly":true}]' ] \
    && pass "data source provisioned: $r" || fail "data sources: $r"
i=0; h=
while [ "$i" -lt 60 ]; do
    h=$(api GET /api/datasources/uid/prometheus/health 2>/dev/null | jq -r '.status')
    [ "$h" = OK ] && break
    sleep 3; i=$((i + 3))
done
[ "$h" = OK ] && pass "data source health OK (Prometheus reachable at prometheus:9090/prometheus)" || fail "data source health: $h"
r=$(api GET '/api/search?type=dash-db' | jq -c '[.[] | .uid] | sort')
[ "$r" = '["node-health","postgresql"]' ] && pass "dashboards provisioned: $r" || fail "dashboards: $r"
for uid in node-health postgresql; do
    r=$(api GET "/api/dashboards/uid/$uid" | jq -c '{tz: .dashboard.timezone, provisioned: .meta.provisioned, panels: (.dashboard.panels | length)}')
    case $r in
        '{"tz":"utc","provisioned":true,'*) pass "dashboard $uid: time zone utc, provisioned ($r)" ;;
        *) fail "dashboard $uid: $r" ;;
    esac
done
want=$(python3 -c 'import sys, yaml; print(" ".join(sorted(r["uid"] for g in yaml.safe_load(open(sys.argv[1]))["groups"] for r in g["rules"])))' "$COMPANION/alert-rules.yaml")
got=$(api GET /api/v1/provisioning/alert-rules | jq -r '[.[] | .uid] | sort | join(" ")')
[ "$got" = "$want" ] && pass "alert rules provisioned, the companion's $(echo "$want" | wc -w): $got" || fail "alert rules: [$got], want [$want]"
r=$(api GET /api/v1/provisioning/alert-rules | jq -r '[.[] | .provenance] | unique | join(",")')
[ "$r" = file ] && pass "alert rules' provenance: file" || fail "alert rules' provenance: $r"
r=$(api GET /api/v1/provisioning/contact-points | jq -c '[.[] | .name]')
[ "$r" = '[]' ] && pass "no contact point provisioned (contact points: $r)" || fail "contact points: $r"
r=$(api GET /api/v1/provisioning/policies | jq -c '.receiver')
info "notification policy root receiver (Grafana's default): $r"
r=$(api GET /api/alertmanager/grafana/config/api/v1/alerts | jq -c '[.alertmanager_config.receivers[] | {name, integrations: ((.grafana_managed_receiver_configs // []) | length)}]')
case $r in
    *'"integrations":0}]') pass "Grafana's alertmanager has no integration to deliver to ($r)" ;;
    *) fail "alertmanager receivers: $r" ;;
esac
# the rules are evaluated; the target-down one fires (the prometheus fixture
# lists db:9110 and prometheus:9110, neither of which answers here)
i=0; ok=
while [ "$i" -lt 240 ]; do
    rules=$(api GET /api/prometheus/grafana/api/v1/rules)
    st=$(printf '%s' "$rules" | jq -r '[.data.groups[].rules[] | select(.name == "Scrape target down") | .state][0]')
    if [ "$st" = firing ]; then ok=1; break; fi
    sleep 5; i=$((i + 5))
done
[ -n "$ok" ] && pass "rule 'Scrape target down' firing after ${i}s, readable in the alerting API" || fail "target-down rule state: $st"
r=$(printf '%s' "$rules" | jq -r '[.data.groups[].rules[] | .health] | unique | join(",")')
[ "$r" = ok ] && pass "every rule evaluates without error (health: $r)" || fail "rule health: $r"
info "rule states: $(printf '%s' "$rules" | jq -r '[.data.groups[].rules[] | .name + "=" + .state] | join("; ")')"

# --- time zone and settings ------------------------------------------------------------
r=$(api GET /api/frontend/settings | jq -r '.dateFormats.defaultTimezone')
[ "$r" = UTC ] && pass "default time zone in effect: UTC (frontend settings)" || fail "frontend default time zone: $r"
r=$(api GET /api/admin/settings | jq -c '[.date_formats.default_timezone, .server.serve_from_sub_path, .analytics.reporting_enabled, .analytics.check_for_updates, .news.news_feed_enabled, .smtp.enabled, .unified_alerting.enabled]')
[ "$r" = '["UTC","true","false","false","false","false","true"]' ] \
    && pass "settings: time zone UTC, sub-path, no reporting, update checks or news, SMTP off, unified alerting on" \
    || fail "admin settings: $r"

# --- UI under the sub-path, from another node ------------------------------------------
r=$(echo 'url = "http://grafana:3000/grafana/login"' | ccurl)
if printf '%s' "$r" | grep -q '<title>Grafana</title>' && printf '%s' "$r" | grep -q '"appSubUrl":"/grafana"'; then
    pass "the UI answers under /grafana/ (GET /grafana/login: Grafana's page, appSubUrl /grafana)"
else
    fail "GET /grafana/login: $(printf '%s' "$r" | head -c 200)"
fi
# assets are relative to <base href="/grafana/">
a=$(printf '%s' "$r" | grep -o 'src="public/build/[^"]*\.js"' | head -n 1 | sed 's/^src="//; s/"$//')
s=$(echo "url = \"http://grafana:3000/grafana/$a\"" | ccurl -o /dev/null -w '%{http_code}')
if printf '%s' "$r" | grep -q '<base href="/grafana/" />' && [ -n "$a" ] && [ "$s" = 200 ]; then
    pass "the UI's assets load under the sub-path (base /grafana/, /grafana/$a: 200)"
else
    fail "asset [$a]: $s"
fi
s=$(echo 'url = "http://grafana:3000/grafana/api/health"' | ccurl -o /dev/null -w '%{http_code}')
[ "$s" = 200 ] && pass "GET /grafana/api/health: 200" || fail "GET /grafana/api/health: $s"
r=$(echo 'url = "http://grafana:3000/grafana/api/user"' | ccurl -w ' %{http_code}')
case $r in *' 401') pass "the API without credentials: 401" ;; *) fail "unauthenticated /grafana/api/user: $r" ;; esac
r=$(echo 'url = "http://grafana:3000/"' | ccurl -o /dev/null -w '%{http_code} %{redirect_url}')
info "outside the sub-path: GET / -> $r"

# --- SSH and sudo ------------------------------------------------------------
u=$(pssh id -un 2>&1 || true)
[ "$u" = player ] && pass "SSH as player with the secret's key" || fail "SSH as player: $u"
g=$(pssh id -nG 2>&1 || true)
[ "$g" = "player grafconf" ] && pass "player's groups: $g (not grafana)" || fail "player's groups: $g"
check "SSH as root refused" sh -c "! docker exec $CLIENT ssh $SSH_OPTS root@grafana true"
allowed=$(pssh sudo -n -l 2>&1 | sed -n '/may run the following commands/,$p' | sed 1d | tr -s ' \t' ' ' | sed 's/^ //')
expected='(root) NOPASSWD: /usr/local/sbin/gm-reload-grafana "", /usr/local/sbin/gm-validate ""'
[ "$allowed" = "$expected" ] && pass "sudo -l lists exactly the two wrappers, no arguments" \
    || fail "sudo -l: got [$allowed]"
check "sudo refuses /bin/sh" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@grafana sudo -n /bin/sh -c true"
check "sudo refuses a wrapper with arguments" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@grafana sudo -n /usr/local/sbin/gm-validate /etc/passwd"
check "sudo refuses -u grafana" sh -c "! docker exec $CLIENT ssh $SSH_OPTS player@grafana sudo -n -u grafana /usr/local/sbin/gm-validate"

# --- validator on the seed -----------------------------------------------------
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ "$out" = "${out#*sudo:}" ] && pass "gm-validate green on the seed, no sudo warning (exit 0: $out)" \
    || fail "gm-validate on seed: exit $rc: $out"
check "sudo logs to /run/gm/sudo.log" docker exec "$C" grep -q 'COMMAND=/usr/local/sbin/gm-validate' /run/gm/sudo.log
out=$(docker exec -u grafana "$C" /opt/gm/validator/validate.sh 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "GM run of the validator as grafana green (exit 0)" || fail "GM validator: exit $rc: $out"
m=$(gm stat -c '%a %U:%G' $PROV $PROV/datasources $PROV/dashboards/node-health.json $PROV/alerting/alert-rules.yaml \
    /var/lib/gm-state /var/lib/gm-state/.gm-seeded /home/player /var/lib/grafana /opt/gm/secrets/tools_password \
    /usr/local/lib/gm/grafana-api /etc/grafana/grafana.ini | tr '\n' ' ')
[ "$m" = "2775 grafana:grafconf 2775 grafana:grafconf 664 grafana:grafconf 664 grafana:grafconf 755 root:root 444 root:root 750 player:player 750 grafana:grafana 440 root:grafana 750 root:grafana 444 root:root " ] \
    && pass "ownership and modes ($m)" || fail "ownership and modes: $m"
for f in datasources.yaml:datasources/datasources.yaml dashboards.yaml:dashboards/dashboards.yaml \
         node-health.json:dashboards/node-health.json postgresql.json:dashboards/postgresql.json \
         alert-rules.yaml:alerting/alert-rules.yaml; do
    check "seeded ${f#*:} is the companion's ${f%%:*}, byte for byte" sh -c \
        "docker exec $C cat $PROV/${f#*:} | cmp -s - '$COMPANION/${f%%:*}'"
done

# --- the secret, the database and the helper out of player's reach -------------------
denied() {  # denied <description> <remote command>: pass if player's command fails
    d=$1; shift
    if pssh "$@" >/dev/null 2>&1; then fail "$d"; else pass "$d"; fi
}
denied "player cannot read the tools password secret" cat /opt/gm/secrets/tools_password
denied "player cannot run the API helper" /usr/local/lib/gm/grafana-api GET /api/health
denied "player cannot read Grafana's database directory" ls /var/lib/grafana
denied "player cannot write grafana.ini" "echo x >> /etc/grafana/grafana.ini"
denied "player cannot write the validator" "echo x >> /opt/gm/validator/validate.sh"
denied "player cannot write a wrapper" "echo x >> /usr/local/sbin/gm-reload-grafana"
denied "player cannot read the record of the last reload" cat /run/gm-grafana/applied
MARKER=/var/lib/gm-state/.gm-seeded
marker0=$(gm cat "$MARKER")
denied "player cannot remove the marker" rm -f "$MARKER"
denied "player cannot create a file next to the marker" touch /var/lib/gm-state/x
check "grafana cannot remove the marker" sh -c "! docker exec -u grafana $C rm -f $MARKER"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "marker unchanged after the attempts" || fail "marker changed or gone"
check "no secret on Grafana's command line" sh -c "! docker exec $C ps -o args= -C grafana | grep -qF -f '$tmp/tools_password'"

# --- an edited dashboard takes effect through the wrapper ---------------------------------
NHJ=$PROV/dashboards/node-health.json
pssh "jq '.title = \"Node health (edited)\"' $NHJ > ~/nh.json && cat ~/nh.json > $NHJ" \
    && pass "player edits $NHJ (title)" || fail "player cannot edit $NHJ"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED pending: '; then
    pass "validator red on an edit not yet reloaded (exit 1: $out)"
else
    fail "pending edit: exit $rc: $out"
fi
t=$(api GET /api/dashboards/uid/node-health | jq -r '.dashboard.title')
[ "$t" = "Node health" ] && pass "the edit is not live before the reload" || fail "title before reload: $t"
out=$(pssh sudo -n gm-reload-grafana 2>&1); rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'provisioning reloaded'; then
    pass "gm-reload-grafana (exit 0: $(printf '%s' "$out" | tr '\n' ' '))"
else
    fail "gm-reload-grafana: exit $rc: $out"
fi
t=$(api GET /api/dashboards/uid/node-health | jq -r '.dashboard.title')
[ "$t" = "Node health (edited)" ] && pass "the edited dashboard is live through the wrapper (title '$t')" || fail "title after reload: $t"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green after the reload (exit 0)" || fail "after reload: exit $rc: $out"

# --- the data source's address and an alert rule, through the wrapper -----------------------
DSY=$PROV/datasources/datasources.yaml
ARY=$PROV/alerting/alert-rules.yaml
pssh "cp $DSY ~/datasources.yaml.good && cp $ARY ~/alert-rules.yaml.good && \
      sed -i 's|url: http://prometheus:9090/prometheus|url: http://nowhere:9090/prometheus|' $DSY && \
      sed -i 's|title: Scrape target down|title: Scrape target down (edited)|' $ARY" \
    && pass "player points the data source elsewhere and renames an alert rule" || fail "edits to $DSY, $ARY"
out=$(pssh sudo -n gm-reload-grafana 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "gm-reload-grafana applies them (exit 0)" || fail "reload: exit $rc: $out"
r=$(api GET /api/datasources/uid/prometheus | jq -r '.url')
[ "$r" = http://nowhere:9090/prometheus ] && pass "the data source's new address is live ($r)" || fail "data source url: $r"
r=$(api GET /api/v1/provisioning/alert-rules/gm-target-down | jq -r '.title')
[ "$r" = "Scrape target down (edited)" ] && pass "the renamed alert rule is live ($r)" || fail "rule title: $r"
h=$(api GET /api/datasources/uid/prometheus/health 2>/dev/null | jq -r '.status')
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$h" != OK ] && [ "$rc" -eq 0 ] \
    && pass "a data source pointing nowhere is a finding, not a red rule (health $h, validator exit 0)" \
    || fail "wrong address: health $h, validator exit $rc: $out"
pssh "cat ~/datasources.yaml.good > $DSY && cat ~/alert-rules.yaml.good > $ARY" && pssh sudo -n gm-reload-grafana >/dev/null 2>&1 \
    || fail "restore the data source and the rule"
r=$(api GET /api/datasources/uid/prometheus | jq -r '.url')
[ "$r" = http://prometheus:9090/prometheus ] && pass "data source restored ($r)" || fail "data source after restore: $r"

# --- broken files: refused, validator red ---------------------------------------------
PGJ=$PROV/dashboards/postgresql.json
pssh "cp $PGJ ~/postgresql.json.good && echo '{ broken' >> $PGJ"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED files: .*postgresql.json is not valid JSON' \
   && printf '%s' "$out" | grep -q '^RED pending: '; then
    pass "validator red on a dashboard file that is not JSON (exit 1)"
else
    fail "broken JSON: exit $rc: $out"
fi
out=$(pssh sudo -n gm-reload-grafana 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'NOT reloaded'; then
    pass "gm-reload-grafana refuses a broken dashboard file (exit 1, NOT reloaded)"
else
    fail "reload with broken JSON: exit $rc: $out"
fi
check "the dashboard is still served after the refused reload" docker exec "$C" "$API" GET /api/dashboards/uid/postgresql
pssh "cat ~/postgresql.json.good > $PGJ"
pssh "echo 'groups: [' >> $ARY"
out=$(pssh sudo -n gm-reload-grafana 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'alerting: REFUSED'; then
    pass "gm-reload-grafana reports alert rules Grafana refuses (exit 1: $(printf '%s' "$out" | grep REFUSED | cut -c1-160))"
else
    fail "reload with broken YAML: exit $rc: $out"
fi
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q '^RED reload: the last reload'; then
    pass "validator red after a refused reload (exit 1)"
else
    fail "after refused reload: exit $rc: $out"
fi
pssh "cat ~/alert-rules.yaml.good > $ARY" && pssh sudo -n gm-reload-grafana >/dev/null 2>&1 || fail "restore the alert rules"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green again after fixing (exit 0: $out)" || fail "after fix: exit $rc: $out"
n=$(api GET /api/v1/provisioning/alert-rules | jq 'length')
[ "$n" = "$(echo "$want" | wc -w)" ] && pass "all $n alert rules back" || fail "alert rules after fix: $n"

# --- a changed administrator's password, then a new container -----------------------------
# The players must not do this (DO NOT TAMPER); the GM's recovery is a
# restart. Change it with the right current password (never a wrong one).
newpw="changed-$(head -c 6 /dev/urandom | od -An -tx1 | tr -d ' \n')"
s=$(printf 'url = "http://grafana:3000/grafana/api/user/password"\nrequest = "PUT"\nuser = "admin:%s"\nheader = "Content-Type: application/json"\ndata = "{\\"oldPassword\\":\\"%s\\",\\"newPassword\\":\\"%s\\",\\"confirmNew\\":\\"%s\\"}"\n' \
    "$pw" "$pw" "$newpw" "$newpw" | ccurl -o /dev/null -w '%{http_code}')
[ "$s" = 200 ] && pass "administrator's password changed through the API (as a tampering player would)" || fail "password change: $s"
pssh "echo 'audit notes' > ~/report.md" && pass "player's home is writable (~/report.md)" || fail "home not writable"
info "forcing a new container (docker service update --force)"
docker service update --force --detach "$SERVICE" >/dev/null 2>&1
if C2=$(wait_healthy "$SERVICE" "$C"); then
    pass "new container healthy ($C2)"
    C=$C2
else
    fail "new container did not become healthy"
fi
r=$(api GET /api/user | jq -r '.login')
[ "$r" = admin ] && pass "the administrator's password is the tools password again after the new container's start" \
    || fail "/api/user after restart: $r"
check "entrypoint logged the password reset" sh -c "docker service logs $SERVICE 2>&1 | grep -q \"administrator's password set from the tools password\""
t=$(api GET /api/dashboards/uid/node-health | jq -r '.dashboard.title')
[ "$t" = "Node health (edited)" ] && pass "the dashboard edit kept in a new container (not re-seeded)" || fail "title in new container: $t"
check "the edit is in the file in the new container" gm grep -q 'Node health (edited)' "$NHJ"
[ "$(gm cat "$MARKER")" = "$marker0" ] && pass "seed marker kept in a new container (volume gmstate)" || fail "marker after new container"
w=$(pssh cat report.md 2>&1 || true)
[ "$w" = "audit notes" ] && pass "player's home kept in a new container" || fail "home after new container: $w"
out=$(pssh sudo -n gm-validate 2>&1); rc=$?
[ "$rc" -eq 0 ] && pass "validator green in the new container ($out)" || fail "validator in new container: exit $rc: $out"
n=$(api GET '/api/users/search?perpage=100' | jq -r '.totalCount')
[ "$n" = 1 ] && pass "still one Grafana user" || fail "user count after restart: $n"

# --- hardening ---------------------------------------------------------------------
check "root filesystem is read-only" sh -c "[ \"\$(docker inspect -f '{{.HostConfig.ReadonlyRootfs}}' $C)\" = true ]"
check "root cannot write /usr/local/sbin" sh -c "! docker exec $C touch /usr/local/sbin/x"
caps=$(docker inspect -f '{{.HostConfig.CapDrop}} {{.HostConfig.CapAdd}}' "$C")
info "capabilities: $caps"
case $caps in "[ALL]"*) pass "cap_drop ALL" ;; *) fail "cap_drop: $caps" ;; esac
mnt=$(docker inspect -f '{{range .Mounts}}{{if eq .Destination "/run"}}{{.Type}}{{end}}{{end}}' "$C")
[ "$mnt" = volume ] && pass "/run is a named volume" || fail "/run mount: $mnt"
for c in sh cat du df awk sed grep sleep perl s6-svstat s6-setuidgid; do
    gm sh -c "PATH=/command:\$PATH command -v $c" >/dev/null 2>&1 || fail "command $c missing (receives)"
done
pass "the commands brick.yaml receives declares are present"
info "memory in use: $(gm cat /sys/fs/cgroup/memory.current) bytes (limit $(gm cat /sys/fs/cgroup/memory.max))"
info "image size: $(docker image inspect -f '{{.Size}}' "$IMAGE") bytes"
info "grafdata volume use: $(gm du -sh /var/lib/grafana | cut -f1)"

echo
if [ "$failures" -eq 0 ]; then
    echo "stack test: all checks passed"
    exit 0
fi
echo "stack test: $failures check(s) failed"
docker service logs --tail 40 "$SERVICE" 2>&1 || true
exit 1
