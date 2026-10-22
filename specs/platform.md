# Platform

Status: draft v15

The swarm the games run on, the resource budget scenarios must fit, how
scenario content reaches the nodes, and the Swarm behaviours that shape the
design. Swarm facts below were checked against Docker's documentation and
source in October 2026 (current Engine 29.x); the few that were not are
marked "unverified".

## Hosting

Hosting is not fixed: it is an input of each game (D7). Among its first
questions, the GM asks where the game takes place: the swarm hosts, access
keys, and so on. Target environments:

- a single laptop;
- a student's home local network;
- a classroom, with the students' laptops joined into one swarm.

Never use an existing production swarm to host or test games (proposed).

**v0.1 runs on one host** (D35): every node on the manager the GM targets
(local, or reached over SSH), local images, no registry. If that host is
not yet a swarm, the GM runs `docker swarm init` there, or guides the user
to. Multi-host swarms, the registry and per-host SSH contexts below apply
from v0.3 (D128); remote swarm creation from a later version.

Docker Swarm is the starting platform; the project must stay adaptable
(D12; see "Portability" below). Swarm is the selected platform; Kubernetes
is future work (D122).

What a game may use is for the GM and the initiator to discuss; a game
lasts at most four hours, and the minimum capacity may rise as versions
add load, which is what a multi-host swarm is for (D122). Armenelos and
the VPS (`ssh vps`) share a Tailscale network: v0.3 brings multi-host
and tests it on that pair, the default game staying single-host (D128).
From v0.3 the playground's hosts must also stay up through two days of
aging, so v0.3 games run on always-on hosts; a classroom swarm of
student laptops waits for a later version (D114, D125).

- **Multi-host swarms use Linux hosts only** (D12). Docker Desktop's engine
  runs in a NAT'd VM, and Docker documents swarm mode on Docker Desktop as
  single-node only: the swarm ports (2377/tcp, 7946/tcp+udp, 4789/udp)
  can't reach the VM. A single Windows or macOS laptop works as a one-host
  swarm. In a classroom or home-network swarm, only Linux machines (or
  Linux VMs in bridged mode) are members; Docker Desktop machines can only
  be clients.
- The capacity available (CPU, RAM, disk) is declared at setup with the
  hosts. The GM maps it onto the scenario in a local implementation, sizing
  and tuning the setup to fit (D16, D23; [formats.md](formats.md), "Local
  implementation"). If capacity is not sufficient, the GM says so and does
  not deploy (D23).
- If a swarm already exists, the GM uses it. If none exists, the GM sets
  one up when it is given sufficient access keys, and otherwise guides the
  user through setting it up (D26).
- In a classroom swarm, students own the hosts: see
  [planes-and-access.md](planes-and-access.md), "Trust".

## Resources and nerfing

- Every scenario fits in the CPU, memory and disk declared for the
  playground; the GM checks the fit in the local implementation (D16, D23;
  in v0.1 without recomputing anything, D32).
- Databases are deliberately nerfed: limited CPU, low memory, small
  `work_mem`/buffers, etc.
- The data schema stays simple and the tables small.
- From v0.3, scenarios may include producers and consumers generating
  activity, scheduler nodes running the GM's queries (D115); from v1.0
  each scenario includes a few. v0.1 and v0.2 have none: their databases
  are static (D14, D35, D67).

Monitoring is not free: v0.2's Prometheus, Grafana, `postgres_exporter`
and the node-health script inside every node count in the budget, and
footprint is a main criterion in choosing the tools (D64, D66, D69).
v0.2 runs on one host, its scenario fitting 2 CPU / 4G / 8G, and `gmctl
fit` also counts the images' sizes against the declared disk, since on a
laptop the images grow, not the volumes (D83). It reads them from the
playground's engine, each image layer counted once, and refuses a
missing image with its build command (D102). The v0.2 estimate is in
[versions/v0.2/README.md](versions/v0.2/README.md), "Footprint".

Proposed:

- Choosing bricks is a knapsack problem: the sum of reservations stays
  within capacity minus headroom.
- Producer load is calibrated against the nerfed databases: enough to show
  contention and symptoms, not enough to saturate the host.
- **Hard limits** are the cgroup limits set by Swarm (`deploy.resources`).
  The player cannot change them; exceeding them self-punishes (OOM kill),
  which is realistic.
- **Soft settings** are engine configuration (`postgresql.conf`, `my.cnf`,
  …) the player may edit within bounds checked by the validator (see
  [planes-and-access.md](planes-and-access.md)).

## Delivering scenario content (D11)

The problem: configuration varies per scenario; the player must edit some of
it on fixable nodes; faults must be plantable; the same mechanism must work
from one laptop to a classroom swarm.

### Options compared

| Option | For | Against |
|---|---|---|
| **A. Per-scenario images**: bake config and fault material into images built for each scenario; a named volume copies the image's files on first mount, giving the player an editable copy | One artifact per node; copy-on-first-mount is native Docker behaviour; works offline on one host | A build per scenario (slow); multi-host needs a registry; the images carry the spoilers, and anyone who can pull them or owns a host can read them; any change means a rebuild |
| **B. Swarm configs as the live files** | Distributed by the swarm itself, no registry, no build | Mounted read-only and immutable: unusable for anything the player edits. Good only for protected files |
| **C. Generic images + configs as seeds + GM-side injection** | Images are built once per brick version and carry no spoilers; scenario files travel through the swarm; editable copies on a volume | Seeding logic in every brick; stateful nodes must be pinned; the GM needs access to each host's engine for state faults (over SSH, D27) |
| **D. Bind mounts or files on the hosts** | Simple on one host | Files must be copied to every host; host paths leak into the stack; the earlier lab rejected bind mounts for good reason |
| **E. Nodes fetch their files from a GM service at start** | Flexible | Another moving part on the player-reachable network, which needs its own authentication |

### Chosen: option C (D11)

1. **Brick images are generic.** One image per brick version: engine,
   supervisor, `sshd`, validator, and a seeding entrypoint. No scenario
   content and no spoilers, so how they are distributed doesn't matter.
2. **Scenario files travel as Swarm configs** with versioned names (configs
   are immutable: a change means a new name). Each node's files from the
   scenario's `nodes/<node>/` folder are mounted under a seed directory,
   root-owned. A config holds up to about 1 MiB, enough for configuration
   files.
3. **Editable files are seeded once.** On first start the entrypoint copies
   the seeds into the node's named volume and marks it seeded, with a
   root-owned marker outside every directory the player can write (D54).
   It never overwrites them afterwards. The player edits the volume copy. Volumes
   are named per scenario and node, and stateful nodes are pinned to a host
   (volumes are per host).
4. **Protected files are mounted directly** as configs, owned by root and
   read-only. Inside the container this is enforced, not just hash-checked.
5. **Faults are planted at three levels.**
   - *Configuration faults* are simply the content of the seeds (a bad
     `postgresql.conf`, a broken crontab).
   - *Parameter faults* change a parameter of the target node, applied
     when the local implementation is rendered (D92), for example a node
     left out of the node-health map. They have no `inject/` material
     ([formats.md](formats.md), "`fault.yaml` must contain", Injection;
     [v0.2 master spec](versions/v0.2/master-spec.md) 6.4).
   - *State faults* (SQL changes, bloat, an abandoned slot, forged history)
     are planted by the GM after deployment: during aging, or right after
     deployment in v0.1, which has no aging (D39). Restored-backup data is
     loaded the same way first. The GM runs the fault's `inject/` material
     inside the container through the engine of the host running it,
     reached over SSH when remote (D27). The material is streamed from the
     catalog or the scenario folder and is never left on a node.
   - Fallback if per-host engine access is not available: deliver the
     injection material as a root-only Swarm secret run once at first start.
6. **Passwords** travel as Swarm secrets.
7. **Image distribution.** On one host, use local images (built or loaded),
   named so they cannot resolve on Docker Hub. On several hosts, run a
   `registry:2` service on the infrastructure plane, with its volume pinned,
   and reference images as `127.0.0.1:5000/...`. Docker documents this
   pattern, and treats 127.0.0.0/8 as an insecure registry by default; that
   it works across hosts is documented but unverified here. The registry
   holds no spoilers, so being reachable from the network leaks nothing.

Trade-offs accepted with C:

- Every brick needs the seed-once entrypoint: a convention each brick's
  own entrypoint follows, under s6-overlay (D30), since there is no shared
  base image (D90).
- Pinned stateful nodes: a node whose host dies loses its state.
- The GM needs to reach each host's engine, over SSH (D27), which it also
  needs for sealed checks and official validator runs.
- On a host the player owns, everything mounted there is readable by that
  host's root. This is trust, as in every option (D13).
- Resetting a node, if it is ever offered (a future idea, D19), is cheap: drop its volume, restart the task,
  re-run its state injection.
- Linux containers only (Swarm configs ignore ownership and mode on Windows
  containers).

## Portability

Swarm is the starting platform, not a commitment (D12). **Portability to
Kubernetes is a requirement** (D22): the design must keep a move to
Kubernetes, self-hosted or managed, a matter of new rendering and new
platform operations, not a redesign. ECS/Fargate is not a requirement.

### Assessment

A rough estimate of what a move would cost, not a design.

| Design element | Kubernetes (incl. managed: EKS, GKE, AKS…) | AWS ECS / Fargate |
|---|---|---|
| Brick images | Carry over unchanged (OCI images). Multi-node needs a registry; managed clusters use the provider's (ECR, Artifact Registry) | Carry over unchanged; pushed to ECR |
| Scenario files as configs, seeded once into a volume | Maps directly: ConfigMaps (also read-only, ~1 MiB) plus an init container or the same entrypoint copying into a persistent volume | Rework: ECS has no config objects. Files come from the image, from S3/Parameter Store fetched at start, or env vars |
| Protected files mounted read-only | ConfigMap mounts, read-only | Rework, as above |
| GM running scripts in containers | Easier: `kubectl exec` goes through the API server, no per-host SSH needed | Rework: ECS Exec (through AWS Systems Manager) instead of `docker exec` |
| Bastion-only rule | Stronger: NetworkPolicies can enforce it; the bastion's SSH is exposed through a NodePort or LoadBalancer | Security groups enforce it; the bastion task gets the only public entry |
| Node pinning (stateful nodes) | StatefulSets with persistent volumes; local volumes still need node affinity; cloud volumes are zone-bound | Fargate has no host to pin to; persistent storage is EFS or an EBS volume attached at task launch |
| Name-based addressing | Carries over: Service DNS names | Carries over: Service Connect / Cloud Map DNS names |
| Hardening | Better: `securityContext` sets read-only root, dropped capabilities, non-root, and `allowPrivilegeEscalation: false` (the `no-new-privileges` equivalent) | Read-only root filesystem supported; Fargate's capability options are narrow |
| Multi-process nodes (supervisor, `sshd`) | Carry over (pods allow sidecars, but a database restart still needs the supervisor) | Carry over |
| Resource nerfing | Carries over: requests and limits | Coarser: Fargate tasks come in fixed CPU/memory sizes, billed per use |

Rough difficulty, cheapest first:

1. **Self-hosted Kubernetes** (k3s on the same machines): moderate. Mostly a
   new renderer from `scenario.yaml` to manifests and a new set of platform
   operations; several things get easier.
2. **Managed Kubernetes**: the same, plus cloud work (accounts, cost per
   game, registry, storage classes, exposing the bastion).
3. **ECS / Fargate**: hardest. Content delivery (D11) and state-fault
   injection need rework, there is no host access at all, and resource
   sizes are coarse.

Details in this table come from general platform knowledge and were not
researched for this project.

### Hedges (D22)

Adopted; none needs a redesign.

- **Stack files are rendered, never written by hand**, from the scenario's
  manifest into its local implementation for the playground
  ([formats.md](formats.md), "Local implementation"). A move then means a
  new renderer.
- **Platform operations go through a few named verbs**: deploy, exec in a
  node, reset a node, stop and tear down, fetch logs. Swarm is their first
  implementation. This is not an abstraction layer, just one place where
  they live.
- **Bricks know nothing about Swarm** ([formats.md](formats.md), "Brick
  definition"). Nothing inside a brick depends on Swarm-only names such as
  `tasks.<service>`.
- **Node names are valid Kubernetes names**: lowercase, digits and hyphens,
  at most 63 characters.
- **State-fault injection scripts are idempotent** and streamed over stdin,
  so they run the same through `docker exec`, `kubectl exec` or ECS Exec.
- **Image names are registry-qualified** from the start.
- **No game mechanic relies on the routing mesh** (only deliberate exposure
  faults do).

### Beyond the hedges (proposed, deferred past v0.1)

Not needed for v0.1 (D35); kept for the versions that go multi-host or
move to Kubernetes.

Checked against the requirement; these go a little further than the cheap
hedges, still without redesigning anything.

- **The verbs also cover access and checks.** Besides deploy, exec, reset,
  stop and logs: *seed node content* (Swarm configs today, ConfigMaps on
  Kubernetes), *enforce the bastion-only rule* (overlay segmentation today,
  NetworkPolicies on Kubernetes), *expose the bastion* (a published port
  today, a NodePort or LoadBalancer on Kubernetes), and *run a node's
  validator or sealed check*. The per-host SSH path that Swarm forces
  (D27) stays inside the exec verb and nowhere else.
- **Networks are declared by purpose**, not as Swarm overlays: the scenario
  says which nodes may talk to which, and the renderer turns that into
  overlays or NetworkPolicies. Kubernetes networks are flat by default, so
  segmentation there depends on a network plugin that enforces policies
  (to verify per distribution).
- **Stateful nodes are declared, not placed**: the scenario marks a node
  stateful; Swarm placement constraints or a StatefulSet with a persistent
  volume are the renderer's choice.
- **The playground declaration is not Swarm-shaped**: "a cluster, its
  hosts, their capacity and access keys" (D16) reads the same for a swarm
  or a Kubernetes cluster. Using an existing one or setting one up (D26)
  applies to both.
- **The seed-once copy stays in the brick's entrypoint** rather than in a
  Kubernetes init container, so bricks behave the same on both platforms.

## What Swarm provides

- Managers (cluster state, API) and workers; services whose tasks are
  scheduled on hosts; placement constraints and host labels.
- Overlay networks spanning all hosts (VXLAN). A service can join several
  networks, which makes dual-homed nodes natural pivots between zones.
  Overlays can be encrypted (`--opt encrypted`). Standalone containers need
  `--attachable` networks.
- Embedded DNS: `service` resolves to a virtual IP, `tasks.service` to the
  individual tasks.
- Swarm configs (up to about 1 MiB) and secrets (up to about 500 KiB).
  - Both are immutable: only labels can change, so new content needs a new
    name.
  - Both are mounted read-only from a tmpfs, with settable target, numeric
    uid/gid, and mode. Defaults: root, mode 0444; configs at `/<name>`,
    secrets under `/run/secrets/`.
  - Only managers can read them through the API (configs in clear,
    secrets never). Only hosts running a task that uses them receive them,
    and that host's root can read them while the task runs.
- Named volumes use the local driver: one volume per host, created on
  demand. On its first mount, an empty volume is populated from the image's
  content at that path, in swarm services too, unless `nocopy` is set.

## Constraints and pitfalls

- **Stack files** use the legacy Compose v3 format. `build:` is ignored, so
  images come from the local engine (one host) or a registry every host can
  reach. `depends_on` is ignored. Named volumes are per host, so stateful
  nodes are pinned with placement constraints.
- **Hardening options under `docker stack deploy`** (see D25):
  - Honoured: `read_only`, `cap_drop`/`cap_add` (Engine 20.10+), `init`,
    `sysctls`, `ulimits`, and tmpfs mounts declared as volumes.
  - Ignored: `security_opt`, so **`no-new-privileges` cannot be set from a
    stack file**. The Swarm API has supported it since Engine 25.0, but only
    through a direct API call.
  - Also ignored, silently: the service-level `tmpfs:` key.
- **No static addresses**: services cannot have fixed IPs, and overlay IPs
  change on restart. Nodes are addressed by name.
- **`docker exec`** only reaches containers through the engine of the host
  running them. The Swarm API has no exec. The GM goes through an SSH
  Docker context per host, or the equivalent (D27).
- **Routing mesh**: a published port is open on every host, even those not
  running the service. Usable deliberately as an exposure fault if network
  faults are in scope (O12); a hazard for monitoring UIs, which only the bastion publishes (D68).
- **Overlay overhead**: VXLAN adds latency and jitter; performance numbers
  measured in the game are not comparable with bare-metal measurements.

Unverified (O10): numeric-only uid/gid in config and secret mounts (read
in the source, not tested); the cross-host `127.0.0.1:5000` registry
pattern; SSH Docker contexts into Windows or macOS machines.
