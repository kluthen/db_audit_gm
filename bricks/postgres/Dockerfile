# PostgreSQL 18 node for db_audit_gm (master spec 9.1).
#
# Generic image: no scenario content. Seed files, the envelope file and the
# secrets arrive at run time at the fixed paths declared in brick.yaml.
# Build:  docker build -t 127.0.0.1:5000/dbagm/postgres:0.5.0 bricks/postgres
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
# pgaudit, pinned exactly (G5, specs/versions/v0.5/wave-log.md): upstream
# 18.0, always installed, turned on by a seed only (v0.5 master spec 7.1).
ARG PG_AUDIT_PACKAGE=18.0-3.pgdg13+1
# pgCluu, pinned exactly (G9, specs/versions/v0.5/wave-log.md): PGDG's 5.0,
# which collects from PostgreSQL 17 and 18 (Debian's 4.0 does not); a
# report tool run on demand by the players, as pgBadger is (master spec
# 7.4), never a daemon. Its CGI and Apache files are removed below.
ARG PG_CLUU_PACKAGE=5.0-1.pgdg13+1
# The OpenSSL floor PostgreSQL's TLS runs on (G5: DSA-6531-1, fixed only in
# trixie-security); the libraries come with postgresql-common.
ARG LIBSSL_FLOOR=3.5.7-1~deb13u3

# s6-overlay v3, pinned, verified against the release's published SHA-256.
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/

# PostgreSQL ${PG_MAJOR} (server and client, pg_stat_statements included,
# built with OpenSSL), pg_cron, pgaudit, pgBadger and pgCluu from the PGDG repository, whose signing key Debian
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
        "postgresql-${PG_MAJOR}" "postgresql-client-${PG_MAJOR}" pgbadger "pgcluu=${PG_CLUU_PACKAGE}" \
        "postgresql-${PG_MAJOR}-cron=${PG_CRON_PACKAGE}" \
        "postgresql-${PG_MAJOR}-pgaudit=${PG_AUDIT_PACKAGE}" cron \
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
    # pgCluu (G9): the pinned package; its report CGI and Apache
    # configuration deleted (no web server here, a report is read with scp);
    # no sysstat (players pass --disable-sar)
    test "$(dpkg-query -W -f '${Version}' pgcluu)" = "${PG_CLUU_PACKAGE}"; \
    rm -f /usr/lib/cgi-bin/pgcluu.cgi /etc/apache2/conf-available/pgcluu.conf; \
    rmdir --ignore-fail-on-non-empty /usr/lib/cgi-bin /etc/apache2/conf-available /etc/apache2 2>/dev/null || true; \
    test ! -e /usr/lib/cgi-bin/pgcluu.cgi; \
    test ! -e /etc/apache2/conf-available/pgcluu.conf; \
    test -x /usr/bin/pgcluu; \
    test -x /usr/bin/pgcluu_collectd; \
    if dpkg-query -W -f '${Status}' sysstat 2>/dev/null | grep -q 'ok installed'; then exit 1; fi; \
    test "$(dpkg-query -W -f '${Version}' "postgresql-${PG_MAJOR}-cron")" = "${PG_CRON_PACKAGE}"; \
    test -f "/usr/lib/postgresql/${PG_MAJOR}/lib/pg_cron.so"; \
    test "$(dpkg-query -W -f '${Version}' "postgresql-${PG_MAJOR}-pgaudit")" = "${PG_AUDIT_PACKAGE}"; \
    test -f "/usr/lib/postgresql/${PG_MAJOR}/lib/pgaudit.so"; \
    # TLS (G5): OpenSSL at or above the floor; ssl-cert's snakeoil pair, the
    # same in every game built from this image, deleted: a game's TLS
    # certificate and key are per-game secrets (brick.yaml)
    dpkg --compare-versions "$(dpkg-query -W -f '${Version}' libssl3t64)" ge "${LIBSSL_FLOOR}"; \
    rm -f /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/certs/ssl-cert-snakeoil.pem; \
    test ! -e /etc/ssl/private/ssl-cert-snakeoil.key; \
    test ! -e /etc/ssl/certs/ssl-cert-snakeoil.pem; \
    # vault-post's core Perl (G5: no package added for the posting command)
    perl -MHTTP::Tiny -e 1; \
    perl -MJSON::PP -MFile::Temp -MSys::Hostname -e 1; \
    test -x "/usr/lib/postgresql/${PG_MAJOR}/bin/pg_basebackup"; \
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
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/lib/gm /usr/local/bin/vault-post /opt/gm/validator \
        /etc/ssh/sshd_config /etc/sudoers.d/gm-player /etc/motd /etc/profile.d/gm-postgres.sh; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-reload-db /usr/local/sbin/gm-restart-db \
        /usr/local/sbin/gm-validate /usr/local/sbin/gm-crontab /usr/local/lib/gm/healthcheck \
        /opt/gm/validator/validate.sh /usr/local/bin/vault-post \
        /etc/s6-overlay/s6-rc.d/postgres/run /etc/s6-overlay/s6-rc.d/sshd/run /etc/s6-overlay/s6-rc.d/cron/run; \
    # root only: the GM check role's psql (its secret is root's alone), the
    # hand-over snapshot of pgdata and the standby's clone (not sudo wrappers)
    chmod 0700 /usr/local/lib/gm/check-psql /usr/local/sbin/gm-snapshot-db /usr/local/lib/gm/clone-standby; \
    perl -c /usr/local/bin/vault-post; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd /etc/profile.d/gm-postgres.sh; \
    chmod 0440 /etc/sudoers.d/gm-player; \
    visudo -c

# The accounts, generated at each start (v0.5 master spec 10.2, `no-access`;
# docs/gm.md, "Accounts and access"). The root filesystem is read-only, so
# the account files and the player's sudo rules live under /run, written
# by gm-entrypoint from the copies kept here: as built on a `fixable` or
# `report-only` node; without `player`, its group and its sudo rules on a
# `no-access` node. The image's own /run/gm-accounts holds the files as
# built: the Docker daemon resolves `docker exec -u postgres` (gmctl's
# exec) from the image's root filesystem, where the /run volume is not
# mounted, so the links must resolve there too; inside the container the
# volume, rewritten at each start, hides that copy. Last step: nothing
# after it resolves a name at build.
RUN set -eux; \
    install -d -o root -g root -m 0755 /usr/local/lib/gm/accounts /run/gm-accounts; \
    for f in passwd group shadow gshadow; do \
        cp -p "/etc/$f" "/usr/local/lib/gm/accounts/$f"; \
        cp -p "/etc/$f" "/run/gm-accounts/$f"; \
    done; \
    mv /etc/sudoers.d/gm-player /usr/local/lib/gm/accounts/sudoers-gm-player; \
    test "$(stat -c '%a %U:%G' /usr/local/lib/gm/accounts/shadow)" = "640 root:shadow"; \
    test "$(stat -c '%a %U:%G' /usr/local/lib/gm/accounts/sudoers-gm-player)" = "440 root:root"; \
    for f in passwd group shadow gshadow; do \
        ln -sfn "/run/gm-accounts/$f" "/etc/$f"; \
    done; \
    ln -s /run/gm-accounts/sudoers-gm-player /etc/sudoers.d/gm-player

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
