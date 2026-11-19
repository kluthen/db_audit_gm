# Aldermoor Veterinary Hospital North

Aldermoor Veterinary Hospitals is a regional franchise of veterinary
hospitals: three national centres, North, Central and South, three
centres abroad, in Liège, Aachen and Luxembourg, and a head office. Each
centre keeps its own records and its own systems; the franchise's
agreement lets the centres exchange what they need about a patient they
share.

You are auditing **Aldermoor Veterinary Hospital North** (site `ALD-N`,
1 Hospital Road, Aldermoor): a small-animal and farm practice with an
emergency service open day and night, wards of boxes and stalls, an
operating suite, imaging and monitoring machines, a training centre, an
owners' portal, and a laboratory that also serves the region's practices,
about 120 of them, who pay for its tests. The centre works in
{{customer_timezone}}: every time of day in this story, in the issues, the
data policy, the partners' file and the data register is in that zone.
Days are busiest from 08:00 to 19:00; the emergency service, the wards and
the night's integration jobs and reports keep the systems busy all night.

## The system

- **The record** (`records`, PostgreSQL 19): the medical record, the
  agenda and the wards in the database `clinic`; the back office's
  registers and reports in `office`; the owners' portal's accounts and
  copies in `portal`. Its write-ahead log is archived to Cold Storage,
  the franchise's off-site archive, and a base backup is sent there every
  night.
- **The standby** (`standby`, PostgreSQL 19), a streaming replica of
  `records` in the centre's **off-site room**, a rented rack in a second
  building at Lowmoor. It is readable: the back office's reports run
  their heavy reads there.
- **The laboratory's server** (`lab`, PostgreSQL 19, database `lab`):
  orders, samples, results, the practices' accounts and their billing.
  It archives to Cold Storage as `records` does.
- **The machines' server** (`machines`, PostgreSQL 19): the imaging
  archive's worklist and reports (`pacs`), the monitors' readings
  (`vitals`) and the biomedical events (`biomed`). It sends a base
  backup to Cold Storage every night, and its old days are shipped there
  and dropped.
- **The applications**, from their vendors: the practice software
  (`pms`: the record, the agenda, the ward screens, the portal's desk),
  the lab's information system (`lis`), the ward service that drives the
  displays on every box and stall (`ward`), the machines' feeds
  (`equipment`). The centre runs them as delivered: it can ask the
  vendors for changes, not make them.
- **The APIs**: the lookup API the other centres call (`clinic-api`,
  the practice software vendor's), the lab's order API (`lab-api`: the
  centre's orders, the practices' orders, the external lab's answers),
  and the owners' portal (`portal-api`). The lab's and the portal's are
  the centre's own.
- **The centre's own jobs**: the integration jobs (`interfaces`: the lab
  orders and their results, the practices' results, the send-outs to the
  external lab, the exchanges with the other centres, the notifications
  of listed diseases, the imaging orders, the portal's publishing and
  messages, the machines' old days to Cold Storage) and the back office's
  reports (`backoffice`, in the off-site room: the medicines and
  controlled-drugs registers, the antimicrobial use, the working time,
  the head office's figures, the practices' statements).
- **Monitoring**: Prometheus, an exporter per database server, pgwatch,
  Grafana and the IT's health checks (`check_postgres` and their own
  scripts) watch the systems; Grafana and the health checks run in the
  off-site room. Every machine reports its own health.
- **The partners** (`partners.md`): Northfield Veterinary Laboratories,
  the external reference lab; the region's practices; the other centres;
  the head office; the franchise's messaging service; Cold Storage; the
  veterinary authority. Their systems are theirs: you can call what they
  publish, with the centre's credentials, and nothing more.

Dr Lars Wagner, the centre's senior vet, signs the controlled-drugs
register's monthly balances.

## Why you are here

Nadia Okafor, the centre's operations manager, has two complaints on her
desk (`issues.md`): the emergency team's, about urgent tests at night,
and a question from the vets about the external lab.

She would like an audit of the centre's data and of everything that moves
it: the problems fixed where the centre may fix them, and clear
recommendations, for the centre, a vendor or a partner, where it may not.
She hands over the franchise's data policy for the centre
(`data-policy.md`), the partners' file (`partners.md`) and the centre's
data register (`data-register.md`): she expects the systems to do what
they say. The franchise's data-protection officer, at the head office,
answers for the register.

The centre is open while you work: animals keep arriving, the lab keeps
working, and nobody will stop or slow anything for you.
