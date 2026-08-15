# Architecture

Toth is built around Docker images and a small wrapper CLI.

## Image model

`images/base` is the common foundation. Other profiles inherit from it:

```text
toth-base
├── toth-dfir
├── toth-malware
└── toth-network
```

This keeps shared shell tooling in one place while allowing profile-specific
packages for DFIR, malware analysis, and network forensics.

## Runtime model

Docker Compose defines one service per profile. The workspace is mounted into
containers as `/cases`, while generated output is mounted under `/opt/toth/output`.

Most profiles use restricted networking. The network profile uses additional
network capabilities because tools such as `tcpdump` and Suricata need packet
access.

### Case-scoped mounts

`docker-compose.yml` always mounts `${TOTH_WORKSPACE}/cases:/cases` and
`${TOTH_WORKSPACE}/output:/opt/toth/output` -- that file never changes based
on case state. What changes is what the wrapper resolves `TOTH_WORKSPACE` to
before invoking `docker compose`:

- No active case: `TOTH_WORKSPACE` is the workspace root, so the mounts
  resolve to the flat `cases/` and `output/` directories (legacy behavior,
  unchanged).
- An active case: the real per-case directories live at
  `<workspace>/cases/<name>/` and `<workspace>/output/<name>/`
  (`wrapper/utils/case.py`). Since those are two independent trees that a
  single "root + fixed suffix" pattern can't address directly, the wrapper
  points `TOTH_WORKSPACE` at a small per-case shim directory
  (`<workspace>/.case-mounts/<name>/`) holding `cases` and `output`
  symlinks into the real directories. `docker-compose.yml` stays untouched
  and `docker compose` is still used, not raw `docker run`.

Case state itself (`$TOTH_WORKSPACE/.active-case`) is separate from the
repo's `.env`: `.env` holds static per-profile configuration, while the
active case is mutable runtime state scoped to the workspace.

## Wrapper model

The Python wrapper calls Docker Compose for common operations:

- `list`: list available profiles and image tags
- `status`: show all Toth containers (wrapper-started or launched manually with
  `docker run`), matched by the Toth OCI image label
- `start`: start a profile container
- `enter`: enter an existing profile container
- `restart`: restart an existing profile container
- `shell`: open an interactive shell in a profile container
- `exec`: run a command in a profile container
- `stop`: stop a profile container
- `remove`: remove an existing profile container
- `update`: pull images from GHCR or build them locally with `--build`
- `case`: manage the active case (`new`, `list`, `use`, `current`), which
  scopes `/cases` and `/opt/toth/output` per engagement
