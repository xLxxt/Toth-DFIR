import re
from pathlib import Path

from utils import config

STATE_FILENAME = ".active-case"

_VALID_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


def _workspace():
    return Path(config.WORKSPACE).expanduser()


def _state_file():
    return _workspace() / STATE_FILENAME


def is_valid_name(name):
    if not name:
        return False
    if name in (".", ".."):
        return False
    if "/" in name or "\\" in name:
        return False
    if name.startswith("."):
        return False
    return bool(_VALID_NAME.match(name))


def active_case():
    state_file = _state_file()
    if not state_file.is_file():
        return None
    name = state_file.read_text().strip()
    if not is_valid_name(name):
        return None
    return name


def set_active_case(name):
    if not is_valid_name(name):
        raise SystemExit(
            f"[!] invalid case name '{name}': must be a single path component, "
            "not empty, and not starting with '.'"
        )
    workspace = _workspace()
    cases_dir, output_dir = case_paths(name)
    cases_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    workspace.mkdir(parents=True, exist_ok=True)
    _state_file().write_text(name + "\n")
    return name


def list_cases():
    cases_root = _workspace() / "cases"
    if not cases_root.is_dir():
        return []
    return sorted(p.name for p in cases_root.iterdir() if p.is_dir())


def case_paths(name_or_none):
    workspace = _workspace()
    if name_or_none is None:
        return workspace / "cases", workspace / "output"
    return workspace / "cases" / name_or_none, workspace / "output" / name_or_none
