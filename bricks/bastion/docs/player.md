# Bastion — player notes

What you may know about the bastion of a db_audit_gm game. Version
0.8, expected to evolve.

## Getting in

The game master gives you the bastion's address and port. No password:
the bastion lets `player` in straight away.

```
ssh -p <port> player@<address>
```

The bastion is your only way into the game. Several of you may log in at
the same time with the same account. `scp` and `sftp` work too, for
copying your notes or your report.

## The web site

The game master also gives you a second port, the web site's. Open the
bastion's web site in your browser; it asks for no login:

```
http://<address>:<web port>/
```

The home page opens with **Access**: every credential your tools need,
with its value (the bastion, the databases' role `dba` and its password,
the login of a web interface that has one, such as Grafana, and where
the partners' credentials are). Then two lists:

- **Sites**: the web interfaces of your game, when it has any (such as
  Prometheus and Grafana, at `/<name>/`); **Reports**, your reports folder
  (see "Reports" below); and, when the company works with partners, one
  **status page** per partner.
- **Documents**: the documents the customer handed over at the
  mission's start, each on its own page under `/docs/`: the README, the
  story, the issues and, when your game has them, the data policy, the
  partners, the data register and the network overview. Then **Tools**:
  the player notes of each kind of node you may reach (this page among
  them), under `/docs/bricks/`.

The documents are shown as they were handed over: never your own edits
(your copies are in your home, see "What is there"). They describe the
system as it was at the mission's start, and stay so: a fix you make may
leave one of them out of date, and that is expected.

A partner's **status page** (`/status/<partner>/`, also linked from the
partner's section of the partners' page) is the partner's own: what it
admits of its incidents, as it says them, with their start and end in
UTC. It shows "Operational", or "Incident ongoing" while an incident it
admits is under way. A partner says only what it knows or will say.

## Reports

Your home has a folder `~/reports/`, served read-only at
`http://<address>:<web port>/reports/`, a listing of what is in it. Bring a
report there in one hop and open it in your browser, for instance
pgBadger's:

```
scp <node>:pgbadger.html ~/reports/
```

or a folder (`scp -r <node>:pgcluu-report ~/reports/`). Only what is in the
folder is served: a symbolic link in it is not followed. A report's own
scripts run in the browser, but kept away from the other pages of the
site. Your own audit report stays yours: write it where you like
(`~/report.md`, say).

## The web interfaces

- If your game has monitoring web interfaces (Prometheus, Grafana), the
  home page links to them. Each is at `http://<address>:<web port>/<name>/`,
  `<name>` being the interface's name, such as `prometheus` or `grafana`.
  If the home shows none, your game has none.
- If the company archives to a partner's vault, cold storage, the home
  may link to its console at `http://<address>:<web port>/cold-storage/`:
  its page and its manifests (`/cold-storage/manifests`), read only, as
  the customer sees them. Nothing else of a partner is on the web page.
- Grafana asks you to log in: its administrator account, `admin`, with
  the password the home's Access section shows. Do not change Grafana's
  users or the administrator's password (DO NOT TAMPER): the game
  master's own checks use them.
- "502 Bad Gateway" means the interface is not up (yet); try again in a
  minute, or tell the game master.
- The connection is plain HTTP: nothing on it is encrypted. Use what it
  shows only for this game.

## What is there

- **Your home**, `/home/player`, the only place you can write. It keeps
  its content if the bastion is restarted.
- **The starter pack** in your home, as Markdown: `README.md` (the
  system, its nodes, the rules, what not to touch, how to run the
  validators), `story.md` (the customer's background), `issues.md` (what
  you are asked to look at) and, when your game has them,
  `data-policy.md` (the company's data policy), `partners.md` (the
  partners the company works with, and the company's own credentials
  with them, where it has any), `data-register.md` (what the company
  holds, where and for how long: its register of processing) and
  `network-overview.md` (the company's nodes and what you may do on
  each). Start with `README.md`.
  The same files are on the web site, as handed over.
- **`~/reports/`**: the reports you want to read in your browser (see
  "Reports").
- **`~/report.md`**: write your findings there. The game master can read
  it when you hand in your final answer.
- **Tools**: `ssh`, `psql` and the other PostgreSQL 19 client tools,
  `curl` (to call the partners' services, for instance), `jq` (to read
  JSON, such as Prometheus' API when your game has Prometheus:
  `curl -s 'http://<its node>:9090/prometheus/api/v1/query?query=up' | jq .`),
  `tmux`, `nano`, `vi`, `less`.

## Reaching the other nodes

- `ssh <node>` logs you in to a node as `player`, with the key already in
  `~/.ssh/id_ed25519`. Use the node names from `README.md`.
- `psql -h <node>` connects you to a database as the role `dba`; the
  password is in `~/.pgpass`, which `psql` reads by itself (the home
  page's Access section shows it too).

Nodes are reached by their name. Their SSH host keys are not checked or
remembered for these names, because a node's key changes when it is
restarted.

## The validator

`gm-validate` checks that the bastion itself is still usable: SSH is
running, your home is writable, and `~/.ssh/id_ed25519` and `~/.pgpass`
are in place with mode `600`. It prints `GREEN: ...` and exits 0, or one
`RED ...` line per problem and exits 1. Each node has its own validator;
see `README.md`.

## The game assistant

The game assistant is an agent you may run beside you: a PostgreSQL DBA
colleague, with no knowledge of the game's answers. It is not the game
master.

- **It cannot touch the databases.** It never connects to one and never
  runs a command that changes something: it writes the SQL and commands,
  you run them. On the bastion it only reads, over SSH, what a colleague
  looking over your shoulder would see; it never reads
  `~/.pgpass`, `~/.ssh/` or the web site (tell it what the site shows).
  It writes only your report, its drafts and the tracking files you ask
  for, on your machine, never on the bastion.
- **The game master takes your report, not the assistant.** The
  assistant never hands it in, never talks to the game master and never
  says whether a finding is right; the game master is not told it
  helped. The game master runs in its own session: anything for the game
  master goes there. Your report reaches the game master as ever:
  pasted, left in `~/report.md`, or talked through.

**Starting it.** On your own machine, from your own clone of the game's
repository:

```
tools/play assistant
```

(`tools/play assistant --opencode` with OpenCode). It starts in a
session of its own, never the game master's.

**Reaching the bastion.** The bastion asks for no password, so the
assistant reaches it directly, one read at a time, with the address and
port you give it:

```
ssh -p <port> player@<address> '<read>'
```

A shared connection is still possible, and optional: opened in your own
terminal (`<game>` is a label of your choice), the assistant may run its
reads through it:

```
ssh -M -S ~/.ssh/dbagm-<game>.sock -fN -p <port> player@<address>
```

## Do not tamper

Do not change SSH, the validator, `~/.ssh/id_ed25519`, `~/.pgpass`, or the
file `~/.gm-starter-copied`. Most of the bastion is read-only anyway.
There is no `sudo` here, and `player` has no password to change.

## Good to know

- Only the bastion's ports are reachable from outside the game: SSH, and
  the web site's port.
- `/tmp` is available; everything outside your home is lost when the
  bastion is restarted.
