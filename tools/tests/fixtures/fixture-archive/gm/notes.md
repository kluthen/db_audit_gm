# GM notes

`f1`: the nightly base backup's log, `/var/log/postgresql/cron/basebackup.log`,
records each shipment's receipt, and nothing reads it: a failed backup
would go unnoticed until the vault's page shows the gap. Report only.

The fixture shows cold storage (`partners/coldstore/`) on the partners'
three shared nodes (`partners/shared/`): `records` archiving its WAL and
sending its base backup through `vault-post`, each shipment a manifest
in `partners-db`, the page and `GET /manifests`, and the five weeks of
planted `wal` and `basebackup` manifests before T0.
