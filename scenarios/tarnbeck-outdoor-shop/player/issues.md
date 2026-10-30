# Issues

Times are in Tarnbeck's time zone, {{customer_timezone}}.

1. **Lunchtime** (expected: fix). Every day around lunchtime checkout
   crawls: payments hang for seconds, and for a moment around noon
   nothing goes through at all. All through the busy hours the shop feels
   sluggish, yet the database server does not look busy. Find out why and
   fix it.

2. **Deliveries counted twice** (expected: fix). Our delivery counts
   don't match the carriers' invoices: some deliveries show up twice in
   our records, more of them every day. Find out why and make it stop.

3. **The accounting export** (expected: fix). The accounting export is
   meant to run every night at 2:00, so that our accountant finds it when
   she starts. She says it only arrives in the middle of the morning. Fix
   it.

4. **Order pages** (expected: fix). Since early this morning, opening an
   order (the customers' order pages, and the shop's own order screens)
   has been slower than it ever was. Find out what changed and fix it.

5. **The "best days" report** (expected: proposal). The back office's
   "best days" sales report gets slower every week, and the database
   works hard every time it runs. The back office is maintained by an
   agency, so do not change it yourselves: tell us what is wrong with the
   report and what the agency should change.

Anything else you find, in the database, around it or in the monitoring,
belongs in your report too.
