# fx-ward (test domain)

A test part of the composed load fixture; not a game domain. Core keys used:
`core_stay`, `core_admitted`.
Its pg_cron job (`data/cron.sql`, chunk 29's (d)): `fx-ward-tidy`, `0 3 * * *`
in `clinic` as `ward_app`, the placements ended 30 days ago deleted.
