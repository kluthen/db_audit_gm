# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default. It is there because a
scenario plants at least one fault.

The fixture exists to prove `gmctl load-data` on two instances: the psql
variables, a user mapping's password, the GM check role's read policy on
`pg_cron`'s tables and its mapping-roles function, `CONNECT` on every
database, a crontab role's password.
