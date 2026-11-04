# Aldermoor Veterinary Hospitals: laboratory data and records policy

The default policy of the centre's laboratory (v0.5 master spec 9.3;
vet-lab-domain.md, "The business's own rules" and "The rules, as the
owner confirmed them", D302), beside the medical record's
([vet-core's policy](../../vet-core/docs/policy.md)). The GM copies it
into a scenario's `player/data-policy.md` with the core's and adapts it
there, with the `governance:` fragment beside it
(`data/governance.yaml`). The centre sits in an unnamed EU member state:
EU law applies as written; where a rule is national, the policy names it
generically; a figure marked *game value* is the lab's choice, not the
law. Sources: ISO/IEC 17025:2017, the AAVLD accreditation requirements
(AC-1, 2018), Regulations (EU) 2016/429, 2017/625, 2020/687 and (EC)
853/2004, and the GDPR.

## Results

1. **Release.** A result leaves the lab, to the portal or to a practice,
   only once a clinical pathologist has released it (the clinic's rule
   11). Inside the centre a technically validated urgent result is shown
   at once, marked unvalidated.
2. **Traceability.** Every result names its batch (or the bench), the
   quality-control run in force, the technician who validated it and the
   vet who released it, with their times (ISO/IEC 17025, 7.5.1).
3. **Amendments.** A released result is never updated: an amendment is a
   new result referencing the one it replaces, the first kept with what
   changed, why and who (7.5.2, 7.8.8).
4. **Quality control.** Every analyser is controlled once a day at the
   bench's opening and before a night run; a failed run holds the
   analyser's results since its last good run, and nothing is released
   from a failed run (7.7.1, 7.10.1).
5. **Unfit samples.** A sample's condition is recorded at receipt; a test
   it makes unfit is not performed, and the customer is told why
   (7.4.3).
6. **Critical values.** A critical value is phoned to the requesting vet
   or to the practice within 60 minutes of the result, read back, and the
   call recorded (*game value*: no veterinary standard fixes the limits
   or the delay).

## Obligations

7. **Notifiable diseases.** National law requires labs to notify, beside
   "operators and other relevant natural or legal persons" (Regulation
   (EU) 2016/429, Art 18). The lab notifies the authority of a positive
   or suspect result for a test tied to a listed disease, for every
   customer, within an hour of its technical validation for a category A
   disease and within a day for another listed disease (*game values* for
   "immediately" and "as soon as practicable"); for category A it
   forwards a sample to an official lab without delay, under custody
   (Delegated Regulation (EU) 2020/687, Art 3(2)).
8. **Chain of custody.** A sample with legal weight (forwarded for
   official confirmation, a welfare, legal or insurance case) records
   each handover: both parties, the time, its condition and its seal
   number.
9. **Residue screening.** The milk inhibitor test is an own check for the
   keeper (Regulation (EC) 853/2004, Annex III, Section IX), never an
   official sample (official residue control is the official labs',
   Regulation (EU) 2017/625, Art 37), never reported to the authority.

## People

10. **The practices' clients.** For an outside order the lab processes
    the practice's client data on the practice's behalf, as its
    processor (GDPR, Art 28): it uses the data for that order only, never
    matches a patient to the centre's animals, and returns a practice
    only its own orders.
11. **Least data.** A send-out carries the accession, the sample's label,
    the species, sex and age, never the owner, the client or a natural
    identifier; the core's lookup API is read without contacts; no
    personal data in the logs: pgaudit on the lab's database logs writes,
    schema changes and role changes (`pgaudit.log = 'write, ddl, role'`),
    its statements' parameters off (`pgaudit.log_parameter = off`).
12. **Retention.** No EU rule sets a lab's periods; ISO/IEC 17025 (8.4.2)
    and the AAVLD leave them to the lab. *Game values*: orders, results,
    validations, amendments, quality-control runs and custody records
    five years, as the clinic's clinical records, then the order's
    personal columns erased or anonymised; samples a week or two; a
    custody sample until its case closes, 60 days at most; charges ten
    years, as national accounting law commonly keeps them.

## Billing

13. **Billing.** One price list, revised each 1 January; a test charged
    at the price of the day it was ordered, half again when urgent, a
    handling fee per order; billable once released, voided if cancelled
    or the sample unfit; a send-out re-billed at the lab's own price; the
    month's charges gathered into the practice's statement on the 1st,
    with a volume discount of 3 to 15 %. The centre's own account is never
    charged, and no owner is ever billed.

## Who reads what

| Role | Reads | Writes |
|---|---|---|
| `lab_app`, the information system | every table | orders, samples, tests, events, results, calls, notifications, QC runs, charges; never the reference tables |
| `lab_api`, the order API | the catalogue, accounts, orders, their tests and results, send-outs | the intake (orders, samples, tests); the external lab's answers |
| `lab_instruments`, the analysers' middleware | samples, tests, analytes, intervals, QC runs; an order's species | batches, results |
| `lab_dispatch`, the dispatch jobs | what a delivery and a send-out carry | callbacks, send-outs, sent-out events, the notifications' sent columns |
| `lab_reports`, the reports | every table | nothing |
