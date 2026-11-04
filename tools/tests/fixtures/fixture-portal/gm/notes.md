# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default. The fixture exists for
chunk 16's short test (`run-short-test.sh`), which never plants or checks
it. The record is `vet-core`'s, the laboratory `vet-lab`'s and the owners'
portal `vet-portal`'s, loaded and derived by `load-data` from the domains;
their notes are `domains/vet-core/docs/gm.md`, `domains/vet-lab/docs/gm.md`
and `domains/vet-portal/docs/gm.md`. The owners' traffic is no third party:
it has no `partners.md` entry.
