# purpose-etl-role-expired — GM notes

**What.** `shop_etl` is the agency's login on the shop's database: the
hourly script's source connection, and the remote role of the reporting
instance's one user mapping, through which the nightly close reads
`src.*` ([`shop-sales-reporting`](../../purposes/shop-sales-reporting/gm.md),
R4). Planted during the aging, on the source database node, the role is
given `VALID UNTIL` the planting moment (master spec 16.2): every
connection after it is refused at authentication, so every run of
either job fails, `rpt.etl_runs` stops, and the dashboards freeze. The
injection ([`inject/10-expire-role.sh`](inject/10-expire-role.sh)) also
ends the role's open sessions: PostgreSQL checks the expiry at
authentication only and the scheduler keeps its sessions between runs,
so without that the expiry would bite only at the next reconnection.

**Writing it into a scenario.**
- The node is the purpose's source database node (`db`), `postgres`
  0.4.0; the scenario names `shop-sales-reporting` in its `purposes:`.
  `plant_at: handover-5h` in the first v0.4 scenario (09:00 at a 14:00
  hand-over: "this morning").
- Parameters: `role` (`shop_etl`), `target` (`reporting/reporting`, the
  ledger's instance), `job` (`rollup-hourly`), the purpose's material
  names.
- The target's `pg_hba.conf` admits `gm_check` from the game network
  (every database node of a scenario with `governance:` does), and this
  node keeps the seed's logging (the check reads the log's `DETAIL`
  lines).
- Visibility: known (I5 in the first v0.4 scenario). Resolution `fix`:
  the database node is fixable.
- **Aging minimum (spec D189).** 1h from the hourly job's first run after
  planting; `plant_at: handover-<N>h` needs N at least that.

**Why it matters.** The back office decides on figures frozen since
morning; nothing on the agency's side alerts, the runs just fail.

**Why it happens.** A password policy applied to every login role
(`VALID UNTIL` set on all of them), a role created for a trial with an
expiry and forgotten, an audit's "every password must expire" taken
literally for service accounts.

**What a good answer says.** Follows the frozen dashboards to the
roll-up's failures (the runner's log, `rpt.etl_runs`), then to the
refused logins in `db`'s log and the role's `Password valid until` in
`\du`, notes the role is also the mapping's remote role (the close
fails too), and lifts the expiry.

**Fix path.** On `db` as `dba`: `ALTER ROLE shop_etl VALID UNTIL
'infinity'`. The next hourly run catches up (its watermark is from
before the expiry).

**Sealed check.** On `db`, as root; R4 cannot run there (it reads the
runner's log), so the check judges what the source node and the ledger
show (`judges: runs`). *Present* (1) while the role cannot log in now
(expired, `NOLOGIN` or gone); while more of its logins than the
threshold (0) were refused for an expired password since the judged
moment (its server log's `DETAIL` lines); or when no run of the job has
landed in `rpt.etl_runs` (read on the target with `check-psql --node`)
for 70 minutes since the judged moment. *Fixed* (0) once a run since the
judged moment is in the ledger, having read changed orders. *Too soon*
(3) in between, `remaining=` to the next hourly run counted from the
ledger's last start (an estimate: the check cannot read the runner's
`jobs.yaml`). The fix is made outside the runner, so no reload raises the
judged moment: after a hand-over, the refused runs of the game count
until the GM passes the fix's time, `gmctl check --since <the fix's UTC
time>` (master spec 12.1), as the purpose's notes say.
