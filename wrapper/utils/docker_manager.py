import os
import shutil
import subprocess
from pathlib import Path

from utils import config


class DockerError(RuntimeError):
    pass


def _env():
    env = os.environ.copy()
    env.setdefault("TOTH_WORKSPACE", config.WORKSPACE)
    return env


def ensure_workspace():
    workspace = Path(config.WORKSPACE).expanduser()
    (workspace / "cases").mkdir(parents=True, exist_ok=True)
    (workspace / "output").mkdir(parents=True, exist_ok=True)


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


def up(svc):
    profile = config.profile_for_service(svc)
    ensure_image(profile)
    return _compose(["up", "-d", svc])


def stop(svc):
    return _compose(["stop", svc])


def shell(svc, command):
    return _compose(["exec", svc] + command)


TOTH_LABEL = "org.opencontainers.image.source=https://github.com/xLxxt/Toth-DFIR"


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
