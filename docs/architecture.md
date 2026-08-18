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

### GUI apps (X11 forwarding)

`--gui` (on `start`/`shell`/`exec`) is a cross-cutting capability, not a
profile: it applies uniformly to all four services rather than being
hardcoded to `network`, since sharing the host's X server has nothing
profile-specific about it. The wrapper layers a second Compose file,
`docker-compose.gui.yml`, on top of `docker-compose.yml` --
`docker compose -f docker-compose.yml -f docker-compose.gui.yml ...` -- only
for invocations that opt in. The override adds an X11 socket bind-mount, a
read-only `.Xauthority` mount, and `DISPLAY`/`XAUTHORITY` environment
variables to whichever service is targeted. Without `--gui`,
`docker-compose.gui.yml` is never referenced and container behavior is
byte-for-byte unchanged from before the feature existed. `wrapper/utils/
docker_manager.py`'s `_env()` resolves the host's `.Xauthority` path
(`$XAUTHORITY`, falling back to `~/.Xauthority`) into `TOTH_XAUTHORITY` for
every invocation, the same pattern used for `TOTH_WORKSPACE` -- it's only
consumed by `docker-compose.gui.yml`, so it has no effect on non-GUI runs.

This is deliberately the simpler of two GUI approaches: it shares the
host's already-running X server via a bind-mounted Unix socket rather than
running a display server inside the container, so it only works when
`toth` runs on the same machine as the Docker host's own desktop session.
noVNC (browser-based, works over SSH to a remote Docker host) is scoped
separately in `docs/roadmap-phase3.md` and not implemented yet. See
`docs/usage.md`'s "Run GUI apps" section for the same-machine limitation
and the X11-exposure security trade-off.

## Wrapper model

The Python wrapper calls Docker Compose for common operations:

- `list`: list available profiles and image tags
- `status`: show all Toth containers (wrapper-started or launched manually with
  `docker run`), matched by the Toth OCI image label
- `start`: start a profile container (`--gui` to share the host's X11
  session, see above)
- `enter`: enter an existing profile container
- `restart`: restart an existing profile container
- `shell`: open an interactive shell in a profile container (`--gui`
  supported)
- `exec`: run a command in a profile container (`--gui` supported)
- `stop`: stop a profile container
- `remove`: remove an existing profile container
- `update`: pull images from GHCR or build them locally with `--build`
- `case`: manage the active case (`new`, `list`, `use`, `current`), which
  scopes `/cases` and `/opt/toth/output` per engagement
