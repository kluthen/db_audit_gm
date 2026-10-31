# Public Health England: lab result files exceed the load process's limit, 15,841 positive COVID-19 cases go unreported

- **Source**: [PHE statement on delayed reporting of COVID-19 cases](https://www.gov.uk/government/news/phe-statement-on-delayed-reporting-of-covid-19-cases) (GOV.UK, 2020-10-04, updated 2020-10-05). Archive: [web.archive.org snapshot](https://web.archive.org/web/20261012002436/https://www.gov.uk/government/news/phe-statement-on-delayed-reporting-of-covid-19-cases). Secondary (technical detail not in the official statement): [BBC News, "Excel: Why using Microsoft's tool caused Covid-19 results to be lost"](https://www.bbc.co.uk/news/technology-54423988)
- **Date of incident**: results from 2020-09-25 to 2020-10-02 (the statement's background table uses 24 September to 1 October); found overnight on 2020-10-02
- **Organization**: Public Health England (UK public health agency; laboratory results reporting)
- **Kind of write-up**: official statement (no full technical post-mortem published); technical mechanism from news

## Tech stack

- Official statement: an automated "data load process that transfers COVID-19 positive lab results into reporting dashboards" and on to contact tracing. No engine or tool named.
- BBC (secondary): labs sent results as CSV files; PHE's process loaded them into Excel templates in the old XLS format before upload to a central system.

## Topology

- Commercial labs send result files; a central PHE load process feeds dashboards and NHS Test and Trace. Details not stated in the official source.

## Symptoms

- Daily reported case counts too low; contacts of positive cases not being traced. Once fixed, the headline figures for two days jumped because of the backlog.

## Diagnosis

- Identified during the data load overnight on 2020-10-02. How it was found is not described further.

## Root cause / main culprits

- Official: some files containing positive results "exceeded the maximum file size" the system could take, so records past the limit were not loaded into central systems.
- BBC: the XLS format caps a sheet at about 65,000 rows; because each test produced several rows, each template held only about 1,400 cases, and rows beyond the cap were dropped.
- Neither source mentions a check that compared rows received with rows loaded.

## Resolution

- Immediate: large files split into smaller ones; all outstanding cases passed to NHS Test and Trace by 01:00 on 2020-10-03; contact attempts raised from 10 to 15 over 96 hours.
- Follow-up: a full end-to-end review of the systems.

## Impact and duration

- 15,841 cases left out of the daily figures (11,968 of them should have been reported between 30 September and 2 October). Everyone who tested positive still received their result as normal; contact tracing for them was delayed.

## Notes (collector's own, not from the source)

- The transferable culprit is an ETL step that truncates without error. A lab analogue: a nightly import into a reporting database that stops at a fixed batch size (or a `LIMIT` left in the job) and reports success. Players find it by comparing row counts between source and target.
- Closest public write-up found for the laboratory category; it is an official statement plus press coverage, not a technical post-mortem.
