# v0.3 — checks on a living system

Status: draft v2

Sealed checks, public validators and the smoke tests were built for a
still system: in v0.2 nothing ran between hand-over and the final answer
but the players. In v0.3 the load never stops (D117, D131), so a reading
drifts and jitters between two runs. This is v0.3's biggest technical
risk. Settled: the principles (D124) and the smoke tests with one full
aged run (D135); the exit code's value and the GM's own reserve are
(proposed).

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

## Principles (D124)

1. **Judge the cause, not the symptom**, wherever the cause is checkable:
   the index exists, the setting is in effect, the repository's query has
   its `WHERE`, the job's time is outside the peak, the consumer's
   connection pools. Such checks are as stable under load as in v0.2.
2. **A behavioural check judges a window**, when only behaviour shows the
   fault (dropped records, duplicates still arriving): over a trailing
   window stated in the answer key (e.g. the last 10 minutes), against a
   threshold with a margin, from a stable source: the scheduler's per-key
   counters ([scheduler.md](scheduler.md), "Its own monitoring"),
   cumulative PostgreSQL counters read twice, never a single sample.
3. **"Too soon to tell" is an answer.** When the window since the fix is
   shorter than the check needs, the check says so rather than guessing,
   with a new exit code (proposed: 3) beside 0 fixed, 1 present, any
   other an error ([format-changes.md](format-changes.md)). The GM then
   waits the stated window, or reports the fault as undetermined in its
   feedback.
4. **The GM's checks never pause the load**, not even after the final
   answer (D131): pausing would remove the very symptoms a check might
   read, and it is an event outside the schedule.
5. **The GM's checks keep a connection.** Producers and consumers connect
   as ordinary roles, so PostgreSQL's `superuser_reserved_connections`
   keep slots for superusers; the GM's checks connect as `postgres` over
   the local socket. The players' `dba` is a superuser too and shares
   those slots; a reserve of the GM's own is O100.
6. **Validators judge state.** Envelopes are state, unaffected. The
   "service healthy" rule must tolerate load: a refused connection under
   an exhaustion fault reads "unhealthy", which is then a red validator
   the answer key declares (D10).

## The smoke tests (D135)

- **Short runs.** The scenario smoke test runs the schedules for a few
  minutes, checks every fault "present" with polling and per-check
  timeouts, and checks the scheduler's keys are running. It checks that
  faults are planted, not their aged evidence. A fault planted during the
  aging (D127) is planted at once in a smoke run (proposed: the smoke
  test compresses the timeline, never a game).
- **One full aged run.** The release gate includes one full aged run, at
  least 48 hours, of the v0.3 scenario, played through as `player`: the
  evidence is there, the checks hold under load, the volumes grew as
  declared, a restart from the hand-over snapshot works (D135, D126).

## Open points

O100 (the GM's connection reserve).
