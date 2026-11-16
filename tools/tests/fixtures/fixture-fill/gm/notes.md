# GM notes

The fixture exists for the fill's short test (`run-short-test.sh`, v0.6
build plan chunk 8): the shop's virtual night and morning, 22:00 to 11:00
the customer's time, run in minutes by `gmctl fill`. Never a game.

`f8`: the shop's index on `order_lines.order_id` dropped at 08:00 the
customer's time (six hours before hand-over), planted by the fill at its
virtual instant. Order pages then read the whole table.
