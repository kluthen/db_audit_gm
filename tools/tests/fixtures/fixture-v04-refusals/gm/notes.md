# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default.

`f2`: the hourly copy counts each order twice; its sealed check judges the
runs since the judged moment.
