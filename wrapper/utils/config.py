import os
from pathlib import Path

VERSION = "0.1.0"
IMAGE_VERSION = "0.1.0"
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
