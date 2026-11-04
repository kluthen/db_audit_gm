# GM notes

The fixture exists for the loader's v0.5 refusals (`tools/tests/test_model.py`,
build plan chunk 6): never deployed, never a game.

`f1`: the producer's `refresh-stats` job reads the last hour's orders; once
an hour is enough, every minute only fills the scheduler's log. The fix is
the job's `at` in `/srv/scheduler/jobs/jobs.yaml`, then `sudo
gm-reload-scheduler`.

`f2`: autovacuum turned off on `orders`, planted four hours before hand-over.
