"""The Docker command line, aimed at the playground's engine.

Master spec 10.2 and 11: the GM targets one swarm manager, the local engine
or one reached over SSH (`docker_endpoint` in `playground.yaml`, such as
`ssh://user@host`; never keys). Every Docker call of gmctl goes through
`Docker.run`, so the unit tests replace it with a stub.

The images' sizes (`gmctl fit`, master spec 8, spec D102) are read here:
`docker image inspect` gives an image's size and its layers' diff ids,
`docker history` the size of each layer. A layer is identified by its
chain id (the OCI ChainID: the layer and every layer under it), the id
the engine stores it by, so a layer two images share is found once.

v0.3 (master spec 10.2; capture W3, items 0, 3 and 6 of
`specs/versions/v0.3/wave-log.md`; D173, D181): a playground of several
hosts. `for_local_dir` returns the manager's Docker, which reaches any
declared host with `.on_host(<host>)` (itself on one host) and a
service's host with `.for_service(<service>)`. Swarm-scoped calls go to
the manager, node-local ones (`ps`, `exec`, a container's `inspect`,
`volume`, `image`, `save`/`load`) to the node's host. A remote host is
reached through its Docker context `dbagm-<host>` in the default store
of the host gmctl runs on (`$HOME/.docker`, which a timer run's
environment has too), ensured from `playground.yaml` before the first
call: created when missing, refused when one of that name names another
endpoint. gmctl never runs `docker context use`, and contexts outlive a
game. Today's one-host form keeps `-H <endpoint>`.
"""

import contextlib
import hashlib
import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

from . import localimpl
from .model import GmError

DOCKER = "docker"
PROBE_TIMEOUT = 60              # seconds for the engine to answer `docker version`
CONTEXT_PREFIX = "dbagm-"       # a remote host's Docker context: dbagm-<swarm node name>
# What a host timer's run lacks (D173): the desktop session's SSH agent,
# askpass and display. The unattended probe runs without them.
SESSION_ONLY_ENV = ("SSH_AUTH_SOCK", "SSH_AGENT_PID", "SSH_ASKPASS", "DISPLAY",
                    "WAYLAND_DISPLAY")


class DockerError(GmError):
    """A Docker command failed; `.args_` is the command, `.stderr` its message."""

    def __init__(self, args, returncode, stderr):
        self.args_ = list(args)
        self.returncode = returncode
        self.stderr = (stderr or "").strip()
        detail = " ".join(self.stderr.split()) or f"exit status {returncode}"
        super().__init__(f"docker {' '.join(self.args_[:3])}: {detail}")


class Docker:
    """`docker [-H <endpoint> | --context <context>] ...` as subprocesses.

    `name` is the host's swarm node name (None in today's one-host form);
    on the manager's, `hosts` maps every other declared host to its Docker
    and `placement` each service to its host."""

    def __init__(self, endpoint=None, name=None):
        self.endpoint = endpoint or None
        self.name = name
        self.hosts = {}
        self.placement = {}

    def describe(self):
        return self.endpoint or "local engine"

    def command(self, args):
        prefix = [DOCKER] + (["-H", self.endpoint] if self.endpoint else [])
        return prefix + [str(a) for a in args]

    def on_host(self, host):
        """The Docker of declared host `host`: this one for the manager, for
        None, and on a playground of one host."""
        if host is None or host == self.name or not self.hosts:
            return self
        if host not in self.hosts:
            raise GmError(f"host {host} is not declared in the playground "
                          f"({', '.join([str(self.name)] + sorted(self.hosts))})")
        return self.hosts[host]

    def for_service(self, service):
        """The Docker of the host the service's node is placed on."""
        return self.on_host(self.placement.get(service))

    def every_host(self):
        """The manager's Docker, then every other declared host's."""
        return [self] + [self.hosts[name] for name in sorted(self.hosts)]

    def run(self, args, input=None, stdin=None, capture=True, check=True, timeout=None,
            env=None, new_session=False):
        """Run `docker <args>`; returns a CompletedProcess (text mode when
        `input` is a str or nothing is fed). `stdin` is a file object
        streamed to the command; `capture=False` leaves stdout and stderr to
        the caller's terminal; `env` replaces the environment;
        `new_session` runs it with no controlling terminal. Raises
        DockerError on a non-zero exit when `check`."""
        binary = isinstance(input, (bytes, bytearray))
        kwargs = {"timeout": timeout, "env": env, "start_new_session": new_session}
        if input is not None:
            kwargs["input"] = input
        elif stdin is not None:
            kwargs["stdin"] = stdin
        else:
            kwargs["stdin"] = subprocess.DEVNULL
        if capture:
            kwargs["stdout"] = subprocess.PIPE
            kwargs["stderr"] = subprocess.PIPE
        try:
            proc = subprocess.run(self.command(args), text=not binary, **kwargs)
        except FileNotFoundError:
            raise GmError("the docker command line is not installed on this host") from None
        except subprocess.TimeoutExpired:
            raise GmError(f"docker {' '.join(map(str, args[:3]))}: no answer within "
                          f"{timeout} s") from None
        if check and proc.returncode != 0:
            raise DockerError(args, proc.returncode, proc.stderr if capture else "")
        return proc

    def lines(self, args):
        """The command's non-empty output lines."""
        out = self.run(args).stdout or ""
        return [line.strip() for line in out.splitlines() if line.strip()]

    def json(self, args):
        return json.loads(self.run(args).stdout or "null")

    @contextlib.contextmanager
    def stream(self, args):
        """`docker <args>` started with its stdout a pipe, yielded as a binary
        file object; DockerError when it then exits non-zero."""
        try:
            proc = subprocess.Popen(self.command(args), stdin=subprocess.DEVNULL,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        except FileNotFoundError:
            raise GmError("the docker command line is not installed on this host") from None
        try:
            yield proc.stdout
        finally:
            proc.stdout.close()
            stderr = proc.stderr.read().decode(errors="replace")
            proc.stderr.close()
            returncode = proc.wait()
        if returncode != 0:
            raise DockerError(args, returncode, stderr)


class ContextDocker(Docker):
    """A host reached through its Docker context `dbagm-<host>` (W3 item 3),
    ensured from the declared endpoint before the first call."""

    def __init__(self, endpoint, name, client=None):
        super().__init__(endpoint, name)
        self.context = context_name(name)
        self.client = client or Docker()
        self._ensured = False

    def describe(self):
        return f"{self.name} (context {self.context}, {self.endpoint})"

    def command(self, args):
        return [DOCKER, "--context", self.context] + [str(a) for a in args]

    def ensure(self):
        if not self._ensured:
            ensure_context(self.client, self.context, self.endpoint)
            self._ensured = True

    def run(self, args, **kwargs):
        self.ensure()
        return super().run(args, **kwargs)

    @contextlib.contextmanager
    def stream(self, args):
        self.ensure()
        with super().stream(args) as out:
            yield out


def context_name(host):
    return f"{CONTEXT_PREFIX}{host}"


def ensure_context(client, context, endpoint):
    """The Docker context `context` aimed at `endpoint`, in the client's
    default store: created when missing; GmError when it exists aimed
    elsewhere (the command to update it named). Never `docker context use`."""
    proc = client.run(["context", "inspect", "--format", "{{.Endpoints.docker.Host}}",
                       context], check=False)
    if proc.returncode == 0:
        current = (proc.stdout or "").strip()
        if current != endpoint:
            raise GmError(f"Docker context {context} names {current}, not {endpoint} as the "
                          f"playground declares: update it (docker context update {context} "
                          f"--docker host={endpoint}) or correct the playground (gmctl fit "
                          "--host)")
        return False
    client.run(["context", "create", context, "--description",
                "db_audit_gm: a playground host (gmctl)", "--docker", f"host={endpoint}"])
    return True


def host_docker(host):
    """The Docker of a declared host (`localimpl.playground_hosts`)."""
    if host.get("docker_endpoint") and host.get("name"):
        return ContextDocker(host["docker_endpoint"], host["name"])
    return Docker(host.get("docker_endpoint"), host.get("name"))


def for_local_dir(ldir):
    """The Docker command line aimed at the playground recorded in `ldir`:
    its manager's, reaching every other declared host with `.on_host`, and
    each node's host with `.for_service` once `fit` placed them."""
    pg = localimpl.read_playground(ldir)
    if pg is None:
        raise GmError(f"no playground.yaml in {ldir}: run gmctl fit first")
    if not localimpl.is_list_form(pg):
        return Docker(pg.get("docker_endpoint"))
    manager = localimpl.manager_host(pg)
    docker = host_docker(manager)
    for host in localimpl.playground_hosts(pg):
        if host["name"] != manager["name"]:
            docker.hosts[host["name"]] = host_docker(host)
    impl = localimpl.read_yaml(Path(ldir) / localimpl.IMPLEMENTATION_FILE) or {}
    docker.placement = {node["service"]: node.get("host")
                        for node in (impl.get("nodes") or {}).values() if node.get("host")}
    return docker


def probe_unattended(docker, timeout=PROBE_TIMEOUT):
    """Whether the host answers as a host timer's run would reach it (D173):
    no SSH agent, no askpass or display, no terminal. `(ok, detail)`."""
    env = {k: v for k, v in os.environ.items() if k not in SESSION_ONLY_ENV}
    env["SSH_ASKPASS_REQUIRE"] = "never"
    try:
        proc = docker.run(["version", "--format", "{{.Server.Version}}"], check=False,
                          timeout=timeout, env=env, new_session=True)
    except GmError as exc:
        return False, str(exc)
    if proc.returncode != 0:
        return False, " ".join((proc.stderr or "").split()) or f"exit status {proc.returncode}"
    return True, (proc.stdout or "").strip()


def label_filter(key, value):
    return f"label={key}={value}"


def running_containers(docker, service):
    """IDs of the running containers of a Swarm service on the host its node
    is placed on, found by the service label Swarm puts on its tasks'
    containers."""
    return docker.for_service(service).lines(["ps", "-q", "--no-trunc",
                         "--filter", label_filter("com.docker.swarm.service.name", service),
                         "--filter", "status=running"])


# --- The engine and its images ----------------------------------------------

class EngineUnreachable(GmError):
    """The targeted engine does not answer."""


def server_version(docker):
    """The targeted engine's version; EngineUnreachable when it does not
    answer (not running, wrong endpoint, SSH refused)."""
    try:
        lines = docker.lines(["version", "--format", "{{.Server.Version}}"])
    except DockerError as exc:
        detail = " ".join(exc.stderr.split()) or f"exit status {exc.returncode}"
        raise EngineUnreachable(f"the engine {docker.describe()} is not reachable: "
                                f"{detail}") from None
    except GmError as exc:
        raise EngineUnreachable(f"the engine {docker.describe()} is not reachable: "
                                f"{exc}") from None
    return lines[0] if lines else ""


def engine_name(docker):
    """The targeted engine's name (`docker info`), its swarm node name."""
    lines = docker.lines(["info", "--format", "{{.Name}}"])
    return lines[0] if lines else ""


def swarm_nodes(docker):
    """The swarm's nodes as the manager lists them, by hostname:
    `{status, availability, manager_status}` (`docker node ls`; manager_status
    is empty for a worker). DockerError when the engine is no manager."""
    nodes = {}
    for line in docker.lines(["node", "ls", "--format",
                              "{{.Hostname}}\t{{.Status}}\t{{.Availability}}\t"
                              "{{.ManagerStatus}}"]):
        parts = (line.split("\t") + ["", "", ""])[:4]
        nodes[parts[0]] = {"status": parts[1], "availability": parts[2],
                           "manager_status": parts[3]}
    return nodes


@dataclass
class Image:
    """An image as the engine holds it. `layers` lists `(chain id, size)`
    from the bottom layer up; it is empty when `docker history` does not
    give one size per layer, and the image then counts whole, sharing
    nothing."""
    name: str
    id: str
    size: int
    layers: list


def chain_ids(diff_ids):
    """The OCI chain ids of a stack of layers given by their diff ids,
    bottom first: the first layer's is its diff id, each next one
    sha256(<chain id below> + " " + <diff id>)."""
    out = []
    for diff in diff_ids:
        if not out:
            out.append(diff)
        else:
            digest = hashlib.sha256(f"{out[-1]} {diff}".encode()).hexdigest()
            out.append(f"sha256:{digest}")
    return out


def layer_sizes(docker, image_id, count):
    """The sizes of an image's `count` layers, bottom first, from `docker
    history` (whose rows without a layer weigh 0); None when its non-empty
    rows are not one per layer (a layer of size 0 makes the match
    ambiguous)."""
    rows = docker.lines(["history", "--no-trunc", "--human=false", "--format", "{{.Size}}",
                         image_id])
    try:
        sizes = [int(row) for row in reversed(rows)]
    except ValueError:
        return None
    sizes = [size for size in sizes if size > 0]
    return sizes if len(sizes) == count else None


def inspect_image(docker, name):
    """The image `name` on the targeted engine, None when it is absent;
    any other failure raises DockerError."""
    proc = docker.run(["image", "inspect", "--format", "{{json .}}", name], check=False)
    if proc.returncode != 0:
        if "no such image" in (proc.stderr or "").lower():
            return None
        raise DockerError(["image", "inspect", name], proc.returncode, proc.stderr)
    data = json.loads(proc.stdout)
    if isinstance(data, list):
        data = data[0]
    image_id, size = data["Id"], int(data["Size"])
    diff_ids = (data.get("RootFS") or {}).get("Layers") or []
    sizes = layer_sizes(docker, image_id, len(diff_ids)) if diff_ids else None
    layers = []
    if sizes is not None and sum(sizes) == size:
        layers = list(zip(chain_ids(diff_ids), sizes))
    return Image(name=name, id=image_id, size=size, layers=layers)


# --- The image copy (master spec 10.2; W3 item 6; D181) ---------------------

def image_id(docker, name):
    """The id the engine holds image `name` under, None when absent."""
    proc = docker.run(["image", "inspect", "--format", "{{.Id}}", name], check=False)
    if proc.returncode != 0:
        if "no such image" in (proc.stderr or "").lower():
            return None
        raise DockerError(["image", "inspect", name], proc.returncode, proc.stderr)
    return (proc.stdout or "").strip() or None


def copy_image(source, target, name):
    """`docker save <name> | docker --context dbagm-<host> load`: the image
    streamed from the manager's engine into the host's, never pulled."""
    with source.stream(["save", name]) as out:
        target.run(["load", "--quiet"], stdin=out)


# --- The networks a host holds (capture W3-a, item 3) -----------------------

def network_subnets(docker):
    """Every network the targeted engine lists (local and swarm-scoped) with
    its IPAM subnets: `[(name, subnet)]`, one pair per subnet, none for a
    network without one (`host`, `none`)."""
    ids = docker.lines(["network", "ls", "-q", "--no-trunc"])
    if not ids:
        return []
    pairs = []
    for line in docker.lines(["network", "inspect", "--format",
                              "{{.Name}}\t{{range .IPAM.Config}}{{.Subnet}} {{end}}", *ids]):
        name, _, subnets = line.partition("\t")
        pairs += [(name, subnet) for subnet in subnets.split()]
    return pairs
