# purpose-mail-overlapping-window — GM notes

**What.** The customer mailing purpose's shipping notices
([`shop-customer-mailing`](../../purposes/shop-customer-mailing/gm.md),
M1): the job `mail-shipped` runs every five minutes and keeps no
watermark, so its window must match its cadence. Planted at render, the
scenario's `queries.yaml` gives `mail.shipped` a ten-minute window,
`[t − 11 min, t − 1 min)`: every shipped order falls in two runs'
windows and gets two `order-shipped` mails, five minutes apart (master
spec 16.2). The material is
[`inject/queries.yaml.snippet`](inject/queries.yaml.snippet), the entry
with an in-world comment ("wide enough that a late run misses
nothing").

**Writing it into a scenario.**
- The node is the purpose's runner (`crm` in the first v0.4 scenario),
  `scheduler` 0.2.0; the scenario names `shop-customer-mailing` in its
  `purposes:` (the loader does not check it). Paste the snippet in place
  of the purpose's `mail.shipped` entry; nothing else changes.
- Parameters: `source` (`db/shop`), where `mail_outbox` lives, and `job`
  (`mail-shipped`), the defaults being the purpose's material names.
- Visibility: known, with the complaint (I1 in the first v0.4 scenario).
  Resolution `fix` needs the repository's write override
  (`/srv/scheduler/repository`).
- **Aging minimum.** 1h from the job's first run after planting, which
  is T0's next five minutes: no raise is needed above any scenario's
  floor. Orders ship day and night (the shop domain's `orders.status`),
  but an order ships on its second status update, so shipping ramps up
  after the load: on armenelos at 09:21 company time the first notices
  went at T0 + 14 minutes and the first duplicates at T0 + 19; at night,
  with a third of the rate, allow the hour.
- Answer-key extras: the `mail_outbox` query of the evidence, and the
  log's `rows=` against the shipments of five minutes (`SELECT count(*)
  FROM orders WHERE shipped_at > now() - interval '5 minutes'`).

**Why it matters.** Customers are mailed twice for every order: noise,
complaints, a provider's quota spent twice, and a reputation for spam.
The same pattern on a pushed obligation would declare twice.

**Why it happens.** A window widened "to be safe" after a late run once
lost a notice; a cadence changed without its query; a job copied from a
ten-minute one.

**What a good answer says.** Reads the job's cadence beside the query's
window, finds the duplicates in `mail_outbox`, and makes the job pick
what was not sent yet: the window back to five minutes, or better a
`NOT EXISTS` on `mail_outbox` for the order and template, which holds
whatever the cadence; a unique `(order_id, template)` with `ON CONFLICT
DO NOTHING` as the database's guard (a unique index alone makes every
overlapping run fail, and then no notice goes at all).

**Fix path.** Edit `/srv/scheduler/repository/queries.yaml` and run
`sudo gm-reload-scheduler`. Moving the job's time (`jobs.yaml`) is the
players' lever for a quick confirmation.

**Sealed check.** M1 narrowed to the notices, adapted from the
purpose's `checks/m1-no-duplicate.sh`; on the runner, as root, judging
the job's runs since `CHECK_SINCE` raised to the runner's last reload
(`judges: runs`). *Present* (1) while more orders than the threshold
(0) have two notices, one sent since the judged moment, whether or not
the job ran since; *too soon* (3) with no run since, or no notice sent
in the half hour before the latest run (the witness); *fixed* (0) once a
run since is clean with a witness: within five minutes of a fix's
reload, day or night. Duplicates sent before the judged moment stay in
`mail_outbox` as evidence and never count.
