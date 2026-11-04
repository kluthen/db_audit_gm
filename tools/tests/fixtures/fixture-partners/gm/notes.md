# GM notes

`f1`: Alpha Laboratories answers its status four seconds late from T0,
its misbehaviour key `alpha.slow` placed standing (the back end's
timeline changes `alpha.normal` to it at T0). Beta keeps answering in
time: the partners share one `api` node, and one partner's slow answers
never hold another's (each request in its own worker thread, each
partner's pool its own).

The fixture shows the partners' three shared nodes (`partners/shared/`):
the hostnames as network aliases, each partner's role and schema on
`partners-db`, whose `pg_hba.conf` admits only the partners' roles on
their database, and the back end's ticks behind `partners_backend`.
