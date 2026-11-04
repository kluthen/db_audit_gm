# pgwatch node for db_audit_gm (v0.5 master spec 7.4; G9, v0.5 wave log).
#
# Generic image: no scenario content. The seed file (the sources, each a
# database node and its metric preset) and the secrets arrive at run time at
# the fixed paths declared in brick.yaml.
# Build:  docker build -t 127.0.0.1:5000/dbagm/pgwatch:0.1.0 bricks/pgwatch
# Architecture: x86_64 only (the s6-overlay and pgwatch archives below).

# --- rootfs/, its modes independent of the checkout --------------------------
# COPY keeps the modes files have in the checkout, which follow the umask it
# was made with. Normalised here: directories and executables 0755, other
# files 0644. The files given other modes on purpose get them in the node
# stage, after the copy.
FROM debian:13-slim AS rootfs-modes
COPY rootfs/ /rootfs/
RUN chmod -R u=rwX,go=rX /rootfs

# --- the node ----------------------------------------------------------------
FROM debian:13-slim

ARG S6_OVERLAY_VERSION=3.2.3.2
# pgwatch, its latest release at the build (G9; spec D368), pinned.
ARG PGWATCH_VERSION=6.1.0

# s6-overlay v3, pinned, verified against the release's published SHA-256.
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/
# pgwatch, the release tarball (not the .deb), verified against the
# release's checksums.txt (G9: it agrees with GitHub's digest).
ADD --checksum=sha256:8c9bb13978e6e769b2c82f304479c2840bbcb44e9a6ba8209507cdfc24a117da \
    https://github.com/cybertec-postgresql/pgwatch/releases/download/v${PGWATCH_VERSION}/pgwatch_Linux_x86_64.tar.gz /tmp/

# Only the binary is kept (G9): the tarball's sample configuration, metric
# definitions file and dashboards are not installed; pgwatch uses the
# metric definitions built into the binary.
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        xz-utils openssh-server sudo curl procps less nano vim-tiny; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    tar -C /tmp -xzf /tmp/pgwatch_Linux_x86_64.tar.gz pgwatch_Linux_x86_64/pgwatch; \
    install -o root -g root -m 0755 /tmp/pgwatch_Linux_x86_64/pgwatch /usr/local/bin/; \
    rm -rf /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz \
        /tmp/pgwatch_Linux_x86_64.tar.gz /tmp/pgwatch_Linux_x86_64; \
    apt-get purge -y xz-utils; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    # host keys are generated per container start (gm-entrypoint), never baked
    rm -f /etc/ssh/ssh_host_*; \
    # the banner names the pinned release; pgwatch exits 1 with no sources
    # (the build condition's `pgwatch --web-disable=all`), after printing it
    { /usr/local/bin/pgwatch --web-disable=all 2>&1 || true; } \
        | grep -Eq "^ *Version: +${PGWATCH_VERSION}\$"; \
    # the `basic` preset, the seed's, needs no helper (G9: no init_sql):
    # pgwatch prints no init SQL for it, and does for `standard`, so the
    # check is not vacuous; pgwatch uses its built-in metric definitions
    test -z "$(/usr/local/bin/pgwatch metric print-init basic 2>&1 | grep -v '^Version info:\|^  \|^$')"; \
    /usr/local/bin/pgwatch metric print-init standard 2>&1 | grep -q '^CREATE '

# Accounts: `pgwatch` runs the collector and is the only account, with
# root, that reads the monitoring password; `player` (SSH by key only) is
# in `pwconf`, which owns the sources file with `pgwatch`. Fixed ids:
# brick.yaml mounts the secret monitoring_password with pgwatch's gid.
RUN set -eux; \
    groupadd --system --gid 990 pgwatch; \
    useradd --system --uid 990 --gid pgwatch --home-dir /nonexistent --no-create-home \
        --shell /usr/sbin/nologin pgwatch; \
    groupadd --system --gid 991 pwconf; \
    useradd --create-home --home-dir /home/player --shell /bin/bash --groups pwconf player; \
    usermod --password '*' player; \
    chmod 0750 /home/player; \
    test "$(id -u pgwatch):$(id -g pgwatch)" = "990:990"; \
    test "$(getent group pwconf | cut -d: -f3)" = 991; \
    if id -nG player | tr ' ' '\n' | grep -qx pgwatch; then exit 1; fi; \
    # sources directory (volume `pwconf`)
    install -d -o pgwatch -g pwconf -m 2775 /etc/pgwatch; \
    # seed marker directory (volume `gmstate`), root-owned, out of pwconf's reach
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
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-restart-pgwatch \
        /usr/local/sbin/gm-validate /usr/local/sbin/gm-write-policy \
        /usr/local/lib/gm/healthcheck /usr/local/lib/gm/pgwatch-sources \
        /opt/gm/validator/validate.sh \
        /etc/s6-overlay/s6-rc.d/pgwatch/run /etc/s6-overlay/s6-rc.d/pgwatch/finish \
        /etc/s6-overlay/s6-rc.d/sshd/run; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd; \
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

EXPOSE 9188 22

# gm-entrypoint prepares /run and the sources file, then execs s6-overlay's
# /init, which supervises `pgwatch` and `sshd`.
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
