# Register of processing: Aldermoor Veterinary Hospital North

What Aldermoor Veterinary Hospital North holds, why, where and for how
long: its record of processing activities. The rules each class of data
follows are in the data policy (`data-policy.md`); security measures are
stated there, not here.

- **Controller**: Aldermoor Veterinary Hospital North
- **Data-protection contact**: the franchise's data-protection officer, at the head office

## The medical record

### vet-core-owners: Owners, their animals and who owns them

- **Purpose**: Registering the owners, keepers and holdings who bring animals, the animals with their natural identifiers and food-chain status, and each dated ownership, so the record follows the animal and the portal reaches its current owner
- **People concerned**: owners, keepers, holdings' keepers
- **Data held**: personal: `owners.id`, `name`, `email`, `phone`, `address`, `country`, `herds.id`, `holding_number`, `animals.id`, `microchip`, `ueln`, `passport_number`, `ear_tag`; customer-linked: `herds.keeper_owner_id`, `ownerships.animal_id`, `owner_id`
- **Where**: `records/clinic` (`owners`, `animals`, `ownerships`, `herds`); the standby `standby`, a streaming replica
- **Shared with**: Aldermoor abroad (id, microchip, ueln, passport_number, ear_tag, name, email, phone, owner_id); Aldermoor Central (id, microchip, ueln, passport_number, ear_tag, name, email, phone, owner_id); Aldermoor South (id, microchip, ueln, passport_number, ear_tag, name, email, phone, owner_id); The veterinary authority (id, name, address, country, holding_number, keeper_owner_id, owner_id, animal_id); the back office, records/office (name, address); the owners' portal, records/portal (id, name, email, phone, animal_id, owner_id, keeper_owner_id, herd_id)
- **Kept for**: 5 years after the owner's last record entry (rule 9, a game value), then anonymised

### vet-core-staff: The centre's staff

- **Purpose**: Knowing who examined, prescribed, gave, cared and signed, by the staff layout, and reaching staff through the franchise's messaging service
- **People concerned**: staff
- **Data held**: personal: `staff.id`, `name`, `email`
- **Where**: `records/clinic` (`staff`); the standby `standby`, a streaming replica
- **Shared with**: The veterinary authority (id, name); the back office, records/office (name); the owners' portal, records/portal (name)
- **Kept for**: 5 years after the staff member leaves, as long as the records they signed are kept (a game value), then erased

### vet-core-referrals: Referrals from the region's practices

- **Purpose**: Receiving referred animals from the region's practices and their vets, and sending each referral's report back by letter
- **People concerned**: referring vets, owners
- **Data held**: personal: `referring_vets.id`, `name`, `email`; customer-linked: `referrals.animal_id`
- **Where**: `records/clinic` (`referring_practices`, `referring_vets`, `referrals`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: 5 years from the referral's last entry (rule 9, a game value), then erased

### vet-core-record: The medical record

- **Purpose**: Examining, diagnosing, treating and hospitalising animals, ordering analyses and imaging, recording alerts, and notifying listed diseases to the authority (rules 7, 8)
- **People concerned**: owners
- **Data held**: personal: `ops.notifications.payload`, `regulatory_submissions.payload`; customer-linked: `stays.animal_id`, `consultations.animal_id`, `herd_id`, `requests.animal_id`, `alerts.animal_id`, `animal_board.animal_id`
- **Where**: `records/clinic` (`consultations`, `diagnoses`, `procedures`, `requests`, `stays`, `alerts`, `animal_board`, `ops.notifications`); `records/office` (`regulatory_submissions`); the standby `standby`, a streaming replica
- **Shared with**: the imaging archive, machines/pacs (animal_id); the owners' portal, records/portal (animal_id, herd_id, kind, signed_at, diagnoses, admitted_at, discharged_at, outcome)
- **Kept for**: 5 years from the record's last entry (rule 9, a game value; no EU rule), then anonymised

### vet-core-medicines: Prescriptions, administrations and supplies of medicines

- **Purpose**: Prescribing, giving and supplying medicines with their batch, quantity and withdrawal period, keeping the medicines and controlled-drugs registers and the antimicrobial-use record (rules 1 to 6)
- **People concerned**: owners, keepers
- **Data held**: personal: `medicines_register.recipient`, `recipient_address`, `prescribing_vet`, `controlled_balances.signed_by`; customer-linked: `prescriptions.animal_id`, `herd_id`, `administrations.animal_id`, `dispensings.owner_id`
- **Where**: `records/clinic` (`prescriptions`, `prescription_lines`, `administrations`, `dispensings`); `records/office` (`medicines_register`, `controlled_balances`); the standby `standby`, a streaming replica
- **Shared with**: the owners' portal, records/portal (medicine, dose, unit, frequency_hours, days, withdrawal_ends_on)
- **Kept for**: 5 years (Regulation (EU) 2019/6 Art 103, 108), 10 years for controlled drugs' movements (the French rule, a game value), then erased

### vet-core-exchanges: Exchanges with the franchise's other centres

- **Purpose**: Transferring animals to and asking examinations of the other centres, and answering theirs, under the franchise's agreement (privileged flows)
- **People concerned**: owners
- **Data held**: personal: `exchanges.partner_patient`; customer-linked: `exchanges.animal_id`
- **Where**: `records/clinic` (`exchanges`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: 5 years from the exchange's report (rule 9, a game value), then erased

## Housing

### vet-housing-care: Placements, feeding plans and the care log

- **Purpose**: Housing each hospitalised animal, moving it as its care changes (isolation, intensive care), feeding it by its plan or holding it nil by mouth, and recording the carers' actions, as the stay's record (rules 2 to 5)
- **People concerned**: owners, staff
- **Data held**: customer-linked: `housing_unit_board.animal_id`
- **Where**: `records/clinic` (`housing_placements`, `housing_feeding_plans`, `housing_care_events`, `housing_unit_board`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: 5 years from the stay's end (rule 8, core rule 9, a game value), then erased

## Scheduling

### vet-scheduling-agenda: The agenda, its rooms, machines and appointment types

- **Purpose**: Booking owners' animals, imaging studies, theatre plans, maintenance blocks and training days on the centre's rooms and machines with the staff they take, never one resource in two places at once (rules 1, 2, 5, 6)
- **People concerned**: owners, staff
- **Data held**: customer-linked: `sched_bookings.animal_id`
- **Where**: `records/clinic` (`sched_settings`, `sched_rooms`, `sched_hours`, `sched_machines`, `sched_types`, `sched_bookings`, `sched_allocations`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: 5 years from the booking, as the clinical record (rule 10, core rule 9, a game value), then erased

### vet-scheduling-rota: The staff rota, its clocked hours and absences

- **Purpose**: Planning and publishing each staff member's shifts, recording the hours actually worked and absences by kind only, the working-time record an inspector may ask for (Directive 2003/88/EC; CJEU C-55/18; rules 3, 4)
- **People concerned**: staff
- **Data held**: personal: `sched_absences.note`, `working_time_days.staff_name`, `working_time_months.staff_name`
- **Where**: `records/clinic` (`sched_shifts`, `sched_absences`); `records/office` (`working_time_days`, `working_time_months`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: 2 years (rule 10, the working-time record; a game value after Germany's rule), then erased

### vet-scheduling-training: The training centre's courses, sessions, trainees and certificates

- **Purpose**: Running the courses for vets, nurses, students, owners and handlers, their waiting lists, attendance and certificates (GDPR Art 6(1)(b); rules 7, 8, 9)
- **People concerned**: trainees
- **Data held**: personal: `sched_trainees.id`, `name`, `email`, `phone`, `referring_vet_id`, `sched_enrolments.certificate_number`; customer-linked: `sched_enrolments.trainee_id`
- **Where**: `records/clinic` (`sched_courses`, `sched_sessions`, `sched_trainees`, `sched_enrolments`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: contacts 3 years after the trainee's last session, enrolments and certificates 5 years (rule 9, game values), then erased

## The laboratory

### vet-lab-orders: Analysis orders and their samples

- **Purpose**: Receiving the centre's and the region's practices' orders, accessioning their samples, routing each test in house or to the external lab, and keeping each sample's custody and storage (rules 5, 8, 10)
- **People concerned**: owners, the practices' clients
- **Data held**: personal: `lab_orders.animal_id`, `patient_ref`, `client_surname`, `microchip`, `ueln`, `ear_tag`, `lab_sample_events.other_party`
- **Where**: `lab/lab` (`lab_orders`, `lab_samples`, `lab_order_tests`, `lab_sample_events`)
- **Shared with**: The veterinary authority (client_surname, patient_ref); the back office, records/office (patient_ref, client_surname); the owners' portal, records/portal (animal_id, test, released_at); Northfield Veterinary Laboratories (accession, label, test, species, sex, age)
- **Kept for**: orders 5 years (rule 12, a game value), then their personal columns; samples a week or two, custody samples 60 days at most, then anonymised

### vet-lab-results: Results, their validation and their quality control

- **Purpose**: Running the analysers and benches, quality control, flagging against reference intervals, technical and clinical validation, amendments, critical-value calls (rules 1 to 4, 6)
- **People concerned**: the practices' staff called
- **Data held**: personal: `lab_critical_calls.called_person`
- **Where**: `lab/lab` (`lab_results`, `lab_batches`, `lab_qc_runs`, `lab_critical_calls`)
- **Shared with**: The region's practices (accession, kind, results); the owners' portal, records/portal (value, flag, unit, low, high)
- **Kept for**: 5 years (rule 12, a game value; ISO/IEC 17025 8.4.2 leaves it to the lab), then erased

### vet-lab-notifications: Notifications of listed diseases

- **Purpose**: Notifying the authority of a positive or suspect result for a listed disease, and forwarding a category A sample to an official lab under custody (rule 7; Regulation (EU) 2016/429 Art 18)
- **People concerned**: owners, the practices' clients
- **Data held**: personal: `ops.notifications.payload`
- **Where**: `lab/lab` (`lab_notifications`, `ops.notifications`)
- **Shared with**: the back office, records/office (payload)
- **Kept for**: 5 years (rule 12, a game value), then erased

### vet-lab-billing: Billing the practices

- **Purpose**: Charging each outside test at its order's day's price, the handling fee and the urgent surcharge, billable on release, for the monthly statements (rule 13)
- **People concerned**: none
- **Data held**: personal: `lab_charge_lines.patient_ref`, `client_surname`
- **Where**: `lab/lab` (`lab_charges`, `lab_prices`, `lab_accounts`); `records/office` (`lab_charge_lines`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: 10 years (national accounting law commonly, a game value), then erased

## The machines

### vet-machinery-imaging: Imaging studies and their reports

- **Purpose**: Scheduling and performing the imaging studies the vets order, archiving their images and reporting them, with the owner's family name and the animal's name in the study as the DICOM standard puts them (rules 1 to 3) and each ionising study's radiation record (rule 5)
- **People concerned**: owners, staff
- **Data held**: personal: `mach_studies.patient_id`, `patient_name`, `mach_worklist.animal_id`, `patient_id`, `patient_name`, `microchip`, `ueln`, `ear_tag`, `responsible_person`
- **Where**: `machines/pacs` (`mach_pacs_settings`, `mach_procedures`, `mach_worklist`, `mach_studies`, `mach_series`, `mach_reports`)
- **Shared with**: no one
- **Kept for**: 5 years from the study (rule 8; the professional code's five years for findings and technical records), then erased

### vet-machinery-monitoring: Monitoring animals in theatre and intensive care

- **Purpose**: Watching the vital signs of the animals under anaesthesia and in intensive care on the central station, charting them as the clinical record and raising alarms, from the core's current stays
- **People concerned**: owners
- **Data held**: customer-linked: `mach_census.animal_id`, `mach_sessions.animal_id`
- **Where**: `machines/vitals` (`mach_vitals_settings`, `mach_census`, `mach_sessions`, `mach_vitals`, `mach_vitals_chart`, `mach_alarms`)
- **Shared with**: no one
- **Kept for**: the chart, sessions and alarms 5 years (rule 8); the raw vitals today and the last full day on site, then the vault (cold storage, a game value), then erased

### vet-machinery-equipment: The machine registry and its maintenance

- **Purpose**: Keeping the registry of the centre's machines, their service visits, quality-assurance tests, calibrations and downtimes (rule 6), with the vendors' engineers who visit
- **People concerned**: vendors' service engineers, staff
- **Data held**: personal: `mach_maintenance.engineer`
- **Where**: `machines/biomed` (`mach_settings`, `mach_machines`, `mach_maintenance`, `mach_downtimes`)
- **Shared with**: no one
- **Kept for**: the machine's life and 5 years (rule 8, a game value), then erased

## The owners' portal

### vet-portal-accounts: The owners' portal accounts and their sessions

- **Purpose**: Inviting every owner of the record to the portal, letting them activate, log in and out, reset their password and close their account, and keeping their sessions by a token's hash (rules 4, 5)
- **People concerned**: owners, keepers
- **Data held**: personal: `portal_accounts.id`, `owner_id`, `display_name`, `email`, `phone`, `invite_hash`, `password_hash`, `portal_sessions.token_hash`; customer-linked: `portal_sessions.account_id`
- **Where**: `records/portal` (`portal_accounts`, `portal_sessions`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: an account as long as it is open, its personal columns erased at once on closing (rule 5); sessions 30 days after they end (rule 11, a game value), then erased

### vet-portal-copies: The portal's copies of the core

- **Purpose**: Holding the animals, the ownerships and the herds as the core holds them, without address or natural identifier, so that each account sees the animals its owner owns now, or keeps with the owner's consent (rules 1, 3)
- **People concerned**: owners, keepers
- **Data held**: customer-linked: `portal_animals.animal_id`, `herd_id`, `portal_ownerships.animal_id`, `owner_id`, `portal_herds.herd_id`, `keeper_owner_id`
- **Where**: `records/portal` (`portal_animals`, `portal_ownerships`, `portal_herds`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: as the core holds them, copied every few minutes (the core's rule 9, a game value), then erased

### vet-portal-documents: Documents released to the owners, and their openings

- **Purpose**: Publishing signed consultations, released results and ended stays to the animal's current owner once past their gate, amendments as new versions, and recording every document opened (rules 2, 3, 8)
- **People concerned**: owners, keepers, staff
- **Data held**: personal: `portal_documents.vet_name`; customer-linked: `portal_documents.animal_id`, `herd_id`, `portal_views.account_id`
- **Where**: `records/portal` (`portal_documents`, `portal_views`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: documents 5 years, as the record they show (the core's rule 9); views 2 years (rule 11, game values), then erased

### vet-portal-consents: Owners' consents

- **Purpose**: Keeping every grant and withdrawal of the reminders' consent and of a keeper's access to an animal, the latest the truth, as proof of consent (rule 6; GDPR Art 7(1), 7(3))
- **People concerned**: owners, keepers
- **Data held**: customer-linked: `portal_consent_events.owner_id`, `animal_id`, `keeper_id`
- **Where**: `records/portal` (`portal_consent_events`); the standby `standby`, a streaming replica
- **Shared with**: no one
- **Kept for**: as long as the account and 5 years after (rule 11, a game value), then erased

### vet-portal-outbox: Messages to the owners

- **Purpose**: Handing account messages, document notices and vaccination reminders to the franchise's messaging service, each with its key, its address, its template, the animal's name and a link, the reminders on consent (rules 6, 7)
- **People concerned**: owners, keepers
- **Data held**: personal: `portal_outbox.account_id`, `owner_id`, `address`, `animal_id`, `payload`
- **Where**: `records/portal` (`portal_outbox`); the standby `standby`, a streaming replica
- **Shared with**: The franchise's messaging service (address, template, name, animal, due_on, link), a processor
- **Kept for**: 2 years (rule 11, a game value), then erased

## Internal data

| Activity | Department | Where | Kept for |
|---|---|---|---|
| vet-core-operations: Running the centre | The medical record | `records/clinic` (`business_settings`, `sites`, `sections`, `diagnosis_codes`, `medicines`, `medicine_batches`) | as long as the centre runs; batches 5 years after their last supply (rule 2, a game value), then erased |
| vet-housing-wards: The wards' units and their displays | Housing | `records/clinic` (`housing_units`, `housing_displays`) | while the unit or the display is in place, then 5 years with the records naming it (a game value), then erased |
| vet-lab-round-trips: Send-outs and the practices' deliveries | The laboratory | `lab/lab` (`lab_send_outs`, `lab_callbacks`) | 5 years (rule 12, a game value), then erased |
| vet-lab-catalogue: Running the lab | The laboratory | `lab/lab` (`lab_settings`, `lab_analytes`, `lab_tests`, `lab_test_analytes`, `lab_reference_intervals`) | as long as the lab runs; a replaced interval as long as a result flagged against it, then erased |
| vet-machinery-logs: The machines' logs | The machines | `machines/biomed` (`mach_events`) | 12 months on site (rule 4, a game value), then erased |
| vet-machinery-telemetry: The machines' telemetry | The machines | `machines/biomed` (`mach_readings`, `mach_readings_daily`) | raw readings today and the last full day on site, then the vault; the daily aggregates 5 years (game values), then erased |
| vet-portal-settings: Running the portal | The owners' portal | `records/portal` (`portal_settings`) | as long as the portal runs, then erased |
| vet-lab-centre-orders: The centre's lab orders posted to the lab's order API, their released results copied back into the record | The medical record | `records/clinic` (`ops.runs`, `ops.incidents`, `ops.watermarks`, `ops.lab_orders_sent`, `ops.request_results`) | as long as the records its runs serve (a game value), then erased |
| vet-lab-practice-results: The lab's released results delivered to the region's practices' callbacks, interim, final and amended | The laboratory | `lab/lab` (`ops.runs`, `ops.incidents`, `ops.watermarks`) | as long as the records its runs serve (a game value), then erased |
| vet-lab-send-outs: The lab's send-outs to the external reference lab, posted at 16:00 on working days, chased, and their answers | The laboratory | `lab/lab` (`ops.runs`, `ops.incidents`, `ops.watermarks`) | as long as the records its runs serve (a game value), then erased |
| vet-centre-exchanges: Exchanges with the franchise's other centres, both ways, answered, reported, chased and escalated | The medical record | `records/clinic` (`ops.exchange_messages`, `ops.runs`, `ops.incidents`, `ops.watermarks`) | as long as the records its runs serve (a game value), then erased |
| vet-notifiable-diseases: Notifiable diseases notified to the authority within their deadline, referenced or escalated, copied to the back office | The medical record | `records/clinic` (`ops.runs`, `ops.incidents`, `ops.watermarks`); `lab/lab` (`ops.runs`, `ops.incidents`, `ops.watermarks`); `records/office` (`runs`) | as long as the records its runs serve (a game value), then erased |
| vet-lab-critical-calls: The lab's watch on critical results not read back within the hour, escalated to the on-call pathologist | The laboratory | `lab/lab` (`ops.runs`, `ops.incidents`, `ops.watermarks`) | as long as the records its runs serve (a game value), then erased |
| vet-medicines-registers: The register of supplies and the controlled-drugs register, fed daily into the back office, closed monthly | The medical record | `records/office` (`controlled_movements`, `register_extracts`, `controlled_inventories`, `runs`) | as long as the records its runs serve (a game value), then erased |
| vet-antimicrobial-use: The yearly antimicrobial-use report to the authority, fed daily into the back office | The medical record | `records/office` (`antimicrobial_use`, `amu_reports`, `runs`) | as long as the records its runs serve (a game value), then erased |
| vet-head-office-figures: The centre's monthly activity figures to the franchise's head office, fed daily into the back office | The medical record | `records/office` (`daily_figures`, `monthly_figures`, `runs`) | as long as the records its runs serve (a game value), then erased |
| vet-lab-statements: The practices' monthly statements from the lab's charges, fed daily into the back office | The laboratory | `records/office` (`lab_statements`, `runs`) | as long as the records its runs serve (a game value), then erased |
| vet-working-time: The working-time record, each day as clocked and its short rests, fed daily into the back office, summed monthly | The medical record | `records/office` (`rest_breaches`, `runs`) | as long as the records its runs serve (a game value), then erased |
| vet-bookings-sync: The agenda and the record kept in step, check-in, imaging and examination bookings, deaths | The medical record | `records/clinic` (`ops.booking_consultations`, `ops.runs`, `ops.incidents`, `ops.watermarks`) | as long as the records its runs serve (a game value), then erased |
| vet-imaging-orders: The imaging requests posted to the PACS's worklist and their final reports copied back | The medical record | `records/clinic` (`ops.imaging_results`, `ops.runs`, `ops.incidents`, `ops.watermarks`); `machines/pacs` (`ops.runs`, `ops.incidents`, `ops.watermarks`) | as long as the records its runs serve (a game value), then erased |
| cold-storage-archive: The machinery's day partitions shipped to the vault, cold storage, and dropped on a full receipt | The machines | `machines/vitals` (`ops.shipments`, `ops.runs`, `ops.incidents`, `ops.watermarks`); `machines/biomed` (`ops.shipments`, `ops.runs`, `ops.incidents`, `ops.watermarks`) | as long as the records its runs serve (a game value), then erased |
| vet-portal-release: The owners' portal's copies of the record and its release gate for consultations, discharges and results | The medical record | `records/portal` (`ops.runs`, `ops.incidents`, `ops.watermarks`) | as long as the records its runs serve (a game value), then erased |
| vet-portal-messages: The owners' portal's document notices and vaccination reminders handed to the franchise's messaging service | The owners' portal | `records/portal` (`ops.runs`, `ops.incidents`, `ops.watermarks`) | as long as the records its runs serve (a game value), then erased |

## Index

| Where | Activities |
|---|---|
| `records/clinic` | vet-core-owners, vet-core-staff, vet-core-referrals, vet-core-record, vet-core-medicines, vet-core-exchanges, vet-housing-care, vet-scheduling-agenda, vet-scheduling-rota, vet-scheduling-training, vet-core-operations, vet-housing-wards, vet-lab-centre-orders, vet-centre-exchanges, vet-notifiable-diseases, vet-bookings-sync, vet-imaging-orders |
| `records/office` | vet-core-record, vet-core-medicines, vet-scheduling-rota, vet-lab-billing, vet-notifiable-diseases, vet-medicines-registers, vet-antimicrobial-use, vet-head-office-figures, vet-lab-statements, vet-working-time |
| `lab/lab` | vet-lab-orders, vet-lab-results, vet-lab-notifications, vet-lab-billing, vet-lab-round-trips, vet-lab-catalogue, vet-lab-practice-results, vet-lab-send-outs, vet-notifiable-diseases, vet-lab-critical-calls |
| `machines/pacs` | vet-machinery-imaging, vet-imaging-orders |
| `machines/vitals` | vet-machinery-monitoring, cold-storage-archive |
| `machines/biomed` | vet-machinery-equipment, vet-machinery-logs, vet-machinery-telemetry, cold-storage-archive |
| `records/portal` | vet-portal-accounts, vet-portal-copies, vet-portal-documents, vet-portal-consents, vet-portal-outbox, vet-portal-settings, vet-portal-release, vet-portal-messages |
