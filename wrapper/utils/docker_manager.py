import os
import shutil
import subprocess
import sys
from pathlib import Path

from utils import case, config, vpn


class DockerError(RuntimeError):
    pass


# Every Toth image's intended interactive user, regardless of which user the
# image itself is configured to default to. This matters concretely for
# toth-network: its ENTRYPOINT needs to start as root (to bring up a VPN
# tunnel), so its image-level USER is root -- but `docker exec`/`docker
# compose exec` use the image's configured default user, not whatever user
# the entrypoint-spawned foreground process ends up running as after
# dropping privileges. Without an explicit --user here, every `toth exec
# network`/`toth shell network`/`toth enter network` would silently run as
# root, even though the container's own PID 1 correctly runs as analyst.
ANALYST_USER = "analyst"


def _ensure_case_mount_link(link_path, target_dir):
    target_dir.mkdir(parents=True, exist_ok=True)
    if link_path.is_symlink():
        try:
            if link_path.resolve() == target_dir.resolve():
                return
        except OSError:
            pass
        link_path.unlink()
    elif link_path.exists():
        # Unexpected non-symlink entry at this path; leave it alone rather
        # than risk deleting something unrelated.
        return
    link_path.symlink_to(target_dir, target_is_directory=True)


def _resolve_workspace():
    """Resolve the TOTH_WORKSPACE value handed to docker/compose.

    docker-compose.yml unconditionally mounts ${TOTH_WORKSPACE}/cases and
    ${TOTH_WORKSPACE}/output. With no active case, TOTH_WORKSPACE is the
    workspace root, so those mounts resolve to the legacy flat directories
    (unchanged behavior). With an active case, the real per-case
    directories live at <workspace>/cases/<name>, <workspace>/output/<name>,
    and <workspace>/vpn/<name> (see utils.case, utils.vpn) -- independent
    trees that a single "root + fixed suffix" pattern can't reach directly.
    To keep docker-compose.yml untouched, TOTH_WORKSPACE is pointed at a
    small per-case shim directory containing "cases", "output", and "vpn"
    symlinks into those real directories. The vpn symlink is created (and
    its target directory created if it doesn't exist yet) even for cases
    with no VPN config, so a future VPN bind-mount always has something to
    mount rather than failing on a missing source path.
    """
    workspace = Path(config.WORKSPACE).expanduser()
    active = case.active_case()
    if active is None:
        return str(workspace)

    cases_dir, output_dir = case.case_paths(active)
    mount_root = workspace / ".case-mounts" / active
    mount_root.mkdir(parents=True, exist_ok=True)
    _ensure_case_mount_link(mount_root / "cases", cases_dir)
    _ensure_case_mount_link(mount_root / "output", output_dir)
    _ensure_case_mount_link(mount_root / "vpn", vpn.vpn_dir(active))
    return str(mount_root)


def _resolve_xauthority():
    """Resolve the host's Xauthority path for --gui (X11 forwarding) mode.

    Mirrors _resolve_workspace()'s pattern: compute a value from host state
    once here and hand it to the compose subprocess as an env var that
    docker-compose.gui.yml interpolates (${TOTH_XAUTHORITY}), rather than
    leaning on Compose's own `${VAR:-default}` interpolation syntax.
    Follows the same $XAUTHORITY-falling-back-to-~/.Xauthority convention
    X11 client libraries themselves use.
    """
    xauthority = os.environ.get("XAUTHORITY")
    if xauthority:
        return xauthority
    return str(Path.home() / ".Xauthority")


def _env():
    env = os.environ.copy()
    # Always resolve, even if TOTH_WORKSPACE is already set in the parent
    # environment: config.WORKSPACE itself already accounts for that value
    # (see utils.config), and case-scoped resolution must take priority so
    # docker/compose consistently mount the *active case's* directories.
    env["TOTH_WORKSPACE"] = _resolve_workspace()
    # Always resolved too, even for non-GUI invocations: cheap, and it means
    # docker-compose.gui.yml can interpolate ${TOTH_XAUTHORITY} unconditionally
    # without a Compose-side "variable not set" warning on --gui. It is only
    # ever referenced by docker-compose.gui.yml, which is only layered in on
    # --gui invocations, so this has no effect on non-GUI containers.
    env["TOTH_XAUTHORITY"] = _resolve_xauthority()
    return env


def ensure_workspace():
    cases_dir, output_dir = case.case_paths(case.active_case())
    cases_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    # Flat vpn root for the no-active-case state, mirroring cases_dir/
    # output_dir's own flat-root fallback above: with no case active,
    # TOTH_WORKSPACE is the workspace root, so docker-compose.yml's
    # ${TOTH_WORKSPACE}/vpn mount (toth-network only) resolves directly here
    # rather than through the per-case symlink shim in _resolve_workspace().
    # Docker won't reliably auto-create a missing bind-mount source, so this
    # has to exist before `docker compose up` runs -- always empty in this
    # state, since vpn.add_vpn_config() always requires a case name.
    (Path(config.WORKSPACE).expanduser() / "vpn").mkdir(parents=True, exist_ok=True)


def ensure_docker():
    if shutil.which("docker") is None:
        raise DockerError("Docker is not installed or not available in PATH.")
    result = subprocess.run(
        ["docker", "info"],
        cwd=str(config.ROOT),
        env=_env(),
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode != 0:
        raise DockerError("Docker daemon is not reachable. Start Docker and retry.")


def _run(args, capture=False):
    ensure_docker()
    ensure_workspace()
    command = ["docker"] + args
    if capture:
        return subprocess.run(
            command,
            cwd=str(config.ROOT),
            env=_env(),
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    return subprocess.call(command, cwd=str(config.ROOT), env=_env())


def _compose_args(args, gui=False):
    """Build the `docker compose` argv, optionally layering in GUI mode.

    Pure and side-effect-free on purpose (no subprocess, no filesystem) so
    it can be exercised directly in tests without Docker or an X server.

    Non-GUI path is untouched from before --gui existed: just
    ["compose"] + args, relying on Compose's default docker-compose.yml
    auto-discovery in cwd (config.ROOT). GUI mode has to name both files
    explicitly with -f -- Compose stops auto-loading docker-compose.yml the
    moment any -f is given, so the base file must be listed too.
    """
    if not gui:
        return ["compose"] + args
    return ["compose", "-f", "docker-compose.yml", "-f", "docker-compose.gui.yml"] + args


def _ensure_gui_available():
    """Fail fast, with a clear message, if --gui can't work on this host.

    Better than letting `docker compose up` succeed and the GUI app fail
    later inside the container with an opaque "cannot open display" error.
    """
    if not os.environ.get("DISPLAY"):
        raise DockerError(
            "--gui requires DISPLAY to be set. Run toth from a real desktop "
            "session on the Docker host itself (a plain SSH session without "
            "-X/-Y won't have a usable DISPLAY)."
        )
    if not Path("/tmp/.X11-unix").exists():
        raise DockerError(
            "--gui requires a running host X server, but /tmp/.X11-unix "
            "was not found."
        )


def _compose(args, gui=False, capture=False):
    if gui:
        _ensure_gui_available()
    return _run(_compose_args(args, gui=gui), capture=capture)


def image_exists(profile):
    result = _run(["image", "inspect", config.image(profile)], capture=True)
    return result.returncode == 0


def ensure_image(profile):
    if not image_exists(profile):
        raise DockerError(
            f"Image {config.image(profile)} is missing. Run: toth update {profile}"
        )


def _print_process_output(result):
    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="")


def _container_exists(name):
    result = _run(["container", "inspect", name], capture=True)
    return result.returncode == 0


def _ensure_container_exists(name, profile):
    if not _container_exists(name):
        raise DockerError(
            f"Container {name} does not exist. Start it with: toth shell {profile}"
        )


def up(svc, gui=False):
    profile = config.profile_for_service(svc)
    ensure_image(profile)
    result = _compose(["up", "-d", svc], gui=gui, capture=True)
    if result.returncode == 0:
        _print_process_output(result)
        return 0

    output = f"{result.stdout}\n{result.stderr}"
    if "already in use" in output and svc in output:
        raise DockerError(
            f"Container name {svc} is already in use. "
            f"Re-enter it with: toth enter {profile}. "
            f"Remove it with: toth remove {profile}."
        )

    _print_process_output(result)
    return result.returncode


def stop(svc):
    return _compose(["stop", svc])


def shell(svc, command, gui=False):
    return _compose(["exec", "--user", ANALYST_USER, svc] + command, gui=gui)


def enter(svc, command):
    profile = config.profile_for_service(svc)
    _ensure_container_exists(svc, profile)
    start_result = _run(["start", svc], capture=True)
    if start_result.returncode != 0:
        _print_process_output(start_result)
        return start_result.returncode
    exec_flags = ["-i", "--user", ANALYST_USER]
    if sys.stdin.isatty():
        exec_flags.append("-t")
    return _run(["exec"] + exec_flags + [svc] + command)


def restart(svc):
    profile = config.profile_for_service(svc)
    _ensure_container_exists(svc, profile)
    return _run(["restart", svc])


def remove(svc):
    profile = config.profile_for_service(svc)
    _ensure_container_exists(svc, profile)
    return _run(["rm", "-f", svc])


TOTH_LABEL = "org.opencontainers.image.source=https://github.com/xLxxt/Toth-DFIR"


def running_names():
    """Return the names of currently running Toth containers."""
    result = _run(
        [
            "ps",
            "--filter",
            f"label={TOTH_LABEL}",
            "--filter",
            "status=running",
            "--format",
            "{{.Names}}",
        ],
        capture=True,
    )
    if result.returncode != 0:
        return []
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def status():
    result = _run(
        [
            "ps",
            "-a",
            "--filter",
            f"label={TOTH_LABEL}",
            "--format",
            "{{.Names}}\t{{.Image}}\t{{.Status}}",
        ],
        capture=True,
    )
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr.strip())
        return result.returncode

    rows = []
    for line in result.stdout.splitlines():
        parts = line.split("\t", 2)
        if len(parts) != 3:
            continue
        rows.append(tuple(parts))

    if not rows:
        print("No Toth containers found.")
        print("Start one with: toth shell dfir")
        return 0

    print(f"{'NAME':<18} {'IMAGE':<38} STATUS")
    for name, image, status_text in rows:
        print(f"{name:<18} {image:<38} {status_text}")
    return 0


def pull(profile):
    ensure_docker()
    ensure_workspace()
    remote = config.remote_image(profile)
    local = config.image(profile)
    print(f"[+] Pulling {remote}")
    code = _run(["pull", remote])
    if code != 0:
        print(f"[!] Failed to pull {remote}")
        print(f"[!] If the image is not published yet, use: toth update --build {profile}")
        return code
    print(f"[+] Tagging {remote} as {local}")
    return _run(["tag", remote, local])


def build(profile):
    ensure_docker()
    ensure_workspace()
    script = config.ROOT / "images" / profile / "build.sh"
    if not script.exists():
        raise SystemExit(f"[!] no build script for profile '{profile}'")
    return subprocess.call(["bash", str(script)], cwd=str(config.ROOT), env=_env())
