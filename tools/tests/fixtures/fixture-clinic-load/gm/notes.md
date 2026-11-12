# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default. The fixture exists for wave
3's gate (spec D407), whose short test (`run-short-test.sh`) loads the six
clinic domains and never plants or checks it. The record is `vet-core`'s,
the wards `vet-housing`'s, the agenda `vet-scheduling`'s, the laboratory
`vet-lab`'s, the machines' systems `vet-machinery`'s and the owners' portal
`vet-portal`'s, loaded and derived by `load-data` from the domains; their
notes are each domain's `docs/gm.md`. Every producer is left out
(`composition.yaml`): no application runs, so nothing ages. The owners'
traffic is no third party: it has no `partners.md` entry.

Since chunk 27 it carries `aldermoor-centre`'s governance (its classes and
locations, the classification copy, the data policy on the bastion; the
readers its purposes alone create left out, no purpose here) and the
scenario's records data file (the back office's `office`), so the short
test runs the governance check set unfaulted: G1 to G4 on `records`, `lab`
and `machines`; `partners-db`, a third party's node, is never walked (spec
D469). The standby and the transformers are not here (O250, a v0.5 known
limit).
