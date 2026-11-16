# Story

Tarnbeck Outdoor sells camping and hiking gear online. Its web shop writes
into one PostgreSQL database through PgBouncer; its back office reads it
directly. The shop works in {{customer_timezone}} and watches the whole
with Prometheus and a PostgreSQL exporter.
