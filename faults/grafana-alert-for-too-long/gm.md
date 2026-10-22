# grafana-alert-for-too-long — GM notes

**What.** One provisioned alert rule, `{RULE}` (`gm-service-down`,
"Service down on a node", in the v0.2 scenario), has a pending period
(`for`) of 2h instead of the companion's 1m. Its condition must hold for
two hours before it fires.

**Why it matters.** The rule looks right in every list: correct query,
correct threshold, state Normal. But an outage shorter than two hours,
which is nearly all of them, never raises the alert, and a longer one
raises it two hours late. A rule that cannot fire in time is no rule.

**Why it happens.** Someone raised `for` to silence a flapping alert
during maintenance and never put it back; minutes and hours confused when
the rule was written; a value copied from a slow-moving capacity alert.

**What a good answer says.** Reads the rule's pending period in the
alerting view (or the file, or the API), compares it with the other
rules' 1m and with the length of the incidents the rule is meant to catch,
and proposes a few minutes: long enough to ride out a service restart,
short enough to matter. Notes that provisioned rules cannot be edited in
Grafana's UI: the change goes into the file.

**Fix paths.**
- On the grafana node, as `player`: edit `for:` under `uid: {RULE}` in
  `/etc/grafana/provisioning/alerting/alert-rules.yaml`, then `sudo
  gm-reload-grafana` (it refuses a broken file with "NOT reloaded").
- Grafana's API (D94) also counts: the check reads Grafana's live state,
  not the file. A change made only through the API is lost at the next
  restart or wrapper reload, which re-provisions from the file; the
  validator's `pending` rule stays red until then.

**Sealed check.** On the grafana node as root, `/usr/local/lib/gm/grafana-api
GET /api/v1/provisioning/alert-rules/{RULE}` and `jq`, on the live state:
*present* while the rule is missing, paused, or its `for` exceeds
`max-for`; *fixed* when it exists, is not paused and its `for` is at most
`max-for`. Exit 2 when the helper exits 2 (Grafana not answering). A file
edited but not reloaded reads *present*. Deleting the rule is not a fix.
Grafana 13.2.4 returns the period as written in the file (`"for": "2h"`);
the check parses either that or Go's long form (`2h0m0s`).

**Placement (no masking).**
- Never `gm-target-down`: its firing is the evidence of
  `prometheus-node-health-node-missing`, which a 2h pending period would
  hide.
- With `prometheus-node-health-service-missing` on the database node: both
  weaken "an alert when the database's service stops" without hiding each
  other's evidence (this one is in the rule, that one in the node's
  service list). One issue may cover both; each is still a finding.

**Feedback points.** Reading an alert rule's timing, not only its query
and threshold; pending period versus evaluation interval; provisioned
configuration lives in files.
