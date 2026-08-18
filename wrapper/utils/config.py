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


VERSION = "0.2.0"
IMAGE_VERSION = _setting("TOTH_IMAGE_VERSION", "0.2.0")
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


def _profile_override(profile):
    """Look up a per-profile local image override, if any.

    Two `.env`-style keys are recognized per profile, named after the
    uppercased profile key:

    - `TOTH_PROFILE_<NAME>_IMAGE`: full image reference override (e.g.
      `TOTH_PROFILE_DFIR_IMAGE=my-custom-dfir:latest`). Bypasses the normal
      `service(profile):IMAGE_VERSION` construction entirely.
    - `TOTH_PROFILE_<NAME>_TAG`: tag-only override (e.g.
      `TOTH_PROFILE_DFIR_TAG=0.2.0-rc1`). Keeps the normal image name but
      swaps the tag.

    If both are set for the same profile, `_IMAGE` wins since it is the more
    specific override. Returns None when no override is configured.

    This only affects `image()` (the local image reference used to run
    containers). `remote_image()` is intentionally left untouched: it feeds
    `toth update <profile>`, which pulls from GHCR, and overrides here are
    for pointing the wrapper at an already-built/pulled local image, not for
    changing where GHCR pulls come from.
    """
    name = profile.upper()
    full_override = _setting(f"TOTH_PROFILE_{name}_IMAGE", None)
    if full_override:
        return full_override
    tag_override = _setting(f"TOTH_PROFILE_{name}_TAG", None)
    if tag_override:
        return f"{service(profile)}:{tag_override}"
    return None


def image(profile):
    override = _profile_override(profile)
    if override:
        return override
    return f"{service(profile)}:{IMAGE_VERSION}"


def remote_image(profile):
    return f"{REGISTRY}/{service(profile)}:{IMAGE_VERSION}"


def profile_for_service(service_name):
    for profile, svc in PROFILES.items():
        if svc == service_name:
            return profile
    raise SystemExit(f"[!] unknown service '{service_name}'")
