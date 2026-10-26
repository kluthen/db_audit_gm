# GM notes

The fixture exists for the load smoke run (`tools/tests/smoke-load.sh`): a
few minutes of schedules, never a game.

`f1`: the producer's `refresh-stats` job reads the last hour's orders; once
an hour is enough, every minute only fills the scheduler's log. The fix is
the job's `at` in `/srv/scheduler/jobs/jobs.yaml`, which the producer's
write override makes fixable, then `sudo gm-reload-scheduler`. Its sealed
check reads "too soon to tell" for the answer key's window after the
reload.

`f2`: autovacuum turned off on `orders`, the table the producer writes,
planted four hours before hand-over (in the smoke run, at once with `gmctl
inject <scenario-dir> --playground <name> --at now --instance f2`). Dead
rows only build up from updates and deletes, which this load has none of;
the evidence is the table's options.
