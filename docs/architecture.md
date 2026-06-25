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

## Wrapper model

The Python wrapper calls Docker Compose for common operations:

- `list`: list available profiles and image tags
- `status`: show Docker Compose container status
- `start`: start a profile container
- `shell`: open an interactive shell in a profile container
- `exec`: run a command in a profile container
- `stop`: stop a profile container
- `update`: build images
