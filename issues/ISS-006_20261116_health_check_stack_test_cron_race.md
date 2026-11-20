# Issue: health-check stack test flaky: gm-validate runs before the cron daemon starts

**ID:** `ISS-006_20261116_health_check_stack_test_cron_race`
**Ref:** `ISS-006`
**Date:** 2026-11-16
**Severity:** Medium
**Status:** In Progress
**Component:** `bricks/health-check/tests/run-stack-test.sh`
**Affects:** `bricks/health-check/validator/validate.sh` (the cron rule), `bricks/health-check/rootfs/usr/local/sbin/gm-validate`, `bricks/health-check/rootfs/etc/s6-overlay/s6-rc.d/cron/run`, `bricks/health-check/rootfs/usr/local/lib/gm/healthcheck`, `bricks/health-check/brick.yaml` (`healthcheck:`); every v0.6 wave gate (each brick's stack test) and the release gate
**Seen on:** armenelos swarm; v0.6 chunk 2 (2026-11-16); `health-check` 0.1.1, image byte-identical to 0.1.0; `sh bricks/health-check/tests/run-stack-test.sh`
**Reported by:** found while coding: v0.6 chunk 2's owner, running the brick's stack test

---

## Summary

The `health-check` brick's stack test fails some of the time on the
report-only redeploy: it runs `sudo gm-validate` as soon as the new
container reports healthy, and sometimes the cron daemon has not started
yet, so the validator answers "RED cron: the cron daemon does not run".
The node itself is fine a few seconds later. The flake predates v0.6 (the
image is byte-identical to 0.1.0), but every v0.6 wave gate runs every
brick's stack test, so it can turn a gate red with nothing broken. A
player or GM running `gm-validate` in the first seconds of a fresh
container can meet the same false red.

---

## What happens

### Expected

The report-only section's last step passes: `gm-validate` exits 0
("report-only: gm-validate green") once the redeployed container is up.

### Observed

2 runs out of 3 failed during chunk 2 at 0.1.1, with the validator's line
"RED cron: the cron daemon does not run; the checks and scripts do not
run" (`fail "validate report-only: exit 1: ..."`). A run of the earlier
script with the 0.1.0 tags passed once.

### How to reproduce

1. Build `health-check` at its v0.6 version (0.1.1) on a swarm host.
2. Run `sh bricks/health-check/tests/run-stack-test.sh`, several times.
3. Look at the report-only section's `gm-validate` result (test lines
   411 to 426). Fails some runs, not all; the frequency depends on how
   long the cron service's first checks run takes against the healthcheck's
   first probe (guessed, not measured).

---

## Cause

**Lead**, close to confirmed: the mechanism is read in the code; the
timings that decide each run were not measured.

The healthcheck does not cover cron by design. It is healthy once sshd is
up and the status page answers
(`rootfs/usr/local/lib/gm/healthcheck`, lines 11 to 18). On the report-only
redeploy the page left by the previous container is still in its volume,
so nginx answers at once.

The `cron` s6 service does not exec cron right away
(`rootfs/etc/s6-overlay/s6-rc.d/cron/run`): it first waits, bounded, up to
`WAIT=30` s (line 14) for health.yaml's hosts to resolve, then makes a
first `health-run checks` run (line 45), and only then
`exec /usr/sbin/cron -f` (line 46). Until that exec the process is the
run script's `sh`, not `cron`.

The validator's cron rule is a one-shot look
(`validator/validate.sh`, lines 56 to 59):

```sh
if [ -z "$(ps -C cron -o pid= 2>/dev/null)" ]; then
    say_red "cron: the cron daemon does not run; the checks and scripts do not run"
fi
```

The test calls it as soon as `wait_healthy` returns
(`tests/run-stack-test.sh`, lines 413 to 426):

```
container start ──> sshd up, page answers (old page in volume) ──> healthy
                 └─> cron/run: host wait (≤30 s) ──> first checks run ──> exec cron
test:                        wait_healthy returns ──> ... gm-validate ──> ps -C cron: empty ──> RED
```

### Where this pattern exists today

The same test already guards the other two starts: after the first deploy
it waits for the `health-start: first run:` log line (lines 206 to 211),
and after `docker service update --force` it waits for it again
(lines 388 to 389). The report-only redeploy (line 413) has no such wait.
Even the log-line wait leaves a tiny gap (the line is printed just before
`exec cron`), and `--since 3m` can match the previous container's line.

---

## Spec and intent

- Specs and decisions: v0.4 spec D305 and v0.5 spec D356 (the lesson "a
  new caller waits, bounded, for the names it resolves at start"; archived
  in `specs/archive/v0.5/decisions-D314-D476.md` and
  `specs/archive/v0.5/build-plan.md`, "Read first"); the brick's GM doc,
  `bricks/health-check/docs/gm.md` lines 147 to 151 (the cron service's
  bounded wait and first run before cron). The healthcheck's own comment
  states that cron being down after the first time is the game's business,
  not Swarm's.
- Intent records: none recorded for this test.
- Verdict: **code bug**, in the test (or the validator's cron rule): a
  caller that starts right after the node does not wait, bounded, for the
  daemon it checks. No spec change needed for the test-side fix; making
  the healthcheck cover cron changes the brick's documented healthcheck
  contract (brick.yaml, docs/gm.md) and goes through the spec's owner.

---

## Risk assessment

| Factor | Value |
|---|---|
| Likelihood | High in the stack test (2 of 3 runs at chunk 2); low in play (only in a fresh container's first seconds) |
| Impact | Medium: a wave or release gate goes red with nothing broken; reruns cost time under the host lock |
| Detectability | High: one RED line naming cron, in the test's output |
| Current mitigation | the stack test waits, bounded (90 s), for the cron daemon before `gm-validate` (78fe203, test-only); a player or GM can still meet the false red in a fresh container's first seconds |

---

## Recommended fix

**Short term (applied, 78fe203, test-only):** in the test, after the
report-only redeploy's `wait_healthy`, wait, bounded (90 s), until
`ps -C cron` finds the daemon in the new container, before calling
`gm-validate`; fail with an explicit message past the bound
("report-only: no cron daemon 90 s after the container was healthy").
The brick and its image are unchanged.

**Medium term (open, not decided):** pick one of, with the brick's next
version:
- `gm-validate`'s cron rule waits, bounded (a few tens of seconds, past
  the cron service's 30 s host wait plus its first run), for the cron
  daemon before reporting it red, so a player or GM meets no false red
  at start either; or
- the healthcheck covers cron the way it covers the page: healthy only
  once cron has run at least once in this container (a mark like
  `/run/gm/health-was-ready`), never failing on cron afterwards. This
  delays healthy (and so Swarm's DNS entry) by the host wait and the
  first run, and changes the documented healthcheck: owner's call.

**Long term:** the stack tests share one helper that waits, bounded, for a
started node's own services (not only Docker's healthy) before checking
them.

**Test:** the brick's stack test itself, run several times in a row at the
wave gate (for example three consecutive green runs), with the report-only
redeploy's `gm-validate` step green each time.

---

## Extra data

- Chunk 2 (2026-11-16), `health-check` 0.1.1: 2 failures in 3 runs, both
  on "RED cron: the cron daemon does not run".
- The earlier script with the 0.1.0 tags: 1 run, passed.
- Not investigated here (no docker run when filing): the duration of the
  report-only container's host wait and first checks run, and the time to
  its first healthy probe.
- v0.6 wave 1 gate (2026-11-16, armenelos, `health-check` 0.1.1, image
  4382f30f251c): with the wait, 4 green runs out of 4. The first run's
  wait read "waited 2s" (the race met, and covered); the next three, on
  the committed fix, read "waited 0s", 97 PASS, 0 FAIL, 179 to 211 s each.

---

## References

- `bricks/health-check/tests/run-stack-test.sh` lines 161 to 172
  (`wait_healthy`), 206 to 211 and 388 to 389 (the existing first-run
  waits), 411 to 426 (report-only redeploy and `gm-validate`)
- `bricks/health-check/validator/validate.sh` lines 56 to 59 (cron rule)
- `bricks/health-check/rootfs/usr/local/sbin/gm-validate` (runs the
  validator as `postgres`)
- `bricks/health-check/rootfs/etc/s6-overlay/s6-rc.d/cron/run` lines 14,
  45, 46
- `bricks/health-check/rootfs/usr/local/lib/gm/healthcheck` lines 11 to 18
- `bricks/health-check/brick.yaml` lines 84 to 90 (`healthcheck:`)
- `bricks/health-check/docs/gm.md` lines 147 to 151
- `specs/archive/v0.6/build-plan.md`, wave gate (every brick's stack test)
- v0.4 spec D305, v0.5 spec D356

---

## Change log

- **2026-11-16**: filed (v0.6 wave 1, from chunk 2's stack-test runs).
- **2026-11-16**: short-term fix applied in the stack test (78fe203,
  test-only): a bounded wait for the cron daemon before the report-only
  `gm-validate`; 3 consecutive green runs at the wave 1 gate. Status In
  Progress: the medium-term options (the validator's cron rule waiting,
  or the healthcheck covering cron) stay open for the brick's next version.
