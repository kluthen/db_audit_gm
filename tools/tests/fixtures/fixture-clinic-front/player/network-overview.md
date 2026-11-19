# Network overview: Aldermoor Veterinary Hospital North

One private network; the partners' services are reached on it by name; from outside, only the bastion's SSH port and web port are reachable.

You work from `bastion`, your access point: [Node health](/grafana/d/node-health/node-health?var-node=bastion&from=now-6h&to=now).

Node health for the whole estate: [Node health](/grafana/d/node-health/node-health?from=now-6h&to=now).

This is the centre's own documentation, kept by its IT. The **Your access** column is the game's rule and always exact.

## Summary

| Name | Role | Description | Your access |
|---|---|---|---|
| [records](#records) | database server | The record's database server, the medical record, the agenda and the wards, the back office's registers and reports, the owners' portal. | write (`/etc/postgresql`) |
| [standby](#standby) | database server | The record's standby, a streaming replica of records where the back office's reports run their heavy reads. | write (`/etc/postgresql`) |
| [lab](#lab) | database server | The laboratory's database server, its orders, samples and results, the practices' accounts and their billing. | write (`/etc/postgresql`) |
| [machines](#machines) | database server | The machines' database server, the imaging worklist and reports, the monitors' readings and the biomedical events. | write (`/etc/postgresql`) |
| [pms](#pms) | application | The practice software, from its vendor, for the record, the agenda, the ward screens and the portal's desk. | read-only |
| [lis](#lis) | application | The laboratory's information system, from its vendor, for the bench, the analysers, the results and the quality control. | read-only |
| [ward](#ward) | application | The ward service, from its vendor, which drives the displays on every box and stall. | read-only |
| [equipment](#equipment) | application | The machines' feeds, from their vendors, for the imaging machines, the monitors and the biomedical equipment. | read-only |
| [clinic-api](#clinic-api) | API | The lookup API the other centres, the lab and the machines call, from the practice software's vendor. | read-only |
| [lab-api](#lab-api) | API | The laboratory's order API, for the centre's orders, the practices' orders and the external lab's answers. | write (`/srv/api/db`) |
| [portal-api](#portal-api) | API | The owners' portal, their accounts, their animals' documents and their reminders. | write (`/srv/api/db`) |
| [interfaces](#interfaces) | integration engine | The centre's integration jobs, for the lab orders and results, the send-outs, the other centres, the notifications, the imaging orders, the portal and the archive. | write (`/srv/scheduler/repository`, `/srv/scheduler/jobs`) |
| [backoffice](#backoffice) | back-office engine | The back office's reports, the medicines and controlled-drugs registers, the antimicrobial use, the working time, the head office's figures and the practices' statements. | write (`/srv/scheduler/repository`, `/srv/scheduler/jobs`) |
| [prometheus](#prometheus) | monitoring | Prometheus, which collects the metrics. | read-only |
| [grafana](#grafana) | monitoring | Grafana, the dashboards and the alert rules. | write (`/etc/grafana/provisioning`, `/etc/grafana/provisioning/alerting`, `/etc/grafana/provisioning/dashboards`, `/etc/grafana/provisioning/datasources`) |
| [exporter-records](#exporter-records) | monitoring | The PostgreSQL exporter for records. | write (`/etc/postgres-exporter`) |
| [exporter-standby](#exporter-standby) | monitoring | The PostgreSQL exporter for the standby. | write (`/etc/postgres-exporter`) |
| [exporter-lab](#exporter-lab) | monitoring | The PostgreSQL exporter for lab. | write (`/etc/postgres-exporter`) |
| [exporter-machines](#exporter-machines) | monitoring | The PostgreSQL exporter for machines. | write (`/etc/postgres-exporter`) |
| [pgwatch](#pgwatch) | monitoring | pgwatch, a second collector of PostgreSQL metrics. | write (`/etc/pgwatch`) |
| [health](#health) | monitoring | The IT's health checks, check_postgres and their own scripts, and their page. | write (`/etc/health`) |

## Database servers

### records

- **Name**: `records` (`ssh records`, `psql -h records`)
- **Role**: database server
- **Description**: The record's database server, the medical record, the agenda and the wards, the back office's registers and reports, the owners' portal.
- **System**: Debian GNU/Linux 13
- **Applications**: PostgreSQL 19; preloaded: pg_stat_statements, pg_cron; options: monitoring; report tools: pgbadger; cron
- **Sizing**: CPU 1 (0.5 reserved), memory 1G (512M reserved), disk 2.25G
- **Your access**: write (`/etc/postgresql`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=records&from=now-6h&to=now)
- **Databases**:
  - `jobs`: pg_cron's jobs (its cron.database_name): the portal's sessions' purge
  - `office`: the back office: the medicines and controlled-drugs registers, the antimicrobial use and its yearly report, working time, the activity figures, the lab's statements; register: [vet-core-record](data-register.md#vet-core-record-the-medical-record), [vet-core-medicines](data-register.md#vet-core-medicines-prescriptions-administrations-and-supplies-of-medicines), [vet-scheduling-rota](data-register.md#vet-scheduling-rota-the-staff-rota-its-clocked-hours-and-absences), [vet-lab-billing](data-register.md#vet-lab-billing-billing-the-practices), [vet-notifiable-diseases](data-register.md#internal-data), [vet-medicines-registers](data-register.md#internal-data), [vet-antimicrobial-use](data-register.md#internal-data), [vet-head-office-figures](data-register.md#internal-data), [vet-lab-statements](data-register.md#internal-data), [vet-working-time](data-register.md#internal-data)
  - `clinic`: the medical record, the wards and the agenda; register: [vet-core-owners](data-register.md#vet-core-owners-owners-their-animals-and-who-owns-them), [vet-core-staff](data-register.md#vet-core-staff-the-centres-staff), [vet-core-referrals](data-register.md#vet-core-referrals-referrals-from-the-regions-practices), [vet-core-record](data-register.md#vet-core-record-the-medical-record), [vet-core-medicines](data-register.md#vet-core-medicines-prescriptions-administrations-and-supplies-of-medicines), [vet-core-exchanges](data-register.md#vet-core-exchanges-exchanges-with-the-franchises-other-centres), [vet-housing-care](data-register.md#vet-housing-care-placements-feeding-plans-and-the-care-log), [vet-scheduling-agenda](data-register.md#vet-scheduling-agenda-the-agenda-its-rooms-machines-and-appointment-types), [vet-scheduling-rota](data-register.md#vet-scheduling-rota-the-staff-rota-its-clocked-hours-and-absences), [vet-scheduling-training](data-register.md#vet-scheduling-training-the-training-centres-courses-sessions-trainees-and-certificates), [vet-core-operations](data-register.md#internal-data), [vet-housing-wards](data-register.md#internal-data), [vet-lab-centre-orders](data-register.md#internal-data), [vet-centre-exchanges](data-register.md#internal-data), [vet-notifiable-diseases](data-register.md#internal-data), [vet-bookings-sync](data-register.md#internal-data), [vet-imaging-orders](data-register.md#internal-data)
  - `portal`: the owners' portal: accounts, consents, the record's released copies, the messages to send; register: [vet-portal-accounts](data-register.md#vet-portal-accounts-the-owners-portal-accounts-and-their-sessions), [vet-portal-copies](data-register.md#vet-portal-copies-the-portals-copies-of-the-core), [vet-portal-documents](data-register.md#vet-portal-documents-documents-released-to-the-owners-and-their-openings), [vet-portal-consents](data-register.md#vet-portal-consents-owners-consents), [vet-portal-outbox](data-register.md#vet-portal-outbox-messages-to-the-owners), [vet-portal-settings](data-register.md#internal-data), [vet-portal-release](data-register.md#internal-data), [vet-portal-messages](data-register.md#internal-data)
- **Fed and used by**:
  - `pms`, database `clinic` as `vet_app`: the practice-management software; reads the whole medical record and its reference tables; writes owners, animals and herds, referrals, consultations, diagnoses and procedures, requests, stays, alerts, exchanges with other centres, prescriptions, administrations and dispensings
  - `pms`, database `clinic` as `housing_app`: the practice software's housing screens; reads the units, the displays, the placements, the feeding plans and the care log, and of the record what placing an animal needs; writes animals placed, moved and released, diets and feeding orders, a unit marked to clean
  - `pms`, database `clinic` as `sched_app`: the practice software's scheduling module; reads the rooms, the opening hours, the machines, the appointment types, the courses, the bookings and the rota, and the free slots; writes bookings, room and machine allocations, the rota, absences, teaching sessions' state, trainees and enrolments
  - `ward`, database `clinic` as `vet_display`: the ward displays; reads the animals' board and the housing units' board; writes nothing
  - `ward`, database `clinic` as `housing_ward`: the ward service, the carers' actions on the displays; reads the units, the placements, the feeding plans, the care log and the units' board; writes care events, a unit marked clean
  - `interfaces`, database `clinic` as `vet_interfaces`: the integration jobs on the record: lab orders, the other centres' exchanges, notifiable diseases, bookings, imaging orders
  - `interfaces`, database `clinic` as `sched_interfaces`: the integration jobs on the agenda: check-ins, bookings, deaths
  - `interfaces`, database `clinic` as `vet_portal_sync`: the portal's release: reads what the record may publish
  - `interfaces`, database `portal` as `portal_sync`: the portal's release: writes the record's released copies
  - `interfaces`, database `portal` as `portal_dispatch`: the portal's messages: hands the notices and reminders to the messaging service
  - `backoffice`, database `office` as `office_jobs`: the back office's jobs: write the registers, the reports and the figures
  - `clinic-api`, database `clinic` as `vet_lookup`: the lookup API the other centres, the lab and the machines call; reads the animals without their death, their owners' names without contact details, the stays' dates; writes nothing
  - `clinic-api`, database `clinic` as `vet_exchange`: the other centres' exchanges, answered through the clinic's API
  - `portal-api`, database `portal` as `portal_api`: the owners' portal API; reads the owners' animals, ownerships, herds and documents, as each account may see them, its own account and the portal's settings; writes logins and sessions, documents viewed, consent changes, an account's notification choices
  - `exporter-records`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `pgwatch`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `health`, database `postgres`: statistics, as monitoring (pg_monitor)
  - `standby`, database `all` as `replication`: streaming replication: a replica of every database
  - `records`, database `portal` as `portal_housekeeping`: pg_cron's job portal.sessions.purge, on this server
- **Uses**: none
- **Users**: none
- **Third parties**:
  - [Cold Storage](partners.md#cold-storage): the WAL archive and the nightly base backup
- **Background tasks**:
  - 30 3 * * * (UTC): the nightly base backup of records' databases to Cold Storage
  - `portal.sessions.purge`, 30 3 * * * (UTC+1 (Etc/GMT-1)): the night's purge of sessions ended or expired more than 30 days ago
- **Backups**:
  - streamed to `standby`, a replica in the off-site room at Lowmoor
  - WAL archived to Cold Storage, segment by segment
  - a base backup each night at 03:30 UTC to Cold Storage
  - the health page checks at 06:30 UTC that last night's base backup is in Cold Storage

### standby

- **Name**: `standby` (`ssh standby`, `psql -h standby`)
- **Role**: database server
- **Description**: The record's standby, a streaming replica of records where the back office's reports run their heavy reads.
- **Site**: the off-site room, at Lowmoor
- **System**: Debian GNU/Linux 13
- **Applications**: PostgreSQL 19; preloaded: pg_stat_statements; options: monitoring; report tools: pgbadger
- **Sizing**: CPU 1 (0.5 reserved), memory 1G (512M reserved), disk 2.25G
- **Your access**: write (`/etc/postgresql`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=standby&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**:
  - `backoffice`, database `clinic` as `vet_reports`: the back office; reads the whole medical record, owners' contact details included; writes nothing
  - `backoffice`, database `clinic` as `sched_reports`: the periodic reports, on the standby; reads every scheduling table; writes nothing
  - `exporter-standby`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `pgwatch`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `health`, database `postgres`: statistics, as monitoring (pg_monitor)
- **Uses**: none
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - itself the streaming replica of `records`; no backup of its own

### lab

- **Name**: `lab` (`ssh lab`, `psql -h lab`)
- **Role**: database server
- **Description**: The laboratory's database server, its orders, samples and results, the practices' accounts and their billing.
- **System**: Debian GNU/Linux 13
- **Applications**: PostgreSQL 19; preloaded: pg_stat_statements, pg_cron; report tools: pgbadger; cron
- **Sizing**: CPU 1 (0.5 reserved), memory 1G (512M reserved), disk 2.25G
- **Your access**: write (`/etc/postgresql`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=lab&from=now-6h&to=now)
- **Databases**:
  - `lab`: the laboratory: orders, samples, results, the practices' accounts and billing; register: [vet-lab-orders](data-register.md#vet-lab-orders-analysis-orders-and-their-samples), [vet-lab-results](data-register.md#vet-lab-results-results-their-validation-and-their-quality-control), [vet-lab-notifications](data-register.md#vet-lab-notifications-notifications-of-listed-diseases), [vet-lab-billing](data-register.md#vet-lab-billing-billing-the-practices), [vet-lab-round-trips](data-register.md#internal-data), [vet-lab-catalogue](data-register.md#internal-data), [vet-lab-practice-results](data-register.md#internal-data), [vet-lab-send-outs](data-register.md#internal-data), [vet-notifiable-diseases](data-register.md#internal-data), [vet-lab-critical-calls](data-register.md#internal-data)
- **Fed and used by**:
  - `lis`, database `lab` as `lab_app`: the laboratory information system; reads every laboratory table; writes orders, samples and their events, tests, results, critical calls, notifications, quality control runs, charges
  - `lis`, database `lab` as `lab_instruments`: the analysers' middleware; reads the samples, the tests ordered, the analytes, the reference intervals, the quality control runs; writes analyser batches and results
  - `interfaces`, database `lab` as `lab_dispatch`: the centre's jobs delivering results and sending tests out; reads the orders, their tests, samples and results, the accounts, the callbacks, the send-outs, the notifications; writes result callbacks, send-outs, sample events, notifications sent
  - `interfaces`, database `lab` as `lab_release`: the portal's release: reads the lab's released results
  - `backoffice`, database `lab` as `lab_reports`: the periodic reports and statements; reads every laboratory table; writes nothing
  - `lab-api`, database `lab` as `lab_api`: the laboratory's order API, for the practices and the external laboratory; reads the test catalogue and its reference intervals, the accounts, the orders, their samples, tests and results, the send-outs; writes new orders with their samples and tests, the external laboratory's answers and results
  - `exporter-lab`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `pgwatch`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `health`, database `postgres`: statistics, as monitoring (pg_monitor)
  - `lab`, database `lab` as `lab_watch`: pg_cron's job lab-critical-calls, on this server
- **Uses**: none
- **Users**: none
- **Third parties**:
  - [Cold Storage](partners.md#cold-storage): the WAL archive and the nightly base backup
- **Background tasks**:
  - 45 3 * * * (UTC): the nightly base backup of lab's databases to Cold Storage
  - `lab-critical-calls`, */10 * * * * (UTC+1 (Etc/GMT-1)): the watch on critical results not read back within the hour, escalated to the on-call pathologist
- **Backups**:
  - WAL archived to Cold Storage, segment by segment
  - a base backup each night at 03:45 UTC to Cold Storage
  - the health page checks at 06:30 UTC that last night's base backup is in Cold Storage

### machines

- **Name**: `machines` (`ssh machines`, `psql -h machines`)
- **Role**: database server
- **Description**: The machines' database server, the imaging worklist and reports, the monitors' readings and the biomedical events.
- **System**: Debian GNU/Linux 13
- **Applications**: PostgreSQL 19; preloaded: pg_stat_statements, pg_cron; options: monitoring; report tools: pgbadger; cron
- **Sizing**: CPU 1 (0.5 reserved), memory 1G (512M reserved), disk 2.25G
- **Your access**: write (`/etc/postgresql`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=machines&from=now-6h&to=now)
- **Databases**:
  - `jobs`: pg_cron's jobs (its cron.database_name): the partition jobs
  - `biomed`: biomedical engineering: the machines, their events, readings, maintenance and downtimes; register: [vet-machinery-equipment](data-register.md#vet-machinery-equipment-the-machine-registry-and-its-maintenance), [vet-machinery-logs](data-register.md#internal-data), [vet-machinery-telemetry](data-register.md#internal-data), [cold-storage-archive](data-register.md#internal-data)
  - `pacs`: imaging: the worklist, the procedures, the studies and the reports; register: [vet-machinery-imaging](data-register.md#vet-machinery-imaging-imaging-studies-and-their-reports), [vet-imaging-orders](data-register.md#internal-data)
  - `vitals`: the monitors: census, sessions, vital signs, charts and alarms; register: [vet-machinery-monitoring](data-register.md#vet-machinery-monitoring-monitoring-animals-in-theatre-and-intensive-care), [cold-storage-archive](data-register.md#internal-data)
- **Fed and used by**:
  - `equipment`, database `pacs` as `mach_pacs_app`: the imaging system (PACS), its worklist and the imaging machines; reads the imaging worklist, the procedures, the studies and the reports; writes the worklist's scheduling, identity and state, studies, series and reports
  - `equipment`, database `vitals` as `mach_vitals_app`: the central monitoring station and the patient monitors; reads every monitoring table; writes the monitoring census, sessions, vital signs, charts and alarms
  - `equipment`, database `biomed` as `mach_biomed_app`: biomedical engineering; reads every machine table; writes machine events, readings, maintenance and downtimes, a machine's status and next quality check
  - `interfaces`, database `pacs` as `mach_orders`: the imaging orders: posts the requests to the worklist, reads the reports
  - `interfaces`, database `vitals` as `mach_archive`: the archive: ships the closed day partitions to Cold Storage, then drops them
  - `interfaces`, database `biomed` as `mach_archive`: the archive: ships the closed day partitions to Cold Storage, then drops them
  - `exporter-machines`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `pgwatch`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `health`, database `postgres`: statistics, as monitoring (pg_monitor)
  - `machines`, database `vitals` as `mach_maint`: pg_cron's job vitals-partitions, on this server
  - `machines`, database `biomed` as `mach_maint`: pg_cron's job readings-partitions, on this server
  - `machines`, database `biomed` as `mach_maint`: pg_cron's job events-partitions, on this server
- **Uses**: none
- **Users**: none
- **Third parties**:
  - [Cold Storage](partners.md#cold-storage): the nightly base backup
- **Background tasks**:
  - 0 4 * * * (UTC): the nightly base backup of machines' databases to Cold Storage
  - `vitals-partitions`, 0 22 * * * (UTC+1 (Etc/GMT-1)): the coming days' partitions of the monitors' vital signs created
  - `readings-partitions`, 5 22 * * * (UTC+1 (Etc/GMT-1)): the coming days' partitions of the machines' readings created
  - `events-partitions`, 0 22 25 * * (UTC+1 (Etc/GMT-1)): next month's partition of the machines' events created
- **Backups**:
  - a base backup each night at 04:00 UTC to Cold Storage (no WAL archive)
  - the health page checks at 06:30 UTC that last night's base backup is in Cold Storage

## Applications and APIs

### pms

- **Name**: `pms` (`ssh pms`)
- **Role**: application
- **Description**: The practice software, from its vendor, for the record, the agenda, the ward screens and the portal's desk.
- **System**: Debian GNU/Linux 13
- **Applications**: the scheduler (gm-scheduler) 0.4.0
- **Sizing**: CPU 0.25 (0.1 reserved), memory 192M (96M reserved), disk 128M
- **Your access**: read-only
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=pms&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `records`, database `clinic` as `vet_app`: the practice-management software; reads the whole medical record and its reference tables; writes owners, animals and herds, referrals, consultations, diagnoses and procedures, requests, stays, alerts, exchanges with other centres, prescriptions, administrations and dispensings
  - `records`, database `clinic` as `housing_app`: the practice software's housing screens; reads the units, the displays, the placements, the feeding plans and the care log, and of the record what placing an animal needs; writes animals placed, moved and released, diets and feeding orders, a unit marked to clean
  - `records`, database `clinic` as `sched_app`: the practice software's scheduling module; reads the rooms, the opening hours, the machines, the appointment types, the courses, the bookings and the rota, and the free slots; writes bookings, room and machine allocations, the rota, absences, teaching sessions' state, trainees and enrolments
  - `portal-api`: the portal's API, for the portal's desk
- **Users**: none
- **Third parties**: none
- **Background tasks**:
  - `administrations-round`, 0 2,6,10,14,18,22 * * * (UTC): the ward round every four hours: the doses due given, the next round's doses planned
  - `prescriptions-expire`, 15 0 * * * (UTC): the night's expiry of prescriptions not dispensed in time
  - `rota-publish`, 0 12 * * 5 (UTC): the Friday rota: the seventh week ahead planned, the week after next published, its machine and theatre blocks booked
- **Backups**:
  - none

### lis

- **Name**: `lis` (`ssh lis`)
- **Role**: application
- **Description**: The laboratory's information system, from its vendor, for the bench, the analysers, the results and the quality control.
- **System**: Debian GNU/Linux 13
- **Applications**: the scheduler (gm-scheduler) 0.4.0
- **Sizing**: CPU 0.25 (0.1 reserved), memory 192M (64M reserved), disk 128M
- **Your access**: read-only
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=lis&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `lab`, database `lab` as `lab_app`: the laboratory information system; reads every laboratory table; writes orders, samples and their events, tests, results, critical calls, notifications, quality control runs, charges
  - `lab`, database `lab` as `lab_instruments`: the analysers' middleware; reads the samples, the tests ordered, the analytes, the reference intervals, the quality control runs; writes analyser batches and results
  - `clinic-api`: the clinic's lookup API: an animal's and its owner's identity
- **Users**: none
- **Third parties**: none
- **Background tasks**:
  - `lab-qc-morning`, 45 6 * * * (UTC): every analyser's quality control before the bench opens
  - `lab-qc-night`, 15 21 * * * (UTC): the on-call analysers' quality control before the night
  - `lab-release-round`, 0 11 * * * (UTC): the pathologist's round: validated results released, completed orders closed, charges billed
  - `lab-release-round-14`, 0 14 * * 1,2,3,4,5,6 (UTC): the pathologist's early afternoon round, Monday to Saturday, as the late morning one
  - `lab-release-round-18`, 0 18 * * 1,2,3,4,5,6 (UTC): the pathologist's evening round, Monday to Saturday, as the late morning one
  - `lab-samples-dispose`, 0 6 * * * (UTC): samples past their keeping date disposed of as clinical waste
  - `lab-identity`, * * * * * (UTC): the centre's new orders completed with the animal's identity, from the clinic's lookup API
- **Backups**:
  - none

### ward

- **Name**: `ward` (`ssh ward`)
- **Role**: application
- **Description**: The ward service, from its vendor, which drives the displays on every box and stall.
- **System**: Debian GNU/Linux 13
- **Applications**: the scheduler (gm-scheduler) 0.4.0
- **Sizing**: CPU 0.25 (0.1 reserved), memory 192M (64M reserved), disk 128M
- **Your access**: read-only
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=ward&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `records`, database `clinic` as `vet_display`: the ward displays; reads the animals' board and the housing units' board; writes nothing
  - `records`, database `clinic` as `housing_ward`: the ward service, the carers' actions on the displays; reads the units, the placements, the feeding plans, the care log and the units' board; writes care events, a unit marked clean
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

### equipment

- **Name**: `equipment` (`ssh equipment`)
- **Role**: application
- **Description**: The machines' feeds, from their vendors, for the imaging machines, the monitors and the biomedical equipment.
- **System**: Debian GNU/Linux 13
- **Applications**: the scheduler (gm-scheduler) 0.4.0
- **Sizing**: CPU 0.25 (0.1 reserved), memory 192M (64M reserved), disk 128M
- **Your access**: read-only
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=equipment&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `machines`, database `pacs` as `mach_pacs_app`: the imaging system (PACS), its worklist and the imaging machines; reads the imaging worklist, the procedures, the studies and the reports; writes the worklist's scheduling, identity and state, studies, series and reports
  - `machines`, database `vitals` as `mach_vitals_app`: the central monitoring station and the patient monitors; reads every monitoring table; writes the monitoring census, sessions, vital signs, charts and alarms
  - `machines`, database `biomed` as `mach_biomed_app`: biomedical engineering; reads every machine table; writes machine events, readings, maintenance and downtimes, a machine's status and next quality check
  - `clinic-api`: the clinic's lookup API: an animal's and its owner's identity for the imaging worklist
- **Users**: none
- **Third parties**: none
- **Background tasks**:
  - `mach-identity`, * * * * * (UTC): new imaging worklist entries completed with the animal's and its owner's identity, from the clinic's lookup API
  - `mach-census`, */5 * * * * (UTC): the animals in hospital copied to the monitoring census from the clinic's lookup API, intensive care sessions opened and closed
  - `vitals-chart`, */5 * * * * (UTC): the anaesthesia and intensive care charts summarised from the monitors' readings
- **Backups**:
  - none

### clinic-api

- **Name**: `clinic-api` (`ssh clinic-api`)
- **Role**: API
- **Description**: The lookup API the other centres, the lab and the machines call, from the practice software's vendor.
- **System**: Debian GNU/Linux 13
- **Applications**: FastAPI 0.162.0
- **Sizing**: CPU 0.25 (0.1 reserved), memory 128M (96M reserved), disk 128M
- **Your access**: read-only
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=clinic-api&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `records`, database `clinic` as `vet_lookup`: the lookup API the other centres, the lab and the machines call; reads the animals without their death, their owners' names without contact details, the stays' dates; writes nothing
  - `records`, database `clinic` as `vet_exchange`: the other centres' exchanges, answered through the clinic's API
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

### lab-api

- **Name**: `lab-api` (`ssh lab-api`)
- **Role**: API
- **Description**: The laboratory's order API, for the centre's orders, the practices' orders and the external lab's answers.
- **System**: Debian GNU/Linux 13
- **Applications**: FastAPI 0.162.0
- **Sizing**: CPU 0.25 (0.1 reserved), memory 128M (96M reserved), disk 128M
- **Your access**: write (`/srv/api/db`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=lab-api&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `lab`, database `lab` as `lab_api`: the laboratory's order API, for the practices and the external laboratory; reads the test catalogue and its reference intervals, the accounts, the orders, their samples, tests and results, the send-outs; writes new orders with their samples and tests, the external laboratory's answers and results
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

### portal-api

- **Name**: `portal-api` (`ssh portal-api`)
- **Role**: API
- **Description**: The owners' portal, their accounts, their animals' documents and their reminders.
- **System**: Debian GNU/Linux 13
- **Applications**: FastAPI 0.162.0
- **Sizing**: CPU 0.25 (0.1 reserved), memory 128M (96M reserved), disk 128M
- **Your access**: write (`/srv/api/db`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=portal-api&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `records`, database `portal` as `portal_api`: the owners' portal API; reads the owners' animals, ownerships, herds and documents, as each account may see them, its own account and the portal's settings; writes logins and sessions, documents viewed, consent changes, an account's notification choices
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

## Integration and back-office engines

### interfaces

- **Name**: `interfaces` (`ssh interfaces`)
- **Role**: integration engine
- **Description**: The centre's integration jobs, for the lab orders and results, the send-outs, the other centres, the notifications, the imaging orders, the portal and the archive.
- **System**: Debian GNU/Linux 13
- **Applications**: the scheduler (gm-scheduler) 0.4.0
- **Sizing**: CPU 0.25 (0.1 reserved), memory 192M (96M reserved), disk 128M
- **Your access**: write (`/srv/scheduler/repository`, `/srv/scheduler/jobs`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=interfaces&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `records`, database `clinic` as `vet_interfaces`: the integration jobs on the record: lab orders, the other centres' exchanges, notifiable diseases, bookings, imaging orders
  - `lab`, database `lab` as `lab_dispatch`: the centre's jobs delivering results and sending tests out; reads the orders, their tests, samples and results, the accounts, the callbacks, the send-outs, the notifications; writes result callbacks, send-outs, sample events, notifications sent
  - `records`, database `clinic` as `sched_interfaces`: the integration jobs on the agenda: check-ins, bookings, deaths
  - `machines`, database `pacs` as `mach_orders`: the imaging orders: posts the requests to the worklist, reads the reports
  - `machines`, database `vitals` as `mach_archive`: the archive: ships the closed day partitions to Cold Storage, then drops them
  - `machines`, database `biomed` as `mach_archive`: the archive: ships the closed day partitions to Cold Storage, then drops them
  - `records`, database `clinic` as `vet_portal_sync`: the portal's release: reads what the record may publish
  - `lab`, database `lab` as `lab_release`: the portal's release: reads the lab's released results
  - `records`, database `portal` as `portal_sync`: the portal's release: writes the record's released copies
  - `records`, database `portal` as `portal_dispatch`: the portal's messages: hands the notices and reminders to the messaging service
  - `lab-api`: the lab's order API: the centre's lab orders and their results
  - The region's practices: the practices' results, delivered
  - Northfield Veterinary Laboratories: the send-outs and their results
  - Aldermoor Central: the exchanges with the franchise's other centres
  - Aldermoor South: the exchanges with the franchise's other centres
  - Aldermoor abroad: the exchanges with the franchise's other centres
  - The veterinary authority: the notifications of listed diseases
  - Cold Storage: the machines' day partitions, shipped to the vault
  - The franchise's messaging service: the portal's notices and reminders, handed over for sending
- **Users**: none
- **Third parties**:
  - [The region's practices](partners.md#the-regions-practices): the practices' results, delivered
  - [Northfield Veterinary Laboratories](partners.md#northfield-veterinary-laboratories): the send-outs and their results
  - [Aldermoor Central](partners.md#aldermoor-central): the exchanges with the franchise's other centres
  - [Aldermoor South](partners.md#aldermoor-south): the exchanges with the franchise's other centres
  - [Aldermoor abroad](partners.md#aldermoor-abroad): the exchanges with the franchise's other centres
  - [The veterinary authority](partners.md#the-veterinary-authority): the notifications of listed diseases
  - [Cold Storage](partners.md#cold-storage): the machines' day partitions, shipped to the vault
  - [The franchise's messaging service](partners.md#the-franchises-messaging-service): the portal's notices and reminders, handed over for sending
- **Background tasks**:
  - `post-lab-orders`, * * * * * (UTC): the analysis requests still requested whose consultation has closed, grouped by consultation and priority, each group posted as one order keyed C-(consultation)-(priority), and in one transaction after the calls the attempts recorded and the answered groups' requests sent
  - `fetch-lab-results`, */5 * * * * (UTC): the centre's tests released, not performed or cancelled since the watermark less a margin, read from lab-api's feed, each request copied once and moved to resulted or cancelled, the watermark advanced, and the requests unanswered past turnaround plus two hours escalated once
  - `deliver-practice-results`, * * * * * (UTC): the practices' deliveries due (an interim on a several-test order's first release, the final at its completion, one per amendment) with no acknowledged attempt, each posted to its own account's callback under its delivery_key, four at a time, an attempt five minutes after the last at most six times, then one incident; one lab_callbacks row per attempt
  - `send-outs`, 0 16 * * 1,2,3,4,5 (UTC): the day's send-outs: each test routed out whose sample is received and which has no send-out yet packed (a lab_send_outs row, its send_key one per test, a sent-out sample event) and posted to the external lab with the catalogue's fields only, the external accession and due time kept on acceptance
  - `chase-send-outs`, */15 * * * * (UTC): acting 08:00 to 19:59 Monday to Saturday in the lab's local time only (every 15 minutes, returning at once outside, spec D436): the send-outs not accepted posted again with their send_key, escalated once from 19:45 on their packing day; the accepted ones unanswered a working day past their due time chased (resend, an incident row each), twice a working day apart, then escalated once
  - `sync-exchanges`, */5 * * * * (UTC): the outbound requests not yet sent (POST /exchanges to the centre's hostname, with the animal's identity, its record's summary and its current owner's name and contact; sent once the call returns 2xx), the inbound answers and reports not yet posted (POST /exchanges/{key}/answer and /report), each post one ops.exchange_messages row with its HTTP status, and one ops.runs row, in one transaction after the calls.
  - `chase-exchanges`, 0 9 * * 1,2,3,4,5 (UTC): on working days, the outbound requests sent and unanswered: a working day after sending resent once with the same exchange_key, two working days after sending one ops.incidents row (kind unanswered, ref the key), once; each resend one ops.exchange_messages row, and one ops.runs row.
  - `notify-vet`, */5 * * * * (UTC): the notifiable diagnoses (suspected or confirmed) recorded since the vet watermark with no notification, posted to the authority keyed vet- and the diagnosis id, with the disease, species, holding or keeper's name and address, the vet and the date, one ops.notifications row each; the unreferenced ones of the last two days whose last post got no answer or a 5xx posted again; one ops.runs row.
  - `notify-lab`, */5 * * * * (UTC): the lab's notifications not yet notified, every customer's, posted keyed lab- and the notification's id, one ops.notifications row each, the retries as notify-vet's; a referenced one's notified_at, channel and authority_ref written back; one ops.runs row.
  - `escalate-notifications`, */15 * * * * (UTC): in each database, the notifications with no reference past their deadline, or rejected, and no incident: one ops.incidents row each, once; one ops.runs row in each database.
  - `check-in`, * * * * * (UTC): the consultation bookings arrived since its watermark (less ten minutes) with no consultation carrying their id: each consultation opened in the core (scheduled, the booking's section, its allocated vet, started at the arrival, booking_id), its ops.booking_consultations row, the run's ops.runs row and the watermark in one clinic transaction.
  - `book-requests`, * * * * * (UTC): the imaging requests recorded since its watermark with no live booking, each booked on its study's machine by sched_free_slots (an urgent one at the machine's first free slot, a routine one within two working days); the inbound examinations accepted since then, booked as 28 000 + the exchange id on their accepted date, or the first free slot after it with an ops.incidents row; one agenda transaction with the run's row.
  - `cancel-deceased`, * * * * * (UTC): the animals recorded died since its watermark: their future bookings still booked cancelled (reason deceased), the release trigger freeing their slots, with the run's row.
  - `post-imaging-orders`, * * * * * (UTC): the imaging requests still requested whose consultation has closed: one worklist entry each in pacs (accession I-4711 for request 4711, ids and the study's procedure only, ON CONFLICT (accession) DO NOTHING) with the run's ops.runs row there, committed first; then the requests sent in clinic with the run's row there.
  - `fetch-imaging-reports`, */5 * * * * (UTC): from pacs, the finals signed and the entries cancelled since their watermarks (less ten minutes); in one clinic transaction each final's copy in ops.imaging_results and its request resulted, each cancelled entry's request cancelled, each sent request past its turnaround with no final one ops.incidents row (overdue), the watermarks and the run's row.
  - `ship-partitions`, 40 0-5 * * * (UTC): for vitals (vitals) and machine-readings (biomed), each day partition older than the window read from the settings: for the readings the day's mach_readings_daily first, committed; the rows as NDJSON posted to cold storage's POST /shipments (shipment id the type and the day, the same on a resend; source the node); on a receipt counting every row, mach_drop_shipped(day); per database one transaction with the run's ops.runs row, the ops.shipments rows and, from the local hour last_hour, one unshipped incident per day still on site.
  - `sync-portal-identity`, */5 * * * * (UTC): from clinic, since the watermark (less two minutes): the owners registered, an account invited each with its invitation queued (random one-time link, kept hashed), an owner with an account never touched; the animals registered or dead, the ownerships started or ended, the herds whose keeper changed, upserted into the copies; in one portal transaction with the watermark and the run's ops.runs row.
  - `publish-records`, */5 * * * * (UTC): from clinic, the consultations signed and the stays ended since the watermark: a document each, version 1 (C- or S- and the record's id), its body the diagnoses' labels and the prescriptions, or the stay's dates and outcome, no free text; a document already published skipped by its reference and version; in one portal transaction with the watermark and the run's row.
  - `publish-results`, */5 * * * * (UTC): from lab, account 1's order tests released and their results amended since the watermark: a document (T- and the test's id) at the release (the values in force), a new version at each amendment, the former superseded; the pathologist's name from clinic's staff; in one portal transaction with the watermark and the run's row.
  - `queue-notices`, */5 * * * * (UTC): the documents published since the watermark (less two minutes): one document-notice queued for each account that sees it (the current owner, a keeper granted access now, a herd's keeper), active, its channel not none, once per document and account; in one portal transaction with the watermark and the run's ops.runs row.
  - `queue-reminders`, 0 9 * * * (UTC): at 09:00 local, the domestic animals and horses alive in the copy whose yearly due day is 14 days ahead, whose current owner's account is not closed and whose latest reminders event is a grant: one reminder per animal and due day, with its withdrawal link; with the run's row.
  - `send-messages`, * * * * * (UTC): the outbox's unsent rows, oldest first (reminders only from 08:00 to 20:00 local, their consent, owner, animal and account checked again), each posted to the messaging service with its message key, five seconds' timeout; 202 provider_id and sent_at; otherwise the attempt counted and retried with the same key, at the sixth failed_at and one ops.incidents row; then one portal transaction with the run's row.
- **Backups**:
  - none

### backoffice

- **Name**: `backoffice` (`ssh backoffice`)
- **Role**: back-office engine
- **Description**: The back office's reports, the medicines and controlled-drugs registers, the antimicrobial use, the working time, the head office's figures and the practices' statements.
- **Site**: the off-site room, at Lowmoor
- **System**: Debian GNU/Linux 13
- **Applications**: the scheduler (gm-scheduler) 0.4.0
- **Sizing**: CPU 0.25 (0.1 reserved), memory 256M (192M reserved), disk 128M
- **Your access**: write (`/srv/scheduler/repository`, `/srv/scheduler/jobs`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=backoffice&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `standby`, database `clinic` as `vet_reports`: the back office; reads the whole medical record, owners' contact details included; writes nothing
  - `lab`, database `lab` as `lab_reports`: the periodic reports and statements; reads every laboratory table; writes nothing
  - `records`, database `office` as `office_jobs`: the back office's jobs: write the registers, the reports and the figures
  - `standby`, database `clinic` as `sched_reports`: the periodic reports, on the standby; reads every scheduling table; writes nothing
  - The veterinary authority: the yearly antimicrobial-use report
  - The franchise's head office: the monthly activity figures
- **Users**: none
- **Third parties**:
  - [The veterinary authority](partners.md#the-veterinary-authority): the yearly antimicrobial-use report
  - [The franchise's head office](partners.md#the-franchises-head-office): the monthly activity figures
- **Background tasks**:
  - `copy-notifications`, 15 2 * * * (UTC): yesterday's notifications (the customer's local date), both databases, not yet copied: one regulatory_submissions row each in office (kind notifiable-disease), and one runs row.
  - `feed-medicines-register`, 30 1 * * * (UTC): yesterday's supplies (the customer's local date): each dispensing and each dose given, with the product, its form and authorisation number, the batch, the quantity, the recipient (the owner's name and address for a dispensing, the centre for a dose given) and the prescribing vet, read on the standby (meds.register.read), one medicines_register line each, once a day; one runs row.
  - `feed-controlled-drugs`, 45 1 * * * (UTC): yesterday's movements of controlled medicines (dispensings and doses given, out of their batches; meds.controlled.read), one controlled_movements row each, once a day; one runs row.
  - `close-medicines-register`, 0 3 * * * (UTC): run daily, acting on the 1st only (the customer's local date; any other day writes nothing): the past month's extract from the register, per product its lines, quantity and checksum (meds.close.compute), once a month; one runs row.
  - `balance-controlled-drugs`, 15 3 * * * (UTC): run daily, acting on the 1st only: each controlled batch's past month, the opening (the previous closing, else the quantity received), the month's movements and the closing (meds.balance.compute), signed by the centre's senior vet, once a month; one runs row.
  - `inventory-controlled-drugs`, 30 3 * * * (UTC): run daily, acting on 1 January only: each controlled batch's stock at the year's start, December's closing (meds.inventory.compute), once a year; one runs row.
  - `feed-antimicrobial-use`, 0 2 * * * (UTC): yesterday's use of antimicrobials (the customer's local date), doses given and dispensings, per species and ATCvet code, a herd treatment under its herd's species: doses, dispensings, quantity, animals and herds treated (amu.feed.read on the standby), once a day; one runs row.
  - `report-antimicrobial-use`, 0 4 * * * (UTC): run daily, acting on 15 January only (the customer's local date; any other day writes nothing): last year's report for each species due that day, summed from the daily rows (amu.report.compute), posted to the authority's POST /amu-reports (up to three attempts); acknowledged, its reference and a regulatory_submissions copy (kind amu-report); else escalated; one runs row.
  - `feed-working-time`, 30 9 * * * (UTC): the shifts that started yesterday (the customer's local date), every night shift clocked out by 09:30: per staff member the shifts, planned hours (on call excluded), hours worked as clocked (on call its call-out only), night hours, call-outs (worktime.feed.read, as sched_reports, the names as vet_reports); each shift on site whose rest since the previous one on site is under 11 hours a breach (worktime.feed.rests); once a day; one runs row.
  - `close-working-time`, 0 5 * * * (UTC): run daily, acting on the 1st only (the customer's local date; any other day writes nothing): each staff member's past month from the daily rows, hours, night hours, call-outs, breaches, and the weekly average over the last four months (worktime.close.compute); one runs row.
  - `feed-daily-figures`, 30 0 * * * (UTC): yesterday's figures (the customer's local date), one row per section and measure: per section of the centre the consultations begun per kind, the stays admitted and ended, the stays, the units occupied and the units in service at the day's closing midnight (figures.feed.read on the standby); the new owners and animals; the lab's tests released per discipline and priority, the outside orders placed and their tests' median turnaround (figures.feed.lab on the lab), once a day; one runs row.
  - `send-monthly-figures`, 0 5 * * * (UTC): run daily, acting on the 1st to the 5th only (the customer's local date; any other day writes nothing): the past month's figures per section and measure, summed from the daily rows (the turnaround the median of its days', figures.send.compute) on its first run and kept, posted to the head office's POST /figures (up to three attempts a run); acknowledged, its reference kept; still unacknowledged after the 5th's attempts, escalated; a month acknowledged or escalated not sent again; one runs row.
  - `feed-lab-charges`, 30 2 * * * (UTC): yesterday's charge events of the practices' accounts (the customer's local date): each charge made billable that day (its release's date) and each voided that day, with its order, test, kind, amount, the order's patient reference and client surname (charges.feed.read on the lab), once a day; never the centre's account; one runs row.
  - `close-lab-statements`, 0 4 * * * (UTC): run daily, acting on the 1st only (the customer's local date; any other day writes nothing): each practice account's statement for the past month from the feeder's lines (charges.close.compute): the billable lines summed, less the month's voids of charges stated, the bracket by the total (3 % from 0, 5 % from 200, 10 % from 400, 15 % from 600, game values), the discount on the total rounded once, the amount due; one runs row.
- **Backups**:
  - none

## Monitoring

### prometheus

- **Name**: `prometheus` (`ssh prometheus`)
- **Role**: monitoring
- **Description**: Prometheus, which collects the metrics.
- **System**: Debian GNU/Linux 13
- **Applications**: Prometheus 3.16.0
- **Sizing**: CPU 0.5 (0.1 reserved), memory 384M (160M reserved), disk 512M
- **Your access**: read-only
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=prometheus&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `exporter-records`: metrics scrape
  - `exporter-standby`: metrics scrape
  - `exporter-lab`: metrics scrape
  - `exporter-machines`: metrics scrape
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

### grafana

- **Name**: `grafana` (`ssh grafana`)
- **Role**: monitoring
- **Description**: Grafana, the dashboards and the alert rules.
- **Site**: the off-site room, at Lowmoor
- **System**: Debian GNU/Linux 13
- **Applications**: Grafana 13.3.1
- **Sizing**: CPU 0.5 (0.1 reserved), memory 384M (272M reserved), disk 256M
- **Your access**: write (`/etc/grafana/provisioning`, `/etc/grafana/provisioning/alerting`, `/etc/grafana/provisioning/dashboards`, `/etc/grafana/provisioning/datasources`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=grafana&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `prometheus`: dashboards' queries
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

### exporter-records

- **Name**: `exporter-records` (`ssh exporter-records`)
- **Role**: monitoring
- **Description**: The PostgreSQL exporter for records.
- **System**: Debian GNU/Linux 13
- **Applications**: postgres_exporter 0.20.1
- **Sizing**: CPU 0.25 (0.05 reserved), memory 128M (48M reserved), disk 64M
- **Your access**: write (`/etc/postgres-exporter`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=exporter-records&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `records`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

### exporter-standby

- **Name**: `exporter-standby` (`ssh exporter-standby`)
- **Role**: monitoring
- **Description**: The PostgreSQL exporter for the standby.
- **System**: Debian GNU/Linux 13
- **Applications**: postgres_exporter 0.20.1
- **Sizing**: CPU 0.25 (0.05 reserved), memory 128M (48M reserved), disk 64M
- **Your access**: write (`/etc/postgres-exporter`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=exporter-standby&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `standby`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

### exporter-lab

- **Name**: `exporter-lab` (`ssh exporter-lab`)
- **Role**: monitoring
- **Description**: The PostgreSQL exporter for lab.
- **System**: Debian GNU/Linux 13
- **Applications**: postgres_exporter 0.20.1
- **Sizing**: CPU 0.25 (0.05 reserved), memory 128M (48M reserved), disk 64M
- **Your access**: write (`/etc/postgres-exporter`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=exporter-lab&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `lab`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

### exporter-machines

- **Name**: `exporter-machines` (`ssh exporter-machines`)
- **Role**: monitoring
- **Description**: The PostgreSQL exporter for machines.
- **System**: Debian GNU/Linux 13
- **Applications**: postgres_exporter 0.20.1
- **Sizing**: CPU 0.25 (0.05 reserved), memory 128M (48M reserved), disk 64M
- **Your access**: write (`/etc/postgres-exporter`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=exporter-machines&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `machines`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

### pgwatch

- **Name**: `pgwatch` (`ssh pgwatch`)
- **Role**: monitoring
- **Description**: pgwatch, a second collector of PostgreSQL metrics.
- **System**: Debian GNU/Linux 13
- **Applications**: pgwatch 6.1.0
- **Sizing**: CPU 0.25 (0.1 reserved), memory 128M (96M reserved), disk 64M
- **Your access**: write (`/etc/pgwatch`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=pgwatch&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `records`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `standby`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `lab`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
  - `machines`, database `postgres` as `monitoring`: statistics, as monitoring (pg_monitor)
- **Users**: none
- **Third parties**: none
- **Background tasks**: none
- **Backups**:
  - none

### health

- **Name**: `health` (`ssh health`)
- **Role**: monitoring
- **Description**: The IT's health checks, check_postgres and their own scripts, and their page.
- **Site**: the off-site room, at Lowmoor
- **System**: Debian GNU/Linux 13
- **Applications**: check_postgres 2.26.0; cron
- **Sizing**: CPU 0.25 (0.1 reserved), memory 128M (64M reserved), disk 64M
- **Your access**: write (`/etc/health`)
- **Activity**: [Node health](/grafana/d/node-health/node-health?var-node=health&from=now-6h&to=now)
- **Databases**: none
- **Fed and used by**: none
- **Uses**:
  - `records`, database `postgres`: statistics, as monitoring (pg_monitor)
  - `standby`, database `postgres`: statistics, as monitoring (pg_monitor)
  - `lab`, database `postgres`: statistics, as monitoring (pg_monitor)
  - `machines`, database `postgres`: statistics, as monitoring (pg_monitor)
- **Users**: none
- **Third parties**:
  - [Cold Storage](partners.md#cold-storage): the morning check that last night's base backups are there
- **Background tasks**:
  - */5 * * * * (UTC): the health page's checks on the four database servers (check_postgres over health.yaml)
  - */5 * * * * (UTC): the IT's disk alarm on records' databases: warning at 2 GB, critical at 4 GB
  - */5 * * * * (UTC): the IT's disk alarm on lab's databases: warning at 2 GB, critical at 4 GB
  - */5 * * * * (UTC): the IT's disk alarm on machines' databases: warning at 2 GB, critical at 4 GB
  - 30 6 * * * (UTC): is records' base backup of last night in Cold Storage? after its nightly backup
  - 30 6 * * * (UTC): is lab's base backup of last night in Cold Storage? after its nightly backup
  - 30 6 * * * (UTC): is machines' base backup of last night in Cold Storage? after its nightly backup
- **Backups**:
  - none

## Third parties

Each partner is reached by its hostname on the network; you have no access to its machines. What each offers is in [the partners' page](partners.md).

| Partner | Hostname | Your access |
|---|---|---|
| [Northfield Veterinary Laboratories](partners.md#northfield-veterinary-laboratories) | `northfield-lab` | none |
| [The region's practices](partners.md#the-regions-practices) | `practices` | none |
| [Aldermoor Central](partners.md#aldermoor-central) | `aldermoor-central` | none |
| [Aldermoor South](partners.md#aldermoor-south) | `aldermoor-south` | none |
| [Aldermoor abroad](partners.md#aldermoor-abroad) | `aldermoor-abroad` | none |
| [The franchise's head office](partners.md#the-franchises-head-office) | `head-office` | none |
| [The franchise's messaging service](partners.md#the-franchises-messaging-service) | `messaging` | none |
| [Cold Storage](partners.md#cold-storage) | `cold-storage` | none |
| [The veterinary authority](partners.md#the-veterinary-authority) | `authority` | none |
