# Aldermoor Veterinary Hospitals: data and records policy

The default policy of the centre's medical record (v0.5 master spec 9.2,
"The default policy: eleven rules"; vet-core-domain.md, "The rules, as the
owner confirmed them", D280). The GM copies it into a scenario's
`player/data-policy.md` and adapts it there, with the `governance:`
fragment beside it (`data/governance.yaml`). The centre sits in an
unnamed EU member state: EU law applies as written; where a rule is
national, the policy takes one member state's figure and says so; a
figure marked *game value* is the clinic's choice, not the law.

## Medicines

1. **Prescriptions.** A prescription states the animal or group, the
   owner's or keeper's name and contact, the date, the vet and their
   signature, the product with its form, strength and quantity, the
   dosage, for a food-producing species the withdrawal period "even if
   such period is zero", warnings, and whether the cascade was used
   (Regulation (EU) 2019/6, Art 105(5)). A prescription for an
   antimicrobial is valid five days from issue (Art 105(10)). Under the
   cascade, with no withdrawal period for the species, the minimum is
   the product's longest period × 1.5, or 28 days for meat and 7 for
   milk when the product is not authorised for food-producing animals
   (Art 115(1)–(2)).
2. **The medicines register.** Every supply of a prescription-only
   medicine is recorded with its date, product, form and strength,
   batch, quantity, the recipient's name and address, the prescribing
   vet and the authorisation number, and kept five years, with a yearly
   audit of stock against it (Art 103(3), (5)). France keeps its
   register ten years (CSP R5141-112); the clinic keeps five (*game
   value*).
3. **The controlled-drugs register.** Every entry and exit of a
   narcotic (ketamine, the opioids), a monthly balance signed by the
   vet, a yearly inventory, destructions recorded; kept ten years from
   its last entry (*game value*, the French rule, CSP R5132-36; Germany
   keeps three, BtMVV § 13(3)).
4. **Antimicrobial use.** Every antimicrobial administration and
   dispensing is recorded, for every species. The yearly report to the
   authority covers the species due at the time (Delegated Regulation
   (EU) 2021/578, Arts 13, 15): cattle now; sheep, goats and horses from
   30 June 2027; dogs and cats from 30 June 2030.
5. **Horses and the food chain.** A horse is in the food chain unless
   Part II of its passport excludes it, a signed and irreversible
   declaration (Implementing Regulation (EU) 2021/963, Art 38). Before
   an off-label treatment the vet checks the status, and may have the
   keeper exclude the horse first (Art 39). A substance on the list
   essential for equines, given to a food-chain horse, imposes a
   six-month withdrawal, recorded in the passport (2019/6 Art 115(5);
   Implementing Regulation (EU) 2025/901).
6. **Food-producing animals.** Every administration and dispensing to a
   food-producing animal records the day its withdrawal ends; the
   keeper's own records are kept at least five years (2019/6 Art 108).

## The record

7. **Notifiable diseases.** The vet who records the diagnosis notifies
   it: a category A disease within the hour, another listed disease
   within the day (*game values*; Regulation (EU) 2016/429, Art 18,
   "immediately" and "as soon as practicable").
8. **Records signed within a day.** A consultation is signed by its vet
   within a day of closing: the clinic's own rule.
9. **Retention.** Clinical records five years from their last entry
   (no EU rule; a German chamber's example, Tierärztekammer Nordrhein
   § 2(6)), medicines records five years, controlled drugs ten (*game
   values*); past them a record is erased or anonymised.

## People

10. **Owners' data.** An owner's name and contacts are personal data,
    and an animal's record linked to an identifiable owner is that
    owner's personal data (GDPR Art 4(1); CJEU C-434/16, *Nowak*).
    Animal health is no special category (Art 9 covers a person's
    health only). So: the least data per reader (the lookup API answers
    without contacts, the ward displays show no identifier); no personal
    data in the logs; an owner with no record left within retention is
    erased or anonymised; an erasure request is bounded by the medicine
    records the law keeps five years.
11. **The portal.** An owner sees the animals they own now, and their
    records from their own ownership only, never a former owner's
    identity; a result once a vet has validated it, a consultation once
    it is signed; no staff contact beyond the clinic's.

## Who reads what

| Reader | What |
|---|---|
| The practice software (`vet_app`) | the whole record; it writes the record and the people it keeps, never the reference tables |
| The lookup API (`vet_lookup`) | an animal's identity and identifiers, its ownerships, an owner's name and kind, the current stays; never a contact, never a death |
| The ward displays (`vet_display`) | the board of the animals in hospital: name, species, stay, alerts, the day's doses; no identifier, no owner |
| The back office (`vet_reports`) | everything, contacts included, to answer owners; it writes nothing |

The record's database is opened only by the roles named for it; no
other application of the centre connects to it.
