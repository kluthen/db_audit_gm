# purpose-receiver-down-unnoticed — GM notes

**What.** Every export declaration must be acknowledged by the customs
gateway within 30 minutes, or become an incident for the shipping
manager by the next escalation run
([`shop-export-declarations`](../../purposes/shop-export-declarations/gm.md),
E4; spec D228). Planted at render on the runner, `escalate.customs`
escalates rejections only
([`inject/queries.yaml.snippet`](inject/queries.yaml.snippet)): an
unanswered declaration is never raised. The outside party's behaviour
makes it show: the **gateway's two-hour outage** during the aging, a
timeline change of the receiver's schedule that switches its stream to a
key answering nothing and back (master spec 16.2). The gateway also
never answers about one declaration in fifty, as standing behaviour
(10.4), so unescalated declarations keep piling up in the game.

**Writing it into a scenario.**
- The node is the purpose's runner (`crm`), `scheduler` 0.2.0; the
  scenario names `shop-export-declarations` in its `purposes:`. Paste
  the snippet in place of the purpose's `escalate.customs`.
- **The outage (the timeline need).** The scenario writes
  [`inject/gateway-outage.yaml`](inject/gateway-outage.yaml) into the
  receiver's files: the key `customs.unavailable` beside
  `customs.acknowledge` in its `queries.yaml`, and the two timeline
  entries in its `schedule.yaml`, two hours apart, at hours when exports
  are packed (the material's `handover-6h` to `handover-4h`, 08:00 to
  10:00 at a 14:00 hand-over; the night packs about one export a quarter
  hour, the morning more).
- Parameter: `source` (`db/shop`), the purpose's material name.
- Visibility: hidden in the first v0.4 scenario. Resolution `fix` needs
  the repository's write override on the runner.
- **Aging minimum.** 1h from the outage's start (a timeline change counts
  from its moment, 16.2): raise the instance's `aging_minimum` to the
  outage's offset from T0 plus 1h. With the material's hours and T0 at
  22:00: `aging_minimum: 11h`. The first declarations of the outage pass
  their deadline 47 minutes after it starts (30 minutes, one 15-minute
  escalation cycle, two minutes' grace).

**Why it matters.** Unacknowledged declarations are goods that may be
held at the border; the company learns of it from the carrier or the
customer, days later. Silence is the failure an escalation exists for.

**Why it happens.** An escalation written against the gateway's error
messages only (a rejection is visible, a silence is not); a timeout
handled "later"; a receiver that answered reliably for months.

**What a good answer says.** Finds the two hours of declarations with
neither answer nor incident (and the stub's steady few), reads the
escalation's SQL, and adds the missing rule: no acknowledgement 30
minutes after sending is an incident; raising the ones missed since is a
good follow-up.

**Fix path.** Edit `/srv/scheduler/repository/queries.yaml` on the
runner and `sudo gm-reload-scheduler`. The escalation looks back a day,
so its next run also raises everything missed since (late incidents,
before the judged moment: not counted).

**Sealed check.** E4, adapted from the purpose's
`checks/e4-acknowledged-or-escalated.sh` with the source as a parameter;
on the runner, as root, judging the declarations sent since
`CHECK_SINCE` raised to the runner's last reload (`judges: triggers`,
12.4). *Present* (1) while more of them than the threshold (0) are past
their deadline with no incident in time; *fixed* (0) once every one
sent two escalation cycles ago or more was handled and one of them was
escalated (the witness: an unanswered or rejected one); *too soon* (3)
otherwise, `remaining=` to the oldest pending deadline. After a fix in
the game, 0 waits for the gateway to leave one declaration unanswered
(about every 25 minutes at the afternoon's export rate) and its incident
45 minutes later: an hour or two.
