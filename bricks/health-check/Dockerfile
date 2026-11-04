# health-check node for db_audit_gm (v0.5 master spec 7.4; G9, v0.5 wave
# log): check_postgres every five minutes from cron, the customer's
# Nagios-style scripts beside it, and a static status page served by nginx.
#
# Generic image: no scenario content. The seed files (the instances, the
# crontab, the scripts) and the secrets arrive at run time at the fixed
# paths declared in brick.yaml.
# Build:  docker build -t 127.0.0.1:5000/dbagm/health-check:0.1.0 bricks/health-check
# Architecture: x86_64 only (the s6-overlay archive below).

# --- rootfs/, its modes independent of the checkout --------------------------
FROM debian:13-slim AS rootfs-modes
COPY rootfs/ /rootfs/
RUN chmod -R u=rwX,go=rX /rootfs

# --- the node ----------------------------------------------------------------
FROM debian:13-slim

ARG S6_OVERLAY_VERSION=3.2.3.2
# check_postgres, Debian's, pinned exactly (G9): Debian's psql 17.11 with it,
# every chosen action run against PostgreSQL 18 in the stack test.
ARG CHECK_POSTGRES_PACKAGE=2.26.0-2
# The OpenSSL floor libpq's TLS runs on (G9, as the postgres brick's G5).
ARG LIBSSL_FLOOR=3.5.7-1~deb13u3

# s6-overlay v3, pinned, verified against the release's published SHA-256.
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/

# check_postgres with no recommends (its psql, libpq, Perl), Debian's cron
# and nginx (the bastion's; static files only, no dynamic module), curl for
# the customer's scripts, unpinned as openssh-server and sudo are.
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        xz-utils "check-postgres=${CHECK_POSTGRES_PACKAGE}" cron nginx curl \
        openssh-server sudo procps less nano vim-tiny; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz; \
    apt-get purge -y xz-utils; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    # host keys are generated per container start (gm-entrypoint), never baked
    rm -f /etc/ssh/ssh_host_*; \
    test "$(dpkg-query -W -f '${Version}' check-postgres)" = "${CHECK_POSTGRES_PACKAGE}"; \
    /usr/bin/check_postgres --version | grep -q 'version 2\.26\.0'; \
    psql --version | grep -q '(PostgreSQL) 17\.'; \
    dpkg --compare-versions "$(dpkg-query -W -f '${Version}' libssl3t64)" ge "${LIBSSL_FLOOR}"; \
    perl -MJSON::PP -MPOSIX -MFcntl -e 1; \
    # nginx static only (G9): no dynamic module package, no module loaded,
    # Debian's sites and conf.d cleared; this node's configuration is
    # /usr/local/lib/gm/nginx.conf, checked below
    test -z "$(dpkg-query -W -f '${Package}\n' 'libnginx-mod-*' 2>/dev/null)"; \
    if [ -d /etc/nginx/modules-enabled ]; then test -z "$(ls -A /etc/nginx/modules-enabled)"; fi; \
    rm -rf /etc/nginx/sites-enabled/* /etc/nginx/sites-available/* /etc/nginx/conf.d/* \
        /var/log/nginx /var/lib/nginx /var/www/html; \
    # cron reads only postgres's crontab in its spool (volume cronspool):
    # no system crontab, no /etc/cron.d entry, no run-parts job as root
    rm -f /etc/crontab; \
    for d in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.yearly; do \
        if [ -d "$d" ]; then find "$d" -mindepth 1 ! -name .placeholder -delete; fi; \
    done; \
    printf 'session    optional   pam_umask.so umask=0022 nousergroups\n' >> /etc/pam.d/cron; \
    test "$(stat -c '%a %U:%G' /var/spool/cron/crontabs)" = "1730 root:crontab"; \
    test -x /usr/sbin/cron

# Accounts: `postgres` runs the crontab (G9: Debian cron as postgres, one
# spool crontab) and is the only account, with root, that reads the
# monitoring password; `player` (SSH by key only) is in `healthconf`, which
# owns /etc/health with `postgres`; nginx runs as www-data. Fixed ids:
# brick.yaml mounts the secret monitoring_password with postgres's gid.
RUN set -eux; \
    groupadd --system --gid 990 postgres; \
    useradd --system --uid 990 --gid postgres --home-dir /nonexistent --no-create-home \
        --shell /usr/sbin/nologin postgres; \
    groupadd --system --gid 991 healthconf; \
    useradd --create-home --home-dir /home/player --shell /bin/bash --groups healthconf player; \
    usermod --password '*' player; \
    chmod 0750 /home/player; \
    test "$(id -u postgres):$(id -g postgres)" = "990:990"; \
    test "$(getent group healthconf | cut -d: -f3)" = 991; \
    if id -nG player | tr ' ' '\n' | grep -qx postgres; then exit 1; fi; \
    # instances and scripts (volume `healthconf`)
    install -d -o postgres -g healthconf -m 2775 /etc/health /etc/health/scripts; \
    # results and the page (volume `healthdata`)
    install -d -o postgres -g postgres -m 0755 /var/lib/health /var/lib/health/results \
        /var/lib/health/www /var/lib/health/www/health; \
    # seed marker directory (volume `gmstate`), root-owned, out of healthconf's reach
    install -d -o root -g root -m 0755 /var/lib/gm-state; \
    # fixed in-container paths for seeds, secrets, validator
    install -d -m 0755 /opt/gm /opt/gm/seed /opt/gm/secrets /opt/gm/validator; \
    # read-only root: temporary files live under /run (see gm-entrypoint)
    rm -rf /tmp /var/tmp; \
    ln -s /run/tmp /tmp; \
    ln -s /run/tmp /var/tmp

COPY --from=rootfs-modes /rootfs/ /
COPY validator/validate.sh /opt/gm/validator/validate.sh

# Protected files: root-owned, read-only for everyone else.
RUN set -eux; \
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/lib/gm /usr/local/bin/health-run \
        /opt/gm/validator /etc/ssh/sshd_config /etc/sudoers.d/gm-player /etc/motd; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-crontab /usr/local/sbin/gm-run-checks \
        /usr/local/sbin/gm-validate /usr/local/sbin/gm-write-policy /usr/local/bin/health-run \
        /usr/local/lib/gm/healthcheck /opt/gm/validator/validate.sh \
        /etc/s6-overlay/s6-rc.d/cron/run /etc/s6-overlay/s6-rc.d/web/run /etc/s6-overlay/s6-rc.d/sshd/run; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd /usr/local/lib/gm/nginx.conf; \
    chmod 0440 /etc/sudoers.d/gm-player; \
    visudo -c; \
    perl -c /usr/local/bin/health-run; \
    # the configuration loads, and holds none of the directives G9 excludes
    install -d -o www-data -g www-data -m 0700 /run/nginx; \
    nginx -q -t -p /run/nginx/ -c /usr/local/lib/gm/nginx.conf; \
    nginx -T -p /run/nginx/ -c /usr/local/lib/gm/nginx.conf 2>/dev/null | grep -v '^[[:space:]]*#' > /run/nginx/T; \
    grep -q 'listen 8080;' /run/nginx/T; \
    if grep -Eq '(^|[[:space:]])(proxy_pass|fastcgi_pass|uwsgi_pass|scgi_pass|grpc_pass|dav_methods|charset|rewrite|return|load_module|include|http2|http3|mail|stream)([[:space:]]|;|$)' /run/nginx/T; then \
        exit 1; \
    fi; \
    rm -rf /run/nginx; \
    # brick.yaml `receives`: each command on an s6 service's PATH
    for c in sh cat du df awk sed grep sleep perl s6-svstat s6-setuidgid; do \
        PATH=/command:/usr/bin:/bin command -v "$c" >/dev/null; \
    done

ENV S6_READ_ONLY_ROOT=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_SERVICES_GRACETIME=8000 \
    S6_KILL_GRACETIME=1000 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EXPOSE 8080 22

# gm-entrypoint prepares /run, the password file and the seeds, then execs
# s6-overlay's /init, which supervises `cron`, `web` and `sshd`.
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
