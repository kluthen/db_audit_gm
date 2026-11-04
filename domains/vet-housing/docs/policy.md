# Aldermoor Veterinary Hospitals: the wards' rules

The default policy of the centre's wards (v0.5 master spec 9.5, "Roles,
classification, rules"; vet-housing-domain.md, "The rules", ruled D318),
beside the medical record's eleven rules (vet-core `docs/policy.md`). The
GM copies it into a scenario's `player/data-policy.md` with the core's and
adapts it there, with the `governance:` fragment beside it
(`data/governance.yaml`). The centre sits in an unnamed EU member state:
EU law applies as written; a figure marked *game value* is the clinic's
choice, not the law.

1. **The board's least data.** A unit's display shows the animal's name,
   species, breed, sex and age, its alerts, the stay's reason, its plan
   and the day's doses and care; never the owner, a contact or a natural
   identifier (the record's rule 10). Its notes are working notes, never
   an owner's name.
2. **Biosecurity.** An animal with a current infectious alert is housed in
   an isolation unit, moved there when the alert comes during its stay,
   as soon as one is free; an isolation unit's occupant never shares the
   ward's ordinary units; every emptied unit is mucked out and
   disinfected before the next animal, an isolation unit always
   (Regulation (EU) 2016/429, Art 10, the operator's biosecurity; the
   clinic's rule).
3. **Nil by mouth.** A vet's nil-by-mouth order is on the board from its
   start; no feeding is recorded while it is in force (*game value*: from
   eight hours before an anaesthetic for a dog, a cat or a small animal,
   twelve for a horse or a ruminant).
4. **Checks and feeding.** Every hospitalised animal is checked at least
   every four hours, around the clock, and fed by its plan at its
   species' rounds: horses at 06:00, 12:00, 17:00 and 21:00; cattle,
   sheep and goats at 07:00 and 16:00; dogs at 08:00 and 17:00; cats and
   small animals at 08:00, 13:00 and 18:00 (*game values*; Council
   Directive 98/58/EC's daily inspection the legal floor for farmed
   animals).
5. **One fact, one place.** A medicine given is recorded in the record's
   administrations, never in the care log; a placement names a stay,
   never an animal.
6. **Actions, not accesses.** The displays record the actions taken; no
   read of a display is logged, in a table, by a heartbeat or in the
   audit log.
7. **Least grants.** The displays read one view and write nothing; the
   ward service adds care events and marks units clean and nothing else.
8. **Retention.** The care log, the plans and the placements are the
   stay's record, kept as the clinical records are: five years from the
   stay's end (the record's rule 9, a *game value*), then erased with it.
