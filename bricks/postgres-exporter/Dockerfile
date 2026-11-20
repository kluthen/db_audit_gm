# postgres-exporter node for db_audit_gm (v0.2 master spec 7 and 7.3).
#
# Generic image: no scenario content. The seed file (the database's address,
# the user, the extra collectors) and the secrets arrive at run time at the
# fixed paths declared in brick.yaml.
# Build:  docker build -t 127.0.0.1:5000/dbagm/postgres-exporter:0.2.1 bricks/postgres-exporter
# Architecture: x86_64 only (the s6-overlay and postgres_exporter archives below).

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
ARG PG_EXPORTER_VERSION=0.21.1
# zlib1g, named in the install below (v0.6 spec D588): debian:13-slim ships
# +b1, and DSA-6613-1's fix is in trixie-security
# only, so naming it upgrades it; the build fails below this floor.
ARG ZLIB_FLOOR=1:1.3.dfsg+really1.3.1-1+deb13u1

# s6-overlay v3, pinned, verified against the release's published SHA-256.
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/
# postgres_exporter, pinned, verified against the release's sha256sums.txt.
ADD --checksum=sha256:02f316da4e9e409749d6f3b25102d3561cb408023110f3653f6514548926ff0c \
    https://github.com/prometheus-community/postgres_exporter/releases/download/v${PG_EXPORTER_VERSION}/postgres_exporter-${PG_EXPORTER_VERSION}.linux-amd64.tar.gz /tmp/

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        xz-utils openssh-server sudo curl jq procps less nano vim-tiny zlib1g; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    tar -C /tmp -xzf "/tmp/postgres_exporter-${PG_EXPORTER_VERSION}.linux-amd64.tar.gz"; \
    install -o root -g root -m 0755 \
        "/tmp/postgres_exporter-${PG_EXPORTER_VERSION}.linux-amd64/postgres_exporter" /usr/local/bin/; \
    rm -rf /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz \
        "/tmp/postgres_exporter-${PG_EXPORTER_VERSION}.linux-amd64.tar.gz" \
        "/tmp/postgres_exporter-${PG_EXPORTER_VERSION}.linux-amd64"; \
    apt-get purge -y xz-utils; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    # host keys are generated per container start (gm-entrypoint), never baked
    rm -f /etc/ssh/ssh_host_*; \
    # zlib1g at or above DSA-6613-1's fix (D588)
    dpkg --compare-versions "$(dpkg-query -W -f '${Version}' zlib1g)" ge "${ZLIB_FLOOR}"; \
    /usr/local/bin/postgres_exporter --version 2>&1 | grep -q "version ${PG_EXPORTER_VERSION} "; \
    # the collectors this release offers, for exporter.conf's COLLECTORS check
    install -d -m 0755 /usr/local/lib/gm; \
    /usr/local/bin/postgres_exporter --help 2>&1 \
        | sed -n 's/^ *--\[no-\]collector\.\([a-z0-9_]*\) .*/\1/p' | sort -u \
        > /usr/local/lib/gm/exporter-collectors; \
    grep -qx stat_statements /usr/local/lib/gm/exporter-collectors; \
    grep -qx database /usr/local/lib/gm/exporter-collectors; \
    # exporter-conf passes the data source as flags (0.21 deprecates the variables)
    /usr/local/bin/postgres_exporter --help 2>&1 | grep -q -- '--datasource.uri='; \
    /usr/local/bin/postgres_exporter --help 2>&1 | grep -q -- '--datasource.pass-file='

# Accounts: `exporter` runs the server and is the only account, with root,
# that reads the monitoring password; `player` (SSH by key only) is in
# `expconf`, which owns the configuration with `exporter`. Fixed ids:
# brick.yaml mounts the secret monitoring_password with exporter's gid.
RUN set -eux; \
    groupadd --system --gid 990 exporter; \
    useradd --system --uid 990 --gid exporter --home-dir /nonexistent --no-create-home \
        --shell /usr/sbin/nologin exporter; \
    groupadd --system --gid 991 expconf; \
    useradd --create-home --home-dir /home/player --shell /bin/bash --groups expconf player; \
    usermod --password '*' player; \
    chmod 0750 /home/player; \
    test "$(id -u exporter):$(id -g exporter)" = "990:990"; \
    test "$(getent group expconf | cut -d: -f3)" = 991; \
    if id -nG player | tr ' ' '\n' | grep -qx exporter; then exit 1; fi; \
    # configuration directory (volume `expconf`)
    install -d -o exporter -g expconf -m 2775 /etc/postgres-exporter; \
    # seed marker directory (volume `gmstate`), root-owned, out of expconf's reach
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
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/lib/gm /opt/gm/validator \
        /etc/ssh/sshd_config /etc/sudoers.d/gm-player /etc/motd; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-restart-exporter \
        /usr/local/sbin/gm-validate /usr/local/lib/gm/healthcheck /usr/local/lib/gm/exporter-conf \
        /opt/gm/validator/validate.sh \
        /etc/s6-overlay/s6-rc.d/postgres-exporter/run /etc/s6-overlay/s6-rc.d/postgres-exporter/finish \
        /etc/s6-overlay/s6-rc.d/sshd/run; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd /usr/local/lib/gm/exporter-collectors \
        /usr/local/lib/gm/postgres_exporter.yml; \
    chmod 0440 /etc/sudoers.d/gm-player; \
    visudo -c; \
    # brick.yaml `receives`: each command on an s6 service's PATH
    for c in sh cat du df awk sed grep sleep perl s6-svstat s6-setuidgid; do \
        PATH=/command:/usr/bin:/bin command -v "$c" >/dev/null; \
    done

ENV S6_READ_ONLY_ROOT=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_SERVICES_GRACETIME=8000 \
    S6_KILL_GRACETIME=1000 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EXPOSE 9187 22

# gm-entrypoint prepares /run and the configuration, then execs s6-overlay's
# /init, which supervises `postgres-exporter` and `sshd`.
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
