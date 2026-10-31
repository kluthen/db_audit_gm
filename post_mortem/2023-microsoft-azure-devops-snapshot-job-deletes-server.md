# Azure DevOps: the nightly snapshot clean-up job deletes the whole Azure SQL server and 17 production databases

- **Source**: [Azure DevOps Outage in South Brazil](https://status.dev.azure.com/_event/392143683) (Azure DevOps status page, post-mortem by Eric Mattingly). The page renders with JavaScript; the text is embedded in the page source. Archive: [web.archive.org snapshot](https://web.archive.org/web/20230525184821/https://status.dev.azure.com/_event/392143683) (the only snapshots are from 2023-05-24 and 2023-05-25, before the post-mortem text was posted on 2023-06-02, so the archive holds the incident notice only, not the post-mortem)
- **Date of incident**: 2023-05-24, 12:10 to 22:31 UTC
- **Organization**: Microsoft (Azure DevOps)
- **Kind of write-up**: official post-mortem (status page)

## Tech stack

- Azure SQL Database on Azure SQL Server logical servers; backups with zone- or geo-zone-redundant storage.
- A daily background job deletes point-in-time snapshot databases that engineers create from production for investigations. .NET code using Azure management SDK packages. IIS web servers (`w3wp`) behind a load balancer.

## Topology

- One "scale unit" in South Brazil with 17 production databases on one Azure SQL server; snapshot databases were created on the same server as production.

## Symptoms

- The scale unit could not serve any customer traffic. After restores started, web servers stayed out of the load balancer and the few that rejoined were overloaded.

## Diagnosis

- Outage detected within 20 minutes; the cause was understood quickly and the snapshot deletion job was disabled to protect other scale units.

## Root cause / main culprits

- A large mechanical pull request replaced the deprecated `Microsoft.Azure.Management.*` packages with `Azure.ResourceManager.*`. A typo in it swapped the job's call that deletes an Azure SQL Database for one that deletes the Azure SQL Server hosting it.
- The code path ran only when an old-enough snapshot existed: none existed in Ring 0, so the bug passed the safe-deployment ring and fired in Ring 1.
- Long recovery: customers cannot restore a deleted Azure SQL server themselves (about one hour to engage the Azure SQL team); restoring with geo-zone-redundant settings copied data to the paired region for databases that had been zone-redundant, adding hours; the web servers' warm-up enumerated every database and retried with exponential backoff, taking about 90 minutes instead of under a second, so health probes failed and servers kept cycling.

## Resolution

- Server and databases restored; all traffic to the scale unit blocked with a resource-utilisation feature so every web server could warm up, then users let back in gradually.
- Follow-ups: fixed the bug; a test that exercises snapshot deletion against real Azure resources; Azure Resource Manager locks on key resources; geo-zone-redundant backups everywhere supported; snapshot databases on separate servers from production; warm-up that tolerates offline databases; a cmdlet that restores deleted databases with their original settings.

## Impact and duration

- About 10.5 hours for that scale unit. "There was no data loss experienced."

## Notes (collector's own, not from the source)

- Scheduled-job culprit: a clean-up cron that only does something when a rare condition exists, and whose blast radius is wider than its name. A lab version is a nightly "drop old snapshot databases" job with a pattern or scope bug, running as a role that can drop production databases.
