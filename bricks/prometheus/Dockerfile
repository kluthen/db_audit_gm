# Prometheus node for db_audit_gm (v0.2 master spec 7 and 7.2).
#
# Generic image: no scenario content. The seed configuration (scrape
# targets, retention) and the secret arrive at run time at the fixed paths
# declared in brick.yaml.
# Build:  docker build -t 127.0.0.1:5000/dbagm/prometheus:0.1.0 bricks/prometheus
# Architecture: x86_64 only (the s6-overlay and Prometheus archives below).
FROM debian:13-slim

ARG S6_OVERLAY_VERSION=3.2.3.2
ARG PROMETHEUS_VERSION=3.13.5

# s6-overlay v3, pinned, verified against the release's published SHA-256.
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/
# Prometheus, pinned, verified against the release's sha256sums.txt.
ADD --checksum=sha256:0388822ace519c5a3a8ef556a541ce1b536e21d872f82deded465bd27a5a0699 \
    https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz /tmp/

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        xz-utils openssh-server sudo curl procps less nano vim-tiny; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    tar -C /tmp -xzf "/tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"; \
    install -o root -g root -m 0755 \
        "/tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/prometheus" \
        "/tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64/promtool" /usr/local/bin/; \
    rm -rf /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz \
        "/tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" \
        "/tmp/prometheus-${PROMETHEUS_VERSION}.linux-amd64"; \
    apt-get purge -y xz-utils; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    # host keys are generated per container start (gm-entrypoint), never baked
    rm -f /etc/ssh/ssh_host_*; \
    /usr/local/bin/prometheus --version | grep -q "version ${PROMETHEUS_VERSION} "

# Accounts: `prometheus` runs the server and owns its data; `player` (SSH by
# key only) is in `promconf`, which owns the configuration with `prometheus`.
RUN set -eux; \
    groupadd --system prometheus; \
    useradd --system --gid prometheus --home-dir /var/lib/prometheus --no-create-home \
        --shell /usr/sbin/nologin prometheus; \
    groupadd --system promconf; \
    useradd --create-home --home-dir /home/player --shell /bin/bash --groups promconf player; \
    usermod --password '*' player; \
    chmod 0750 /home/player; \
    # configuration directory (volume `promconf`)
    install -d -o prometheus -g promconf -m 2775 /etc/prometheus; \
    # TSDB (volume `promdata`)
    install -d -o prometheus -g prometheus -m 0750 /var/lib/prometheus; \
    # seed marker directory (volume `gmstate`), root-owned, out of promconf's reach
    install -d -o root -g root -m 0755 /var/lib/gm-state; \
    # fixed in-container paths for seeds, secrets, validator
    install -d -m 0755 /opt/gm /opt/gm/seed /opt/gm/secrets /opt/gm/validator /usr/local/lib/gm; \
    # read-only root: temporary files live under /run (see gm-entrypoint)
    rm -rf /tmp /var/tmp; \
    ln -s /run/tmp /tmp; \
    ln -s /run/tmp /var/tmp

COPY rootfs/ /
COPY validator/validate.sh /opt/gm/validator/validate.sh

# Protected files: root-owned, read-only for everyone else.
RUN set -eux; \
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/lib/gm /opt/gm/validator \
        /etc/ssh/sshd_config /etc/sudoers.d/gm-player /etc/motd; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-reload-prometheus \
        /usr/local/sbin/gm-validate /usr/local/lib/gm/healthcheck /opt/gm/validator/validate.sh \
        /etc/s6-overlay/s6-rc.d/prometheus/run /etc/s6-overlay/s6-rc.d/sshd/run; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd; \
    chmod 0440 /etc/sudoers.d/gm-player; \
    visudo -c

ENV S6_READ_ONLY_ROOT=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_SERVICES_GRACETIME=8000 \
    S6_KILL_GRACETIME=1000 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EXPOSE 9090 22

# gm-entrypoint prepares /run and the configuration, then execs s6-overlay's
# /init, which supervises `prometheus` and `sshd`.
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
