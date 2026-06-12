# Usage

Toth provides Docker profiles for common Blue Team workflows.

## Profiles

- `base`: shared shell, utilities, and helper aliases
- `dfir`: memory, event log, timeline, and forensic tooling
- `malware`: static malware analysis tooling
- `network`: packet and network forensic tooling

## Build images

```bash
make build-base
make build-dfir
make build-malware
make build-network
```

## Open a shell

```bash
python3 wrapper/toth.py exec dfir
python3 wrapper/toth.py exec malware
python3 wrapper/toth.py exec network
```

The wrapper starts the selected service with Docker Compose and opens a shell.
Cases are mounted under `/cases` in the container.

## Run one command

```bash
python3 wrapper/toth.py exec dfir vol3 -h
python3 wrapper/toth.py exec malware capa -h
python3 wrapper/toth.py exec network tshark --version
```

## Stop a profile

```bash
python3 wrapper/toth.py stop dfir
```
