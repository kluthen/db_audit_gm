# scheduler-query-error — GM notes

**What.** One query of a scheduler node's repository (`queries.yaml`, the
`key` parameter: a query, one entry of a pool, or one step of a sequence)
carries an error PostgreSQL rejects at every call: a syntax error
(42601), an operator or function that does not exist for the types
(42883), a datatype mismatch (42804), an invalid input (22P02). The
program never checks SQL, so it loads the entry and the key keeps
running and failing. Planted at render: the broken SQL is the scenario's,
written into `nodes/<node>/queries.yaml`; nothing runs at injection.

**Writing it into a scenario.** Pick a key a stream runs, never one whose
calls another instance's evidence needs (an index fault's lookup, the
duplicates' ingestion). A pool entry with a weight of about one call in
ten makes a fault that fails *sometimes*, closer to a real bug than a key
that never works. The answer key adds the PostgreSQL log's `ERROR` and
`STATEMENT` lines (`node:<db>`, with the seed's logging block) and the
error rate in Grafana.

**Why it matters.** Every failing call is a user-facing failure (a page,
an export, an API call); the application hides it behind a generic
message, so it can run for weeks. It also fills the database log.

**Why it happens.** A query edited in a hurry and deployed untested; a
parameter whose type changed (a text id compared with an integer column);
a migration that renamed a column the query still uses.

**What a good answer says.** Finds the key's error lines (scheduler log,
or the database log), names the SQLSTATE and its cause in the SQL, and
corrects the entry; where the repository is fixable, edits
`queries.yaml` and runs `sudo gm-reload-scheduler`.

**Fix path.** Only through the node's write override
`/srv/scheduler/repository` (spec D170): edit the entry, then `sudo
gm-reload-scheduler`. A report-only node: report and propose.

**Sealed check.** Reads `/opt/gm/seed/queries.yaml` (the planted entry),
the live `queries.yaml`, `/run/scheduler/loaded` and the log; no
connection. *Present* while the file is not reloaded, while the loaded
entry equals the planted one, or while a class 42 or 22 error of the key
follows the reload (a 2 s grace for a call drawn before it). *Fixed* once
a minute that began after the reload has calls of the key and no such
error. *Too soon* (exit 3) in between: `remaining=` the seconds to that
minute's key line, up to about 130 s right after a reload, then at most
70. Any reload of the node starts the wait over (calls are judged since
the last load), so a fix of another fault on the same node puts it back
to *too soon* for a minute or two. Not behavioural: the answer key gives
it no window.
