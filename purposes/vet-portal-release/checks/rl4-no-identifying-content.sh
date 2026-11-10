#!/bin/sh
# RL4 no identifying content (vet-portal-release, purpose 15;
# vet-portal-domain.md, "vet-portal-release", rule 3): (a) the copies
# (portal_animals, portal_ownerships, portal_herds) and portal_accounts have
# exactly the schema's columns (a column added, an address, an identifier, is
# present); (b) every document published since the judged moment has in its
# body only the keys the jobs write, by its kind, and no body text holds its
# animal's microchip, UELN, passport number or ear tag (a herd's: its holding
# number), the address of an owner or keeper of it (a herd's keeper), or an
# '@'; its vet_name no '@'; (c) every T- document's test belongs to the
# centre's lab account. Judges runs (the findings or the clinical notes
# copied into a body, a staff contact for the vet's name, a practice's
# results published, an identifier column added to a copy).
#
# Runs on the runner node (interfaces) as root, fed to `sh -s` by gmctl
# check, with CHECK_SINCE (YYYY-MM-DDTHH:MM:SSZ): the judged moment is
# CHECK_SINCE raised to the runner's last reload (check-runs since); portal,
# clinic and lab are read as gm_check with check-sql, portal's tables through
# the GM's read policy gm_check_read (spec D432: no verdict when it is gone or
# a restrictive policy hides rows); no job is ever run. The witness is every
# document published and every copy written (synced_at) since the judged
# moment. Exit 0 fixed (with its witness, 12.3), 1 present, 2 cannot judge, 3
# too soon (remaining=). Written for the clinic's names (the constants
# below); the GM adapts them as it copies the purpose.
exec /usr/bin/python3 -I - <<'PY'
INVARIANT = "RL4"
PORTAL = ("records", "portal")       # the target part: node, database
CLINIC = ("records", "clinic")       # the source part
LAB = ("lab", "lab")                 # the source_lab part
ACCOUNT = 1                          # the centre's lab account (publish-results' options.account)
PURPOSE = "vet-portal-release"
# The columns of the copies and of the accounts, as the portal's schema has them.
COLUMNS = {
    "portal_animals": {"animal_id", "name", "species", "sex", "born_on", "herd_id", "status", "died_at",
                       "synced_at"},
    "portal_ownerships": {"animal_id", "owner_id", "role", "from_at", "until_at", "synced_at"},
    "portal_herds": {"herd_id", "keeper_owner_id", "synced_at"},
    "portal_accounts": {"id", "owner_id", "kind", "display_name", "email", "phone", "status", "invited_at",
                        "invite_hash", "invite_expires_at", "activated_at", "password_hash", "failed_logins",
                        "locked_until", "last_login_at", "notify_by", "reminders", "closed_at", "synced_at"},
}
# The body keys the jobs write, by document kind; a list's keys under "<key>[]".
BODY = {
    "consultation": {"": {"kind", "section", "started_at", "diagnoses", "prescriptions"},
                     "diagnoses[]": {"code", "label", "confirmed"},
                     "prescriptions[]": {"medicine", "dose", "unit", "frequency_hours", "days",
                                         "withdrawal_ends_on"}},
    "discharge": {"": {"section", "admitted_at", "discharged_at", "outcome"}},
    "result": {"": {"test", "name", "discipline", "performed_by", "amended", "analytes"},
               "analytes[]": {"code", "name", "unit", "value", "flag", "low", "high"}},
}
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

CHECK_SQL = "/usr/local/lib/gm/check-sql"
CHECK_RUNS = "/usr/local/lib/gm/check-runs"
FMT = "%Y-%m-%dT%H:%M:%SZ"
BATCH = 300                          # rows per -v value, well under one argument's 128 KiB
GUARD = """
SELECT t.name,
       CASE WHEN c.oid IS NULL THEN 'missing'
            WHEN NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname
                                AND p.tablename = c.relname AND p.policyname = 'gm_check_read') THEN 'gone'
            WHEN NOT EXISTS (SELECT 1 FROM pg_policies p WHERE p.schemaname = n.nspname
                                AND p.tablename = c.relname AND p.policyname = 'gm_check_read'
                                AND p.permissive = 'PERMISSIVE' AND p.cmd IN ('SELECT', 'ALL')
                                AND p.qual = 'true' AND p.roles && ARRAY['public', 'gm_check']::name[])
                 THEN 'changed'
            ELSE 'ok' END,
       coalesce((SELECT string_agg(p.policyname, ',' ORDER BY p.policyname) FROM pg_policies p
                  WHERE p.schemaname = n.nspname AND p.tablename = c.relname
                    AND p.permissive = 'RESTRICTIVE' AND p.cmd IN ('SELECT', 'ALL')
                    AND EXISTS (SELECT 1 FROM unnest(p.roles) AS r (role)
                                 WHERE CASE WHEN r.role = 'public' THEN true
                                            ELSE pg_has_role('gm_check', r.role, 'MEMBER') END)), '')
  FROM unnest(string_to_array(%(tables)s, ',')) WITH ORDINALITY AS t (name, i)
  LEFT JOIN pg_class c ON c.oid = to_regclass(t.name)
  LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
 ORDER BY t.i
"""


def cannot(text):
    print(f"{INVARIANT} cannot be judged: {text}")
    sys.exit(2)


def helper(argv, stdin=None):
    try:
        p = subprocess.run(argv, input=stdin, capture_output=True, text=True)
    except OSError as exc:
        cannot(f"{argv[0]}: {exc.strerror}")
    if p.returncode != 0:
        cannot(p.stderr.strip() or f"{argv[0]} exited {p.returncode}")
    return p.stdout


def epoch(text):
    return datetime.strptime(text, FMT).replace(tzinfo=timezone.utc).timestamp()


def iso(ts):
    return datetime.fromtimestamp(ts, timezone.utc).strftime(FMT)


def query(text, db, width=None, **values):
    """Rows of the statement; with width, the last column keeps any '|' it holds."""
    node, name = db
    argv = [CHECK_SQL, "-h", node, "-d", name]
    for key, value in values.items():
        argv += ["-v", f"{key}={value}"]
    return [line.split("|", width - 1) if width else line.split("|")
            for line in helper(argv, text).splitlines()]


def batched(text, db, rows, width=None, **values):
    """The statement once per BATCH of rows, given as the JSON array %(rows)s."""
    out = []
    for i in range(0, len(rows), BATCH):
        out += query(text, db, width, rows=json.dumps(rows[i:i + BATCH], separators=(",", ":")), **values)
    return out


def guard(tables):
    """Exit 2 unless gm_check reads every row of each portal table (spec D432)."""
    for name, state, hiding in query(GUARD, PORTAL, tables=",".join(tables)):
        if state == "missing":
            cannot(f"{name} is not in {PORTAL[1]}")
        if state == "gone":
            cannot(f"the GM's read policy on {name} is gone")
        if state == "changed":
            cannot(f"the GM's read policy on {name} is changed: it no longer shows gm_check every row")
        if hiding:
            cannot(f"a restrictive policy {hiding.split(',')[0]} on {name} hides rows from gm_check")


def wait(job, why):
    """Exit 3, remaining= until the job's next run."""
    out = subprocess.run([CHECK_RUNS, "next", job], capture_output=True, text=True).stdout
    if "remaining=" not in out:
        cannot(f"{job} is not in the loaded jobs.yaml, or never due: no run to wait for")
    print(f"remaining={max(1, int(out.split('remaining=')[1].split()[0]))} {why}")
    sys.exit(3)


def present(what, how, count, window):
    more = f" ({count} {what} {window})" if count > 1 else ""
    print(f"{INVARIANT} present: {how}{more}")
    sys.exit(1)


def strings(value):
    """Every string in a JSON value, its keys too."""
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for k, v in value.items():
            yield k
            yield from strings(v)
    elif isinstance(value, list):
        for v in value:
            yield from strings(v)


def stray_keys(kind, body):
    """The keys of a body the jobs never write for its kind ('<list>[].<key>' for a list's)."""
    allowed = BODY.get(kind)
    if allowed is None:
        return [f"(kind {kind})"]
    if not isinstance(body, dict):
        return ["(a body that is no object)"]
    out = [k for k in body if k not in allowed[""]]
    for key, value in body.items():
        inner = allowed.get(f"{key}[]")
        if inner is None:
            continue
        if not isinstance(value, list):
            out.append(f"{key} (no list)")
            continue
        for item in value:
            if not isinstance(item, dict):
                out.append(f"{key}[] (no object)")
            else:
                out += [f"{key}[].{k}" for k in item if k not in inner]
    return out


guard(["portal_animals", "portal_ownerships", "portal_herds", "portal_accounts", "portal_documents"])
judged = epoch(helper([CHECK_RUNS, "since", os.environ.get("CHECK_SINCE", "")]).strip())
window = f"since {iso(judged)}"

# (a) The columns, at any time.
found = {}
for table, column in query("""
SELECT c.table_name, c.column_name FROM information_schema.columns c
 WHERE c.table_name = ANY (string_to_array(%(tables)s, ','))
   AND c.table_schema = (SELECT n.nspname FROM pg_class k JOIN pg_namespace n ON n.oid = k.relnamespace
                          WHERE k.oid = to_regclass(c.table_name))
 ORDER BY 1, 2
""", PORTAL, tables=",".join(COLUMNS)):
    found.setdefault(table, set()).add(column)
wrong = []
for table, expected in COLUMNS.items():
    have = found.get(table, set())
    wrong += [f"{table} has a column {c} the schema does not" for c in sorted(have - expected)]
    wrong += [f"{table} lacks the schema's column {c}" for c in sorted(expected - have)]
if wrong:
    present("columns", wrong[0], len(wrong), "in the copies and the accounts")

# The witness: the copies written, the documents published.
copies = int(query("""
SELECT (SELECT count(*) FROM portal_animals WHERE synced_at > to_timestamp(%(judged)s::float8))
     + (SELECT count(*) FROM portal_ownerships WHERE synced_at > to_timestamp(%(judged)s::float8))
     + (SELECT count(*) FROM portal_herds WHERE synced_at > to_timestamp(%(judged)s::float8))
     + (SELECT count(*) FROM portal_accounts WHERE synced_at > to_timestamp(%(judged)s::float8))
""", PORTAL, judged=judged)[0][0])
docs = query("""
SELECT id, kind, source_ref, coalesce(animal_id::text, ''), coalesce(herd_id::text, ''),
       jsonb_build_object('vet_name', vet_name, 'body', body)::text
  FROM portal_documents WHERE published_at > to_timestamp(%(judged)s::float8)
 ORDER BY published_at, id
""", PORTAL, width=6, judged=judged)
docs = [(int(i), k, ref, int(a) if a else None, int(h) if h else None, json.loads(j))
        for i, k, ref, a, h, j in docs]

# (b) The bodies: their keys, then what no text may hold.
bad = []
for did, kind, ref, animal, herd, j in docs:
    stray = stray_keys(kind, j["body"])
    if stray:
        bad.append(f"document {did} ({ref}): its {kind} body holds {stray[0]}, a key the jobs never write")
    elif any("@" in s for s in strings(j["body"])):
        bad.append(f"document {did} ({ref}): its body holds an '@' (an address)")
    elif "@" in (j["vet_name"] or ""):
        bad.append(f"document {did} ({ref}): its vet_name holds an '@' (a staff contact)")
if bad:
    present("documents", bad[0], len(bad), window)

# What the record holds about each document's animal or herd, read as gm_check.
known = {}                           # (animal|herd, id): its identifiers and addresses
for kind, key, text in batched("""
SELECT 'animal', a.id, to_jsonb(v.text)::text
  FROM animals a, LATERAL (VALUES (a.microchip), (a.ueln), (a.passport_number), (a.ear_tag)) AS v (text)
 WHERE a.id = ANY (SELECT (x ->> 'animal')::integer FROM jsonb_array_elements(%(rows)s::jsonb) x)
   AND v.text IS NOT NULL
UNION ALL
SELECT 'animal', w.animal_id, to_jsonb(o.address)::text
  FROM ownerships w JOIN owners o ON o.id = w.owner_id
 WHERE w.animal_id = ANY (SELECT (x ->> 'animal')::integer FROM jsonb_array_elements(%(rows)s::jsonb) x)
UNION ALL
SELECT 'herd', h.id, to_jsonb(v.text)::text
  FROM herds h JOIN owners o ON o.id = h.keeper_owner_id,
       LATERAL (VALUES (h.holding_number), (o.address)) AS v (text)
 WHERE h.id = ANY (SELECT (x ->> 'herd')::integer FROM jsonb_array_elements(%(rows)s::jsonb) x)
""", CLINIC, [{"animal": a, "herd": h} for _, _, _, a, h, _ in docs], width=3):
    text = json.loads(text).strip()
    if text:
        known.setdefault((kind, int(key)), set()).add(text)
for did, kind, ref, animal, herd, j in docs:
    held = known.get(("animal", animal) if animal is not None else ("herd", herd), set())
    texts = list(strings(j["body"])) + [json.dumps(j["body"], ensure_ascii=False)]
    if any(s in t for s in held for t in texts):
        bad.append(f"document {did} ({ref}): its body holds an identifier or an address of its "
                   f"{'animal' if animal is not None else 'herd'}")
if bad:
    present("documents", bad[0], len(bad), window)

# (c) The results: every T- document's test the centre's.
tests = [{"id": did, "test": int(ref[2:])} for did, kind, ref, _, _, _ in docs
         if ref.startswith("T-") and ref[2:].isdigit()]
bad += [f"document {did} (T-{test}): its test is not of lab account {ACCOUNT}"
        for did, test in batched("""
SELECT x.id, x.test
  FROM jsonb_to_recordset(%(rows)s::jsonb) AS x (id integer, test integer)
  LEFT JOIN lab_order_tests t ON t.id = x.test LEFT JOIN lab_orders o ON o.id = t.order_id
 WHERE o.account_id IS DISTINCT FROM %(account)s::integer
 ORDER BY x.id
""", LAB, tests, account=ACCOUNT)]
bad += [f"document {did} ({ref}): a result whose source_ref names no test" for did, kind, ref, _, _, _ in docs
        if kind == "result" and not (ref.startswith("T-") and ref[2:].isdigit())]
if bad:
    present("documents", bad[0], len(bad), window)

if docs or copies:
    print(f"{INVARIANT} fixed: {len(docs)} documents published and {copies} copies written {window}, "
          f"the copies' and the accounts' columns the schema's, no body with a stray key, an identifier, an "
          f"address or an '@', every result the centre's")
    sys.exit(0)
wait("publish-records", f"no document published and no copy written {window}")
PY
