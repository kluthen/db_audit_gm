# Facebook and Instagram: user passwords found unmasked in internal data storage

- **Source**: [Keeping Passwords Secure](https://about.fb.com/news/2019/03/keeping-passwords-secure/) (Meta newsroom, 2019-03-21, updated 2019-04-18). Archive: [web.archive.org snapshot](https://web.archive.org/web/20261011021854/https://about.fb.com/news/2019/03/keeping-passwords-secure/)
- **Date of incident**: discovered in January 2019 during a routine security review; announced 2019-03-21. How long the passwords had been stored is not stated.
- **Organization**: Facebook (now Meta), including Instagram
- **Kind of write-up**: official company statement (not a technical post-mortem)

## Tech stack

- "Internal data storage systems" (for Instagram, logs). No engine, pipeline or logging system named.

## Topology

- Not stated.

## Symptoms

- None user-visible. Found by a regular security check.

## Diagnosis

- Routine security review in January 2019; a later review found additional Instagram passwords "in a readable format" in logs.

## Root cause / main culprits

- Passwords stored unmasked in internal storage although the login systems are designed to mask them. The statement gives no technical root cause (which component wrote them, or why).

## Resolution

- Issues fixed; affected users notified as a precaution; other data types such as access tokens reviewed and problems fixed.

## Impact and duration

- Estimated hundreds of millions of Facebook Lite users, tens of millions of other Facebook users, and (after the update) millions of Instagram users. The company says the passwords were "never visible to anyone outside of Facebook" and it found no evidence of internal abuse.

## Notes (collector's own, not from the source)

- Included for the data-governance category ("personal data or secrets leaking into logs or internal stores") despite the thin technical detail. In a PostgreSQL lab the same culprit is `log_statement = 'all'` or `log_min_duration_statement = 0` on a database where the application sends credentials or personal data as literals, so they land in the server log and in pgBadger reports.
