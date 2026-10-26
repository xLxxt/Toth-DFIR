#!/usr/bin/env python3
"""Regression test for per-profile image overrides in Docker Compose."""

import os
import subprocess
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Make the result independent of inherited overrides and repository .env.
for key in list(os.environ):
    if (
        key.startswith("TOTH_PROFILE_")
        or key.startswith("TOTH_COMPOSE_IMAGE_")
        or key in {
            "COMPOSE_FILE",
            "COMPOSE_PATH_SEPARATOR",
            "TOTH_IMAGE_VERSION",
            "TOTH_WORKSPACE",
        }
    ):
        os.environ.pop(key, None)

with tempfile.TemporaryDirectory(prefix="toth-image-overrides-") as tmp:
    tmp_path = Path(tmp)
    env_file = tmp_path / "test.env"
    env_file.write_text(
        "\n".join(
            [
                f"TOTH_WORKSPACE={tmp_path}",
                "TOTH_IMAGE_VERSION=dotenv-version",
                "TOTH_PROFILE_BASE_IMAGE=dotenv-base:full",
                "TOTH_PROFILE_BASE_TAG=ignored-base-tag",
                "TOTH_PROFILE_DFIR_TAG=dotenv-dfir-tag",
                "TOTH_PROFILE_MALWARE_IMAGE=dotenv-malware:full",
                "",
            ]
        ),
        encoding="utf-8",
    )

    env = os.environ.copy()
    env.update(
        {
            "TOTH_IMAGE_VERSION": "env-version",
            "TOTH_PROFILE_BASE_IMAGE": "env-base:full",
            "TOTH_PROFILE_DFIR_TAG": "env-dfir-tag",
        }
    )
    command = [
        "docker",
        "compose",
        "--env-file",
        str(env_file),
        "-f",
        str(ROOT / "docker-compose.yml"),
        "config",
        "--images",
    ]
    result = subprocess.run(
        command,
        cwd=ROOT,
        env=env,
        check=True,
        capture_output=True,
        text=True,
    )

    actual = set(result.stdout.splitlines())
    expected = {
        "env-base:full",                 # env full image beats .env image/tag
        "toth-dfir:env-dfir-tag",         # env tag beats .env tag
        "dotenv-malware:full",            # .env full-image override
        "toth-network:env-version",       # no profile override; env version
    }
    assert actual == expected, f"Compose images differ: {actual!r} != {expected!r}"
    print("[+] Compose uses profile image overrides and preserves defaults")
