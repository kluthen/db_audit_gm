# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default.

`f2`: a lookup by `customer_id` without an index scans all of `orders`;
`CREATE INDEX ON orders (customer_id)` restores it, under any name.
