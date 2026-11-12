# GM notes

`f1`: on SSD storage a `random_page_cost` near 1.1 lets the planner prefer
index scans; 4.0 is the spinning-disk default. The fixture exists for
chunk 18b's short test (`run-short-test.sh`), which never plants or checks
it. The record is `vet-core`'s and the laboratory `vet-lab`'s, loaded by
`load-data` from the domains, the lab's two partners' stubs composed on the
partners' three nodes; the purposes are `vet-lab-practice-results` and
`vet-lab-send-outs`. Their notes are `domains/vet-core/docs/gm.md`,
`domains/vet-lab/docs/gm.md` and each purpose's `gm.md`.

`I1`, the false alarm fa (v0.5 master spec 17.2, chunk 22): "the external
lab is slow", the small-animal PCR panel back on its fourth day. No fault:
the panel's turnaround is 96 hours, and the one answered on its fourth day
after it was sent came back before its `lab_send_outs.due_by` (packed plus
50 minutes plus the turnaround). The answer key's `false_alarms:` entry
gives the query; `run-false-alarm-test.sh` reads it on the load (placing
one such panel if the load holds none) and the starter pack's issue. The
players report it as no fault, citing the turnaround; it counts in no
score.
