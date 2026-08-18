import os
import shutil
from pathlib import Path

from utils import case as case_utils
from utils import config

CONFIG_FILENAMES = {
    "openvpn": "config.ovpn",
    "wireguard": "config.conf",
}
CREDS_FILENAME = "creds.txt"


def _workspace():
    return Path(config.WORKSPACE).expanduser()


def _vpn_dir(case_name):
    return _workspace() / "vpn" / case_name


def _copy_restricted(src, dst):
    """Copy src to dst, created with 0600 from the start (no world/group-
    readable window between the copy and a follow-up chmod)."""
    fd = os.open(dst, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "wb") as out, open(src, "rb") as src_f:
        shutil.copyfileobj(src_f, out)


def vpn_paths(case_name):
    """Inspect <workspace>/vpn/<case_name>/ and report what's there.

    Returns (config_path_or_none, creds_path_or_none, kind), where kind is
    "openvpn", "wireguard", or None if no config is present.
    """
    _require_case(case_name)
    vpn_dir = _vpn_dir(case_name)
    ovpn_path = vpn_dir / CONFIG_FILENAMES["openvpn"]
    wg_path = vpn_dir / CONFIG_FILENAMES["wireguard"]

    if ovpn_path.is_file():
        config_path, kind = ovpn_path, "openvpn"
    elif wg_path.is_file():
        config_path, kind = wg_path, "wireguard"
    else:
        return None, None, None

    creds_path = vpn_dir / CREDS_FILENAME
    creds_path = creds_path if creds_path.is_file() else None
    return config_path, creds_path, kind


def _require_case(case_name):
    if case_name not in case_utils.list_cases():
        raise SystemExit(
            f"[!] case '{case_name}' does not exist. Create it with: toth case new {case_name}"
        )


def add_vpn_config(case_name, source_file, creds_file=None, force=False):
    """Copy a VPN config (and optional creds file) into a case's vpn dir.

    source_file must end in .ovpn (OpenVPN) or .conf (WireGuard); anything
    else is rejected. Refuses to overwrite an existing config unless
    force=True. Returns (config_path, creds_path_or_none, kind).
    """
    _require_case(case_name)

    source_path = Path(source_file).expanduser()
    if not source_path.is_file():
        raise SystemExit(f"[!] VPN config file not found: {source_path}")

    suffix = source_path.suffix.lower()
    if suffix == ".ovpn":
        kind = "openvpn"
    elif suffix == ".conf":
        kind = "wireguard"
    else:
        raise SystemExit(
            f"[!] unrecognized VPN config extension '{suffix}': expected "
            ".ovpn (OpenVPN) or .conf (WireGuard)"
        )

    vpn_dir = _vpn_dir(case_name)
    dest_config = vpn_dir / CONFIG_FILENAMES[kind]

    existing_config, _existing_creds, _existing_kind = vpn_paths(case_name)
    if existing_config is not None and not force:
        raise SystemExit(
            f"[!] case '{case_name}' already has a VPN config "
            f"({existing_config.name}). Use --force to overwrite, or "
            "`toth vpn remove` first."
        )

    creds_path = None
    if creds_file is not None:
        creds_source = Path(creds_file).expanduser()
        if not creds_source.is_file():
            raise SystemExit(f"[!] VPN creds file not found: {creds_source}")
        creds_path = creds_source

    vpn_dir.mkdir(parents=True, exist_ok=True)

    # If switching kinds (e.g. previously OpenVPN, now WireGuard), clear out
    # the other kind's stale config so vpn_paths() doesn't see two configs.
    for other_kind, filename in CONFIG_FILENAMES.items():
        if other_kind != kind:
            (vpn_dir / filename).unlink(missing_ok=True)

    # Config files can embed private keys/certificates (common OpenVPN
    # practice), so lock them down the same way creds.txt already is,
    # rather than leaving them at the process's default umask.
    _copy_restricted(source_path, dest_config)

    dest_creds = vpn_dir / CREDS_FILENAME
    if creds_path is not None:
        _copy_restricted(creds_path, dest_creds)
    else:
        dest_creds.unlink(missing_ok=True)

    return dest_config, (dest_creds if creds_path is not None else None), kind


def remove_vpn_config(case_name):
    """Delete a case's vpn dir contents, if any. Returns True if something
    was actually removed, False if there was nothing to remove."""
    _require_case(case_name)
    vpn_dir = _vpn_dir(case_name)
    if vpn_dir.is_dir():
        shutil.rmtree(vpn_dir)
        return True
    return False


def active_vpn(case_name_or_none):
    """Convenience wrapper for callers that only know the active case.

    Returns the same shape as vpn_paths(): (config_path_or_none,
    creds_path_or_none, kind). With no case, there is no VPN config.
    """
    if case_name_or_none is None:
        return None, None, None
    return vpn_paths(case_name_or_none)
