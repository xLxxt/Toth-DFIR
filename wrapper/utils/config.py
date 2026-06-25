import os
from pathlib import Path

VERSION = "0.2.0-dev"
IMAGE_VERSION = os.environ.get("TOTH_IMAGE_VERSION", "0.1.0")
REGISTRY = os.environ.get("TOTH_REGISTRY", "ghcr.io/xlxxt")
ROOT = Path(__file__).resolve().parents[2]
WORKSPACE = os.environ.get("TOTH_WORKSPACE", os.path.expanduser("~/toth/workspace"))

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
