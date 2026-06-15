import os
import subprocess

from utils import config


def _compose(args):
    env = os.environ.copy()
    env.setdefault("TOTH_WORKSPACE", config.WORKSPACE)
    return subprocess.call(["docker", "compose"] + args, cwd=str(config.ROOT), env=env)


def up(svc):
    return _compose(["up", "-d", svc])


def stop(svc):
    return _compose(["stop", svc])


def shell(svc, command):
    return _compose(["exec", svc] + command)


def build(profile):
    script = config.ROOT / "images" / profile / "build.sh"
    if not script.exists():
        raise SystemExit(f"[!] no build script for profile '{profile}'")
    return subprocess.call(["bash", str(script)], cwd=str(config.ROOT))
