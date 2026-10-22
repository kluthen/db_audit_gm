# GM notes — fernway-clinics-monitoring

Sealed. Longer explanations for the feedback; the authoritative answer is
`answer-key.yaml`, and each fault's own `gm.md` (under `faults/`) has the
general background and the placement rules.

## The shape of the game

A partly tooled customer (master spec 11.1): monitoring present and
ill-configured, one need left uncovered. Eight defects on four nodes, all
visible without any activity; one silent tooling expectation.

| Instance | Defect | Node | Visibility | Issue |
|---|---|---|---|---|
| f1 | `grafana:9110` missing from Prometheus' node-health job | prometheus | known | I1 (fix) |
| f2 | no node-health script on `exporter` (target down, alert firing) | prometheus (map) | hidden | — |
| f3 | `postgres` missing from `db`'s node-health service list | prometheus (map) | known | I2 (propose) |
| f4 | `pg_stat_statements` not preloaded | db | known | I3 (fix) |
| f5 | "Service down on a node" waits 2h | grafana | known | I2 (propose) |
| f6 | `trust` for every remote address in `pg_hba.conf` | db | hidden | — |
| f7 | `clinic_app` is a superuser | db | hidden | — |
| f8 | autovacuum off on `appointments` | db | hidden | — |
| t1 | no log analysis (tooling expectation) | — | silent | — |

The story hints at each hidden item without naming it: an alert "red since
April, a leftover" (f2); access "opened up" for the monitoring set-up
(f6); an agency-built site with its own login (f7); a table changing all
day (f8); log files nobody opens and a May crash nobody explained (t1).
The comment on `pg_hba.conf`'s trust line and on the commented-out preload
line are on the nodes, where a careful team reads them.

Starved tools: f1 and f4 (Prometheus never asks grafana; the server never
collects statement statistics). f2 and f3 are the node-health faults:
report or propose only, the script and its list being mounted read-only.
Every validator is green at hand-over; nothing leaves one red.

## Times

History starts at deployment: the dashboards are thin for the first 10 to
15 minutes. From the end of the deployment: `exporter:9110` down at the
first scrape (under 30 s); "Scrape target down" pending at about 1 minute
and firing at about 2 minutes (f2); the `stat_statements` collector at 0
and `db`'s services `sshd` only from the first scrape. After a fix: f4 and
f5 read fixed at once, f1 after the next scrape (15 to 30 s; run the check
a little after the player's reload); the statement panels fill about 70 s
after `gm-restart-db`.

## Feedback points

- **I1 (f1).** The point is the difference between a target *absent*
  (silence: nothing says a node is missing) and a target *down* (f2,
  which shouts). The best teams compare the targets page with the
  topology (five nodes, four node-health targets), show from the
  prometheus node that `grafana:9110` answers, add the target and reload,
  then check the targets page and the dashboard. A team that also finds
  f2 while doing this has read the targets page properly; credit it as a
  hidden finding.
- **I2 (f3, f5).** Two independent reasons, each enough on its own: the
  node-health script on `db` does not watch `postgres` (no series, so
  nothing to go to 0), and the rule would wait two hours anyway (the
  outage lasted 90 minutes). A team naming only one has half the answer:
  say which half is missing. f3 cannot be fixed by the players (proposal:
  add `postgres` to `db`'s list, redeploy); f5 can, and fixing it as well
  as proposing is fine. A strong answer also proposes an
  application-level alert, and reads the story's clue: "Exporter
  disconnected from PostgreSQL" (on `pg_up`, `for: 1m`) did fire during
  the outage, since the exporter loses its connection when PostgreSQL
  stops; it was the database outage signal, misread as a monitoring
  problem (worth a clearer name or description, or a runbook line on the
  reception screen). Notification: alerts are read on the reception screen by design
  (the brick sends nothing); a team proposing e-mail or chat notification
  makes a good extra point, not the expected answer.
- **I3 (f4).** Connect the empty panels to the cause, not to a broken
  dashboard: the exporter is connected (`pg_up` 1) while one collector
  fails. A reload is not enough; credit a team that says the restart drops
  every connection and should be planned. The comment ("off while chasing
  the May crash; to put back") is part of the story: the crash had
  nothing to do with the extension, and nobody put it back.
- **f2.** "An alert that always fires is still an alert." Removing
  `exporter:9110` from the targets to silence it is hiding the problem,
  not fixing it; say so if a team did it.
- **f6.** The trust line was "temporary" for the monitoring set-up; the
  monitoring role has had its own `scram-sha-256` line ever since, so
  removing the trust line breaks nothing. A fix that also removes or
  narrows the `monitoring` `samenet` line disconnects the exporter
  (`pg_up` 0, PostgreSQL panels empty, "Exporter disconnected from
  PostgreSQL" firing): the sealed check reads fixed, but judge the fix as
  breaking the monitoring. The best teams test both sides: a
  password-less login fails, `pg_up` stays 1.
- **f7.** Removing the attribute is enough: the role already holds its
  grants (data file). Dropping it or its grants breaks the booking site.
- **f8.** Easy to miss because `SHOW autovacuum` says on and the
  validator is green. A manual `VACUUM` is a catch-up, not a fix.
- **t1 (tooling expectation).** Fernway logs a great deal (slow statements
  over 100 ms, connections, lock waits, checkpoints, autovacuum) to files
  on `db`, and nothing reads them: the monitoring is metrics only. Expect
  a proportionate proposal: a scheduled pgBadger report someone reads, or
  shipping the log into the Grafana they already run (Loki). Running
  pgBadger during the game is the players' kit at work, not the
  customer's tooling: it demonstrates the need, it does not meet it. Not
  covered by any issue; judge it in feedback.

## Interactions

None in the strict sense (no instance hides another's evidence); the
placement follows each fault's `gm.md`:

- f1, f2 and f3 are on three different nodes (grafana, exporter, db): f2
  keeps its target, so its alert fires; f3's dashboard and Prometheus
  evidence stay, `db` being scraped.
- f1 leaves `exporter:9187` in place, so f4's collector failure shows.
- f5 is on `gm-service-down`, never `gm-target-down`, whose firing is f2's
  evidence.
- f3 and f5 both silence "Service down on a node" for `db`'s PostgreSQL
  without hiding each other's evidence; I2 covers both.
- f6 makes f7 worse in principle (password-less logins as `clinic_app`),
  but with `trust` anyone can already log in as `dba`, so it changes
  nothing in practice.

## After the game

The `clinic_app` password is in `data/db.sql` (GM side). The players do
not need it: they work as `dba`, and `SET ROLE clinic_app` tests the
site's rights. Release gate item 6 (a *fix* issue on a monitoring tool
going from 1 to 0) is I1 (f1); f5 can serve as a second one when a team
fixes it.
