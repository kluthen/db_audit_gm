# scheduler-display-refresh-loop — GM notes

**What.** The ward service, `ward`, serves the wards' 64 displays, each
reading its unit's row of the board once a minute through one statement,
`ward.board` (vet-housing, [`docs/gm.md`](../../domains/vet-housing/docs/gm.md),
"D287 applied: finding a faulty display"). Planted at render, one
display's firmware loops: a key `ward.board-loop` whose SQL is
`ward.board`'s byte for byte with the unit fixed
([`inject/queries.yaml.snippet`](inject/queries.yaml.snippet)), read by a
stream on the displays' connection `ward-board` at about once a second
([`inject/schedule.yaml.snippet`](inject/schedule.yaml.snippet)). The
board statement's calls go from about 64 a minute to about 124, one
queryid, below what saturates the ward's pool of four (T150; class M in
the clinic). Many small consumers behind one service: the excess is one
consumer's, and the players find which.

**Writing it into a scenario.**
- The node is the ward service (`ward`), `scheduler` 0.3.0, composed from
  vet-housing's `producers/ward/`. The two seed changes go in the
  scenario layer `compose/ward/` (`queries.yaml`, a new file;
  `schedule.yaml`, the stream beside the layer's `intensity`), then
  `gmctl compose`; never in `nodes/ward/` (capture W5 item 0).
- Parameters: `unit` (required: one with a display, `housing_displays`
  without `removed_on`, and occupied at T0 so the chain reaches an
  animal; units 7 and 41 have had two displays, the older removed),
  `rate` (`3600/h`), `db_node` (`records`), `database` (`clinic`). The
  snippets' `{UNIT}` and `{RATE}` are the instance's values.
- The answer key's `sealed_check`: `window` the check's sampling time
  (`1m`: it reads `pg_stat_statements` twice that far apart and sleeps
  in between), `threshold` the displays' calls a minute and a margin (64
  at the ward's intensity 1.0: `80`). At another `ward` intensity the
  displays refresh faster or slower (vet-housing, D32): scale both.
- Resolution `report` only, under every write policy; never clear it in
  play (master spec 6.3, 17.2). Judged at the final answer on the report
  alone: the unit, its display's serial and the animal named, the excess
  shown, no instance-wide logging left behind. The feedback says the
  technician would replace the display.
- **With `governance-statement-log-personal` (s7) planted**:
  `log_statement = 'all'` already logs the board's parameter, so the
  careful step (logging for `vet_display` alone) is unneeded while it
  stands; "no instance-wide logging left behind" is met by s7's fix. Say
  so in both instances' `interactions:`.

**Why it matters.** Each read is cheap; a display reading sixty times a
minute doubles the wards' load on the record for nothing, and the next
faulty display adds its own. Finding it means walking from a statement to
a box on a wall.

**Why it happens.** A display's refresh timer resets to zero after a
firmware update; nothing on the service side caps a client's rate.

**What a good answer says.** Shows the board statement's calls a minute
against the displays' one each, ties them to `ward` and `vet_display`,
logs the parameter for `vet_display` alone (never instance-wide: the
practice software's statements carry owners' names and phones, T1) and
resets the setting after, names the unit, its display's serial, the stay
and the animal, and asks for the display to be replaced.

**Clearing it (tests only, never in play).** Remove the stream: the
fixture's or scenario's unfaulted `schedule.yaml` (and `queries.yaml`)
written into the live repository `/srv/scheduler/repository/` as root and
the scheduler reloaded through s6 (`s6-svc -h /run/service/scheduler`, as
`gm-reload-scheduler`'s step 4 does; `schedule.yaml` is never the
players'); or `ward` redeployed from the recomposed layer. The calls fall
back to about 64 a minute within a minute.

**Sealed check.** On `ward`, as root, through `check-sql` as `gm_check`
to `{db_node}`'s database `postgres`: the board statement's calls in
`{database}` read twice, `window` apart, as calls a minute. *Present* (1)
above `threshold`, *fixed* (0) at or below it, *too soon* (3) when the
statistics were reset between the reads. A behavioural reading of the
effect, never of the planted key: it reads the same whichever display
loops.
