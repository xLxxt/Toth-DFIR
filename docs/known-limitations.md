# Known Limitations

Toth is still in early development. This document tracks the practical limits
that users and contributors should know before relying on it in a real case.

## Project maturity

- The project is currently built around the `dev` branch.
- The wrapper CLI supports `list`, `status`, `start`, `shell`, `exec`, `stop`,
  and `update`.
- Advanced wrapper features such as profile templates, pull/build selection, and
  richer user configuration are planned for Phase 2.

## Installation

- The public installer defaults to HTTPS clone from GitHub.
- Private repository installs require SSH through `TOTH_REPO_URL`.
- The installer must not be run with `sudo`; it is user-scoped by design.
- Docker must be usable by the current user before installation.

## Docker images

- Images are currently tagged `0.1.0`.
- Profile images inherit from `toth-base:0.1.0`.
- Rebuilding `base` can require rebuilding the specialized images.
- The network profile uses Docker network capabilities for packet tooling.

## Architecture support

- Images are intended to build on `amd64` and `arm64`.
- Detect It Easy CLI (`diec`) is installed on `amd64` only because the upstream
  Linux release used by Toth does not provide an arm64 package.
- Some upstream forensic tools may change archive names, checksums, package
  dependencies, or Python compatibility without notice.

## GUI tools

- The current project phase is container-first and CLI-first.
- Browser-accessible desktop support with noVNC is planned for Phase 3.
- GUI-heavy tools such as Autopsy and Wireshark GUI are not the current runtime
  focus, even when supporting packages are present.

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
