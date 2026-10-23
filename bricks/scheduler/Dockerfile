# scheduler node for db_audit_gm (v0.3 master spec 7.1).
#
# Generic image: no scenario content. The schedule, the repository, the jobs
# and the role passwords arrive at run time at the fixed paths declared in
# brick.yaml.
# Build:       docker build -t 127.0.0.1:5000/dbagm/scheduler:0.1.0 bricks/scheduler
# Unit tests:  sh bricks/scheduler/tests/run-unit-tests.sh (the `unit-test` stage)
# Architecture: x86_64 only (the s6-overlay archive below).

# --- the brick's files, their modes independent of the checkout -------------
# COPY keeps the modes files have in the checkout, which follow the umask it
# was made with (umask 002 gives 775 directories and 664 files, and COPY
# rootfs/ / would apply them to /etc, /usr, /usr/local...). Normalised here:
# directories 0755, files 0644 (the program), directories and executables
# 0755, other files 0644 (rootfs/). The files given other modes on purpose
# get them in the node stage, after the copy.
FROM debian:13-slim AS modes
COPY program/gm_scheduler/ /stage/gm_scheduler/
COPY rootfs/ /stage/rootfs/
COPY validator/validate.sh /stage/validator/validate.sh
RUN find /stage/gm_scheduler -type d -exec chmod 0755 {} + \
    && find /stage/gm_scheduler -type f -exec chmod 0644 {} + \
    && chmod -R u=rwX,go=rX /stage/rootfs /stage/validator

# --- the program: Python 3.13, psycopg and PyYAML from Debian ---------------
FROM debian:13-slim AS program
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends python3 python3-psycopg python3-yaml tzdata; \
    rm -rf /var/lib/apt/lists/*
# /usr/local/lib/python3.13/dist-packages is on Debian's python3 path, -I included
COPY --from=modes /stage/gm_scheduler/ /usr/local/lib/python3.13/dist-packages/gm_scheduler/
RUN set -eux; \
    python3 -I -c 'import sys; assert sys.version_info[:2] == (3, 13), sys.version'; \
    python3 -I -c 'import gm_scheduler, gm_scheduler.__main__, psycopg, yaml, zoneinfo; zoneinfo.ZoneInfo("Etc/GMT-3")'; \
    python3 -I -m compileall -q /usr/local/lib/python3.13/dist-packages/gm_scheduler

# --- the unit tests, against a throwaway PostgreSQL (never in the node) -----
FROM program AS unit-test
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends postgresql; \
    rm -rf /var/lib/apt/lists/*
COPY tests/unit/ /opt/gm-test/unit/
CMD ["/bin/sh", "/opt/gm-test/unit/run-in-image.sh"]

# --- the node ----------------------------------------------------------------
FROM program AS node

ARG S6_OVERLAY_VERSION=3.2.3.2

# s6-overlay v3, pinned, verified against the release's published SHA-256.
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/

RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        xz-utils openssh-server sudo curl procps less nano vim-tiny; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz; \
    apt-get purge -y xz-utils; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    # host keys are generated per container start (gm-entrypoint), never baked
    rm -f /etc/ssh/ssh_host_*

# Accounts: `scheduler` runs the program and is the only account, with root,
# that reads its state; it never reads the schedule or the role passwords
# (the run script passes them on standard input). `player` (SSH by key only)
# is in `schedconf`, which owns the repository and jobs with `scheduler`.
# Fixed ids (capture W1-y).
RUN set -eux; \
    groupadd --system --gid 993 scheduler; \
    useradd --system --uid 993 --gid scheduler --home-dir /var/lib/scheduler --no-create-home \
        --shell /usr/sbin/nologin scheduler; \
    groupadd --system --gid 994 schedconf; \
    useradd --create-home --home-dir /home/player --shell /bin/bash --groups schedconf player; \
    usermod --password '*' player; \
    chmod 0750 /home/player; \
    test "$(id -u scheduler):$(id -g scheduler)" = "993:993"; \
    test "$(getent group schedconf | cut -d: -f3)" = 994; \
    if id -nG player | tr ' ' '\n' | grep -qx scheduler; then exit 1; fi; \
    if id -nG scheduler | tr ' ' '\n' | grep -qx schedconf; then exit 1; fi; \
    # the repository and jobs (volumes `repository`, `jobs`): the entrypoint
    # sets their modes by the write policy at every start
    install -d -o root -g root -m 0755 /srv/scheduler; \
    install -d -o scheduler -g schedconf -m 2755 /srv/scheduler/repository /srv/scheduler/jobs; \
    install -d -o scheduler -g schedconf -m 0755 /srv/scheduler/repository/builders; \
    # the log (volume `schedlog`), read by players through schedconf
    install -d -o scheduler -g schedconf -m 2750 /var/log/scheduler; \
    # the program's state (volume `schedstate`)
    install -d -o scheduler -g scheduler -m 0750 /var/lib/scheduler; \
    # seed and load markers (volume `gmstate`), root-owned
    install -d -o root -g root -m 0755 /var/lib/gm-state; \
    # fixed in-container paths for seeds, secrets, validator
    install -d -m 0755 /opt/gm /opt/gm/seed /opt/gm/secrets /opt/gm/validator; \
    # read-only root: temporary files live under /run (see gm-entrypoint)
    rm -rf /tmp /var/tmp; \
    ln -s /run/tmp /tmp; \
    ln -s /run/tmp /var/tmp

COPY --from=modes /stage/rootfs/ /
COPY --from=modes /stage/validator/validate.sh /opt/gm/validator/validate.sh

# Protected files: root-owned, read-only for everyone else.
RUN set -eux; \
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/lib/gm /opt/gm/validator /etc/scheduler \
        /usr/local/lib/python3.13/dist-packages/gm_scheduler /etc/ssh/sshd_config /etc/sudoers.d/gm-player /etc/motd; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-reload-scheduler /usr/local/sbin/gm-validate \
        /usr/local/lib/gm/healthcheck /opt/gm/validator/validate.sh \
        /etc/s6-overlay/s6-rc.d/scheduler/run /etc/s6-overlay/s6-rc.d/scheduler/finish \
        /etc/s6-overlay/s6-rc.d/sshd/run; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd /etc/scheduler/scheduler.yaml; \
    chmod 0440 /etc/sudoers.d/gm-player; \
    visudo -c; \
    test "$(readlink -f /bin/sh)" = /usr/bin/dash; \
    python3 -I -m gm_scheduler --help >/dev/null; \
    # brick.yaml `receives`: each command on an s6 service's PATH
    for c in sh cat du df awk sed grep sleep perl s6-svstat s6-setuidgid; do \
        PATH=/command:/usr/bin:/bin command -v "$c" >/dev/null; \
    done

ENV S6_READ_ONLY_ROOT=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_SERVICES_GRACETIME=8000 \
    S6_KILL_GRACETIME=1000 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EXPOSE 9120 22

# gm-entrypoint prepares /run, the policy and the files, then execs
# s6-overlay's /init, which supervises `scheduler` and `sshd`.
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
