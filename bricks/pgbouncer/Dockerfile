# PgBouncer node for db_audit_gm (v0.3 master spec 7.2): the optional pooler.
#
# Generic image: no scenario content. The seed pgbouncer.ini (databases,
# pool sizes, pool mode), the lookup role's password and the envelope file
# arrive at run time at the fixed paths declared in brick.yaml.
# Build:  docker build -t 127.0.0.1:5000/dbagm/pgbouncer:0.1.0 bricks/pgbouncer
# Architecture: x86_64 only (the s6-overlay archive below).

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

ARG S6_OVERLAY_VERSION=3.2.3.2
# Debian 13's package (master spec 7.2); the build fails on another version.
ARG PGBOUNCER_VERSION=1.24.1

# s6-overlay v3, pinned, verified against the release's published SHA-256.
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/

# PgBouncer and psql (the console, for players, the GM and the validator).
# The package's own files (a sample pgbouncer.ini and userlist.txt, the
# systemd unit, logrotate) are not used: the configuration is the seed's
# and the GM's (gm-entrypoint), the service s6's.
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        xz-utils openssh-server sudo procps less nano vim-tiny pgbouncer postgresql-client; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz; \
    apt-get purge -y xz-utils; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    # host keys are generated per container start (gm-entrypoint), never baked;
    # no package-made key either (ssl-cert's snakeoil pair is unused)
    rm -f /etc/ssh/ssh_host_* /etc/ssl/private/ssl-cert-snakeoil.key /etc/ssl/certs/ssl-cert-snakeoil.pem; \
    rm -rf /etc/pgbouncer /var/log/postgresql /etc/logrotate.d/pgbouncer; \
    /usr/sbin/pgbouncer --version | grep -q "^PgBouncer ${PGBOUNCER_VERSION}\$"

# Accounts: `pgbouncer` runs PgBouncer and is its console's admin over the
# local socket (peer); `player` (SSH by key only) is in `pgbconf`, which owns
# the configuration and reads the log with `pgbouncer`. Fixed ids, so a
# volume copied by number (the hand-over snapshot) keeps its owners.
RUN set -eux; \
    groupadd --system --gid 991 pgbouncer; \
    useradd --system --uid 991 --gid pgbouncer --home-dir /var/lib/pgbouncer --no-create-home \
        --shell /usr/sbin/nologin pgbouncer; \
    groupadd --system --gid 992 pgbconf; \
    useradd --create-home --home-dir /home/player --shell /bin/bash --groups pgbconf player; \
    usermod --password '*' player; \
    chmod 0750 /home/player; \
    test "$(id -u pgbouncer):$(id -g pgbouncer)" = "991:991"; \
    test "$(getent group pgbconf | cut -d: -f3)" = 992; \
    if id -nG player | tr ' ' '\n' | grep -qx pgbouncer; then exit 1; fi; \
    if id -nG pgbouncer | tr ' ' '\n' | grep -qx pgbconf; then exit 1; fi; \
    # the configuration (volume `pgbconf`): modes by the write policy at every start
    install -d -o pgbouncer -g pgbconf -m 2775 /etc/pgbouncer; \
    # the log (volume `pgblog`), read by players through pgbconf
    install -d -o pgbouncer -g pgbconf -m 2750 /var/log/pgbouncer; \
    # PgBouncer's home: nothing kept there
    install -d -o pgbouncer -g pgbouncer -m 0750 /var/lib/pgbouncer; \
    # seed marker directory (volume `gmstate`), root-owned, out of pgbconf's reach
    install -d -o root -g root -m 0755 /var/lib/gm-state; \
    # fixed in-container paths for seeds, secrets, validator, envelope file
    install -d -m 0755 /opt/gm /opt/gm/seed /opt/gm/secrets /opt/gm/validator /opt/gm/protected \
        /usr/local/lib/gm; \
    # read-only root: temporary files live under /run (see gm-entrypoint)
    rm -rf /tmp /var/tmp; \
    ln -s /run/tmp /tmp; \
    ln -s /run/tmp /var/tmp

COPY --from=rootfs-modes /rootfs/ /
COPY validator/validate.sh /opt/gm/validator/validate.sh

# Protected files: root-owned, read-only for everyone else.
RUN set -eux; \
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/lib/gm /opt/gm/validator \
        /etc/ssh/sshd_config /etc/sudoers.d/gm-player /etc/motd; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-reload-pgbouncer \
        /usr/local/sbin/gm-validate /usr/local/sbin/gm-write-policy \
        /usr/local/lib/gm/healthcheck /usr/local/lib/gm/pgbouncer-check /usr/local/lib/gm/pgbouncer-conf \
        /opt/gm/validator/validate.sh \
        /etc/s6-overlay/s6-rc.d/pgbouncer/run /etc/s6-overlay/s6-rc.d/sshd/run; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd \
        /usr/local/lib/gm/pgbouncer-gm.ini /usr/local/lib/gm/pgbouncer_hba.conf; \
    chmod 0440 /etc/sudoers.d/gm-player; \
    visudo -c

ENV S6_READ_ONLY_ROOT=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_SERVICES_GRACETIME=8000 \
    S6_KILL_GRACETIME=1000 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EXPOSE 6432 22

# gm-entrypoint prepares /run, the lookup role's password and the
# configuration, then execs s6-overlay's /init, which supervises
# `pgbouncer` and `sshd`.
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
