# from vet-portal@regional-franchise: domains/vet-portal/producers/partners/owners/db/owners_tick.py
"""The owners' tick, its database side (vet-portal's owners' traffic; capture
W3 item 5; spec D369; vet-portal-domain.md, "Rates at intensity 1.0"): as the
role owners, on partners; the owners' calls through the connection
owners-portal (portal-api, public, the session a cookie portal_session, as a
browser sends it). A short transaction reads what the tick needs, the calls
follow with no session held, and every call is then written to owners.visits
(when, as which account, the call, its status, the animals and documents it
returned), RL6's evidence.

The planted accounts' passwords and links are the HMAC-SHA256, in hex, of the
account's id or of '<template>:<id>' under owners.settings' password_key
(D406; vet-portal docs/gm.md, "The key, the passwords, the links"); a planted
session's token that of 'session-<rank>:<id>'. The route's own logins are
owners.accounts; the messaging stub's record (messaging.messages, purpose
16's) is read when it exists: the recipients of the last day's messages, the
tokens of the invitations and resets made in play, the reminders' keys."""

import hashlib
import hmac
import json
import random
from datetime import datetime, timedelta, timezone

import gm_api

COOKIE = "portal_session"
HORSE_OWNERS = (302, 901)          # the core's layout (vet-core docs/gm.md, "core_owner")
_rng = random.Random()


def _hmac(key, msg):
    return hmac.new(key.encode("utf-8"), msg.encode("utf-8"), hashlib.sha256).hexdigest()


def _u(text):
    return int(hashlib.sha256(text.encode("utf-8")).hexdigest()[:8], 16) / 2 ** 32


def _now():
    return datetime.now(timezone.utc)


class Browser:
    """One owner's calls on portal-api, each kept for owners.visits."""

    def __init__(self, account_id):
        self.portal = gm_api.client("owners-portal")
        self.account_id = account_id
        self.token = None
        self.visits = []

    def call(self, method, path, shown, body=None, token=None):
        """-> (status, JSON body or None); status None when portal-api did not answer."""
        headers = {}
        token = token or self.token
        if token:
            headers["Cookie"] = f"{COOKIE}={token}"
        at = _now()
        try:
            if method == "GET":
                answer = self.portal.get(path, headers=headers)
            elif method == "PUT":
                # gm_api's client offers get() and post(); a PUT goes through
                # its own request path, with its headers (never Authorization).
                answer = self.portal._call("PUT", path, json.dumps(body).encode("utf-8"), self.portal._headers(
                    dict(headers, **{"Content-Type": "application/json"})))
            else:
                answer = self.portal.post(path, {} if body is None else body, headers=headers)
        except gm_api.HttpError:
            self.visits.append((at, self.account_id, shown, None, None, None))
            return None, None
        try:
            data = answer.json()
        except ValueError:
            data = None
        self.visits.append((at, self.account_id, shown, answer.status) + _ids(shown, answer.status, data, path))
        return answer.status, data

    def login(self, email, password):
        status, data = self.call("POST", "/login", "POST /login", {"email": email, "password": password})
        if status == 201:
            self.token = data["token"]
        return status

    def logout(self):
        self.call("POST", "/logout", "POST /logout")
        self.token = None


def _ids(shown, status, data, path):
    """(animal_ids, document_ids) a call returned."""
    if status != 200:
        return None, None
    if shown == "GET /animals":
        return [a["animal_id"] for a in data], None
    if shown == "GET /animals/{id}/documents":
        return [int(path.split("/")[2])], [d["document_id"] for d in data]
    if shown == "GET /documents/{id}":
        return ([data["animal_id"]] if data.get("animal_id") is not None else None), [data["document_id"]]
    return None, None


def _messaging(conn):
    return conn.execute("SELECT to_regclass('messaging.messages') IS NOT NULL").fetchone()[0]


def _key(conn):
    return conn.execute("SELECT value FROM owners.settings WHERE name = 'password_key'").fetchone()[0]


def _record(conn, browsers):
    rows = [v for b in browsers for v in b.visits]
    if rows:
        with conn.cursor() as cur:
            cur.executemany("INSERT INTO owners.visits (at, account_id, call, status, animal_ids, document_ids) "
                            "VALUES (%s, %s, %s, %s, %s, %s)", rows)
    return len(rows)


def _active(conn, low=None, high=None, recent=False):
    """-> (account_id, email) of an active account, or None: with the
    messaging stub and recent, a recipient of the last day's messages."""
    if recent and _messaging(conn):
        row = conn.execute(
            "SELECT a.account_id, a.email FROM messaging.messages AS m JOIN owners.accounts AS a USING (account_id) "
            "WHERE m.received_at > now() - interval '1 day' AND a.status = 'active' "
            "ORDER BY random() LIMIT 1").fetchone()
        if row is not None:
            return row
    return conn.execute(
        "SELECT account_id, email FROM owners.accounts WHERE status = 'active' "
        "AND account_id BETWEEN %s AND %s ORDER BY random() LIMIT 1",
        (low or 0, high or 2 ** 31 - 1)).fetchone()


def visit(conn, key):
    """Logs in (one in 25 mistypes once first; one in 300 five times, locked;
    one in 50 first tries a past session's token, a bookmarked link), lists
    the animals, opens one or two documents of one (1.6 on average), one in
    ten changes its channel or the reminders' consent, logs out half the time."""
    row = _active(conn, recent=_rng.random() < 0.7)
    conn.rollback()
    if row is None:
        return []
    account_id, email = row
    b = Browser(account_id)
    password = _hmac(key, str(account_id))
    if _rng.random() < 1 / 50:
        b.call("GET", "/animals", "GET /animals", token=_hmac(key, f"session-1:{account_id}"))
    if _rng.random() < 1 / 300:
        for _ in range(5):
            if b.login(email, password + "x") == 423:
                break
        return [b]
    if _rng.random() < 1 / 25:
        b.login(email, password + "x")
    if b.login(email, password) != 201:
        return [b]
    status, animals = b.call("GET", "/animals", "GET /animals")
    if status == 200 and animals:
        animal = _rng.choice(animals)["animal_id"]
        status, docs = b.call("GET", f"/animals/{animal}/documents", "GET /animals/{id}/documents")
        if status == 200 and docs:
            for d in docs[:2 if _rng.random() < 0.6 else 1]:
                b.call("GET", f"/documents/{d['document_id']}", "GET /documents/{id}")
    if _rng.random() < 0.1:
        status, me = b.call("GET", "/me", "GET /me")
        if status == 200 and _rng.random() < 0.5:
            channel = "sms" if me["notify_by"] == "email" else "email"
            b.call("PUT", "/me/preferences", "PUT /me/preferences", {"notify_by": channel})
        elif status == 200:
            b.call("POST", "/me/consents", "POST /me/consents",
                   {"purpose": "reminders", "granted": not me["reminders"]})
    if _rng.random() < 0.5:
        b.logout()
    return [b]


def activate(conn, key):
    """The oldest invitation whose activation delay has passed, activated with
    its token and the account's password, the reminders' consent granted by
    80 %: a planted one (owners.accounts' activates_at), else, with the
    messaging stub, one made in play (an account the route does not know,
    0 to 3 days after its message by a hash of its id, three in ten never)."""
    row = conn.execute(
        "SELECT account_id, email FROM owners.accounts WHERE status = 'invited' AND link = 'invitation' "
        "AND activates_at <= now() ORDER BY activates_at LIMIT 1").fetchone()
    token = None
    if row is not None:
        token = _hmac(key, f"invitation:{row[0]}")
    elif _messaging(conn):
        for account_id, email, link, received in conn.execute(
                "SELECT m.account_id, m.address, m.payload ->> 'link', m.received_at FROM messaging.messages AS m "
                "WHERE m.template = 'invitation' AND m.received_at > now() - interval '14 days' "
                "AND NOT EXISTS (SELECT 1 FROM owners.accounts AS a WHERE a.account_id = m.account_id) "
                "ORDER BY m.received_at").fetchall():
            u = _u(f"owners:activate:{account_id}")
            if u >= 0.3 and received + timedelta(days=3 * _u(f"owners:delay:{account_id}")) <= _now() and link:
                row, token = (account_id, email), link.rsplit("/", 1)[1]
                break
    conn.rollback()
    if row is None:
        return [], None
    account_id, email = row
    b = Browser(account_id)
    status, _ = b.call("POST", "/accounts/activate", "POST /accounts/activate",
                       {"token": token, "password": _hmac(key, str(account_id)),
                        "reminders": _rng.random() < 0.8})
    if status == 200:
        update = ("INSERT INTO owners.accounts (account_id, email, status) VALUES (%s, %s, 'active') "
                  "ON CONFLICT (account_id) DO UPDATE SET status = 'active', link = NULL, activates_at = NULL",
                  (account_id, email))
    elif status is not None:                 # a link refused: never tried again
        update = ("UPDATE owners.accounts SET link = NULL, activates_at = NULL WHERE account_id = %s",
                  (account_id,))
    else:
        update = None
    return [b], update


def reset(conn, key):
    """A reset made earlier used through its message's token (the messaging
    stub), then an active account asks a new one."""
    browsers = []
    if _messaging(conn):
        pending = conn.execute(
            "SELECT m.account_id, m.payload ->> 'link' FROM messaging.messages AS m "
            "JOIN owners.accounts AS a USING (account_id) "
            "WHERE m.template = 'password-reset' AND a.status = 'active' AND m.received_at > now() - interval '14 days' "
            "AND EXISTS (SELECT 1 FROM owners.visits AS v WHERE v.account_id = m.account_id "
            "            AND v.call = 'POST /password-reset' AND v.at <= m.received_at) "
            "AND NOT EXISTS (SELECT 1 FROM owners.visits AS v WHERE v.account_id = m.account_id "
            "                AND v.call = 'POST /password-reset/{token}' AND v.at >= m.received_at) "
            "ORDER BY m.received_at LIMIT 1").fetchone()
        if pending is not None and pending[1]:
            b = Browser(pending[0])
            b.call("POST", f"/password-reset/{pending[1].rsplit('/', 1)[1]}", "POST /password-reset/{token}",
                   {"password": _hmac(key, str(pending[0]))})
            browsers.append(b)
    row = _active(conn)
    conn.rollback()
    if row is not None:
        b = Browser(row[0])
        b.call("POST", "/password-reset", "POST /password-reset", {"email": row[1]})
        browsers.append(b)
    return browsers


def unsubscribe(conn, key):
    """A reminder received a few hours ago (three to 14 days), one in twenty by
    a hash of its key, withdrawn through its link (the messaging stub's)."""
    if not _messaging(conn):
        conn.rollback()
        return []
    rows = conn.execute(
        "SELECT m.account_id, m.message_key::text FROM messaging.messages AS m "
        "JOIN owners.accounts AS a USING (account_id) "
        "WHERE m.template = 'reminder' AND a.status = 'active' "
        "AND m.received_at BETWEEN now() - interval '14 days' AND now() - interval '3 hours' "
        "AND NOT EXISTS (SELECT 1 FROM owners.visits AS v WHERE v.account_id = m.account_id "
        "                AND v.call = 'POST /unsubscribe/{message_key}' AND v.at >= m.received_at) "
        "ORDER BY m.received_at").fetchall()
    conn.rollback()
    for account_id, message_key in rows:
        if _u(f"owners:unsubscribe:{message_key}") < 0.05:
            b = Browser(account_id)
            b.call("POST", f"/unsubscribe/{message_key}", "POST /unsubscribe/{message_key}")
            return [b]
    return []


def keeper(conn, key):
    """A horse owner grants a keeper of its horse access (three in four) or
    withdraws it: one of the keepers its consents name (GET /me)."""
    row = _active(conn, *HORSE_OWNERS)
    conn.rollback()
    if row is None:
        return []
    b = Browser(row[0])
    if b.login(row[1], _hmac(key, str(row[0]))) != 201:
        return [b]
    status, me = b.call("GET", "/me", "GET /me")
    kept = [c for c in (me or {}).get("consents", []) if c["purpose"] == "keeper-access"] if status == 200 else []
    if kept:
        c = _rng.choice(kept)
        b.call("POST", "/me/consents", "POST /me/consents",
               {"purpose": "keeper-access", "animal_id": c["animal_id"], "keeper_id": c["keeper_id"],
                "granted": _rng.random() < 0.75})
    b.logout()
    return [b]


def close(conn, key):
    """An active account closed (POST /me/close)."""
    row = _active(conn)
    conn.rollback()
    if row is None:
        return [], None
    b = Browser(row[0])
    if b.login(row[1], _hmac(key, str(row[0]))) != 201:
        return [b], None
    status, _ = b.call("POST", "/me/close", "POST /me/close")
    if status == 200:
        return [b], ("UPDATE owners.accounts SET status = 'closed' WHERE account_id = %s", (row[0],))
    return [b], None


def tick(kind):
    """-> {account_id, calls}."""
    with gm_api.connection("owners-db") as conn:
        key = _key(conn)
        update = None
        if kind == "activate":
            browsers, update = activate(conn, key)
        elif kind == "close":
            browsers, update = close(conn, key)
        else:
            browsers = {"visit": visit, "reset": reset, "unsubscribe": unsubscribe, "keeper": keeper}[kind](conn, key)
        conn.rollback()
        calls = _record(conn, browsers)
        if update is not None:
            conn.execute(*update)
        conn.commit()
    return {"account_id": browsers[-1].account_id if browsers else None, "calls": calls}
