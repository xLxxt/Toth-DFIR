<div align="center">

# 𓅓 Toth

**Blue Team Docker Distribution for DFIR & Threat Hunting**

[![Docker](https://img.shields.io/badge/Docker-ready-2496ED?logo=docker)](https://github.com/xLxxt/Toth-DFIR)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-WIP-orange.svg)]()
[![Contributions](https://img.shields.io/badge/Contributions-Welcome-brightgreen.svg)](docs/contributing.md)

*Inspired by [Exegol](https://github.com/ThePorgs/Exegol) — Built for the Blue Side*

</div>

---

## 🔭 What is Toth ?

**Toth** is a Docker-based distribution designed for **Blue Team analysts**, 
**SOC operators** and **DFIR specialists**.

Named after the Egyptian god of knowledge and writing, Toth aims to provide 
a **ready-to-use**, **reproducible** and **collaborative** environment for:

- 🔍 Digital Forensics & Incident Response (DFIR)
- 🌐 Network Forensics
- 🦠 Malware Analysis (static & dynamic)
- 🎯 Threat Hunting
- 🏆 CTF Blue Team (HackTheBox Sherlock, CyberDefenders...)

---

## 🚀 Quick Start

> ⚠️ **Work in Progress** — First stable release coming soon.

```bash
# Clone the repository
git clone https://github.com/xLxxt/Toth-DFIR.git
cd Toth-DFIR

# Build the base image
make build-base

# Start a DFIR container
make run