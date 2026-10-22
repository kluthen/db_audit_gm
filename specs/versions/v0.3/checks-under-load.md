# v0.3 — checks on a living system

Status: draft v1

Sealed checks, public validators and the smoke tests were built for a
still system: in v0.2 nothing ran between hand-over and the final answer
but the players. In v0.3 the load never stops (D117), so a reading
drifts and jitters between two runs. This is v0.3's biggest technical
risk. Everything here is (proposed); the question is O82.

## What changes

- **Symptoms move.** Lock waits come and go with the traffic shape; bloat
  regrows after a `VACUUM FULL` if its cause stays; a latency is lower at
  night than at noon.
- **Readings lag.** Counters (`pg_stat_*`, Prometheus) describe a window,
  not a moment; a check right after a fix still sees the old window.
- **Connections compete.** Under a connection-exhaustion fault, a
  validator or sealed check connecting to PostgreSQL may itself be
  refused.
- **The smoke tests** cannot wait two days, and the scenario smoke test
  today expects every sealed check at "present" within 120 s of the
  injection (`tools/tests/smoke-scenario.sh`).

## Principles (proposed)

1. **Judge the cause, not the symptom**, wherever the cause is checkable:
   the index exists, the setting is in effect, the repository's query has
   its `WHERE`, the job's time is outside the peak, the consumer's
   connection pools. Such checks are as stable under load as in v0.2.
2. **A behavioural check judges a window**, when only behaviour shows the
   fault (dropped records, a client still leaking connections): over a
   trailing window stated in the answer key (e.g. the last 10 minutes),
   against a threshold with a margin, from a stable source: the
   scheduler's own counters ([scheduler.md](scheduler.md), "Its own
   monitoring"), cumulative PostgreSQL counters read twice, never a single
   sample.
3. **"Too soon to tell" is an answer.** When the window since the fix is
   shorter than the check needs, the check says so rather than guessing:
   a new exit code (e.g. 3, "undetermined") beside 0 fixed, 1 present, any
   other an error ([formats.md](../../formats.md), "Script contracts").
   The GM then waits the stated window, or reports the fault as
   undetermined in its feedback.
4. **The GM's checks never pause the load.** Not even after the final
   answer (O88): pausing would remove the very symptoms a check might
   read, and it is an event outside the schedule.
5. **The GM's checks always get in.** Producers and consumers connect as
   ordinary roles, so PostgreSQL's `superuser_reserved_connections` keep
   slots for superusers; the GM's checks connect as `postgres` over the
   local socket. The players' `dba` is a superuser too and shares those
   slots; a dedicated reserve for the GM (`reserved_connections` with
   `pg_use_reserved_connections`, PostgreSQL 16+) would hold even then,
   at the cost of a setting the players could edit in a fixable node's
   configuration (to settle).
6. **Validators judge state.** Envelopes are state, unaffected. The
   "service healthy" rule must tolerate load: a refused connection under
   an exhaustion fault reads "unhealthy", which is then a red validator
   the answer key declares (D10).

## The smoke tests

- **Short runs.** The scenario smoke test runs the schedules for a few
  minutes, checks every fault "present" with polling and per-check
  timeouts, and checks the scheduler's keys are running. It checks that
  faults are planted, not their aged evidence.
- **One full aged run.** At least once before the release gate, the v0.3
  scenario ages for its full minimum and is played through as `player`:
  the evidence is there, the checks hold under load, the volumes grew as
  declared (O92).

## Open points

O82 (the principles above, and the new exit code), O88 (no pause), O92
(the full aged run before release).
