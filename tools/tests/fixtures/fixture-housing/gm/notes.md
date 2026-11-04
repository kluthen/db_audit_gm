# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default. The fixture exists for
chunk 14's short test (`run-short-test.sh`), which never plants or checks
it. The record is `vet-core`'s and the wards `vet-housing`'s, both loaded
by `load-data` from the domains into `clinic`; their notes are
`domains/vet-core/docs/gm.md` and `domains/vet-housing/docs/gm.md`.
