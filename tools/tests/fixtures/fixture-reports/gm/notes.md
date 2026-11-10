# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default. The fixture exists for
chunk 20's short test (`run-short-test.sh`), which never plants or checks
it. The record is `vet-core`'s, with `vet-housing` and `vet-scheduling`,
read by the reports on its standby `standby`; the laboratory `vet-lab`'s;
both loaded by `load-data` from the domains. The purposes are
`vet-medicines-registers`, `vet-antimicrobial-use` and `vet-working-time`,
their notes `purposes/<id>/gm.md`; the authority's stub is purpose 5's,
with purpose 8's route.
