"""`gmctl deploy`: the game's stack on the playground's swarm.

Master spec 10.1, 10.2, 11 and 12; names, labels and files fixed by
capture W2-A, the Python interface by capture W2-B. In order:

1. the playground's engine must be a swarm manager (reported if it is not;
   `--init-swarm` runs `docker swarm init` on it), and every node's image
   must be present on it (deployment never pulls: `--resolve-image never`);
2. the per-game credentials are generated into `local/<playground>/secrets/`
   (directory 0700, files 0600; never printed);
3. every config and secret of `implementation.yaml` is created, named after
   the game id and labelled with it (the stack file refers to them as
   external, spec D46);
4. `docker stack deploy --resolve-image never`;
5. gmctl waits until every node's container is healthy.

Steps 2 to 5 form one setup step: if one fails, or the GM stops it, what
was deployed is torn down and the failure recorded in `state.yaml`.
"""

import os
import secrets as _random
import shutil
import subprocess
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path

from . import localimpl, state
from .docker import for_local_dir, running_containers
from .model import GmError

DEPLOY_STAGE = "deployed"
HEALTH_TIMEOUT = 300            # seconds; the database brick's start period is 60 s
POLL_INTERVAL = 3               # seconds between two health polls

# Players type their password; the database password is only ever read from files.
PLAYER_PASSWORD_ALPHABET = "abcdefghjkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
PLAYER_PASSWORD_LENGTH = 16
DBA_PASSWORD_ALPHABET = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
DBA_PASSWORD_LENGTH = 32
SSH_KEYGEN = "ssh-keygen"


# --- Swarm and images ----------------------------------------------------

def swarm_state(docker):
    """`(local node state, is manager)` of the targeted engine."""
    info = docker.json(["info", "--format", "{{json .Swarm}}"]) or {}
    return info.get("LocalNodeState") or "inactive", bool(info.get("ControlAvailable"))


def ensure_swarm(docker, init=False):
    """The engine must be a swarm manager. Without one: report, or run
    `docker swarm init` when `init`. Returns a line for the report."""
    node_state, manager = swarm_state(docker)
    if node_state == "active" and manager:
        return f"swarm: active, {docker.describe()} is a manager"
    if node_state == "active":
        raise GmError(f"{docker.describe()} is a swarm worker, not a manager: target the "
                      "swarm's manager (gmctl fit --endpoint)")
    if not init:
        raise GmError(f"{docker.describe()} is not part of a swarm (state {node_state}). "
                      "Run `docker swarm init` on it, or deploy again with --init-swarm")
    docker.run(["swarm", "init"])
    node_state, manager = swarm_state(docker)
    if node_state != "active" or not manager:
        raise GmError(f"docker swarm init on {docker.describe()} left the node {node_state}")
    return f"swarm: initialised on {docker.describe()} (docker swarm init)"


def missing_images(docker, impl):
    """Node images absent from the targeted engine (deploy never pulls)."""
    missing = []
    for node in impl["nodes"].values():
        image = node["image"]
        if image in missing:
            continue
        if docker.run(["image", "inspect", "--format", "{{.Id}}", image],
                      check=False).returncode != 0:
            missing.append(image)
    return missing


# --- Credentials ---------------------------------------------------------

def random_password(alphabet, length):
    return "".join(_random.choice(alphabet) for _ in range(length))


def write_secret_file(path, text):
    """Atomic write, mode 0600 from creation on."""
    path = Path(path)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=f".{path.name}.")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.chmod(tmp, 0o600)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


def ssh_keygen(private_path, comment):
    """An unencrypted ed25519 key pair: `private_path` and `private_path.pub`."""
    if shutil.which(SSH_KEYGEN) is None:
        raise GmError("ssh-keygen (OpenSSH) is not installed on this host: it is needed "
                      "for the players' inner-hop key")
    proc = subprocess.run([SSH_KEYGEN, "-q", "-t", "ed25519", "-N", "", "-C", comment,
                           "-f", str(private_path)],
                          stdin=subprocess.DEVNULL, capture_output=True, text=True)
    if proc.returncode != 0:
        raise GmError(f"ssh-keygen failed: {' '.join(proc.stderr.split())}")


def generate_credentials(ldir, game_id, keygen=ssh_keygen):
    """Fresh per-game credentials in `secrets/` (directory 0700, files 0600):
    the four files of localimpl.SECRET_FILES. Returns their paths."""
    sdir = localimpl.secrets_dir(ldir)
    sdir.mkdir(mode=0o700, parents=True, exist_ok=True)
    os.chmod(sdir, 0o700)
    files = {name: sdir / fname for name, fname in localimpl.SECRET_FILES.items()}
    for path in files.values():
        if path.exists():
            path.unlink()
    write_secret_file(files["player_password"],
                      random_password(PLAYER_PASSWORD_ALPHABET, PLAYER_PASSWORD_LENGTH))
    write_secret_file(files["dba_password"],
                      random_password(DBA_PASSWORD_ALPHABET, DBA_PASSWORD_LENGTH))
    # ssh-keygen writes the private key 0600 inside the 0700 directory.
    keygen(files["player_ssh_key"], f"{game_id}-player")
    for path in files.values():
        if not path.is_file():
            raise GmError(f"credential {path.name} was not written")
        os.chmod(path, 0o600)
    return list(files.values())


# --- Configs, secrets and the stack -------------------------------------

def label_args(game_id):
    args = []
    for key, value in localimpl.labels(game_id).items():
        args += ["--label", f"{key}={value}"]
    return args


def create_objects(docker, scenario_dir, impl):
    """Every config and secret of the implementation, named after and
    labelled with the game id. Returns (configs, secrets) created."""
    gid = impl["game_id"]
    scenario_dir = Path(scenario_dir).resolve()
    labels = label_args(gid)
    configs, secrets = [], []
    for node in impl["nodes"].values():
        for config in node["configs"]:
            if config["name"] in configs:
                continue
            path = scenario_dir / config["file"]
            if not path.is_file():
                raise GmError(f"config {config['name']}: {path} does not exist")
            docker.run(["config", "create", *labels, config["name"], str(path)])
            configs.append(config["name"])
    for secret in impl["secrets"]:
        path = scenario_dir / secret["file"]
        if not path.is_file():
            raise GmError(f"secret {secret['name']}: {path} does not exist")
        docker.run(["secret", "create", *labels, secret["name"], str(path)])
        secrets.append(secret["name"])
    return configs, secrets


def stack_deploy(docker, stack_file, game_id):
    docker.run(["stack", "deploy", "--detach=true", "--resolve-image", "never",
                "-c", str(stack_file), game_id])


def service_health(docker, service):
    """`(status, detail)`: status is `healthy`, `starting`, `unhealthy`,
    `pending` (no running container yet) or `rejected` (Swarm refused the
    task: it will never start)."""
    statuses = []
    for container in running_containers(docker, service):
        out = docker.run(["inspect", "--format",
                          "{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}",
                          container], check=False).stdout or ""
        statuses.append(out.strip())
    if any(s in ("healthy", "none") for s in statuses):
        return "healthy", ""
    tasks = docker.lines(["service", "ps", "--no-trunc",
                          "--format", "{{.CurrentState}}\t{{.Error}}", service])
    detail = " ".join(tasks[0].split()) if tasks else "no task yet"
    if tasks and tasks[0].startswith("Rejected"):
        return "rejected", detail
    if statuses:
        return statuses[0] or "starting", detail
    return "pending", detail


def wait_healthy(docker, impl, timeout=HEALTH_TIMEOUT, sleep=time.sleep, clock=time.monotonic,
                 interval=POLL_INTERVAL):
    """Wait until every node's container is healthy; GmError on a rejected
    task or when `timeout` seconds pass first."""
    pending = {name: node["service"] for name, node in impl["nodes"].items()}
    deadline = clock() + timeout
    last = {}
    while True:
        for name, service in list(pending.items()):
            status, detail = service_health(docker, service)
            if status == "healthy":
                del pending[name]
            elif status == "rejected":
                raise GmError(f"node {name}: Swarm rejected its task: {detail}")
            else:
                last[name] = (status, detail)
        if not pending:
            return
        if clock() >= deadline:
            waiting = "; ".join(f"node {n}: {last[n][0]} ({last[n][1]})" for n in pending)
            raise GmError(f"health checks did not pass within {timeout} s: {waiting}")
        sleep(interval)


# --- gmctl deploy --------------------------------------------------------

@dataclass
class DeployResult:
    game_id: str
    endpoint: str
    swarm: str
    credentials: list = field(default_factory=list)
    configs: list = field(default_factory=list)
    secrets: list = field(default_factory=list)
    services: list = field(default_factory=list)
    ports: list = field(default_factory=list)

    def text(self):
        out = [f"Game {self.game_id}: deployed on {self.endpoint}.",
               f"  {self.swarm}",
               f"  credentials: {len(self.credentials)} files in "
               f"{self.credentials[0].parent}/ (mode 0600, not printed)",
               f"  {len(self.configs)} configs and {len(self.secrets)} secrets created, "
               f"labelled {localimpl.LABEL_GAME}={self.game_id}",
               f"  stack {self.game_id}: {len(self.services)} services healthy "
               f"({', '.join(self.services)})"]
        for node, port in self.ports:
            out.append(f"  node {node}: port {port['published']} on the swarm host "
                       f"(container port {port['target']})")
        out.append("Stage deployed.")
        return "\n".join(out)


def deployable(st):
    """A rendered game, or one whose previous deployment failed (and was torn down)."""
    if st.get("stage") == "rendered":
        return True
    failure = st.get("failure") or {}
    return (st.get("stage") == localimpl.FAILED and failure.get("stage") == DEPLOY_STAGE
            and localimpl.effective_stage(st) == "rendered")


def deploy(scenario_dir, playground, init_swarm=False, timeout=HEALTH_TIMEOUT, docker=None,
           keygen=ssh_keygen, sleep=time.sleep, clock=time.monotonic):
    """`gmctl deploy`; returns a DeployResult, raises GmError on a refusal
    (nothing done) or state.SetupFailed on a failure (recorded)."""
    ldir = localimpl.local_dir(scenario_dir, playground)
    st = localimpl.read_state(ldir)
    if st is None:
        raise GmError(f"no game on playground {playground}: run gmctl fit first")
    if not deployable(st):
        raise GmError(f"game {st.get('game_id')} is at stage {st.get('stage')}; deploy needs "
                      "stage rendered (run gmctl render), or a failed deployment to retry")
    impl = localimpl.read_implementation(ldir)
    gid = impl["game_id"]
    stack_file = ldir / localimpl.STACK_FILE
    if not stack_file.is_file():
        raise GmError(f"{stack_file} is missing: run gmctl render")
    docker = docker or for_local_dir(ldir)

    swarm = ensure_swarm(docker, init=init_swarm)
    missing = missing_images(docker, impl)
    if missing:
        raise GmError(f"image(s) not present on {docker.describe()}: {', '.join(missing)}. "
                      "Build each brick there first (docker build -t <image> bricks/<id>); "
                      "deployment never pulls")

    result = DeployResult(gid, docker.describe(), swarm)
    with state.setup_step(ldir, DEPLOY_STAGE):
        result.credentials = generate_credentials(ldir, gid, keygen)
        result.configs, result.secrets = create_objects(docker, scenario_dir, impl)
        stack_deploy(docker, stack_file, gid)
        wait_healthy(docker, impl, timeout, sleep=sleep, clock=clock)
    localimpl.set_stage(ldir, DEPLOY_STAGE)
    result.services = [node["service"] for node in impl["nodes"].values()]
    result.ports = [(name, port) for name, node in impl["nodes"].items()
                    for port in node.get("published_ports") or []]
    return result
