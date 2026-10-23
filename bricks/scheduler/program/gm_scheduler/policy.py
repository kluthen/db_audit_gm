"""The write policy on a scheduler node (capture W1 item 5), run as root by
the entrypoint and by `gm-reload-scheduler`.

`/run/gm/write-policy` (written by the entrypoint from GM_WRITE_POLICY and
GM_WRITE_OVERRIDES) says the node's policy and overrides. A path is
fixable when the policy is `fixable`, or it is an override or lies under
one. Every seeded file (`queries.yaml`, the files in `builders/`,
`jobs.yaml`) is owned scheduler:schedconf, 0664 when fixable, 0644
otherwise; the directories holding them, 2775 or 2755. Contents are never
touched, and nothing is done through a symbolic link: every file is opened
with O_NOFOLLOW and changed through its descriptor, so a link a player
left in a fixable directory changes nothing outside it.
"""

import grp
import os
import pwd
import stat

POLICY_FILE = "/run/gm/write-policy"
POLICIES = ("fixable", "report-only", "no-access")
REPOSITORY_DIR = "/srv/scheduler/repository"
JOBS_DIR = "/srv/scheduler/jobs"
WRITABLE_PATHS = (REPOSITORY_DIR, JOBS_DIR, "/home/player")
OWNER, GROUP = "scheduler", "schedconf"


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
    overrides = values.get("overrides", "").split()
    return policy, overrides


def check_policy(policy, overrides):
    """The entrypoint's refusals: an unknown policy, an override that is not
    one of the brick's writable_paths. Returns a message or None."""
    if policy not in POLICIES:
        return f"GM_WRITE_POLICY={policy!r} is not one of {', '.join(POLICIES)}"
    for o in overrides:
        if o not in WRITABLE_PATHS:
            return f"GM_WRITE_OVERRIDES: {o!r} is not one of this brick's writable_paths ({', '.join(WRITABLE_PATHS)})"
    return None


def is_fixable(path, policy, overrides):
    if policy == "fixable":
        return True
    return any(path == o or path.startswith(o.rstrip("/") + "/") for o in overrides)


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


def restore(policy, overrides, repository=REPOSITORY_DIR, jobs=JOBS_DIR, uid=None, gid=None):
    """Applies the owner and modes; returns a list of notes (entries left
    alone: a link, a file with other hard links). Raises OSError on a
    directory that cannot be opened."""
    if uid is None:
        uid = pwd.getpwnam(OWNER).pw_uid
    if gid is None:
        gid = grp.getgrnam(GROUP).gr_gid
    notes = []
    plan = [(repository, ("queries.yaml",), False), (os.path.join(repository, "builders"), None, True),
            (jobs, ("jobs.yaml",), False)]
    for directory, names, optional in plan:
        fixable = is_fixable(directory, policy, overrides)
        try:
            dfd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        except FileNotFoundError:
            if optional:
                continue
            raise
        except OSError as exc:
            if optional and exc.errno in (20, 40):   # ENOTDIR, ELOOP: a player's file or link
                notes.append(f"{directory}: not a directory, left alone")
                continue
            raise
        try:
            _fix(dfd, uid, gid, 0o2775 if fixable else 0o2755, os.fstat(dfd))
            if names is None:
                names = sorted(e.name for e in os.scandir(dfd) if not e.name.startswith("."))
            for name in names:
                try:
                    ffd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_NOCTTY, dir_fd=dfd)
                except FileNotFoundError:
                    continue
                except OSError as exc:
                    if exc.errno == 40:
                        notes.append(f"{directory}/{name}: a symbolic link, left alone")
                        continue
                    raise
                try:
                    st = os.fstat(ffd)
                    if not stat.S_ISREG(st.st_mode):
                        if not stat.S_ISDIR(st.st_mode):
                            notes.append(f"{directory}/{name}: not a regular file, left alone")
                        continue
                    if st.st_nlink != 1:
                        notes.append(f"{directory}/{name}: has other hard links, left alone")
                        continue
                    _fix(ffd, uid, gid, 0o664 if is_fixable(os.path.join(directory, name), policy, overrides)
                         else 0o644, st)
                finally:
                    os.close(ffd)
        finally:
            os.close(dfd)
    return notes


def any_fixable(policy, overrides):
    """Whether any file gm-reload-scheduler applies is fixable."""
    return any(is_fixable(p, policy, overrides) for p in (REPOSITORY_DIR, JOBS_DIR))
