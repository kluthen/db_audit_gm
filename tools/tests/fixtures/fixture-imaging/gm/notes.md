# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default. The fixture exists for
chunk 15b's short test (`run-short-test.sh`), which never plants or checks
it. The record is `vet-core`'s, loaded into `clinic` on `records`; the
machines' three databases are `vet-machinery`'s, loaded into `pacs`,
`vitals` and `biomed` on `machines`, its partition jobs in `jobs`, pg_cron's
database. Their notes are `domains/vet-core/docs/gm.md` and
`domains/vet-machinery/docs/gm.md`. `interfaces` stands idle until chunk 21
adds the imaging-orders purpose: until then the worklist gains entries only
from the short test's plants.
