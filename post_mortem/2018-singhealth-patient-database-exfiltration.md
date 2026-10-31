# SingHealth: attackers query the patient database through Citrix servers, 1.5 million records taken unnoticed

- **Source**: [Public Report of the Committee of Inquiry into the cyber attack on SingHealth](https://go.gov.sg/singhealthcoi) (PDF, 454 pages, released 2019-01-10; resolves to file.go.gov.sg/singhealthcoi.pdf). Announcement page: [MDDI newsroom](https://www.mddi.gov.sg/newsroom/public-report-of-the-coi/). Archive: [web.archive.org snapshot of the PDF link](https://web.archive.org/web/20250403014956/https://go.gov.sg/singhealthcoi), [snapshot of the announcement](https://web.archive.org/web/20260702045330/https://www.mddi.gov.sg/newsroom/public-report-of-the-coi/)
- **Date of incident**: initial intrusion around 2017-08-23; database queried and data exfiltrated 2018-06-27 to 2018-07-04; last malicious activity 2018-07-19
- **Organization**: Singapore Health Services (SingHealth), with IHiS operating its IT systems
- **Kind of write-up**: official public inquiry report (government Committee of Inquiry)

## Tech stack

- Sunrise Clinical Manager (SCM) electronic medical records system: front-end workstations, Citrix servers, and the SCM database. The public report withholds network architecture and exploited vulnerabilities (they are in the classified version); it does not name the database engine in the summary (a 2014 internal discussion it recounts mentions "Microsoft's SQL server").

## Topology

- Users reach the SCM database through Citrix servers acting as intermediary. An "open network connection" existed between the SGH Citrix servers and the SCM database, kept for administrative tools and custom applications "but there was no necessity to do so".

## Symptoms

- IT administrators saw unauthorised logins to Citrix servers and failed attempts to access the SCM database on 2018-06-11, 12, 13 and 26. On 2018-07-04 an SCM administrator noticed suspicious queries on the database.

## Diagnosis

- Administrators terminated the ongoing queries and blocked further queries from 2018-07-04. Senior management was told on 2018-07-09; the Cyber Security Agency on 2018-07-10, after which joint investigation began.
- The report reconstructs over 200 SQL queries in three kinds: reconnaissance on the schema and test queries, direct queries on specific individuals, and bulk queries on patients in general. Some were run with a program not legitimately used in the environment.

## Root cause / main culprits

- Database-related: the unnecessary network path from Citrix servers to the database; database credentials obtained, likely via a coding vulnerability in the SCM application; "a lack of monitoring at the SCM database for unusual queries and access" (no controls to detect bulk queries or queries from illegitimate applications; no database activity monitoring).
- Access: 2FA for administrator access not enforced as the only way in; weak administrator passwords; remediation of a 2017 penetration test mismanaged.
- People and process: staff did not recognise the signs or escalate; the incident response manager delayed reporting.

## Resolution

- Containment with the Cyber Security Agency; internet surfing separation for SingHealth from 2018-07-20; public announcement on 2018-07-20 and patient outreach (2.16 million patients to contact).
- Sixteen recommendations (seven priority), from defence-in-depth and a reviewed security stack to staff awareness, incident response and, explicitly, database activity monitoring.

## Impact and duration

- Personal particulars of almost 1.5 million patients exfiltrated; about 159,000 also had outpatient dispensed-medication records taken. The Prime Minister's data was specifically targeted.

## Notes (collector's own, not from the source)

- The most detailed healthcare database write-up found. The game-relevant culprits are governance ones: a bastion-like jump host with a direct path to the clinical database, shared or stealable database credentials, and no audit of who runs bulk `SELECT`s. In PostgreSQL terms: `pg_hba.conf` open to a whole subnet, an application role reused by humans, and no `log_statement`/pgAudit.
