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


def status():
    return _compose(["ps"])


def build(profile):
    ensure_docker()
    ensure_workspace()
    script = config.ROOT / "images" / profile / "build.sh"
    if not script.exists():
        raise SystemExit(f"[!] no build script for profile '{profile}'")
    return subprocess.call(["bash", str(script)], cwd=str(config.ROOT), env=_env())
