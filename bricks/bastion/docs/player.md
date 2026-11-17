# Bastion — player notes

What you may know about the bastion of a db_audit_gm game. Version
0.6, expected to evolve.

## Getting in

The game master gives you the bastion's address, port and password:

```
ssh -p <port> player@<address>
```

The bastion is your only way into the game. Several of you may log in at
the same time with the same account. `scp` and `sftp` work too, for
copying your notes or your report.

## The web site

The game master also gives you a second port and a second password, the
**tools password**. Open the bastion's web site in your browser:

```
http://<address>:<web port>/
```

Your browser asks for a user name and password: user `player`, password
the tools password. Without them you get "401 Unauthorized", on every
page.

The home page has two lists:

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
- Grafana asks you to log in as well: its administrator account, with
  the same tools password. Do not change Grafana's users or the
  administrator's password (DO NOT TAMPER): the game master's own checks
  use them.
- "502 Bad Gateway" means the interface is not up (yet); try again in a
  minute, or tell the game master.
- The connection is plain HTTP: the tools password is not encrypted on
  the way. Use it only for this game.

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
- **Tools**: `ssh`, `psql` and the other PostgreSQL 18 client tools,
  `curl` (to call the partners' services, for instance), `jq` (to read
  JSON, such as Prometheus' API when your game has Prometheus:
  `curl -s 'http://<its node>:9090/prometheus/api/v1/query?query=up' | jq .`),
  `tmux`, `nano`, `vi`, `less`.

## Reaching the other nodes

- `ssh <node>` logs you in to a node as `player`, with the key already in
  `~/.ssh/id_ed25519`. Use the node names from `README.md`.
- `psql -h <node>` connects you to a database as the role `dba`; the
  password is in `~/.pgpass`.

Nodes are reached by their name. Their SSH host keys are not checked or
remembered for these names, because a node's key changes when it is
restarted.

## The validator

`gm-validate` checks that the bastion itself is still usable: SSH is
running, your home is writable, and `~/.ssh/id_ed25519` and `~/.pgpass`
are in place with mode `600`. It prints `GREEN: ...` and exits 0, or one
`RED ...` line per problem and exits 1. Each node has its own validator;
see `README.md`.

## Do not tamper

Do not change SSH, the validator, `~/.ssh/id_ed25519`, `~/.pgpass`, or the
file `~/.gm-starter-copied`. Most of the bastion is read-only anyway.
There is no `sudo` here, and you cannot change the password.

## Good to know

- Only the bastion's ports are reachable from outside the game: SSH, and
  the web site's port.
- `/tmp` is available; everything outside your home is lost when the
  bastion is restarted.
