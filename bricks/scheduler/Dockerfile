# scheduler node for db_audit_gm (v0.3 master spec 7.1).
#
# Generic image: no scenario content. The schedule, the repository, the jobs
# and the role passwords arrive at run time at the fixed paths declared in
# brick.yaml.
# Build:       docker build -t 127.0.0.1:5000/dbagm/scheduler:0.1.0 bricks/scheduler
# Unit tests:  sh bricks/scheduler/tests/run-unit-tests.sh (the `unit-test` stage)

# --- the program's files, their modes independent of the checkout -----------
# COPY keeps the modes files have in the checkout, which follow the umask it
# was made with. Normalised here: directories 0755, files 0644.
FROM debian:13-slim AS modes
COPY program/gm_scheduler/ /stage/gm_scheduler/
RUN find /stage -type d -exec chmod 0755 {} + && find /stage -type f -exec chmod 0644 {} +

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
    find /usr/local/lib/python3.13/dist-packages/gm_scheduler -name __pycache__ -prune -exec rm -rf {} +

# --- the unit tests, against a throwaway PostgreSQL (never in the node) -----
FROM program AS unit-test
RUN set -eux; \
    export DEBIAN_FRONTEND=noninteractive; \
    apt-get update; \
    apt-get install -y --no-install-recommends postgresql; \
    rm -rf /var/lib/apt/lists/*
COPY tests/unit/ /opt/gm-test/unit/
CMD ["/bin/sh", "/opt/gm-test/unit/run-in-image.sh"]
