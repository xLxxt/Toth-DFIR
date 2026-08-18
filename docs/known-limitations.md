# Known Limitations

Toth is still in early development. This document tracks the practical limits
that users and contributors should know before relying on it in a real case.

## Project maturity

- The project is currently built around the `dev` branch.
- The wrapper CLI supports `list`, `status`, `start`, `enter`, `restart`,
  `shell`, `exec`, `stop`, `remove`, `update`, `case`, and `vpn`.
- `toth vpn add/remove/show` (see `docs/usage.md`) only stores a per-case VPN
  config (OpenVPN `.ovpn` or WireGuard `.conf`, plus an optional OpenVPN
  creds file) under `~/toth/workspace/vpn/<case>/`. This is the storage/CLI
  layer only -- **no container mounts it, no tunnel gets established, and no
  profile grants the capabilities (`NET_ADMIN`, `/dev/net/tun`) a real VPN
  connection needs.** Wiring this into `docker_manager.py`'s symlink shim,
  `docker-compose.yml`, and a root-first container entrypoint is deliberately
  deferred, larger-scope follow-up work (see `docs/roadmap-vpn.md`).
- Per-profile image/tag overrides for the four built-in profiles are
  supported via `.env` (`TOTH_PROFILE_<NAME>_IMAGE` /
  `TOTH_PROFILE_<NAME>_TAG`, see `docs/usage.md`). Defining entirely new,
  user-named profiles beyond `base`, `dfir`, `malware`, and `network` is
  still not supported; that is deferred, larger-scope work.
- There is a single global active case (not per-profile); switching cases
  while a container is running requires a restart to pick up the new
  mounts (`toth case use` / `toth case new` warn about this).

## Installation

- The public installer defaults to HTTPS clone from GitHub.
- Private repository installs require SSH through `TOTH_REPO_URL`.
- The installer must not be run with `sudo`; it is user-scoped by design.
- Docker must be usable by the current user before installation.

## Docker images

- Images are currently tagged `0.2.0`.
- Profile images inherit from `toth-base:0.2.0`.
- `toth update` pulls from GHCR by default; if public images are not available
  yet, use `toth update --build <profile>`.
- Rebuilding `base` can require rebuilding the specialized images.
- The network profile uses Docker network capabilities for packet tooling.
- A `full` profile combining every tool set is planned but not implemented yet:
  `images/full/` is an empty placeholder, not wired into the wrapper, the
  `Makefile`, or CI.
- `tools/install/**` (per-tool install scripts, one per forensic/malware/network
  tool) is an empty scaffold from an earlier design. Tool installation currently
  lives entirely in each profile's `Dockerfile` as inline `RUN` steps; moving it
  to these standalone scripts is a possible future refactor, not done yet.
- `config/shell/.bashrc`, `config/shell/.zshrc`, `config/tmux/tmux.conf`, and
  `config/vim/vim.rc` are empty placeholders and are not copied into any image
  today. Only `config/shell/aliases.sh` is currently wired into the `base`
  image. Shipping custom shell/tmux/vim defaults is planned but not started.
- `lynis`, `chkrootkit`, and `rkhunter` in the `dfir` image audit the live
  host/filesystem they run on (or a chroot'd copy of a suspect filesystem),
  not arbitrary evidence files dropped in `/cases`. Run standalone inside a
  fresh `toth-dfir` container, they audit the container itself, which is not
  a typical DFIR workflow for these tools. They are included for
  live-response and chroot-based Linux host triage, not for direct
  evidence-file scanning like the rest of the `dfir` tool set. `rkhunter`'s
  file-properties database (`--propupd`) is baked in at build time because
  `dfir` runs with `network_mode: none` and cannot fetch it at runtime.

## Architecture support

- Images are intended to build on `amd64` and `arm64`.
- Detect It Easy CLI (`diec`) is installed on `amd64` only because the upstream
  Linux release used by Toth does not provide an arm64 package.
- Some upstream forensic tools may change archive names, checksums, package
  dependencies, or Python compatibility without notice.

## GUI tools

- X11 forwarding (`--gui` on `start`/`shell`/`exec`, see `docs/usage.md`) is
  implemented and works uniformly across all four profiles. Wireshark GUI
  ships in the `network` image as the first concrete tool that uses it.
- X11 forwarding only works when `toth` runs on the same machine as the
  Docker host's own desktop session -- it bind-mounts the host's X11 socket,
  which does not work over a plain SSH session to a remote/shared Docker
  host the way a browser-based remote desktop would.
- Browser-accessible desktop support with noVNC -- which *does* work over
  SSH to a remote Docker host, unlike X11 forwarding -- is planned for
  Phase 3 and not implemented yet.
- Autopsy and other GUI-heavy tools beyond Wireshark are not currently
  packaged in any image.

## Validation coverage

- `toth-check` verifies command presence and selected Python imports.
- It does not prove that every tool can process every evidence format.
- Real-case validation still requires sample evidence: EVTX, memory images,
  malware samples, and PCAP files.

## Operational caution

- Toth is a lab and analyst workstation environment, not a hardened sandbox for
  executing unknown malware.
- Treat malware samples as hostile and follow your normal isolation process.
- Avoid mounting sensitive host directories into containers unless needed for a
  case.
