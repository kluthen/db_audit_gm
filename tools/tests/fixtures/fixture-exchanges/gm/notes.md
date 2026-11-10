# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default. The fixture exists for
chunk 19's short test (`run-short-test.sh`), which never plants or checks
it. The record is `vet-core`'s and the laboratory `vet-lab`'s, loaded by
`load-data` from the domains; the purposes are `vet-centre-exchanges` and
`vet-notifiable-diseases`, their notes `purposes/<id>/gm.md`; the other
centres' stub is `vet-core`'s (`domains/vet-core/docs/gm.md`), the
authority's purpose 5's.
