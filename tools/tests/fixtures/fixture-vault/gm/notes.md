# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default. The fixture exists for
chunk 21a's short test (`run-short-test.sh`), which never plants or checks
it.

The record is `vet-core`'s, loaded into `clinic` on `records`; the
machines' three databases are `vet-machinery`'s, loaded into `pacs`,
`vitals` and `biomed` on `machines`, its partition jobs in `jobs`, pg_cron's
database. Purpose 14 (`cold-storage-archive`, its `gm.md`) runs on
`interfaces`: `ship-partitions` ships each day partition of `mach_vitals`
and `mach_readings` older than the kept window to cold storage
(`partners/coldstore/` on the partners' `api` node and database, no back
end: its state stays at the planted baseline) and drops it on a full
receipt. Its history plants the vault's manifests of the days before the
window.

The test sets `window_days` to 0 in `mach_vitals_settings` (vitals) and
`mach_settings` (biomed), as `postgres`, after the load (spec D442): the
last full day then lies before the window and ships at the job's next
run, which the test moves to the minute after T0 (about 21:55 local).
