import os
import shutil
import subprocess
import sys
from pathlib import Path

from utils import case, config


class DockerError(RuntimeError):
    pass


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
    directories live at <workspace>/cases/<name> and
    <workspace>/output/<name> (see utils.case) -- two independent trees
    that a single "root + fixed suffix" pattern can't reach directly. To
    keep docker-compose.yml untouched, TOTH_WORKSPACE is pointed at a small
    per-case shim directory containing "cases" and "output" symlinks into
    those real directories.
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
    return str(mount_root)


def _env():
    env = os.environ.copy()
    # Always resolve, even if TOTH_WORKSPACE is already set in the parent
    # environment: config.WORKSPACE itself already accounts for that value
    # (see utils.config), and case-scoped resolution must take priority so
    # docker/compose consistently mount the *active case's* directories.
    env["TOTH_WORKSPACE"] = _resolve_workspace()
    return env


def ensure_workspace():
    cases_dir, output_dir = case.case_paths(case.active_case())
    cases_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)


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


def _compose(args, capture=False):
    return _run(["compose"] + args, capture=capture)


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


def up(svc):
    profile = config.profile_for_service(svc)
    ensure_image(profile)
    result = _compose(["up", "-d", svc], capture=True)
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


def shell(svc, command):
    return _compose(["exec", svc] + command)


def enter(svc, command):
    profile = config.profile_for_service(svc)
    _ensure_container_exists(svc, profile)
    start_result = _run(["start", svc], capture=True)
    if start_result.returncode != 0:
        _print_process_output(start_result)
        return start_result.returncode
    exec_flags = ["-i"]
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
