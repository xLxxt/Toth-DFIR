from utils import case as case_utils
from utils import docker_manager


def _warn_if_running():
    # Case management is a filesystem operation and must work even when
    # Docker itself isn't installed or reachable -- only *check* for
    # running containers on a best-effort basis.
    try:
        running = docker_manager.running_names()
    except docker_manager.DockerError:
        return
    if running:
        names = ", ".join(running)
        print(
            f"[!] warning: {names} still running against the previous case's "
            "mounts. `toth restart` does NOT pick up the new mounts (it only "
            "restarts the process). Recreate the container instead: "
            "toth start <profile> (or toth enter/exec <profile>)."
        )


def new(args):
    _warn_if_running()
    name = case_utils.set_active_case(args.name)
    print(f"[+] case '{name}' created and set active")
    return 0


def list_cmd(_args):
    active = case_utils.active_case()
    cases = case_utils.list_cases()
    if not cases:
        print("No cases found.")
        print("Create one with: toth case new <name>")
        return 0
    print("Cases:\n")
    for name in cases:
        marker = "*" if name == active else " "
        print(f"  {marker} {name}")
    if active is None:
        print("\nNo case is currently active (legacy workspace mode).")
    return 0


def use(args):
    name = args.name
    if name not in case_utils.list_cases():
        raise SystemExit(
            f"[!] case '{name}' does not exist. Create it with: toth case new {name}"
        )
    _warn_if_running()
    case_utils.set_active_case(name)
    print(f"[+] case '{name}' is now active")
    return 0


def current(_args):
    active = case_utils.active_case()
    if active is None:
        print(
            "No case is currently active (legacy workspace mode: using "
            "cases/ and output/ directly)."
        )
    else:
        print(active)
    return 0
