# Register of processing: Aldermoor Veterinary Hospitals' centre

What Aldermoor Veterinary Hospitals' centre holds, why, where and for
how long: its record of processing activities. The rules each class of
data follows are in the data policy (`data-policy.md`); security
measures are stated there, not here.

- **Controller**: Aldermoor Veterinary Hospitals' centre
- **Data-protection contact**: the franchise's data-protection officer

## The medical record

### vet-core-owners: Owners, their animals and who owns them

- **Purpose**: Registering the owners, keepers and holdings who bring animals, the animals with their natural identifiers and food-chain status, and each dated ownership, so the record follows the animal and the portal reaches its current owner
- **People concerned**: owners, keepers, holdings' keepers
- **Data held**: personal: `owners.id`, `name`, `email`, `phone`, `address`, `country`, `herds.id`, `holding_number`, `animals.id`, `microchip`, `ueln`, `passport_number`, `ear_tag`; customer-linked: `herds.keeper_owner_id`, `ownerships.animal_id`, `owner_id`
- **Where**: `records/clinic` (`owners`, `animals`, `ownerships`, `herds`); cold storage (WAL archive, nightly base backup)
- **Shared with**: Cold Storage (the whole instance, archived), a processor
- **Kept for**: 5 years after the owner's last record entry (rule 9, a game value), then anonymised

### vet-core-staff: The centre's staff

- **Purpose**: Knowing who examined, prescribed, gave, cared and signed, by the staff layout, and reaching staff through the franchise's messaging service
- **People concerned**: staff
- **Data held**: personal: `staff.id`, `name`, `email`
- **Where**: `records/clinic` (`staff`); cold storage (WAL archive, nightly base backup)
- **Shared with**: Cold Storage (the whole instance, archived), a processor
- **Kept for**: 5 years after the staff member leaves, as long as the records they signed are kept (a game value), then erased

### vet-core-referrals: Referrals from the region's practices

- **Purpose**: Receiving referred animals from the region's practices and their vets, and sending each referral's report back by letter
- **People concerned**: referring vets, owners
- **Data held**: personal: `referring_vets.id`, `name`, `email`; customer-linked: `referrals.animal_id`
- **Where**: `records/clinic` (`referring_practices`, `referring_vets`, `referrals`); cold storage (WAL archive, nightly base backup)
- **Shared with**: Cold Storage (the whole instance, archived), a processor
- **Kept for**: 5 years from the referral's last entry (rule 9, a game value), then erased

### vet-core-record: The medical record

- **Purpose**: Examining, diagnosing, treating and hospitalising animals, ordering analyses and imaging, recording alerts, and notifying listed diseases to the authority (rules 7, 8)
- **People concerned**: owners
- **Data held**: customer-linked: `stays.animal_id`, `consultations.animal_id`, `herd_id`, `requests.animal_id`, `alerts.animal_id`, `animal_board.animal_id`
- **Where**: `records/clinic` (`consultations`, `diagnoses`, `procedures`, `requests`, `stays`, `alerts`, `animal_board`); cold storage (WAL archive, nightly base backup)
- **Shared with**: Cold Storage (the whole instance, archived), a processor
- **Kept for**: 5 years from the record's last entry (rule 9, a game value; no EU rule), then anonymised

### vet-core-medicines: Prescriptions, administrations and supplies of medicines

- **Purpose**: Prescribing, giving and supplying medicines with their batch, quantity and withdrawal period, keeping the medicines and controlled-drugs registers and the antimicrobial-use record (rules 1 to 6)
- **People concerned**: owners, keepers
- **Data held**: customer-linked: `prescriptions.animal_id`, `herd_id`, `administrations.animal_id`, `dispensings.owner_id`
- **Where**: `records/clinic` (`prescriptions`, `prescription_lines`, `administrations`, `dispensings`); cold storage (WAL archive, nightly base backup)
- **Shared with**: Cold Storage (the whole instance, archived), a processor
- **Kept for**: 5 years (Regulation (EU) 2019/6 Art 103, 108), 10 years for controlled drugs' movements (the French rule, a game value), then erased

### vet-core-exchanges: Exchanges with the franchise's other centres

- **Purpose**: Transferring animals to and asking examinations of the other centres, and answering theirs, under the franchise's agreement (privileged flows)
- **People concerned**: owners
- **Data held**: personal: `exchanges.partner_patient`; customer-linked: `exchanges.animal_id`
- **Where**: `records/clinic` (`exchanges`); cold storage (WAL archive, nightly base backup)
- **Shared with**: Cold Storage (the whole instance, archived), a processor
- **Kept for**: 5 years from the exchange's report (rule 9, a game value), then erased

## Internal data

| Activity | Department | Where | Kept for |
|---|---|---|---|
| vet-core-operations: Running the centre | The medical record | `records/clinic` (`business_settings`, `sites`, `sections`, `diagnosis_codes`, `medicines`, `medicine_batches`) | as long as the centre runs; batches 5 years after their last supply (rule 2, a game value), then erased |

## Index

| Where | Activities |
|---|---|
| `records/clinic` | vet-core-owners, vet-core-staff, vet-core-referrals, vet-core-record, vet-core-medicines, vet-core-exchanges, vet-core-operations |
