# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default. The fixture exists for the
v0.5 monitoring smoke run (`tools/tests/smoke-monitoring-v05.sh`), which
never plants or checks it.
