# PostgreSQL 18 node for db_audit_gm (master spec 9.1).
#
# Generic image: no scenario content. Seed files, the envelope file and the
# secrets arrive at run time at the fixed paths declared in brick.yaml.
# Build:  docker build -t 127.0.0.1:5000/dbagm/postgres:0.1.0 bricks/postgres
# Architecture: x86_64 only in v0.1 (the s6-overlay archive below).
FROM debian:13-slim

ARG PG_MAJOR=18
ARG S6_OVERLAY_VERSION=3.2.3.2

# s6-overlay v3, pinned, verified against the release's published SHA-256.
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/

# PostgreSQL ${PG_MAJOR} (server and client) from the PGDG repository, whose
# signing key Debian ships in postgresql-common. No cluster is created at
# install time: the entrypoint initialises PGDATA on first start.
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates postgresql-common xz-utils; \
    sed -ri 's/^#?[[:space:]]*create_main_cluster.*/create_main_cluster = false/' /etc/postgresql-common/createcluster.conf; \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt trixie-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        "postgresql-${PG_MAJOR}" "postgresql-client-${PG_MAJOR}" \
        openssh-server openssh-client sudo procps less nano vim-tiny; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz; \
    apt-get purge -y xz-utils; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    # host keys are generated per container start (gm-entrypoint), never baked
    rm -f /etc/ssh/ssh_host_*; \
    test -x "/usr/lib/postgresql/${PG_MAJOR}/bin/postgres"

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
    # PGDATA (volume `pgdata`)
    install -d -o postgres -g postgres -m 0700 "/var/lib/postgresql/${PG_MAJOR}/data"; \
    # fixed in-container paths for seeds, secrets, protected configs, validator
    install -d -m 0755 /opt/gm /opt/gm/seed /opt/gm/secrets /opt/gm/protected /opt/gm/validator /usr/local/lib/gm; \
    # read-only root: temporary files live under /run (see gm-entrypoint)
    rm -rf /tmp /var/tmp; \
    ln -s /run/tmp /tmp; \
    ln -s /run/tmp /var/tmp

COPY rootfs/ /
COPY validator/validate.sh /opt/gm/validator/validate.sh

# Protected files: root-owned, read-only for everyone else.
RUN set -eux; \
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/lib/gm /opt/gm/validator \
        /etc/ssh/sshd_config /etc/sudoers.d/gm-player /etc/motd /etc/profile.d/gm-postgres.sh; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-reload-db /usr/local/sbin/gm-restart-db \
        /usr/local/sbin/gm-validate /usr/local/lib/gm/healthcheck /opt/gm/validator/validate.sh \
        /etc/s6-overlay/s6-rc.d/postgres/run /etc/s6-overlay/s6-rc.d/sshd/run; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd /etc/profile.d/gm-postgres.sh; \
    chmod 0440 /etc/sudoers.d/gm-player; \
    visudo -c

ENV S6_READ_ONLY_ROOT=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_SERVICES_GRACETIME=8000 \
    S6_KILL_GRACETIME=1000 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/lib/postgresql/18/bin

EXPOSE 5432 22

# gm-entrypoint prepares /run, the configuration and PGDATA, then execs
# s6-overlay's /init, which supervises `postgres` and `sshd`.
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
