import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def _load_dotenv(path):
    values = {}
    if not path.is_file():
        return values
    for line in path.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        values[key.strip()] = value.strip()
    return values


_DOTENV = _load_dotenv(ROOT / ".env")


def _setting(key, default):
    return os.environ.get(key, _DOTENV.get(key, default))


VERSION = "0.2.0-dev"
IMAGE_VERSION = _setting("TOTH_IMAGE_VERSION", "0.1.0")
REGISTRY = _setting("TOTH_REGISTRY", "ghcr.io/xlxxt")
WORKSPACE = os.path.expanduser(_setting("TOTH_WORKSPACE", "~/toth/workspace"))

PROFILES = {
    "base": "toth-base",
    "dfir": "toth-dfir",
    "malware": "toth-malware",
    "network": "toth-network",
}

DEFAULT_PROFILE = "dfir"


def service(profile):
    if profile not in PROFILES:
        raise SystemExit(f"[!] unknown profile '{profile}' (choices: {', '.join(PROFILES)})")
    return PROFILES[profile]


def image(profile):
    return f"{service(profile)}:{IMAGE_VERSION}"


def remote_image(profile):
    return f"{REGISTRY}/{service(profile)}:{IMAGE_VERSION}"


def profile_for_service(service_name):
    for profile, svc in PROFILES.items():
        if svc == service_name:
            return profile
    raise SystemExit(f"[!] unknown service '{service_name}'")
