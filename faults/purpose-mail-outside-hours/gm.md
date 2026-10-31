# purpose-mail-outside-hours — GM notes

**What.** The campaign may reach a recipient only within the sending
hours in their own zone, 08:00 to 21:00 their time
([`shop-customer-mailing`](../../purposes/shop-customer-mailing/gm.md),
M3). Planted at render, the scenario's `mail.campaign` reads the local
time in `business_settings.timezone`, the company's zone, instead of
`customers.timezone`
([`inject/queries.yaml.snippet`](inject/queries.yaml.snippet)). The job
runs only in the company's day (08:00 to 20:45), so the test always
passes: the company's day is the only filter, and one recipient in ten
lives eight hours behind or five ahead (the shop domain's zones), so
some are mailed at night in their time (master spec 16.2).

**Writing it into a scenario.**
- The node is the purpose's runner (`crm`), `scheduler` 0.2.0; the
  scenario names `shop-customer-mailing` in its `purposes:`. Paste the
  snippet in place of the purpose's `mail.campaign`. With
  `purpose-leads-stale-consent` on the same runner the entry carries both
  changes (the flag in place of the consent `LATERAL`, and this one's
  zone).
- Parameters: `source` (`db/shop`), `job` (`mail-campaign`), the
  purpose's material names.
- Visibility: known, with the complaint (I3 in the first v0.4 scenario,
  relative, never a city: the recipient's zone moves with the shift).
- **Shift invariance.** Every zone in the shop domain is an offset from
  the customer's, so the fault holds at any shift, 0 included.
- **Aging minimum (spec D189).** The definition's 1h counts from the
  campaign's first run after planting, its first batch of the company's
  day: raise the instance's `aging_minimum` to that run's offset from T0
  plus 1h. With T0 at 22:00 and the campaign from 08:00:
  `aging_minimum: 11h`. Before 16:00 company time the recipients eight
  hours behind are outside their hours (about one lead in twenty, so two
  or three a batch); from 16:00 those five hours ahead are.

**Why it matters.** Marketing mail at 3 a.m. is the complaint, a breach
of the company's own rule, and in several countries of the law on
unsolicited mail; the times look right to anyone reading them in the
company's zone.

**Why it happens.** A job written when every customer lived in the
company's zone; a "sending hours" rule implemented as the job's
schedule; the wrong zone column picked from a join.

**What a good answer says.** Reads the zone the hour test uses, finds
mail sent at night in the recipients' own time, and makes each batch
test each recipient's local time (`now() AT TIME ZONE c.timezone`), so
those outside their hours wait for the next batch.

**Fix path.** Edit `/srv/scheduler/repository/queries.yaml` on the
runner and `sudo gm-reload-scheduler`. Moving the job's times is not a
fix: some recipients are outside their hours at any company hour.

**Sealed check.** M3, adapted from the purpose's
`checks/m3-sending-hours.sh`; on the runner, as root, judging the
campaign's runs since `CHECK_SINCE` raised to the runner's last reload
(`judges: runs`). *Present* (1) while more marketing mails sent since
the judged moment than the threshold (0) fall outside their recipient's
hours, whether or not the job ran since; *too soon* (3) with no run
since, or no waiting lead with consent outside their hours at the latest
run (the witness: there is one all day once the leads are extracted);
*fixed* (0) within a quarter hour of a fix's reload, in the campaign's
day. Outside it (21:00 to 08:00 company time) the check reads 3 with
`remaining=` to the next morning's batch.
