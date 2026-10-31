# GM notes

The fixture is v0.4's campaign topology (master spec 16.1) with nothing
wrong in it but `f0`, which is there because a scenario plants at least
one fault: on SSD storage a `random_page_cost` near 1.1 lets the planner
prefer index scans; 4.0 is the spinning-disk default.

Chunks 14 and 15 plant and check the faults of master spec 16.2 and 16.3
on scratch copies of it (capture W3-b item 6); chunk 16's scenario
copies its shape. Unfaulted, every purpose check reads 0 (or 3 where its
witness has not come yet: R1 and R3 until the next noon or night after
the judged moment), never 1.

- `db`'s crontab refreshes `popular_products` at minute 17 as
  `shop_refresh`, a light hourly entry on the shop's own instance, well
  placed and well privileged here.
- `reporting` preloads `pg_cron` and runs its cron daemon with nothing
  scheduled: f9's job and f10's entry are those faults' seed changes.
- `reporting` is left unscraped by design (`t1`, master spec 13.4).
- The data policy (`player/data-policy.md`) is correct: the back office
  (`shop_reports`) may read names and e-mail addresses in `shop`;
  personal and customer-linked data stay out of `reporting`.
