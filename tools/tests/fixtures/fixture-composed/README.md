# fixture-composed

Fixture of `tools/tests/test_coherence.py` (v0.5 chunk 8, capture W2 item
3): not a game and not a complete scenario. `catalog/` is a test catalogue
root: a core, `fx-core` (variant `small`), shipping `data/keys.sql` (its
`pg_temp.core_*` key functions) and a partner's state,
`producers/partners/xlab/data.sql`; its part `fx-ward` (`lands_with:
fx-core`, a contrib extension, `btree_gist`, in its schema) with a
`pg_cron` job, `data/cron.sql` (chunk 29's (d)); its part `fx-docs` in a
database of its own (`records/docs`, `pgcrypto` in its schema) with its
own key functions, `data/keys.sql` (`pg_temp.docs_*`, chunk 29's (a)),
and a derivation, `data/derive.sql`, sanctioned after `fx-core`; both
parts with `data/coherence.yaml`; a purpose, `fx-weekly`, whose
`material/history.sql` plants `records/office`; and a purpose,
`fx-intake`, whose `ddl: {target: material/target-ddl.sql}` creates its
role, grants, policy and `ops` table in `records/clinic`, a composed
domain's database (chunk 29b's (e)). `scenario/` composes them
on two `postgres` nodes, `records` (its seed `postgresql.conf`
preloading `pg_cron`, its jobs in `office`, which its data file creates
with the extension) and the partners' `partners-db`, its
`composition.yaml` loading `fx-docs` before `fx-ward` (not `domains:`'
order) and leaving out `fx-docs`' `desk` producer (`left_out:`, chunk
29's (b)).

The unit tests read it with load-data's SQL runs stubbed. The composed
test load runs it into two throwaway containers of the `postgres` image
at its current tag (never a Swarm deployment), `partners-db` on the
partners' own `partners/shared/partners-db/pg_hba.conf` (its partners'
line naming `xlab`, no `gm_check` host line), so `fx-ward`'s check reading
`partners` can pass only when run on the partners' node (spec D383),
`records` preloading `pg_cron` with `cron.database_name = office` as its
seed says; a passing load (`fx-ward`'s job still in `cron.job` after the
`pg_cron` clean-up), then a broken range failing the coherence check,
under the host lock:

    flock /tmp/dbagm-docker.lock systemd-inhibit --what=sleep:idle:handle-lid-switch \
        --who=dbagm --why=composed-load env GM_TEST_COMPOSED_LOAD=1 \
        python3 -m unittest tools.tests.test_coherence.TestComposedLoad -v

`GM_TEST_PG_IMAGE` names another image (default
`127.0.0.1:5000/dbagm/postgres:0.5.0`).
