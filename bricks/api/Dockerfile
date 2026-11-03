# api node for db_audit_gm (v0.5 master spec 7.2, "The `api` brick").
#
# Generic image: no scenario content. api.yaml, the endpoint files
# (routes/, db/) and the secrets arrive at run time at the fixed paths
# declared in brick.yaml. FastAPI on uvicorn, from the hash-pinned PyPI set
# of requirements.txt (G6, specs/versions/v0.5/wave-log.md).
# Build:       docker build -t 127.0.0.1:5000/dbagm/api:0.1.0 bricks/api
# Unit tests:  sh bricks/api/tests/run-unit-tests.sh (the `unit-test` stage)
# Architecture: x86_64 only (the s6-overlay archive, pydantic-core's wheel).

# --- the brick's files, their modes independent of the checkout -------------
# COPY keeps the checkout's modes (umask 002 gives 775 and 664); normalised
# here: directories 0755, files 0644 (the library), executables 0755
# (rootfs/). The files given other modes on purpose get them in the node
# stage, after the copy.
FROM debian:13-slim AS modes
COPY program/gm_api/ /stage/gm_api/
COPY rootfs/ /stage/rootfs/
COPY validator/validate.sh /stage/validator/validate.sh
RUN find /stage/gm_api -type d -exec chmod 0755 {} + \
    && find /stage/gm_api -type f -exec chmod 0644 {} + \
    && chmod -R u=rwX,go=rX /stage/rootfs /stage/validator

# --- the PyPI set, in a throwaway stage: pip never reaches the node ----------
# G6's conditions: --require-hashes, wheels only, no dependency resolution
# (the set is complete), into a target directory copied below. Debian's pip
# (python3-pip) is build-time only.
FROM debian:13-slim AS wheels
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends python3 python3-pip ca-certificates; \
    rm -rf /var/lib/apt/lists/*
COPY requirements.txt /stage/requirements.txt
RUN python3 -I -m pip install --require-hashes --only-binary=:all: --no-deps --no-compile \
        --disable-pip-version-check --no-cache-dir --target /stage/site -r /stage/requirements.txt \
    && rm -rf /stage/site/bin

# --- the program: Debian's Python 3.13, libpq5 and python3-yaml; the set -----
FROM debian:13-slim AS program
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends python3 libpq5 python3-yaml tzdata; \
    rm -rf /var/lib/apt/lists/*
# /usr/local/lib/python3.13/dist-packages is on Debian's python3 path, -I included
COPY --from=wheels /stage/site/ /usr/local/lib/python3.13/dist-packages/
COPY --from=modes /stage/gm_api/ /usr/local/lib/python3.13/dist-packages/gm_api/
RUN --mount=type=bind,source=build/check-image.py,target=/opt/gm-build/check-image.py \
    --mount=type=bind,source=requirements.txt,target=/opt/gm-build/requirements.txt \
    set -eux; \
    find /usr/local/lib/python3.13/dist-packages -type d -exec chmod 0755 {} +; \
    find /usr/local/lib/python3.13/dist-packages -type f -exec chmod 0644 {} +; \
    python3 -I -m compileall -q /usr/local/lib/python3.13/dist-packages; \
    python3 -I /opt/gm-build/check-image.py /opt/gm-build/requirements.txt
# FastAPI 0.162 imports opentelemetry-api, which exports nothing without the SDK
ENV OTEL_SDK_DISABLED=true

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

# Accounts: `api` runs the server and owns db/ and the log; it reads the
# copies of the secrets the entrypoint writes under /run. `player` (SSH by
# key only) is in `apiconf`, which owns db/ and reads the log with `api`.
# Fixed ids (capture W1-z).
RUN set -eux; \
    groupadd --system --gid 991 api; \
    useradd --system --uid 991 --gid api --home-dir /var/lib/api --no-create-home \
        --shell /usr/sbin/nologin api; \
    groupadd --system --gid 992 apiconf; \
    useradd --create-home --home-dir /home/player --shell /bin/bash --groups apiconf player; \
    usermod --password '*' player; \
    chmod 0750 /home/player; \
    test "$(id -u api):$(id -g api)" = "991:991"; \
    test "$(getent group apiconf | cut -d: -f3)" = 992; \
    if id -nG player | tr ' ' '\n' | grep -qx api; then exit 1; fi; \
    if id -nG api | tr ' ' '\n' | grep -qx apiconf; then exit 1; fi; \
    # the endpoint files (volume `endpoints`): the entrypoint seeds them once
    # and sets their owners and modes by the write policy at every start
    install -d -o root -g root -m 0755 /srv/api /srv/api/routes; \
    install -d -o api -g apiconf -m 2755 /srv/api/db; \
    # the request log (volume `apilog`), read by players through apiconf
    install -d -o api -g apiconf -m 2750 /var/log/api; \
    install -d -o api -g api -m 0750 /var/lib/api; \
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
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/lib/gm /opt/gm/validator \
        /usr/local/lib/python3.13/dist-packages /etc/ssh/sshd_config /etc/sudoers.d/gm-player /etc/motd; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/sbin/gm-reload-api /usr/local/sbin/gm-validate \
        /usr/local/lib/gm/healthcheck /opt/gm/validator/validate.sh \
        /etc/s6-overlay/s6-rc.d/api/run /etc/s6-overlay/s6-rc.d/api/finish \
        /etc/s6-overlay/s6-rc.d/sshd/run; \
    chmod 0644 /etc/ssh/sshd_config /etc/motd; \
    chmod 0440 /etc/sudoers.d/gm-player; \
    visudo -c; \
    test "$(readlink -f /bin/sh)" = /usr/bin/dash; \
    python3 -I -m gm_api --help >/dev/null; \
    python3 -I -m uvicorn --version; \
    # G6: no pip in the node
    if python3 -I -m pip --version >/dev/null 2>&1; then echo "pip is in the node" >&2; exit 1; fi; \
    if command -v pip pip3 >/dev/null 2>&1; then echo "a pip command is in the node" >&2; exit 1; fi; \
    # brick.yaml `receives`: each command on an s6 service's PATH
    for c in sh cat du df awk sed grep sleep perl s6-svstat s6-setuidgid; do \
        PATH=/command:/usr/bin:/bin command -v "$c" >/dev/null; \
    done

# The accounts, generated at each start (v0.5 master spec 10.2, `no-access`;
# as postgres 0.5.0 does it). The root filesystem is read-only, so the
# account files and the player's sudo rules live under /run, written by
# gm-entrypoint from the copies kept here: as built on a `fixable` or
# `report-only` node; without `player`, its group, its membership of
# apiconf and its sudo rules on a `no-access` node. The image's own
# /run/gm-accounts holds the files as built: the Docker daemon resolves
# `docker exec -u api` from the image's root filesystem, where the /run
# volume is not mounted, so the links must resolve there too; inside the
# container the volume, rewritten at each start, hides that copy. Last
# step: nothing after it resolves a name at build.
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
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

EXPOSE 8000 22

# gm-entrypoint prepares /run, the accounts, the policy and the files, then
# execs s6-overlay's /init, which supervises `api` and `sshd`.
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
