# Usage

Toth provides Docker profiles for common Blue Team workflows. Each profile is a
Docker image with a focused toolset.

## Profiles

| Profile | Image | Use case |
|---------|-------|----------|
| `base` | `toth-base:0.1.0` | Shared shell, utilities, archives, text processing |
| `dfir` | `toth-dfir:0.1.0` | Memory, event logs, timelines, forensic triage |
| `malware` | `toth-malware:0.1.0` | Static malware analysis, YARA, capa, FLOSS, DIE |
| `network` | `toth-network:0.1.0` | PCAP triage, Zeek, Suricata, tshark, tcpdump |

## Workspace layout

By default, Toth uses this local workspace:

```text
~/toth/workspace/
|-- cases/
`-- output/
```

Docker mounts it like this:

| Host path | Container path | Purpose |
|-----------|----------------|---------|
| `~/toth/workspace/cases` | `/cases` | Evidence, logs, memory dumps, PCAP files |
| `~/toth/workspace/output` | `/opt/toth/output` | Reports and generated artifacts |

Why: keeping evidence and output outside the container makes rebuilds safe. You
can delete or rebuild images without losing cases.

## Update images

By default, the wrapper pulls images from GHCR and tags them locally for Docker
Compose:

```bash
toth update base
toth update dfir
toth update malware
toth update network
```

Update every profile:

```bash
toth update
```

For development, build images locally instead of pulling them:

```bash
toth update --build base
toth update --build dfir
toth update --build malware
toth update --build network
```

Build every profile locally:

```bash
toth update --build
```

From a development clone, you can still use Make directly:

```bash
make build-base
make build-dfir
make build-malware
make build-network
make build-all
```

## List profiles and status

List available profiles and their local image tags:

```bash
toth list
```

Show Toth containers, including containers started by the wrapper and Toth images
started manually with `docker run`:

```bash
toth status
```

## Open a shell

Installed command:

```bash
toth shell dfir
toth shell malware
toth shell network
```

Development command:

```bash
python3 wrapper/toth.py shell dfir
```

The wrapper starts the selected Docker Compose service and opens a shell inside
the container. `toth exec <profile>` still works as a backwards-compatible alias
when no command is provided.

## Manage containers

Re-enter an existing container without recreating it:

```bash
toth enter dfir
```

Restart or remove a profile container:

```bash
toth restart dfir
toth remove dfir
```

If Docker reports that a container name such as `toth-dfir` is already in use,
use `toth enter dfir` to recover the shell or `toth remove dfir` to remove the
stale container.

## Run one command

```bash
toth exec dfir vol3 -h
toth exec malware capa -h
toth exec network tshark --version
```

## Stop a profile

```bash
toth stop dfir
toth stop malware
toth stop network
```

## Check installed tools

Every image includes the `toth-check` helper:

```bash
toth exec dfir toth-check
toth exec malware toth-check
toth exec network toth-check
```

For direct Docker checks:

```bash
docker run --rm toth-dfir:0.1.0 toth-check
docker run --rm toth-malware:0.1.0 toth-check
docker run --rm toth-network:0.1.0 toth-check
```

## DFIR examples

Run Volatility3 against a memory dump placed in `~/toth/workspace/cases`:

```bash
toth exec dfir vol3 -f /cases/memory.raw windows.info
```

Run Chainsaw on Windows EVTX logs:

```bash
toth exec dfir chainsaw hunt /cases/evtx \
  --sigma /opt/toth/rules/sigma \
  --mapping /opt/toth/tools/chainsaw/mappings/sigma-event-logs-all.yml \
  --output /opt/toth/output/chainsaw-results
```

Run Hayabusa on a directory of EVTX logs:

```bash
toth exec dfir hayabusa csv-timeline \
  --directory /cases/evtx \
  --output /opt/toth/output/hayabusa-timeline.csv
```

Extract IOCs (IPs, domains, hashes, ...) from a text report. `ioc-finder`
parses its `TEXT` argument or stdin directly — it does not read a file path
argument as a file — so redirect from the file inside the container:

```bash
toth exec dfir bash -c 'ioc-finder < /cases/report.txt'
```

`lynis`, `chkrootkit`, and `rkhunter` are also available in `dfir`, but they
audit the host/filesystem they run on rather than scanning arbitrary evidence
files — see `docs/known-limitations.md` before relying on them for a case.

## Malware examples

Inspect a suspicious binary with capa:

```bash
toth exec malware capa /cases/suspicious.exe
```

Extract strings with FLOSS:

```bash
toth exec malware floss /cases/suspicious.exe \
  > ~/toth/workspace/output/floss-suspicious.txt
```

Run YARA rules:

```bash
toth exec malware yara -r /cases/rules /cases/samples
```

Run Detect It Easy CLI on amd64:

```bash
toth exec malware diec /cases/suspicious.exe
```

## Network examples

Read a PCAP with tshark:

```bash
toth exec network tshark -r /cases/capture.pcap -q -z io,phs
```

Generate Zeek logs from a PCAP:

```bash
toth exec network zeek -r /cases/capture.pcap LogAscii::use_json=T
```

Run Suricata against a PCAP:

```bash
toth exec network suricata -r /cases/capture.pcap -l /opt/toth/output/suricata
```

## Direct Docker usage

The wrapper now creates the default workspace automatically before Docker
operations. Direct Docker is still useful for debugging:

```bash
docker run --rm -it \
  -v "$HOME/toth/workspace/cases:/cases" \
  -v "$HOME/toth/workspace/output:/opt/toth/output" \
  toth-dfir:0.1.0 /bin/bash
```

For the network image, Docker Compose is preferred because the service declares
network capabilities in `docker-compose.yml`.
