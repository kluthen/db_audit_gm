# Grafana node for db_audit_gm (v0.2 master spec 7 and 7.4).
#
# Generic image: no scenario content. The seed files (data source,
# dashboards, alert rules) and the secrets arrive at run time at the fixed
# paths declared in brick.yaml.
# Build:  docker build -t 127.0.0.1:5000/dbagm/grafana:0.1.0 bricks/grafana
# Architecture: x86_64 only (the s6-overlay and Grafana archives below).

# --- Grafana OSS, pinned, unpacked and trimmed in a stage of its own -------
# The release archive (about 460MB) never reaches the final image: only the
# trimmed tree is copied over.
FROM debian:13-slim AS grafana-dist

ARG GRAFANA_VERSION=13.2.4
ARG GRAFANA_BUILD=38252365904

# Grafana OSS from dl.grafana.com, verified against the SHA-256 the release
# publishes (<archive>.sha256, and grafana.com's package list).
ADD --checksum=sha256:c48765988fd88572607e4ea670251af8a8e64ab3e360d0f3cf67a6f3587b92ab \
    https://dl.grafana.com/grafana/release/${GRAFANA_VERSION}/grafana_${GRAFANA_VERSION}_${GRAFANA_BUILD}_linux_amd64.tar.gz \
    /tmp/grafana.tar.gz

# Kept: the binary, conf/defaults.ini, the front end, and of the plugins
# bundled with the release only the Prometheus data source (the only one a
# scenario provisions). Dropped: the other bundled plugins, the front end's
# source maps, the Swagger UI, documentation and packaging samples.
RUN set -eux; \
    mkdir /dist; \
    tar -C /dist --strip-components=1 -xzf /tmp/grafana.tar.gz; \
    cd /dist; \
    test -x bin/grafana; \
    test -f data/plugins-bundled/prometheus/plugin.json; \
    find data/plugins-bundled -mindepth 1 -maxdepth 1 ! -name prometheus -exec rm -rf {} +; \
    find public -name '*.map' -delete; \
    rm -rf public/build-swagger docs packaging tools Dockerfile; \
    chown -R root:root /dist; \
    chmod -R go-w /dist

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
ARG GRAFANA_VERSION=13.2.4

# s6-overlay v3, pinned, verified against the release's published SHA-256.
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        xz-utils openssh-server sudo curl jq procps less nano vim-tiny; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz; \
    apt-get purge -y xz-utils; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    # host keys are generated per container start (gm-entrypoint), never baked
    rm -f /etc/ssh/ssh_host_*

COPY --from=grafana-dist /dist /usr/share/grafana

# Accounts, with fixed ids (the tools_password secret's gid in brick.yaml is
# grafana's): `grafana` (472:472) runs the server and owns its database;
# `player` (SSH by key only) is in `grafconf` (473), which owns the
# provisioning files with `grafana`. player is never in group grafana, so the
# secret and the database stay out of its reach.
RUN set -eux; \
    groupadd --system --gid 472 grafana; \
    useradd --system --uid 472 --gid grafana --home-dir /var/lib/grafana --no-create-home \
        --shell /usr/sbin/nologin grafana; \
    groupadd --system --gid 473 grafconf; \
    useradd --create-home --home-dir /home/player --shell /bin/bash --groups grafconf player; \
    usermod --password '*' player; \
    chmod 0750 /home/player; \
    test "$(id -u grafana):$(id -g grafana)" = "472:472"; \
    test "$(getent group grafconf | cut -d: -f3)" = 473; \
    ! id -nG player | tr ' ' '\n' | grep -qx grafana; \
    # provisioning directory (volume `grafconf`)
    install -d -o root -g root -m 0755 /etc/grafana; \
    install -d -o grafana -g grafconf -m 2775 /etc/grafana/provisioning; \
    # database and plugins (volume `grafdata`)
    install -d -o grafana -g grafana -m 0750 /var/lib/grafana; \
    # seed marker directory (volume `gmstate`), root-owned, out of grafconf's reach
    install -d -o root -g root -m 0755 /var/lib/gm-state; \
    # fixed in-container paths for seeds, secrets, validator
    install -d -m 0755 /opt/gm /opt/gm/seed /opt/gm/secrets /opt/gm/validator /usr/local/lib/gm; \
    # read-only root: temporary files live under /run (see gm-entrypoint)
    rm -rf /tmp /var/tmp; \
    ln -s /run/tmp /tmp; \
    ln -s /run/tmp /var/tmp

COPY --from=rootfs-modes /rootfs/ /
COPY validator/validate.sh /opt/gm/validator/validate.sh

# Protected files: root-owned, read-only for everyone else. The API helper
# reads the tools password: root and grafana only.
RUN set -eux; \
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/lib/gm /opt/gm/validator \
        /etc/grafana/grafana.ini /etc/ssh/sshd_config /etc/sudoers.d/gm-player /etc/motd; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-reload-grafana \
        /usr/local/sbin/gm-validate /usr/local/lib/gm/healthcheck /opt/gm/validator/validate.sh \
        /etc/s6-overlay/s6-rc.d/grafana/run /etc/s6-overlay/s6-rc.d/sshd/run; \
    chown root:grafana /usr/local/lib/gm/grafana-api; \
    chmod 0750 /usr/local/lib/gm/grafana-api; \
    chmod 0444 /etc/grafana/grafana.ini /usr/local/lib/gm/grafana-files; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd; \
    chmod 0440 /etc/sudoers.d/gm-player; \
    visudo -c; \
    /usr/share/grafana/bin/grafana --version | grep -qx "grafana version ${GRAFANA_VERSION}"; \
    # the commands brick.yaml `receives` declares, on an s6 service's PATH
    for c in sh cat du df awk sed grep sleep perl s6-svstat s6-setuidgid; do \
        PATH=/command:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin command -v "$c" >/dev/null; \
    done

ENV S6_READ_ONLY_ROOT=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_SERVICES_GRACETIME=8000 \
    S6_KILL_GRACETIME=1000 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EXPOSE 3000 22

# gm-entrypoint prepares /run, the provisioning files and the database
# directory, then execs s6-overlay's /init, which supervises `grafana` and
# `sshd`.
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
