"""`gmctl restart --confirmation "<the player's words>"`: the whole-game
restart (v0.3 master spec 12, 13; access model 3, 5 "Game control", 9;
spec D126, D136, D163, D176, D182).

Refused, nothing touched, without the confirmation (or a blank one), and
before hand-over: it needs `handed-over`, `final-answer` or
`feedback-given`, or `failed` after a failed restart, so the GM can retry
it (the game had been handed over, and the snapshot is still there).

The rebuild, in order:

1. Checks before anything is touched: the scenario unchanged since `fit`
   (render's check), the swarm, every placed host (deploy's), every image
   on the manager, every secret file of the game in `secrets/`, the
   snapshot's copies on their hosts when it was taken, and the overlay's
   subnet re-checked as `deploy` does with the outgoing game's network
   left out by name (Swarm removes it asynchronously; the new game keeps
   the subnet, D182).
2. The restart recorded in `state.yaml` `restarts` with the player's
   words, `status: started`, before anything else.
3. The old game's host timers and every object carrying its labels
   removed, the snapshot's copies left (`teardown.remove_game_objects`
   without `snapshot_ids`).
4. A new game id: `implementation.yaml` rebuilt for it (same hosts, the
   snapshot's verdict and the overlay's subnet kept), `state.yaml` carried
   over under it (its stage kept, its timers cleared: the old units are
   gone), then rendered with the planned hand-over, the shift and the
   customer's zone kept and a new seed in every scheduler's
   `schedule.yaml`, which is not on a volume (D163).
5. Deployed as `deploy` does, with no new credential: every secret file
   is kept, so the new `<new id>_<name>` Swarm objects carry the same
   values (master spec 12).
6. From the snapshot: before the stack, each copied volume created on its
   node's host under the new id, labelled as Swarm labels a stack's
   volume, and filled from its copy by a helper container (`--rm`,
   `--pull never`, no network, labelled `dbagm.game=<new id>`, the node's
   own image); once healthy, each scheduler polled until it reads
   `running` (it resumes from its marker, T0 unchanged). The copies carry
   the check role's `CONNECT` with the data (D176).
   With no snapshot (it did not fit): `load-data`'s steps, its grants
   included; every state fault's scripts at once, those due at T0 and
   those due during the aging; with scheduler nodes, every load started
   at once under a new T0, every timeline change already past and so
   applied (the planned hand-over is kept). `start-load`'s and `inject
   --at`'s after-hand-over refusals do not apply: the restart calls the
   steps beneath them.
7. The rebuilt game at `handed-over`, its four hours still counting from
   the first hand-over (`aging.handover_instant`); the restart's record
   `completed`; the snapshot record and its copies unchanged, for a
   second restart and for teardown.

A failure from step 3 on tears down what the restart deployed, records
`failed` (failure stage `handed-over`) and the restart's record `failed`
with its reason; the snapshot stays.

Recorded in `state.yaml` (master spec 12 "Record"; access model 9):

    restarts:
      - from_game: <old id>
        to_game: <new id>
        at: <instant it began>
        from_snapshot: true | false
        confirmation: <the player's words>
        status: started | completed | failed
        finished_at: <instant>          # completed
        previous_t0: <instant>          # with no snapshot, in a game that ages
        reason: <the failure>           # failed
"""

import time
from dataclasses import dataclass, field
from pathlib import Path

from . import aging, deploy, inject, localimpl, model, render, snapshot, state, teardown
from .docker import for_local_dir
from .execnode import exec_node
from .model import GmError

HANDED_OVER = aging.HANDED_OVER
FROM_STAGES = aging.AFTER_HANDOVER          # handed-over, final-answer, feedback-given
STARTED, COMPLETED, FAILED = "started", "completed", "failed"
RESTORE_MOUNT = "/volume"
BY_RESTART = "restart"
CONFIRMATION_HINT = '--confirmation "<the player\'s words>"'

# A scheduler restored from the snapshot resumes from its marker: its
# status file reads `running` once it does (W1-y), within RUNNING_WITHIN s.
RESUME_SCRIPT = f"""line=
i=0
while [ "$i" -lt {aging.RUNNING_WITHIN} ]; do
    line=$(cat {aging.SCHEDULER_STATUS} 2>/dev/null || true)
    case "$line" in
        "running "*) printf '%s\\n' "$line"; exit 0 ;;
    esac
    sleep 1
    i=$((i + 1))
done
echo "status did not read running within {aging.RUNNING_WITHIN} s (last: ${{line:-none}})"
exit 1
"""


# --- Refusals -----------------------------------------------------------------

def confirmation_text(confirmation):
    """The player's words, whitespace collapsed to one line; GmError when
    none is given (master spec 12: refused without it)."""
    text = " ".join(str(confirmation or "").split())
    if not text:
        raise GmError("restart refused: no confirmation. A restart runs only once a player has "
                      "confirmed it in so many words, recorded with " + CONFIRMATION_HINT
                      + "; nothing done")
    return text


def retrying(st):
    """A failed game whose failure is a restart's: the GM may run it again."""
    restarts = st.get("restarts") or []
    return (st.get("stage") == localimpl.FAILED
            and (st.get("failure") or {}).get("stage") == HANDED_OVER
            and bool(restarts) and restarts[-1].get("status") == FAILED)


def refusal(st):
    """Why `restart` is refused at the game's stage; None when it may run."""
    gid, stage = st.get("game_id"), st.get("stage")
    if stage == localimpl.TORN_DOWN or localimpl.teardown_record(st):
        return f"game {gid} is torn down: there is nothing to restart"
    if stage in FROM_STAGES or retrying(st):
        return None
    return (f"game {gid} is at stage {stage}: a restart rebuilds a handed-over game, so it "
            f"needs stage {', '.join(FROM_STAGES[:-1])} or {FROM_STAGES[-1]} (or failed after "
            "a failed restart)")


def snapshot_record(st):
    """`(record, from the snapshot)`; GmError when the hand-over snapshot
    is neither taken nor recorded as not fitting (D172 makes it a
    condition of the hand-over)."""
    record = st.get("snapshot") or {}
    if record.get("status") not in snapshot.READY:
        raise GmError(f"restart refused: game {st.get('game_id')}'s hand-over snapshot is "
                      f"{record.get('status') or 'not recorded'}, neither taken nor recorded as "
                      "not fitting; nothing done")
    return record, record["status"] == snapshot.TAKEN


def check_secret_files(scenario_dir, impl):
    """Every secret file of the game is kept by a restart: each must be there."""
    missing = [sec["file"] for sec in impl.get("secrets") or []
               if not (Path(scenario_dir) / sec["file"]).is_file()]
    if missing:
        raise GmError(f"restart refused: the game's secret file(s) {', '.join(missing)} are "
                      "missing: a restart keeps every secret's value; nothing done")


def check_snapshot_hosts(impl, record):
    """Each copy is restored on its node's host, the one it was taken on."""
    wrong = [f"{v['copy']} on {v.get('host')}, node {v['node']} on "
             f"{(impl['nodes'].get(v['node']) or {}).get('host')}"
             for v in record.get("volumes") or []
             if v["node"] not in impl["nodes"]
             or (impl["nodes"][v["node"]].get("host") or None) != (v.get("host") or None)]
    if wrong:
        raise GmError("restart refused: the snapshot's copies are not on their nodes' hosts: "
                      + "; ".join(wrong) + "; nothing done")


# --- The rebuild ----------------------------------------------------------------

def new_implementation(scenario, playground, old, game_id, subnet):
    """`implementation.yaml` for the new game id: each node on its host,
    `snapshot_fit` and the overlay's subnet kept; its timeline added by
    the restart's render."""
    hosts = {name: node.get("host") for name, node in old["nodes"].items()}
    impl = localimpl.build_implementation(scenario, playground, game_id, localimpl.now_iso(),
                                          hosts, old.get("snapshot_fit"))
    if subnet:
        impl[localimpl.OVERLAY] = {"subnet": subnet}
    return impl


def new_timeline(scenario, old):
    """The restart's timeline: the planned hand-over, the shift and the
    customer's zone kept, a new seed (capture W2 item 1; D136, D163)."""
    planned = aging.parse_instant((old.get(localimpl.TIMELINE) or {}).get("planned_handover"))
    return render.build_timeline(scenario, planned, None, aging.iso(aging.now_utc()))


def carry_state(st, game_id):
    """`state` (a dict) carried over to the new game id: its stage, history
    and records kept, every timer cleared (the old game's units are gone).
    A retry after a failed restart is back at the stage it had reached,
    with no history entry (the restart's close writes one), so the steps
    that run in the nodes find a deployed stage."""
    st["game_id"] = game_id
    if st.get("stage") == localimpl.FAILED:
        st["stage"] = localimpl.effective_stage(st)
        st["failure"] = None
    early = st.get("early_check")
    if early and early.get("timer"):
        early["timer"] = None
    for planting in (st.get("plantings") or {}).values():
        if planting and planting.get("timer"):
            planting["timer"] = None
    return st


def switch_game(ldir, impl, game_id):
    """The local implementation now holds the new game: implementation.yaml
    first, then state.yaml under the state lock."""
    localimpl.write_implementation(ldir, impl)
    localimpl.update_state(ldir, lambda st: carry_state(st, game_id) and None)


def place(docker, impl):
    """The Docker's map from each node's service to its host, for the new names."""
    placement = getattr(docker, "placement", None)
    if placement is not None:
        placement.update({node["service"]: node.get("host")
                          for node in impl["nodes"].values() if node.get("host")})


def volume_name(impl, node, volume):
    """The new game's name of `node`'s volume `volume`."""
    return f"{impl['game_id']}_{node}_{volume}"


def restore_args(impl, node, volume, copy):
    """The helper container filling a fresh volume from its copy."""
    gid = impl["game_id"]
    return ["run", "--rm", "--pull", "never", "--network", "none", "--user", "0:0",
            "--label", f"{localimpl.LABEL_GAME}={gid}",
            "-v", f"{copy}:{snapshot.COPY_MOUNT}:ro",
            "-v", f"{volume_name(impl, node, volume)}:{RESTORE_MOUNT}",
            "--entrypoint", "tar", impl["nodes"][node]["image"],
            "--extract", f"--file={snapshot.COPY_MOUNT}/{snapshot.TAR_NAME}",
            "--numeric-owner", "--same-permissions", f"--directory={RESTORE_MOUNT}"]


def restore_volumes(docker, impl, record):
    """Every copied volume created fresh on its node's host under the new
    id, labelled as Swarm labels the stack's volumes (Swarm uses a volume
    of the name it would create), and filled from its copy. Returns the
    names restored."""
    gid = impl["game_id"]
    restored = []
    for vol in record.get("volumes") or []:
        node, volume = vol["node"], vol["volume"]
        host = docker.on_host(impl["nodes"][node].get("host"))
        name = volume_name(impl, node, volume)
        host.run(["volume", "create", "--label", f"{localimpl.LABEL_NAMESPACE}={gid}",
                  "--label", f"{localimpl.LABEL_GAME}={gid}", name])
        proc = host.run(restore_args(impl, node, volume, vol["copy"]), check=False)
        if proc.returncode != 0:
            detail = " ".join((proc.stderr or "").split()) or f"exit status {proc.returncode}"
            raise GmError(f"restoring {node} {volume} from {vol['copy']}: {detail}")
        restored.append(name)
    return restored


def resume_schedulers(ldir, impl, docker):
    """Each scheduler, restored with its marker, reads `running`. Returns
    `{node: running line}`; GmError naming those that do not."""
    running, failed = {}, []
    for node in aging.scheduler_nodes(impl):
        run = exec_node(ldir, node, "root", stdin=RESUME_SCRIPT,
                        timeout=aging.START_TIMEOUT, docker=docker)
        if run.ok:
            running[node] = aging.first_line(run)
        else:
            failed.append(f"{node}: {aging.first_line(run)}")
    if failed:
        raise GmError("scheduler(s) restored from the snapshot did not resume: "
                      + "; ".join(failed))
    return running


def plant_everything(ldir, scenario, impl, docker, timeout=None, out=print):
    """Every state fault's scripts, in instance order, whatever its planting
    moment (master spec 12, "Otherwise, no history"). Returns
    `[(instance, script)]` run."""
    ran = []
    for iid, fault, node, run_as, env, scripts in inject.inject_plan(scenario, impl):
        for script, text in scripts:
            run = exec_node(ldir, node, run_as, stdin=text, env=env, timeout=timeout,
                            docker=docker)
            inject._print_run(out, f"{iid} {script} ({node}, as {run_as})", run)
            if not run.ok:
                raise GmError(f"planting {iid} ({fault.id}) stopped at {script}: exit "
                              f"{run.returncode}: {inject._first_line(run)}")
            ran.append((iid, script))
    return ran


def start_schedulers(ldir, impl, docker, t0):
    """Every scheduler's marker written with `t0` and its load started
    (`start-load`'s script); `{node: {outcome, running_at}}`; GmError
    naming those that do not start."""
    nodes, failed = {}, []
    for node in aging.scheduler_nodes(impl):
        run = exec_node(ldir, node, "root", stdin=aging.START_SCRIPT, env={"GM_T0": t0},
                        timeout=aging.START_TIMEOUT, docker=docker)
        line = aging.first_line(run)
        if run.ok:
            nodes[node] = {"outcome": "ok",
                           "running_at": line.split(" ", 1)[1] if " " in line else line}
        else:
            failed.append(f"{node}: {line}")
    if failed:
        raise GmError("the load did not start: " + "; ".join(failed))
    return nodes


def restart_plantings(scenario, impl, at):
    """`plantings` after a restart with no snapshot: every instance planted
    at `at` by the restart."""
    timeline = (impl.get(localimpl.TIMELINE) or {}).get("instances") or {}
    out = {}
    for inst, _ in inject.fault_instances(scenario):
        plant_at = inject.plant_at_of(scenario, impl, inst)
        if plant_at == aging.T0:
            out[inst["id"]] = {"plant_at": plant_at, "planted_at": at, "by": BY_RESTART}
        else:
            out[inst["id"]] = {"plant_at": plant_at,
                               "planned_at": (timeline.get(inst["id"]) or {}).get("planned_at"),
                               "timer": None,
                               "attempts": [{"at": at, "by": BY_RESTART, "outcome": "ok"}],
                               "planted_at": at, "by": BY_RESTART}
    return out


# --- gmctl restart --------------------------------------------------------------

@dataclass
class RestartResult:
    from_game: str
    to_game: str
    from_snapshot: bool
    confirmation: str
    at: str
    lines: list = field(default_factory=list)       # the checks' lines
    restored: list = field(default_factory=list)    # volumes filled from the snapshot
    running: dict = field(default_factory=dict)     # schedulers resumed or started
    t0: str = None                                  # with no snapshot, a game that ages
    planted: list = field(default_factory=list)     # [(instance, script)], no snapshot
    loaded: object = None                           # load-data's steps, no snapshot
    seed: int = None

    def text(self):
        how = "from the hand-over snapshot" if self.from_snapshot else "with no history"
        out = [f"Game {self.from_game} restarted {how} as game {self.to_game} "
               f"(confirmed: \"{self.confirmation}\")."]
        out += [f"  {line}" for line in self.lines]
        out.append(f"  game {self.from_game} removed, its snapshot kept; every secret's value "
                   f"kept under new objects named {self.to_game}_<name>")
        if self.seed is not None:
            out.append(f"  new seed {self.seed} in every scheduler's schedule.yaml")
        if self.from_snapshot:
            out.append(f"  {len(self.restored)} volumes restored from the snapshot")
            out += [f"  {node}: resumed from its marker, {line}"
                    for node, line in self.running.items()]
        else:
            if self.loaded is not None:
                out.append(f"  data loaded: {len(self.loaded.loaded)} node(s); scheduler "
                           f"passwords on {len(self.loaded.passwords)}; check role's CONNECT "
                           f"on {len(self.loaded.grants)}")
            out.append(f"  every fault planted at once: {len(self.planted)} script(s) run")
            if self.t0:
                out.append(f"  load started at once, T0 {self.t0}, every timeline change "
                           "already applied")
        out.append(f"Stage {HANDED_OVER}; the four hours still count from the first hand-over.")
        return "\n".join(out)


def restart(scenario_dir, playground, confirmation, docker=None, systemd=None,
            timeout=deploy.HEALTH_TIMEOUT, out=print, sleep=time.sleep, clock=time.monotonic):
    """`gmctl restart --confirmation "<words>"`; returns a RestartResult.
    Raises GmError on a refusal (nothing done, nothing recorded) or
    state.SetupFailed on a failure (what it deployed torn down, recorded)."""
    ldir = localimpl.local_dir(scenario_dir, playground)
    st = localimpl.read_state(ldir)
    if st is None:
        raise GmError(f"no game on playground {playground}: run gmctl fit first")
    words = confirmation_text(confirmation)
    why = refusal(st)
    if why:
        raise GmError(f"restart refused: {why}; nothing done")
    impl = localimpl.read_implementation(ldir)
    old = impl["game_id"]
    if st.get("game_id") != old:
        raise GmError(f"state.yaml (game {st.get('game_id')}) and implementation.yaml (game "
                      f"{old}) disagree: nothing done")
    record, from_snapshot = snapshot_record(st)
    scenario = model.load_scenario(scenario_dir)
    render._check_fit(scenario, impl, playground)
    check_secret_files(scenario_dir, impl)
    systemd = systemd or aging.Systemd()
    if not systemd.reachable() and aging.records_timer(st):
        raise GmError(f"restart refused: the user's systemd manager does not answer, and game "
                      f"{old} has host timers to remove; nothing done")
    docker = docker or for_local_dir(ldir)
    lines = [deploy.ensure_swarm(docker)]
    lines += deploy.check_hosts(docker, impl)
    missing = deploy.missing_images(docker, impl)
    if missing:
        raise GmError(f"restart refused: image(s) not present on {docker.describe()}: "
                      f"{', '.join(missing)}; nothing done")
    if from_snapshot:
        check_snapshot_hosts(impl, record)
        snapshot.check_copies(docker, record)
    chosen = deploy.game_subnet(docker, impl)
    subnet = None
    if chosen:
        subnet, line = chosen
        lines.append(line)

    new = localimpl.new_game_id(scenario.id, localimpl.max_game_id_length(scenario))
    while new == old:
        new = localimpl.new_game_id(scenario.id, localimpl.max_game_id_length(scenario))
    began = aging.iso(aging.now_utc())
    entry = {"from_game": old, "to_game": new, "at": began, "from_snapshot": from_snapshot,
             "confirmation": words, "status": STARTED}
    localimpl.update_state(ldir, lambda s: s.setdefault("restarts", []).append(entry))
    result = RestartResult(old, new, from_snapshot, words, began, lines)

    current = [old]

    def undo():
        return teardown.remove_game_objects(docker, current[0], sleep=sleep, clock=clock).text()

    try:
        with state.setup_step(ldir, HANDED_OVER, undo=undo):
            aging.remove_game_timers(systemd, old, st)
            teardown.remove_game_objects(docker, old, sleep=sleep, clock=clock)
            new_impl = new_implementation(scenario, playground, impl, new, subnet)
            switch_game(ldir, new_impl, new)
            current[0] = new
            place(docker, new_impl)
            timeline = new_timeline(scenario, impl)
            render.write_rendered(scenario, playground, ldir, new_impl, timeline)
            result.seed = (timeline or {}).get("seed")
            deploy.record_images(ldir, deploy.copy_images(docker, new_impl))
            deploy.create_objects(docker, scenario_dir, new_impl)
            if from_snapshot:
                result.restored = restore_volumes(docker, new_impl, record)
            deploy.stack_deploy(docker, ldir / localimpl.STACK_FILE, new)
            deploy.wait_healthy(docker, new_impl, timeout, sleep=sleep, clock=clock)
            if from_snapshot:
                result.running = resume_schedulers(ldir, new_impl, docker)
            else:
                result.loaded = inject.LoadResult(new)
                inject.load_steps(ldir, inject.load_plans(scenario, new_impl), docker,
                                  result.loaded, out=out)
                result.planted = plant_everything(ldir, scenario, new_impl, docker, out=out)
                planted_at = localimpl.now_iso()
                if aging.scheduler_nodes(new_impl):
                    result.t0 = aging.iso(aging.now_utc())
                    started = start_schedulers(ldir, new_impl, docker, result.t0)
                    result.running = {n: r["running_at"] for n, r in started.items()}
    except state.SetupFailed as exc:
        def failed(s):
            last = (s.get("restarts") or [None])[-1]
            if last and last.get("to_game") == new:
                last.update(status=FAILED, reason=exc.reason, finished_at=localimpl.now_iso())
        localimpl.update_state(ldir, failed)
        raise

    finished = localimpl.now_iso()

    def close(s):
        last = s["restarts"][-1]
        last.update(status=COMPLETED, finished_at=finished)
        if not from_snapshot:
            s["plantings"] = restart_plantings(scenario, new_impl, planted_at)
            if result.t0:
                load = s.setdefault("load", {"t0": None, "attempts": []})
                last["previous_t0"] = load.get("t0")
                load.setdefault("attempts", []).append(
                    {"began": result.t0, "by": BY_RESTART, "nodes": started})
                load["t0"] = result.t0
                aging.write_earliest(s, new_impl, aging.parse_instant(result.t0))
        localimpl.enter_stage(s, HANDED_OVER, finished)
    localimpl.update_state(ldir, close)
    return result
