import subprocess

from utils import config


def _compose(args):
    return subprocess.call(["docker", "compose"] + args, cwd=str(config.ROOT))


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
