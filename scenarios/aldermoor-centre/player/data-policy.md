# Aldermoor Veterinary Hospital North: data policy

This policy applies to every application and staff account of the centre
working with its owners', animals', staff's and the practices' clients'
data. The centre is in an EU member state: EU law applies as written;
where a figure is the centre's own choice, it says so.

## What we hold

- **Personal data**: anything that identifies a person, or is stored with
  something that does: owners' and keepers' names, addresses, e-mail and
  phone numbers; staff names and contacts; the practices' clients; the
  portal's accounts, consents and messages. An animal's record linked to
  an identifiable owner is that owner's personal data, and so are the
  animal's identifiers (microchip, UELN, passport, ear tag).
- **Customer-linked data**: an owner, animal or stay number with nothing
  identifying beside it, such as the wards' boards, a booking, or a
  monitor's readings.
- **Internal data**: everything else: the catalogue of medicines and
  tests, the rooms, machines and rotas, figures and aggregates.

## Where it may live

- Personal data: in the record's databases (`clinic`, `office` and
  `portal`, on the record's server), the laboratory's (`lab`), and the
  imaging archive's and the biomedical events' databases (`pacs` and
  `biomed`, on the machines' server); and, once sent under this policy,
  in the partners' own systems.
- Customer-linked data: in `clinic` and `portal`, and in the monitors'
  readings (`vitals`, on the machines' server).
- Internal data may live anywhere.

The standby in the off-site room and the archives in Cold Storage hold
copies of the servers they protect, under the same rules.

## Who may read it

Each application reads through its own account, and only what it needs:

- Personal data: the practice software (`vet_app`, `sched_app`, its
  wards module `housing_app`), the ward service (`housing_ward`), the
  lookup API (`vet_lookup`, never a contact), the back office and its
  reports (`vet_reports`, `sched_reports`, `office_reader`,
  `office_jobs`), the lab's information system, order API, dispatch and
  reports (`lab_app`, `lab_api`, `lab_dispatch`, `lab_reports`,
  `lab_release`, `lab_watch`), the imaging archive's and the biomedical
  applications (`mach_pacs_app`, `mach_biomed_app`) and the service
  engineers' account (`mach_service`), the integration jobs
  (`vet_interfaces`, `vet_exchange`, `vet_portal_sync`,
  `sched_interfaces`, `mach_orders`, `mach_archive`, `portal_sync`,
  `portal_dispatch`), and the portal (`portal_api`, `portal_housekeeping`).
- Customer-linked data: the same applications where they read it, and
  the ward displays (`vet_display`) and the monitors' application
  (`mach_vitals_app`).
- Internal data: any of our accounts.

No other account reads personal or customer-linked data.

## What may leave, and to whom

- To the franchise's messaging service, through the portal's outbox only:
  the address, the message's template, the recipient's name, the
  animal's name, a reminder's due date and the link to the portal.
  Nothing of the record goes in a message.
- To the other centres of the franchise, under its agreement: what an
  exchange about a shared patient needs.
- To Northfield Veterinary Laboratories, for a send-out: the accession,
  the sample's label, the species, sex and age, and the tests; never the
  owner, the client or an animal's identifier.
- To a practice: the results of its own orders, and nothing else.
- To the veterinary authority: the notifications of listed diseases and
  the yearly antimicrobial-use report, as the law requires them.
- To the head office: the month's activity figures, as numbers only.
- To Cold Storage, our archive (a processor): the archived servers and
  the machines' old days.

Every flow of personal data to a partner is listed in the data register.

## Rules

1. **The least data per reader.** The lookup API answers without
   contacts; the ward displays show an animal's name, species and care,
   never an identifier or an owner.
2. **No personal data in the logs**: no password, token, name, address
   or phone number in a server's log.
3. **The portal.** An owner sees the animals they own now, and their
   records from their own ownership only, never a former owner's
   identity; a result once a vet has validated it; a consultation once
   it is signed.
4. **Medicines.** Every supply of a prescription-only medicine is in the
   medicines register (kept five years, the centre's choice); every
   movement of a controlled drug in its register, balanced every month
   and signed by the senior vet, inventoried every year (kept ten years,
   the centre's choice).
5. **Antimicrobial use.** Every antimicrobial given or dispensed is
   recorded, for every species, herds included; the yearly report to the
   authority covers the species due (cattle today).
6. **Notifiable diseases.** A category A disease is notified to the
   authority within the hour, another listed disease within the day.
7. **Records signed within a day** of the consultation's close.
8. **Working time.** Every shift is planned and clocked, with at least
   eleven hours of rest between two shifts.
9. **The laboratory.** A result leaves the lab only once released; a
   released result is never changed, only amended; a critical value is
   phoned to the requesting vet.

## Keeping it

Clinical records are kept five years from their last entry, medicines
records five years, controlled drugs ten, then erased or anonymised.
