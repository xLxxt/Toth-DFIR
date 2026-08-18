<div align="center">

<img src="assets/logo.png" alt="Toth" width="140">

# 𓅓 Toth

**Blue Team Docker Distribution for DFIR & Threat Hunting**

[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker)](https://github.com/xLxxt/Toth-DFIR)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-WIP-orange.svg)]()
[![Contributions](https://img.shields.io/badge/Contributions-Welcome-brightgreen.svg)](docs/contributing.md)

*Inspired by [Exegol](https://github.com/ThePorgs/Exegol) - Built for the Blue Side*

</div>

---

## What is Toth ?

**Toth** is a Docker-based distribution designed for Blue Team analysts,
SOC operators and DFIR specialists.

Named after the Egyptian god of knowledge and writing, Toth provides a
ready-to-use, reproducible and collaborative environment for:

- Digital Forensics & Incident Response (DFIR)
- Network Forensics
- Malware Analysis (static & dynamic)
- Threat Hunting
- CTF Blue Team (HackTheBox Sherlock, CyberDefenders, ...)

---

## Quick tour

```text
$ toth case new acme-ransomware-2026-08
[+] Case created: acme-ransomware-2026-08

$ toth shell dfir
analyst@toth-dfir:/cases$ vol3 -f memory.raw windows.pstree.PsTree
analyst@toth-dfir:/cases$ chainsaw hunt evtx/ --sigma /opt/toth/rules/sigma \
    --mapping /opt/toth/tools/chainsaw/mappings/sigma-event-logs-all.yml
analyst@toth-dfir:/cases$ exit

$ toth exec --gui network wireshark
# Wireshark opens on your own desktop, same mechanism as `ssh -X`
```

Everything an analyst does lands under a per-case, per-profile directory on
the host (`~/toth/workspace/cases/acme-ransomware-2026-08/`), not scattered
across whatever container happened to be running. See
[docs/usage.md](docs/usage.md) for the full command set.

---

## Images

| Profile   | Image           | Focus                                            |
|-----------|-----------------|---------------------------------------------------|
| `base`    | `toth-base`     | Shared tooling, shell and helpers                  |
| `dfir`    | `toth-dfir`     | Volatility3, Chainsaw, Hayabusa, Plaso, RegRipper  |
| `malware` | `toth-malware`  | YARA, capa, FLOSS, oletools, DIE, radare2          |
| `network` | `toth-network`  | tshark, Zeek, Suricata, tcpdump, dnstwist, Wireshark GUI |

Full tool inventory: [docs/tools-list.md](docs/tools-list.md).

---

## Installation

One line install (Linux and macOS):

```bash
curl -sSL https://raw.githubusercontent.com/xLxxt/Toth-DFIR/dev/install.sh | bash
```

It installs Toth in `~/.toth`, creates the workspace and adds the `toth`
command to `~/.local/bin`. Images are pulled later with `toth update`.

Installer requirements: `git`, `python3`. Runtime requirements: Docker Engine
and the Docker Compose plugin.

Detailed install instructions, Fedora notes, private repository setup and
troubleshooting are available in [docs/installation.md](docs/installation.md).

On Windows, use WSL2 or clone the repository and call the wrapper directly
with `python wrapper\toth.py`.

### Manual install

```bash
git clone --branch dev https://github.com/xLxxt/Toth-DFIR.git
cd Toth-DFIR

make build-base
make build-dfir

make run
```

---

## Usage

```bash
toth list
toth status
toth update dfir          # pull from GHCR
toth update --build dfir  # build locally for development
toth start dfir
toth shell dfir
toth enter dfir
toth exec dfir vol3 -h
toth restart dfir
toth stop dfir
toth remove dfir
toth update

toth case new <name>      # isolate this engagement's evidence/output
toth case use <name>
toth case list

toth shell --gui network  # GUI tools (Wireshark) on your own desktop
```

`toth shell <profile>` starts the container if needed and drops you into a
shell. `toth exec <profile> <command>` runs a single command. Your cases live
under `$TOTH_WORKSPACE` or `~/toth/workspace` by default, and are mounted at
`/cases` -- scoped to the active `toth case` when one is set.

Profiles: `base`, `dfir`, `malware`, `network`.

See [docs/usage.md](docs/usage.md) for workspace layout, tool checks and
practical DFIR, malware and network examples.

Release readiness is tracked in [docs/release-checklist.md](docs/release-checklist.md),
GHCR publication in [docs/ghcr-publication.md](docs/ghcr-publication.md),
and current project limits are documented in [docs/known-limitations.md](docs/known-limitations.md).

---

## Architecture support

Images build natively on `amd64` and `arm64` (Apple Silicon included).
Detect It Easy has no Linux arm64 build, so it is installed on amd64 only.

---

## License

Released under the [MIT License](LICENSE).
