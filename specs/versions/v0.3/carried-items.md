# v0.3 — items carried in

Status: draft v2

Earlier rulings, known issues and open questions that land in v0.3.
v0.3 takes every item below (D140); the shapes are (proposed) until the
owner reviews this draft.

| Item | From | What v0.3 does | Cost |
|---|---|---|---|
| **Report-only monitoring nodes** | D108 | The renderer passes each node's write policy to its container, and `prometheus`, `postgres-exporter` and `grafana` honour it (seed files read-only for `player` on a report-only node, reload wrappers refused). Grafana's UI gap stays known (D94) | small to medium: three brick bumps, renderer |
| **`ALTER SYSTEM` on report-only databases** | O45, ruled D121 | Accepted on the trust line: nothing prevents it; the access model lists it as a known gap; sealed checks judge the effective live state as before | none in code; documentation |
| **`where` in `fault.yaml`** | O78, D140 | Option (b) in v0.3's format change: `fault.yaml`'s free text moves to `source`, its `where` takes the location set, `node` meaning the fault's target node. Which locations a fault may name: O101 | small: template, loader, the eleven catalog faults |
| **A player's `sed -i` leaves a config owned by `player`** | RG-2 (D112) | The reload wrappers restore owner and mode before reloading | small |
| **`gmctl status` says "handed over" for a tools password that does not exist** | RG-3 (D112) | No tools-password line without a web front (D103) | trivial |
| **Prometheus retention at least the aged history** | D114, D140 | Every scenario's retention covers its aging minimum plus four hours, unless a short retention is the planted fault; `fernway-clinics-monitoring` (`1d`) raised | trivial per scenario |
| **Game restart** | D110, D123, D126, O81 | [aging-and-timeline.md](aging-and-timeline.md), "Restart" | medium |
| **The format's aging items** | [formats.md](../../formats.md) | The fault definition's aging technique and minimum, and the scenario's aging plan, exist in the spec but not in the templates or the loader; v0.3 adds them ([format-changes.md](format-changes.md)) | small |

Not carried: brick options and the conditional `monitoring` role stay in
v0.5 (D107, D113).
