# Brief

Hand-written, no initiator's brief: the v0.3 scenario of master spec
15.2 (normal difficulty), built in chunk 15a of the v0.3 build plan as
capture W4 item 10 of `specs/versions/v0.3/wave-log.md` proposes (spec
D188), for the owner's review at gate G7.

What 15.2 asks, as given there:

- one `postgres` database, PgBouncer in front of it, a producer (orders,
  ingestion, a nightly batch) and a consumer (reporting queries, an export
  job), Prometheus, the exporter and Grafana; single-host on armenelos,
  also deployed once across armenelos and the VPS;
- ten faults: six or seven of the new catalog faults, three or four
  existing ones that gain evidence under load (the missing join index,
  autovacuum off on a hot table, one monitoring fault), at least one
  `state` fault planted during the aging;
- write policies: the database and PgBouncer fixable; the scheduler nodes
  report-only, the producer's repository and both `jobs.yaml` fixable by
  override; Prometheus report-only, Grafana and the exporter fixable;
- aging minimum 16 hours, the hand-over in the customer's early
  afternoon; Prometheus' retention at least 20 hours.
