# Basecamp 3: the events table's 32-bit ID runs out, the app goes read-only for five hours

- **Source**: [Postmortem on the read-only outage of Basecamp on November 9th, 2018](https://signalvnoise.com/svn3/postmortem-on-the-read-only-outage-of-basecamp-on-november-9th-2018/) (Signal v. Noise, Basecamp). Archive: [web.archive.org snapshot](https://web.archive.org/web/20260120091637/https://signalvnoise.com/svn3/postmortem-on-the-read-only-outage-of-basecamp-on-november-9th-2018/)
- **Date of incident**: dated 2018-11-09 in the post (07:21 to 12:11 CST). Secondary coverage and the linked status-update URLs say 2018-11-08.
- **Organization**: Basecamp
- **Kind of write-up**: official post-mortem

## Tech stack

- Ruby on Rails. The database engine and version are not stated in the post.

## Topology

- Not stated.

## Symptoms

- Users could read messages, to-dos and files but could not create or change anything: almost every action writes to the events table.

## Diagnosis

- The post does not describe the diagnostic steps; it states the table could no longer accept writes.

## Root cause / main culprits

- "The root cause was that our database hit the ceiling of 2,147,483,647 on our very busy events table" (the signed 32-bit integer maximum).
- Contributing: work to widen the table was already in progress but the team "failed to properly account for how quickly we were running out of headroom"; Rails 5.1 had already switched new tables to 64-bit IDs, which the author says should have prompted the change sooner.

## Resolution

- Raised the limit to the 64-bit maximum (9,223,372,036,854,775,807). The migration method and its duration are not described. No specific follow-up list beyond an apology and support handling.

## Impact and duration

- About 4 hours 50 minutes read-only; uptime since Basecamp 3's launch dropped from 99.998% to 99.978%. The author calls it "an avoidable problem".

## Notes (collector's own, not from the source)

- In PostgreSQL the same failure is an `integer` primary key backed by a sequence reaching 2^31-1 ("nextval: reached maximum value of sequence" or an out-of-range error on insert). A lab can plant it with `ALTER SEQUENCE ... RESTART WITH 2147483600` so that it fires mid-game; the slow part to show is that converting the column to `bigint` rewrites the whole table under an exclusive lock.
