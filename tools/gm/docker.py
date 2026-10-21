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
"""

import hashlib
import json
import subprocess
from dataclasses import dataclass

from . import localimpl
from .model import GmError

DOCKER = "docker"
PROBE_TIMEOUT = 60              # seconds for the engine to answer `docker version`


class DockerError(GmError):
    """A Docker command failed; `.args_` is the command, `.stderr` its message."""

    def __init__(self, args, returncode, stderr):
        self.args_ = list(args)
        self.returncode = returncode
        self.stderr = (stderr or "").strip()
        detail = " ".join(self.stderr.split()) or f"exit status {returncode}"
        super().__init__(f"docker {' '.join(self.args_[:3])}: {detail}")


class Docker:
    """`docker [-H <endpoint>] ...` as subprocesses."""

    def __init__(self, endpoint=None):
        self.endpoint = endpoint or None

    def describe(self):
        return self.endpoint or "local engine"

    def command(self, args):
        prefix = [DOCKER] + (["-H", self.endpoint] if self.endpoint else [])
        return prefix + [str(a) for a in args]

    def run(self, args, input=None, stdin=None, capture=True, check=True, timeout=None):
        """Run `docker <args>`; returns a CompletedProcess (text mode when
        `input` is a str or nothing is fed). `stdin` is a file object
        streamed to the command; `capture=False` leaves stdout and stderr to
        the caller's terminal. Raises DockerError on a non-zero exit when
        `check`."""
        binary = isinstance(input, (bytes, bytearray))
        kwargs = {"timeout": timeout}
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


def for_local_dir(ldir):
    """The Docker command line aimed at the playground recorded in `ldir`."""
    pg = localimpl.read_playground(ldir)
    if pg is None:
        raise GmError(f"no playground.yaml in {ldir}: run gmctl fit first")
    return Docker(pg.get("docker_endpoint"))


def label_filter(key, value):
    return f"label={key}={value}"


def running_containers(docker, service):
    """IDs of the running containers of a Swarm service on the targeted
    engine, found by the service label Swarm puts on its tasks' containers."""
    return docker.lines(["ps", "-q", "--no-trunc",
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
