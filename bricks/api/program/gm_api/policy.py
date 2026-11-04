"""The write policy on an `api` node (capture W1 item 5; v0.3 capture W1
item 5), run as root by gm-entrypoint and by gm-reload-api.

`/run/gm/write-policy` (written by the entrypoint from GM_WRITE_POLICY and
GM_WRITE_OVERRIDES) says the node's policy and overrides. Per directory:

  /srv/api              root:root 0755
  /srv/api/api.yaml     root:root 0644    protected, always
  /srv/api/routes/      root:root 0755, its files root:root 0644: the
                        contract, protected, never fixable
  /srv/api/db/          api:apiconf 2775, its files 0664, when fixable (the
                        policy `fixable`, or an override naming /srv/api/db);
                        2755 and 0644 otherwise

`no-access` is not fixable (the node has no player). Contents are never
touched, and nothing is done through a symbolic link: every file is opened
with O_NOFOLLOW and changed through its descriptor; a link, a file with
other hard links or anything not a regular file is left alone and named.
"""

import grp
import os
import pwd
import stat

POLICY_FILE = "/run/gm/write-policy"
POLICIES = ("fixable", "report-only", "no-access")
ROOT = "/srv/api"
DB_DIR = "/srv/api/db"
WRITABLE_PATHS = (DB_DIR, "/home/player")
OWNER, GROUP = "api", "apiconf"


class PolicyError(Exception):
    pass


def read_policy(path=POLICY_FILE):
    """-> (policy, [overrides])."""
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError as exc:
        raise PolicyError(f"{path}: cannot be read ({exc.strerror})") from None
    values = {}
    for line in text.splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            values[k] = v
    policy = values.get("policy")
    if policy not in POLICIES:
        raise PolicyError(f"{path}: no valid policy line")
    return policy, values.get("overrides", "").split()


def check_policy(policy, overrides):
    """The entrypoint's refusals; a message or None."""
    if policy not in POLICIES:
        return f"GM_WRITE_POLICY={policy!r} is not one of {', '.join(POLICIES)}"
    for o in overrides:
        if o not in WRITABLE_PATHS:
            return (f"GM_WRITE_OVERRIDES: {o!r} is not one of this brick's writable_paths "
                    f"({', '.join(WRITABLE_PATHS)})")
    if policy == "no-access" and overrides:
        return "GM_WRITE_OVERRIDES: a no-access node has no player, so nothing to override"
    return None


def db_fixable(policy, overrides):
    if policy == "fixable":
        return True
    if policy == "no-access":
        return False
    return DB_DIR in overrides


def _fix(fd, uid, gid, mode, st):
    if (st.st_uid, st.st_gid) != (uid, gid):
        os.fchown(fd, uid, gid)
    if stat.S_IMODE(os.fstat(fd).st_mode) == mode:
        return
    if mode & stat.S_ISGID and os.getegid() != gid:
        # without CAP_FSETID the kernel drops the setgid bit unless the
        # caller is in the file's group: chmod with that group as gid
        old = os.getegid()
        os.setegid(gid)
        try:
            os.fchmod(fd, mode)
        finally:
            os.setegid(old)
    else:
        os.fchmod(fd, mode)


def _open_dir(path):
    return os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)


def _files(dfd, directory, uid, gid, mode, notes, only=None):
    names = only if only is not None else sorted(e.name for e in os.scandir(dfd))
    for name in names:
        try:
            ffd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_NOCTTY, dir_fd=dfd)
        except FileNotFoundError:
            continue
        except OSError as exc:
            if exc.errno == 40:                  # ELOOP: a symbolic link
                notes.append(f"{directory}/{name}: a symbolic link, left alone")
                continue
            raise
        try:
            st = os.fstat(ffd)
            if not stat.S_ISREG(st.st_mode):
                if not (stat.S_ISDIR(st.st_mode) and name in ("routes", "db")):
                    notes.append(f"{directory}/{name}: not a regular file, left alone")
                continue
            if st.st_nlink != 1:
                notes.append(f"{directory}/{name}: has other hard links, left alone")
                continue
            _fix(ffd, uid, gid, mode, st)
        finally:
            os.close(ffd)


def restore(policy, overrides, root=ROOT, uid=None, gid=None):
    """Applies the owners and modes; returns notes (entries left alone).
    Raises OSError on a directory that cannot be opened."""
    if uid is None:
        uid = pwd.getpwnam(OWNER).pw_uid
    if gid is None:
        gid = grp.getgrnam(GROUP).gr_gid
    notes = []
    rfd = _open_dir(root)
    try:
        _fix(rfd, 0, 0, 0o755, os.fstat(rfd))
        _files(rfd, root, 0, 0, 0o644, notes, only=["api.yaml"])
    finally:
        os.close(rfd)
    routes = os.path.join(root, "routes")
    dfd = _open_dir(routes)
    try:
        _fix(dfd, 0, 0, 0o755, os.fstat(dfd))
        _files(dfd, routes, 0, 0, 0o644, notes)
    finally:
        os.close(dfd)
    db = os.path.join(root, "db")
    fixable = db_fixable(policy, overrides)
    dfd = _open_dir(db)
    try:
        _fix(dfd, uid, gid, 0o2775 if fixable else 0o2755, os.fstat(dfd))
        _files(dfd, db, uid, gid, 0o664 if fixable else 0o644, notes)
    finally:
        os.close(dfd)
    return notes
