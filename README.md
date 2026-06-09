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

## Images

| Profile   | Image           | Focus                                      |
|-----------|-----------------|--------------------------------------------|
| `base`    | `toth-base`     | Shared tooling, shell and helpers          |
| `dfir`    | `toth-dfir`     | Volatility3, Chainsaw, Hayabusa, Plaso     |
| `malware` | `toth-malware`  | YARA, capa, FLOSS, oletools, DIE           |
| `network` | `toth-network`  | tshark, Zeek, Suricata, tcpdump            |

---

## Quick Start

> Work in Progress - first stable release coming soon.

```bash
git clone https://github.com/xLxxt/Toth-DFIR.git
cd Toth-DFIR

make build-base
make build-dfir

make run
```

`make run` starts the DFIR container and drops you into a shell. Your cases
live under `$TOTH_WORKSPACE` (set in `.env`) and are mounted at `/cases`.

---

## Wrapper

Toth ships a small wrapper to manage containers, similar to the Exegol CLI.

```bash
python3 wrapper/toth.py start dfir       # start a profile container
python3 wrapper/toth.py exec dfir        # open a shell in it
python3 wrapper/toth.py exec dfir vol3   # run a single command
python3 wrapper/toth.py stop dfir        # stop the container
python3 wrapper/toth.py update all       # build or rebuild images
```

Profiles: `base`, `dfir`, `malware`, `network`.

---

## License

Released under the [MIT License](LICENSE).
