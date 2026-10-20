"""`gmctl exec` and `gmctl logs`: reaching a node of a deployed game.

Master spec 11: `exec` finds the node's container on the targeted engine by
its Swarm service label and streams stdin into `sh -s` in it, with
environment variables, as a given user. In-node scripts are POSIX shell.
The GM's side of injection, data load, validation and sealed checks (chunk
7) goes through `exec_node`; the data load streams SQL into `psql` rather
than a script into `sh -s`, through its optional `argv` (capture W3-A).

Exit status: `exec_node` returns the script's own exit status; it raises
ExecError (a GmError) when the script cannot be started at all (no game, no
running container, unknown user, Docker error). Docker 29 returns 1 for its
own errors, the same code a script can return, so the user and container
are probed first (`docker exec -u <user> <container> true`).
"""

import re
from dataclasses import dataclass

from . import localimpl, state
from .docker import for_local_dir, running_containers
from .model import GmError

ENV_NAME_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
USER_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_.-]*(:[A-Za-z0-9_][A-Za-z0-9_.-]*)?$")
CANNOT_RUN = 125        # gmctl exec's exit status when the script could not be started
SHELL_ARGV = ("sh", "-s")   # what exec_node runs in the container by default


class ExecError(GmError):
    """The script could not be started on the node."""


@dataclass
class ExecResult:
    node: str
    user: str
    container: str
    returncode: int
    stdout: str = None      # None when not captured (streamed to the terminal)
    stderr: str = None

    @property
    def ok(self):
        return self.returncode == 0


def parse_env(pairs):
    """`["KEY=VALUE", ...]` (the `--env` options) as a dict."""
    env = {}
    for pair in pairs or []:
        key, sep, value = str(pair).partition("=")
        if not sep or not ENV_NAME_RE.match(key):
            raise GmError(f"--env {pair!r}: expected KEY=VALUE, KEY a shell variable name")
        env[key] = value
    return env


def _game(ldir):
    """(state, implementation) of a game whose stack is deployed."""
    st = localimpl.read_state(ldir)
    if st is None:
        raise ExecError(f"no game in {ldir}: run gmctl fit first")
    if st.get("stage") not in state.DEPLOYED_STAGES:
        raise ExecError(f"game {st.get('game_id')} is at stage {st.get('stage')}: "
                        "nothing is deployed")
    return st, localimpl.read_implementation(ldir)


def _service(impl, node):
    nodes = impl["nodes"]
    if node not in nodes:
        raise ExecError(f"no node {node!r} in this game (nodes: {', '.join(nodes)})")
    return nodes[node]["service"]


def node_container(docker, impl, node):
    """The running container of `node`, found by its Swarm service label;
    the healthy one if Swarm is replacing it."""
    service = _service(impl, node)
    containers = running_containers(docker, service)
    if not containers:
        raise ExecError(f"node {node}: no running container of service {service} on "
                        f"{docker.describe()}")
    if len(containers) > 1:
        for container in containers:
            health = docker.run(["inspect", "--format",
                                 "{{if .State.Health}}{{.State.Health.Status}}{{end}}",
                                 container], check=False).stdout or ""
            if health.strip() == "healthy":
                return container
    return containers[0]


def exec_node(ldir, node, user, stdin=None, env=None, capture=True, timeout=None,
              docker=None, argv=None):
    """Run `sh -s` as `user` in `node`'s container, the script fed on stdin.

    `stdin`: the script, a str or bytes, or a binary file object streamed as
    is (a large SQL dump); `env`: {name: value}, set with `docker exec -e`;
    `capture`: return stdout and stderr (text, or bytes when `stdin` is
    bytes) in the result, else leave them to the terminal; `argv`: the
    command run in the container instead of `sh -s` (`load-data` runs
    `psql`), stdin fed to it the same way. Returns an ExecResult whose
    `returncode` is the script's; raises ExecError when the script cannot
    be started."""
    if not USER_RE.match(str(user or "")):
        raise ExecError(f"user {user!r}: expected a user name (root, postgres, player)")
    env = dict(env or {})
    for key in env:
        if not ENV_NAME_RE.match(key):
            raise ExecError(f"environment variable {key!r}: not a shell variable name")
    _, impl = _game(ldir)
    docker = docker or for_local_dir(ldir)
    container = node_container(docker, impl, node)

    probe = docker.run(["exec", "-u", user, container, "true"], check=False, timeout=60)
    if probe.returncode != 0:
        detail = " ".join((probe.stderr or "").split()) or f"exit status {probe.returncode}"
        raise ExecError(f"node {node}: cannot run as {user}: {detail}")

    args = ["exec", "-i", "-u", user]
    for key, value in env.items():
        args += ["-e", f"{key}={value}"]
    args += [container, *(argv or SHELL_ARGV)]
    kwargs = {"capture": capture, "check": False, "timeout": timeout}
    if isinstance(stdin, (str, bytes, bytearray)):
        kwargs["input"] = stdin
    elif stdin is not None:
        kwargs["stdin"] = stdin
    else:
        kwargs["input"] = ""
    proc = docker.run(args, **kwargs)
    return ExecResult(node, user, container, proc.returncode,
                      proc.stdout if capture else None, proc.stderr if capture else None)


def logs(ldir, node, tail=None, follow=False, docker=None):
    """`docker service logs` of `node`'s service, to the terminal; returns
    Docker's exit status."""
    st = localimpl.read_state(ldir)
    if st is None:
        raise GmError(f"no game in {ldir}: run gmctl fit first")
    impl = localimpl.read_implementation(ldir)
    service = _service(impl, node)
    docker = docker or for_local_dir(ldir)
    args = ["service", "logs", "--timestamps"]
    if tail is not None:
        args += ["--tail", str(tail)]
    if follow:
        args.append("--follow")
    args.append(service)
    return docker.run(args, capture=False, check=False).returncode
