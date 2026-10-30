# Bastion — player notes

What you may know about the bastion of a db_audit_gm game. Version
0.4, expected to evolve.

## Getting in

The game master gives you the bastion's address, port and password:

```
ssh -p <port> player@<address>
```

The bastion is your only way into the game. Several of you may log in at
the same time with the same account. `scp` and `sftp` work too, for
copying your notes or your report.

## The web page

The game master also gives you a second port and a second password, the
**tools password**. Open the bastion's web page in your browser:

```
http://<address>:<web port>/
```

- Your browser asks for a user name and password: user `player`, password
  the tools password. Without them you get "401 Unauthorized".
- The page shows the starter pack as the game master handed it over, for
  easy reading: the README, the story, the issues and, when your game
  has one, the company's data policy. It is read-only and never shows
  your own edits; your copies are in your home (see "What is there").
- If your game has monitoring web interfaces (Prometheus, Grafana), the
  page links to them. Each is at `http://<address>:<web port>/<name>/`,
  `<name>` being the interface's name, such as `prometheus` or `grafana`.
  If the page shows no link, your game has none.
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
  you are asked to look at) and, when your game has one,
  `data-policy.md` (the company's data policy). Start with `README.md`.
  The same files are on the web page, as handed over.
- **`~/report.md`**: write your findings there. The game master can read
  it when you hand in your final answer.
- **Tools**: `ssh`, `psql` and the other PostgreSQL 18 client tools,
  `nano`, `vi`, `less`.

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
  the web page's port.
- `/tmp` is available; everything outside your home is lost when the
  bastion is restarted.
