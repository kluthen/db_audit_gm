# GM notes

`f1`: a physical replication slot, `old_reports`, left on `records` by a
reporting replica switched off long ago, inactive beside the standby's own
slot, `standby`, which is active. Every WAL segment since its restart_lsn
is kept. Report it; dropping it is the fix.

The fixture shows the restart from the hand-over snapshot giving back
replication (v0.5 master spec 15, "The restore from the hand-over
snapshot"; spec D397): the standby held as one and cloned again from its
restored primary, the planted slot re-created, and `records` archiving to
cold storage (`partners/coldstore/` on the partners' `api` node and
database, no back end: its state stays at the planted baseline).
