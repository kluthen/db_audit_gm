# Issues

Three issues from Pages & Co. Each says what is expected of you:

- **report**: find the cause and explain it in your report;
- **propose**: find the cause and recommend a change, in your report,
  with the reason; you need not make it;
- **fix**: find the cause, make the change on `db`, check that it works,
  and say in your report what you did.

Beyond these, report anything else you find that puts the database or
the business at risk.

## I1 — Out-of-memory crashes during the month-end reports (fix)

> Since the move to the new server, the database has been killed twice
> for lack of memory while the month-end reports were running. The old
> server never did that. Please make it stop.

## I2 — Can anyone connect without a password? (propose)

> Our insurer's questionnaire asks whether anyone on our network can
> connect to the database without a password. We do not know what the
> contractor set up. Tell us how connections are authenticated today,
> and propose what it should be.

## I3 — Opening an order is slow (fix)

> Opening an order in the back office takes far longer than on the old
> server, and it gets worse as orders pile up. Please fix it.
