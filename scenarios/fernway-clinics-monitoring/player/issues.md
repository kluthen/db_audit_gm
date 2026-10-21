# Issues

Three issues from Fernway. Each says what is expected of you:

- **report**: find the cause and explain it in your report;
- **propose**: find the cause and recommend a change, in your report,
  with the reason; you need not make it;
- **fix**: find the cause, make the change, check that it works, and say
  in your report what you did.

Beyond these, report anything else you find that puts the clinics'
database, their monitoring or the business at risk.

## I1 — Grafana's machine restarted and nothing showed it (fix)

> In September the machine that runs Grafana restarted by itself, twice
> in one week; we only knew because the dashboards went blank for a
> minute. The node-health dashboard, which we were told shows every
> machine, never showed anything about it. Please find out why, and fix
> it.

## I2 — No alert when the database stopped (propose)

> On a Tuesday afternoon in October the database stopped for about an
> hour and a half and nobody could book. On the reception screen,
> "Service down on a node", which is there for exactly that, never
> fired; only "Exporter disconnected from PostgreSQL" came up, and we
> took it for a problem with the monitoring. Tell us why the service
> alert stayed silent, and propose what to change so that the next
> outage is caught.

## I3 — The costliest-queries panels are empty (fix)

> On Monday mornings booking gets slow. The PostgreSQL dashboard has
> panels for the costliest queries, but they have said "No data" since
> May. We would like to see which queries cost the most. Please make
> those panels work.
