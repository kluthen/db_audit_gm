# PostgreSQL 18 node for db_audit_gm (master spec 9.1).
#
# Generic image: no scenario content. Seed files, the envelope file and the
# secrets arrive at run time at the fixed paths declared in brick.yaml.
# Build:  docker build -t 127.0.0.1:5000/dbagm/postgres:0.4.0 bricks/postgres
# Architecture: x86_64 only in v0.1 (the s6-overlay archive below).

# --- rootfs/, its modes independent of the checkout --------------------------
# COPY keeps the modes files have in the checkout, which follow the umask it
# was made with (umask 002 gives 775 directories and 664 files, and COPY
# rootfs/ / would apply them to /etc, /usr, /usr/local...). Normalised here:
# directories and executables 0755, other files 0644. The files given other
# modes on purpose get them in the node stage, after the copy.
FROM debian:13-slim AS rootfs-modes
COPY rootfs/ /rootfs/
RUN chmod -R u=rwX,go=rX /rootfs

# --- the node ----------------------------------------------------------------
FROM debian:13-slim

ARG PG_MAJOR=18
ARG S6_OVERLAY_VERSION=3.2.3.2
# pg_cron, pinned exactly (G5, specs/versions/v0.4/wave-log.md; the
# pgbouncer precedent, D177): 1.6.8 stops cron.unschedule matching a job's
# owner case-insensitively, so 1.6.7 is not acceptable.
ARG PG_CRON_PACKAGE=1.6.8-1.pgdg13+2

# s6-overlay v3, pinned, verified against the release's published SHA-256.
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/

# PostgreSQL ${PG_MAJOR} (server and client, pg_stat_statements included),
# pg_cron and pgBadger from the PGDG repository, whose signing key Debian
# ships in postgresql-common (packages verified by apt against it), and
# Debian's cron daemon, unpinned as openssh-server and sudo are (master
# spec 7.2). Both jobs packages sit idle until a scenario uses them: a seed
# preloading pg_cron, a seed crontab starting the s6 service `cron`. They
# come in the second install, after postgresql-common has created
# `postgres`, so its 100:102 holds. No cluster is created at install time:
# the entrypoint initialises PGDATA on first start.
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates postgresql-common xz-utils; \
    sed -ri 's/^#?[[:space:]]*create_main_cluster.*/create_main_cluster = false/' /etc/postgresql-common/createcluster.conf; \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt trixie-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        "postgresql-${PG_MAJOR}" "postgresql-client-${PG_MAJOR}" pgbadger \
        "postgresql-${PG_MAJOR}-cron=${PG_CRON_PACKAGE}" cron \
        openssh-server openssh-client sudo procps less nano vim-tiny; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz; \
    apt-get purge -y xz-utils; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    # host keys are generated per container start (gm-entrypoint), never baked
    rm -f /etc/ssh/ssh_host_*; \
    test -x "/usr/lib/postgresql/${PG_MAJOR}/bin/postgres"; \
    test -f "/usr/lib/postgresql/${PG_MAJOR}/lib/pg_stat_statements.so"; \
    pgbadger --version; \
    test "$(dpkg-query -W -f '${Version}' "postgresql-${PG_MAJOR}-cron")" = "${PG_CRON_PACKAGE}"; \
    test -f "/usr/lib/postgresql/${PG_MAJOR}/lib/pg_cron.so"; \
    test -x /usr/sbin/cron; \
    # cron reads only postgres's crontab in its spool (volume cronspool):
    # no system crontab, no /etc/cron.d entry, no run-parts job as root
    rm -f /etc/crontab; \
    for d in /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly /etc/cron.yearly; do \
        if [ -d "$d" ]; then find "$d" -mindepth 1 ! -name .placeholder -delete; fi; \
    done; \
    # a job's files 0644, not 0664: Debian's pam_umask (USERGROUPS_ENAB) gives
    # postgres's jobs umask 0002, which would let the players' group pgconf
    # write the job logs in the setgid /var/log/postgresql/cron/
    printf 'session    optional   pam_umask.so umask=0022 nousergroups\n' >> /etc/pam.d/cron; \
    test "$(tail -n 1 /etc/pam.d/cron)" = "session    optional   pam_umask.so umask=0022 nousergroups"; \
    # the spool as Debian makes it (cron skips a crontab of another owner or mode)
    test "$(stat -c '%a %U:%G' /var/spool/cron/crontabs)" = "1730 root:crontab"; \
    # brick.yaml mounts the secret monitoring_password with postgres' gid
    test "$(id -u postgres):$(id -g postgres)" = "100:102"

# Accounts: `player` (SSH by key only, member of `pgconf`, which owns the
# configuration with `postgres`); `postgres` comes from the package.
RUN set -eux; \
    groupadd --system pgconf; \
    useradd --create-home --home-dir /home/player --shell /bin/bash --groups pgconf player; \
    usermod --password '*' player; \
    chmod 0750 /home/player; \
    # configuration directory (volume `pgconf`), outside PGDATA
    rm -rf /etc/postgresql; \
    install -d -o postgres -g pgconf -m 2775 /etc/postgresql; \
    # seed marker directory (volume `gmstate`), root-owned, out of pgconf's reach
    install -d -o root -g root -m 0755 /var/lib/gm-state; \
    # log directory (volume `pglog`): files readable by the players' group
    rm -rf /var/log/postgresql; \
    install -d -o postgres -g pgconf -m 2750 /var/log/postgresql; \
    # PGDATA (volume `pgdata`)
    install -d -o postgres -g postgres -m 0700 "/var/lib/postgresql/${PG_MAJOR}/data"; \
    # fixed in-container paths for seeds, secrets, protected configs, validator
    install -d -m 0755 /opt/gm /opt/gm/seed /opt/gm/secrets /opt/gm/protected /opt/gm/validator /usr/local/lib/gm; \
    # read-only root: temporary files live under /run (see gm-entrypoint)
    rm -rf /tmp /var/tmp; \
    ln -s /run/tmp /tmp; \
    ln -s /run/tmp /var/tmp

COPY --from=rootfs-modes /rootfs/ /
COPY validator/validate.sh /opt/gm/validator/validate.sh

# Protected files: root-owned, read-only for everyone else.
RUN set -eux; \
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/lib/gm /opt/gm/validator \
        /etc/ssh/sshd_config /etc/sudoers.d/gm-player /etc/motd /etc/profile.d/gm-postgres.sh; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-reload-db /usr/local/sbin/gm-restart-db \
        /usr/local/sbin/gm-validate /usr/local/sbin/gm-crontab /usr/local/lib/gm/healthcheck \
        /opt/gm/validator/validate.sh \
        /etc/s6-overlay/s6-rc.d/postgres/run /etc/s6-overlay/s6-rc.d/sshd/run /etc/s6-overlay/s6-rc.d/cron/run; \
    # root only: the GM check role's psql (its secret is root's alone) and
    # the hand-over snapshot of pgdata (not a sudo wrapper)
    chmod 0700 /usr/local/lib/gm/check-psql /usr/local/sbin/gm-snapshot-db; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd /etc/profile.d/gm-postgres.sh; \
    chmod 0440 /etc/sudoers.d/gm-player; \
    visudo -c

ENV S6_READ_ONLY_ROOT=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_SERVICES_GRACETIME=8000 \
    S6_KILL_GRACETIME=1000 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/postgresql/18/bin

EXPOSE 5432 22

# gm-entrypoint prepares /run, the configuration, the cron spool and PGDATA,
# then execs s6-overlay's /init, which supervises `postgres`, `sshd` and
# `cron` (down on a node seeding no crontab).
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
