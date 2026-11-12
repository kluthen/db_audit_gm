# GM notes

`s10` (`pg-monitoring-option-absent`): `lab` does not choose the option
`monitoring`, so its cluster has no role `monitoring` and the exporter's
logins fail (`pg_up 0`). The game's `monitoring_password` still exists:
`postgres-exporter` declares it, so `gmctl deploy` generates it and
mounts it on `exporter` alone. Resolved by *report* or *propose*; the GM
applies an accepted proposal by creating the role on `lab` as the
option's initdb step does, with that password (the fault's `gm.md`). The
fixture exists for chunk 25's short test (`run-short-test.sh`).
