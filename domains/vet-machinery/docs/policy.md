# Aldermoor Veterinary Hospitals: the machines' data policy

The default policy of the centre's machines and their three systems (v0.5
master spec 9.6, "The business's own rules"; vet-machinery-domain.md, "The
business's own rules", D319), beside the medical record's
([vet-core's policy](../../vet-core/docs/policy.md)). The GM copies it
into a scenario's `player/data-policy.md` with the core's and adapts it
there, with the `governance:` fragment beside it
(`data/governance.yaml`). The centre sits in an unnamed EU member state:
EU law applies as written; where a rule is national, Germany is the
example and the policy says so; a figure marked *game value* is the
clinic's choice, not the law.

## The rules

1. **Release.** An imaging report leaves the PACS, to the medical record,
   only once the imaging specialist's final report is signed. A night's
   preliminary, by the duty vet, is visible inside the centre, marked
   preliminary; the request is resulted on the final only.
2. **Addenda.** A signed final report is never updated. An addendum is a
   new report superseding it; the first is kept, with why and who.
3. **Identity in studies.** A study carries the owner's family name and
   the animal's name (DICOM PS3.5 6.2; PS3.3 Responsible Person), taken
   from the medical record's lookup service: a name only, never a contact.
4. **Machine logs** name an operator by staff id only, never an animal's
   or an owner's name, and are kept twelve months on site, then dropped
   (*game value*). No personal data in the server's logs: the audit on
   the machinery's server logs writes, DDL and roles, without parameters.
5. **Radiation protection.** Each ionising study records its
   radiographer, the staff who restrained the animal, and whether a
   companion was present (Directive 2013/59/Euratom Arts 9, 35–41;
   StrlSchV § 144: never a pregnant companion). Workers' dose records are
   the approved dosimetry service's, kept until age 75 and 30 years at
   least (Art 43(3)), outside these systems.
6. **Equipment checks.** Each ionising machine passes a quality-assurance
   test every twelve months (*game value*), recorded with its next due
   date, and an expert check at least every five years (StrlSchV
   § 88(4)). A machine past its QA date is not used.
7. **Critical machine alerts** (an MRI's helium or compressor, a quench)
   are acknowledged by the biomedical engineer within four hours (*game
   value*).
8. **Retention.** Images, reports and the anaesthesia and intensive-care
   chart: five years, as the clinic's records (Tierärztekammer Nordrhein
   professional code § 2(6), technical records included). Raw vitals and
   machine readings: today and the last full day on site, then the cold
   storage vault, whose own retention is outside these systems. Logs:
   twelve months. Maintenance and QA: the machine's life and five years
   (*game value*).
9. **Vendors' access.** A vendor's service account reaches the
   biomedical engineering system only, through its own role, never as a
   superuser, its password a secret the clinic sets. It never reaches the
   PACS or the central station.
10. **Least data to the vault.** A shipment carries the table's internal
    columns only: a vitals row by its session's id, never the animal. Cold
    storage processes it on the clinic's behalf (GDPR Art 28).
11. **Aggregates first.** No day ships before what the clinic keeps from
    it exists on site: the chart for the vitals, the daily aggregate for
    the readings.
