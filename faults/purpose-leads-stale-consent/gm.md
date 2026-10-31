# purpose-leads-stale-consent — GM notes

**What.** The company's rule is that consent is the latest
`marketing-email` event, never the opt-in flag
([`shop-winback-leads`](../../purposes/shop-winback-leads/gm.md), L2;
[`shop-customer-mailing`](../../purposes/shop-customer-mailing/gm.md),
M2). Planted at render on the runner, `leads.extract` and
`mail.campaign` test `customers.marketing_opt_in` instead
([`inject/queries.yaml.snippet`](inject/queries.yaml.snippet)). On its
own that changes nothing: the web shop wrote both places. The outside
party's behaviour makes it bite: a **web-shop release at T0** whose
unsubscribe link records the withdrawal in `consent_events` and no
longer clears the flag (master spec 16.2). From then on every customer
who unsubscribes stays flagged, so the extraction can take them and the
campaign mails them.

**Writing it into a scenario.**
- The node is the runner of both purposes (`crm`), `scheduler` 0.2.0;
  the scenario names `shop-winback-leads` and `shop-customer-mailing` in
  its `purposes:`. Paste the snippet's two entries in place of the
  purposes' own. With `purpose-mail-outside-hours` on the same runner,
  `mail.campaign` carries both changes: the flag here, the company's
  zone there.
- **The release (the timeline need).** The scenario writes
  [`inject/producer-release.yaml`](inject/producer-release.yaml) into
  the producer's files: the key `consent.unsubscribe-v2` beside the
  shop domain's `consent.unsubscribe` in its `queries.yaml`, and the
  timeline entry at `T0` in its `schedule.yaml`, switching the stream
  (known by its initial key) to it. The producer's repository is the
  players' to read (and, with its write override, to fix).
- Parameters: `source` (`db/shop`), `leads-job` (`leads-extract`),
  `mail-job` (`mail-campaign`), the purposes' material names.
- Visibility: known, with the complaint (I2 in the first v0.4 scenario,
  citing the data policy). Resolution `fix` needs the repository's write
  override on the runner; `improve` is the flags repaired.
- **Aging minimum (spec D189).** The definition's 1h counts from the
  campaign's first run after the release: raise the instance's
  `aging_minimum` to that run's offset from T0 plus 1h. With T0 at 22:00
  and the campaign from 08:00: `aging_minimum: 11h`. The leads' side
  shows earlier: the extraction's first run after T0 (at :20) takes the
  lapsed customers who withdrew since T0, about five in twenty minutes.
  The mail's side needs withdrawn leads among each batch's best 50: about
  15 lapsed withdrawals an hour against 4 000 leads, so by 08:00 a batch
  holds about two.

**Why it matters.** Mailing people who withdrew their consent is the
complaint and a breach of the data policy (and of the law the policy
states); the flag looks right to whoever reads only `customers`.

**Why it happens.** Two places for one fact: a release moved consent to
the history and dropped the flag's update, and the jobs written against
the flag were never told.

**What a good answer says.** Finds the jobs testing the flag, compares
the flag with the history (they disagree for everyone who unsubscribed
since T0), finds the release in the producer's repository and log, and
makes both jobs read the latest event, as the policy says; repairing the
flags and restoring their update in the web shop is the improvement.

**Fix path.** Edit `/srv/scheduler/repository/queries.yaml` on the
runner (both entries) and `sudo gm-reload-scheduler`. The producer path
(its `consent.unsubscribe-v2` clearing the flag again, through its own
repository override and reload) stops new drift but leaves the flags of
everyone who withdrew since T0: the jobs keep extracting and mailing
them until the flags are repaired, and the check keeps reading present.

**Sealed check.** L2 and M2 together, adapted from the purposes'
`checks/l2-consented.sh` and `checks/m2-consent.sh`; on the runner, as
root, judging both jobs' runs since `CHECK_SINCE` raised to the
runner's last reload (`judges: runs`). *Present* (1) while more leads
and campaign mails than the threshold (0), extracted or sent since the
judged moment, lacked consent by the latest event at their time and a
minute before. *Too soon* (3) until each job has a run since with a
witness: the campaign within a quarter hour in its day, the extraction
within the hour (`remaining=` the later). *Fixed* (0) then. Before the
hand-over (judged from T0) the leads extracted at T0's first run read
present; a fix confirmed in the game needs the next `:20`, or the job
moved.
