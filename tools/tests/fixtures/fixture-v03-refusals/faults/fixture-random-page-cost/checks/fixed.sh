#!/bin/sh
# Sealed check of fixture-random-page-cost: exit 0 once random_page_cost
# is below 4 in the effective live state, 1 while it is still 4 or more.
v=$(runuser -u postgres -- psql -XAtq -c "SHOW random_page_cost") || exit 2
if awk -v v="$v" 'BEGIN { exit !(v + 0 < 4) }'; then
  echo "random_page_cost is $v, below the spinning-disk default."
  exit 0
fi
echo "random_page_cost is still $v, the spinning-disk default."
exit 1
