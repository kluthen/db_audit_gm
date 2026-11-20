# Bastion node for db_audit_gm (master spec 9.2).
#
# The players' only entry point: sshd (password login as `player`), the
# PostgreSQL 19 client tools and an SSH client for the inner hop, curl (the
# players' HTTP client), and the web front (nginx, port 8080), in every
# game: its home the starter-pack page, rendered at start-up by cmark-gfm,
# and the monitoring web interfaces when the scenario routes any (v0.4
# master spec 7.3, D224).
# Generic image: no scenario content. The starter pack and the secrets
# arrive at run time at the fixed paths declared in brick.yaml.
# Build:  docker build -t 127.0.0.1:5000/dbagm/bastion:0.6.0 bricks/bastion
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

# PostgreSQL 19 (v0.6 spec D587), as the PostgreSQL brick.
ARG PG_MAJOR=19
ARG S6_OVERLAY_VERSION=3.2.3.2
# zlib1g, named in the install below (v0.6 spec D588): debian:13-slim ships
# +b1, and DSA-6613-1's fix (with CVE-2026-76844's) is in trixie-security
# only, so naming it upgrades it; the build fails below this floor.
ARG ZLIB_FLOOR=1:1.3.dfsg+really1.3.1-1+deb13u1

# s6-overlay v3, pinned, verified against the release's published SHA-256
# (same version and checksums as the PostgreSQL brick).
ADD --checksum=sha256:5379750ed30a84bbd2e2dd74847ba6b5bd29cd0b2e3ea2ec58049b57eb2eda12 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz /tmp/
ADD --checksum=sha256:e6befcc96a437a3831386ecfc51808c5d3e939dc5fe3c02ae9284599e8aa2408 \
    https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz /tmp/

# PostgreSQL ${PG_MAJOR} client tools from the PGDG repository (signing key
# shipped in postgresql-common), as in the PostgreSQL brick. `openssl`
# hashes the per-game passwords at start-up (gm-entrypoint). nginx, from
# Debian's own repository, is the web front; its packaged site, logs and
# state are removed (its configuration is written under /run at start-up).
# cmark-gfm, from Debian too, renders the starter pack into the front's
# page (D222, gate G13): tables on (-e table), raw HTML omitted (its safe
# default; never --unsafe), asserted below. curl, from Debian too, is the
# players' HTTP client (access model 4; gate G11.2, owner accepted
# 2026-11-10): the partners' endpoints with the credentials handed over.
# v0.6 (master spec 7.7; gate G6, cleared 2026-11-17): jq, to read
# Prometheus' API, and tmux, from Debian too, unpinned; jq also reads the
# partners' status file (capture W2 item 1).
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates postgresql-common xz-utils; \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt trixie-pgdg main" \
        > /etc/apt/sources.list.d/pgdg.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        "postgresql-client-${PG_MAJOR}" \
        openssh-server openssh-client openssl procps less nano vim-tiny nginx cmark-gfm curl \
        jq tmux zlib1g; \
    tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz; \
    tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz; \
    rm -f /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz; \
    apt-get purge -y xz-utils; \
    apt-get autoremove -y; \
    rm -rf /var/lib/apt/lists/*; \
    # host keys live in the `hostkeys` volume (gm-entrypoint), never baked
    rm -f /etc/ssh/ssh_host_*; \
    rm -rf /etc/nginx/sites-enabled/* /etc/nginx/sites-available/* /etc/nginx/conf.d/* \
        /var/log/nginx /var/lib/nginx /var/www/html; \
    test -x "/usr/lib/postgresql/${PG_MAJOR}/bin/psql"; \
    # PostgreSQL 19 only (G9.2): the client and libpq at 19, no other
    # major's client or server left
    case "$(dpkg-query -W -f '${Version}' "postgresql-client-${PG_MAJOR}")" in 19.*) ;; *) exit 1 ;; esac; \
    case "$(dpkg-query -W -f '${Version}' libpq5)" in 19.*) ;; *) exit 1 ;; esac; \
    if dpkg-query -W -f '${Package} ${Status}\n' 'postgresql-1[0-8]*' 'postgresql-client-1[0-8]*' 2>/dev/null | grep -q 'ok installed'; then exit 1; fi; \
    # zlib1g at or above DSA-6613-1's fix (D588)
    dpkg --compare-versions "$(dpkg-query -W -f '${Version}' zlib1g)" ge "${ZLIB_FLOOR}"; \
    test -x /usr/sbin/nginx; \
    command -v cmark-gfm; \
    curl --version; \
    jq --version; \
    tmux -V; \
    test -f /etc/nginx/mime.types; \
    printf '| a |\n|---|\n| 1 |\n' | cmark-gfm -e table | grep -q '<table>'; \
    printf '<b>x</b>\n' | cmark-gfm | grep -q 'raw HTML omitted'

# Account `player` (SSH by password only). Its password is set at each
# start: /etc/shadow is a symlink to /run/gm/shadow, which gm-entrypoint
# builds from the image's own copy plus the hash of the per-game secret.
RUN set -eux; \
    useradd --create-home --home-dir /home/player --shell /bin/bash player; \
    usermod --password '*' player; \
    chmod 0750 /home/player; \
    install -d -m 0755 /usr/local/lib/gm; \
    mv /etc/shadow /usr/local/lib/gm/shadow.base; \
    chown root:shadow /usr/local/lib/gm/shadow.base; \
    chmod 0640 /usr/local/lib/gm/shadow.base; \
    ln -s /run/gm/shadow /etc/shadow; \
    rm -f /etc/shadow- /etc/gshadow-; \
    # fixed in-container paths for the starter pack, secrets, validator,
    # and the mount point of the `hostkeys` volume
    install -d -m 0755 /opt/gm /opt/gm/starter /opt/gm/secrets /opt/gm/validator \
        /opt/gm/docs /opt/gm/docs/bricks; \
    install -d -m 0700 /var/lib/gm-sshd-keys; \
    # read-only root: temporary files live under /run (see gm-entrypoint)
    rm -rf /tmp /var/tmp; \
    ln -s /run/tmp /tmp; \
    ln -s /run/tmp /var/tmp

COPY --from=rootfs-modes /rootfs/ /
COPY validator/validate.sh /opt/gm/validator/validate.sh

# Protected files: root-owned, read-only for everyone else.
RUN set -eux; \
    chown -R root:root /etc/s6-overlay /usr/local/sbin /usr/local/bin /opt/gm/validator \
        /etc/ssh/sshd_config /etc/ssh/ssh_config.d/gm-game.conf /etc/motd /etc/profile.d/gm-bastion.sh; \
    chown root:root /usr/local/lib/gm/healthcheck /usr/local/lib/gm/html-ids /usr/local/lib/gm/pages.sh \
        /usr/local/lib/gm/render-status; \
    chmod 0755 /usr/local/sbin/gm-entrypoint /usr/local/lib/gm/healthcheck /opt/gm/validator/validate.sh \
        /usr/local/lib/gm/html-ids /usr/local/lib/gm/render-status \
        /etc/s6-overlay/s6-rc.d/sshd/run /etc/s6-overlay/s6-rc.d/web-front/run \
        /etc/s6-overlay/s6-rc.d/status-pages/run; \
    chmod 0644 /usr/local/lib/gm/pages.sh; \
    printf '# A\n\n## B c\n\n## B c\n\n[p](partners.md#b-c)\n' | cmark-gfm -e table \
        | perl /usr/local/lib/gm/html-ids | grep -q '<h2 id="b-c-1">'; \
    chmod 0644 /etc/ssh/sshd_config /etc/ssh/ssh_config.d/gm-game.conf /etc/motd /etc/profile.d/gm-bastion.sh; \
    ln -s /opt/gm/validator/validate.sh /usr/local/bin/gm-validate

ENV S6_READ_ONLY_ROOT=1 \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_SERVICES_GRACETIME=8000 \
    S6_KILL_GRACETIME=1000

EXPOSE 22 8080

# gm-entrypoint prepares /run, the sshd host key, the password, the
# player's home, starter pack and ~/reports/, the web front's
# configuration, password file and pages, then execs s6-overlay's /init,
# which supervises `sshd`, `web-front` and `status-pages` (the partners'
# status pages, every minute, when the game has a status file).
ENTRYPOINT ["/usr/local/sbin/gm-entrypoint"]
