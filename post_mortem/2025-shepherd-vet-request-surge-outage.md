# Shepherd Veterinary Solutions: heavy queries surge and take the practice-management app down for all clinics

- **Source**: [Shepherd Application System Outage](https://status.shepherd.vet/incidents/lh2fw90b2h43) (Shepherd status page, incident report and postmortem posted 2025-09-24). Archive: no web.archive.org snapshot found (checked 2026-10-31).
- **Date of incident**: 2025-09-17, 16:28 to 17:01 ET per the incident timeline (the postmortem text says service was restored at "3:01 PM", which conflicts)
- **Organization**: Shepherd Veterinary Solutions (veterinary practice-management software)
- **Kind of write-up**: official status-page postmortem (short)

## Tech stack

- A "main database" and planned "read-only systems" are mentioned; engines, versions and hosting not stated. Affected services: the Shepherd application, SMS texting, AI services, and the OpenAPI integrations ("Clinic Connect").

## Topology

- Not stated. The follow-ups talk about "the main database" and about an issue in one area that should not impact all practices, which suggests (collector's inference) one shared database for every clinic.

## Symptoms

- All users lost access to the application.

## Diagnosis

- The outage "was triggered by a sudden spike in database requests": load rose from about 150 requests at a given time to "over 1,000 requests within just a few minutes", exhausting system resources. The report says existing queries unexpectedly used far more resources than usual and that it was not caused by a recent release. The exact trigger was still under investigation.

## Root cause / main culprits

- Not determined in the report. Stated contributing condition: heavy or long-running queries running on the main database that every clinic depends on.

## Resolution

- Service restored (method not described).
- Follow-ups: lower alert threshold on request volume to give engineers several extra minutes; move heavy and long-running queries off the main database to read-only systems; reduce single points of failure so one problem does not affect every practice. "No repeating pattern has been observed in the days since the outage."

## Impact and duration

- About 33 minutes, all clinics.

## Notes (collector's own, not from the source)

- The only veterinary-sector database incident found with any published cause, and it is thin. Still a close fit for the next version's clinic franchise: reporting-style queries on the primary of a multi-clinic database, with the follow-up being a read replica for them.
