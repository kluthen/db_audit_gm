# Welcome

Nodes: `bastion` (you are here), `records` (PostgreSQL 19, the clinic's
medical record in the database `clinic`, the back office's in `office`),
`standby` (PostgreSQL 19, the record's read-only standby, where the reports
read), `lab` (PostgreSQL 19, the laboratory's database `lab`) and
`backoffice` (the back office's report runner). Reach each with
`ssh <node>`; reach the databases with `psql` from there.

The report runner's queries (`/srv/scheduler/repository/queries.yaml`)
and jobs are yours to fix. Jobs you may move (in
`/srv/scheduler/jobs/jobs.yaml`, then `sudo gm-reload-scheduler`), all on
`backoffice`: `feed-medicines-register`, `feed-controlled-drugs`,
`close-medicines-register`, `balance-controlled-drugs`,
`inventory-controlled-drugs`, `feed-antimicrobial-use`,
`report-antimicrobial-use`, `feed-working-time`, `close-working-time`,
`feed-daily-figures`, `send-monthly-figures`, `feed-lab-charges` and
`close-lab-statements`. There is no "run now": to see a job work after a
fix, move its time a few minutes ahead, reload, then put it back. A
feeder writes its day once.

DO NOT TAMPER: the lines `local all postgres peer`, `local replication
postgres peer` and `local all gm_check scram-sha-256` in
`/etc/postgresql/pg_hba.conf`.

Run each node's validator with `sudo /usr/local/sbin/gm-validate`.
Write your report in `~/report.md`.
