> **Archived 2026-11-14.** v0.5 closed (released at its release gate, G15 cleared by the owner on 2026-11-14, merged into `main`); entries D306 to D309 of the decisions log, verbatim. Live summary: [where it now lives](README.md#where-it-now-lives). Relative links were written from `specs/`; links to the build plan archived in the same pass were repaired to its archived path (`archive/v0.5/build-plan.md`), still written from `specs/`.

- **D306 (2026-11-02, owner answer "agreed", relayed by the coordinator):
  `vet-core`'s and `vet-lab`'s purposes (step 7) are ruled as drafted,
  all eight points:** the ten purposes built in v0.5 (the release to the
  portal waits for `vet-portal`, the electronic referral report later);
  the `interfaces` and `backoffice` scheduler nodes and the critical
  calls on the lab's `pg_cron`; results polled from a released-results
  feed on `lab-api` every 5 minutes with a watermark, the lab never
  writing `clinic`; `office_jobs` writing `office` only, the reports
  reading as `vet_reports` and `lab_reports` (settling replication.md's
  name); `exchanges` and its streams and endpoints under `vet_exchange`,
  amending vet-core steps 4 and 6; rare-flow faults only with a story
  raising the rate from T0 in the profile layer; one notification
  purpose, `diagnosis_codes.notifiable` none/A/other, the lab's
  deadlines for the vet's; the game values; and vet-lab's two asks (the
  feed on `lab-api`, `resend` on the external lab's stub). Closes O155.
  Now in: [versions/v0.5/clinic-purposes.md](versions/v0.5/clinic-purposes.md#points-for-the-owner-ruled-d306).
- **D307 (2026-11-02, same answer): The purpose format's extensions are
  accepted as listed** in clinic-purposes.md section 4 (the round-trip
  block, the `api` and `partner` parts, HTTP connections, endpoint and
  receiver material, periodic jobs with feeder and planted history,
  `judged:`, the classes of a purpose's tables, the `ops` schema); they
  feed O111. Closes O156. Now in:
  [versions/v0.5/clinic-purposes.md](versions/v0.5/clinic-purposes.md#4-the-format-and-what-the-round-trip-extends-ruled-d307).
- **D308 (2026-11-02, owner ruling, relayed by the coordinator): The
  partners' stubs are grouped on one `api` node,** each partner under
  its own hostname through network aliases, so players still see
  distinct partners; with the shared scheduler and database, three
  partner nodes instead of eleven. Per partner still: its routes, its
  `partners.md` entry, its misbehaviour keys, and for cold storage alone
  the bastion's route to its page (D296). The owner: "Indeed partners
  can be grouped for ease of usage." Amends D293's node count. Now in:
  [versions/v0.5/one-centre.md](versions/v0.5/one-centre.md#4-the-partners-nodes-d293-d308),
  [versions/v0.5/third-parties.md](versions/v0.5/third-parties.md) 3.
- **D309 (2026-11-02, owner ruling, relayed by the coordinator):
  Selecting a scenario's faults is the GM's role,** at deploy, with
  whoever sets up the game; a domain's step 8 lists the traps with their
  D290 classes and stops there. Amends D233's "the owner joins when he
  defines faults" and the procedure's step 8 owner column; D290's cap
  and mix still bind any selection. The spec picks a test selection for
  the build's smoke run and the proof in play, a fixture, not the
  canonical scenario. The owner: "selecting the faults is the GM's role
  (with the assistance of the person that setup the game)". Now in:
  [versions/v0.5/domain-procedure.md](versions/v0.5/domain-procedure.md#2-the-steps-from-a-brief-to-a-finished-domain),
  [bricks-and-faults.md](bricks-and-faults.md).
