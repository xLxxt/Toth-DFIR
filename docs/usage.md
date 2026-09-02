# Usage

Toth provides Docker profiles for common Blue Team workflows. Each profile is a
Docker image with a focused toolset.

## Profiles

| Profile | Image | Use case |
|---------|-------|----------|
| `base` | `toth-base:0.2.0` | Shared shell, utilities, archives, text processing |
| `dfir` | `toth-dfir:0.2.0` | Memory, event logs, timelines, forensic triage |
| `malware` | `toth-malware:0.2.0` | Static malware analysis, YARA, capa, FLOSS, DIE |
| `network` | `toth-network:0.2.0` | PCAP triage, Zeek, Suricata, tshark, tcpdump |

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

This is the default, flat layout used when no case is active (see
[Manage cases](#manage-cases) below). It's what you get out of the box, and
it keeps working exactly like this if you never touch the `case` command.

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

## Per-profile image overrides

For any of the four built-in profiles (`base`, `dfir`, `malware`, `network`),
you can override which local image the wrapper uses by setting one of these
in `.env` (see `.env.example`):

```bash
# Full override: use a custom image name and tag for this profile.
TOTH_PROFILE_DFIR_IMAGE=my-custom-dfir:latest

# Tag-only override: keep the default image name, swap the tag.
TOTH_PROFILE_DFIR_TAG=0.2.0-rc1
```

`<NAME>` is the uppercased profile key (`BASE`, `DFIR`, `MALWARE`,
`NETWORK`). If both keys are set for the same profile, `TOTH_PROFILE_<NAME>_IMAGE`
wins. `toth list` marks any profile with an active override as
`(overridden)`.

This only changes which local image `toth start`/`shell`/`exec`/etc. run --
it does not affect where `toth update <profile>` pulls from; that always
follows `TOTH_REGISTRY` and `TOTH_IMAGE_VERSION`. Use overrides to point the
wrapper at an image you already built or pulled under a different name, for
example while testing a release candidate tag locally.

This is Tier 1 configuration: it only overrides the four built-in profiles'
image reference. Defining entirely new, user-named profiles is not
supported yet.

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

## Run GUI apps (X11 forwarding)

`start`, `shell`, and `exec` accept `--gui`. It shares your host's X11
session with the container -- the same mechanism `ssh -X` uses -- so a GUI
app launched inside the container displays a real window on your desktop,
with no VNC and no browser tab involved:

```bash
toth exec --gui network wireshark
toth shell --gui network
```

`--gui` works the same way for any of the four profiles (`base`, `dfir`,
`malware`, `network`) -- the mechanism itself has nothing profile-specific
about it, even though Wireshark (`network`) is the first tool that ships
with a GUI package installed.

**This only works when you run `toth` on the same machine as the Docker
host's own desktop session.** X11 forwarding here bind-mounts the host's
`/tmp/.X11-unix` Unix socket into the container; it is not a network
connection, so unlike a browser-based remote desktop it does **not** work
over a plain SSH session to a remote/shared Docker host. If you're on a
remote analysis box, `--gui` gives you nothing today; a browser-accessible
remote desktop (noVNC) is planned for a later phase (see
`docs/known-limitations.md`) and is the feature that will cover that case.

How it works: `--gui` layers a second Compose file
(`docker-compose.gui.yml`) on top of `docker-compose.yml`, adding an X11
socket mount, a read-only `.Xauthority` mount, and `DISPLAY`/`XAUTHORITY`
environment variables to the container. Containers started without `--gui`
are completely unaffected -- no socket, no `.Xauthority` file, and no new
environment variables are added.

Requirements:

- `DISPLAY` must be set in the shell you run `toth` from. A normal Linux
  desktop session already sets this; a plain SSH session without `-X`/`-Y`
  usually does not. `toth` fails fast with a clear error if `DISPLAY` is
  unset or `/tmp/.X11-unix` doesn't exist, instead of letting the GUI app
  fail deep inside the container with a confusing X11 connection error.
- Toth mounts your host's `.Xauthority` (from `$XAUTHORITY`, falling back to
  `~/.Xauthority`) into the container read-only and points `XAUTHORITY` at
  it -- this is the automatic, default auth mechanism, and it works whether
  or not the container's `analyst` user (uid 1000) matches your host uid,
  because the X server checks the auth cookie in that file, not the
  connecting uid. If your `.Xauthority` isn't populated the way most
  desktop environments populate it (some minimal window managers don't) and
  the GUI app fails to connect, the documented fallback is a manual,
  one-time host-side command: `xhost +si:localuser:$(whoami)`. Avoid bare
  `xhost +` (disables all X access control for every user) and
  `xhost +local:` (grants every local user, not just you) -- prefer the
  scoped `+si:localuser:` form.
- `toth enter <profile>` re-enters an existing container without recreating
  it, so it does not take a `--gui` flag: a container's mounts are fixed
  when it's created, so start (or recreate) it with `shell --gui`/
  `exec --gui`/`start --gui` first.

**Security note.** Sharing the host's X11 socket is a real, standing
trade-off, not a formality. X11 has essentially no per-client sandboxing:
once a client authenticates to an X server it can, by protocol design, read
keystrokes typed into *other* windows on the same session, screenshot the
entire screen (not just its own window), and inject synthetic input -- this
is the same reason `ssh -X` to an untrusted host is a known bad idea, and it
is not specific to Docker or Toth. It is a filesystem-socket concern, not a
network one: Toth's `network_mode: none`/`bridge` settings provide no
mitigation here, and none of the profiles change their network isolation
posture for this feature. Prefer `--gui` for tools you trust (Wireshark on
already-captured or live-interface traffic, the concrete case this ships
for). Think twice before combining `--gui` with anything that runs
untrusted or attacker-supplied code -- e.g. samples in the `malware`
profile -- since that pairing widens the trust boundary beyond Toth's usual
"isolated, `network_mode: none` container" story for that workflow.

### Wireshark example

```bash
toth exec --gui network wireshark
```

Opens a real Wireshark window on your desktop. Live capture on interfaces
visible to the container works because `network` already has
`NET_ADMIN`/`NET_RAW` via `cap_add`, and the image grants `dumpcap` the
matching file capabilities so non-root capture works without extra setup.

## Manage cases

Toth can scope evidence (`/cases`) and generated output (`/opt/toth/output`)
to a single active case, so different engagements don't mix their files.
There is one active case globally, shared by every profile.

Create a case and make it active:

```bash
toth case new acme-intrusion-2026
```

This creates `~/toth/workspace/cases/acme-intrusion-2026/` and
`~/toth/workspace/output/acme-intrusion-2026/`, and records the active case
in `~/toth/workspace/.active-case`.

List known cases (the active one is marked with `*`):

```bash
toth case list
```

Switch to a different, already-existing case:

```bash
toth case use other-case
```

If a Toth container is currently running, `toth case new`/`toth case use`
print a warning: the running container still has the previous case's
directories mounted. `toth restart` only restarts the process and does
*not* pick up the new mounts -- recreate the container instead:

```bash
toth start dfir
```

(`toth enter dfir` and `toth exec dfir ...` also recreate it if needed,
since they call the same `docker compose up -d` path under the hood.)

Show the active case (or a message that none is set):

```bash
toth case current
```

With no active case, `/cases` and `/opt/toth/output` mount the flat
`cases/` and `output/` directories described above -- this is the default
and requires no setup. Once a case is active, every profile mounts that
case's own `cases/<name>/` and `output/<name>/` subdirectories instead.

## Store and connect a per-case VPN config

Toth can hold a VPN config (OpenVPN `.ovpn` or WireGuard `.conf`) alongside a
case, in `~/toth/workspace/vpn/<case-name>/`, and auto-connect it when you
start the `network` profile -- the natural fit for the CTF Blue Team / HTB
Sherlock workflow this was built for. **Only `network` connects it.**
`base`, `dfir`, and `malware` don't mount the config or gain the
capabilities a tunnel needs, so `toth vpn add` while working in one of those
profiles just stores the config for later; see `docs/known-limitations.md`.

Add a config to a case (the case must already exist):

```bash
toth vpn add acme-intrusion-2026 ~/Downloads/acme-htb.ovpn
```

This copies the file (not a symlink) to
`~/toth/workspace/vpn/acme-intrusion-2026/config.ovpn`. A `.conf` file is
detected as WireGuard instead and copied to `config.conf` -- a case holds at
most one config, OpenVPN and WireGuard are mutually exclusive.

For OpenVPN username/password auth, attach a creds file (line 1: username,
line 2: password); its permissions are tightened to `600` (owner-only) when
it's written:

```bash
toth vpn add acme-intrusion-2026 ~/Downloads/acme-htb.ovpn --creds ~/Downloads/acme-creds.txt
```

`toth vpn add` refuses to overwrite an existing config for a case unless you
pass `--force`:

```bash
toth vpn add acme-intrusion-2026 ~/Downloads/acme-htb-renewed.ovpn --force
```

Show what's stored for a case (defaults to the active case; never prints
`creds.txt` contents):

```bash
toth vpn show
toth vpn show acme-intrusion-2026
```

Remove a case's stored VPN config:

```bash
toth vpn remove acme-intrusion-2026
```

Connect it by starting `network` with that case active -- the tunnel comes
up automatically before the shell is handed to you, no separate connect
step:

```bash
toth case use acme-intrusion-2026
toth shell network
```

Check the tunnel came up. The entrypoint's own log (did it find a config, did
`openvpn`/`wg-quick` launch at all) goes to the container's stdout, prefixed
`[vpn-entrypoint]`; OpenVPN's own connection log (it detaches immediately, so
its actual connect/auth result lands here, not in the entrypoint's log) goes
to a file inside the container:

```bash
docker logs toth-network
toth exec network cat /var/log/toth-openvpn.log   # OpenVPN only
toth exec network ip addr show wg0                # or: tun0, for OpenVPN
```

`wg show wg0` needs `CAP_NET_ADMIN`, which the unprivileged `analyst` user
doesn't have even though the container itself does (same reason the tunnel
setup needs the root-first entrypoint in the first place) -- `toth exec`
runs as `analyst`, so `wg show` fails with "Operation not permitted" there.
`ip addr show wg0` (above) doesn't need it and is enough to confirm the
interface is up; if you specifically need `wg show`'s peer/handshake
detail, run it as root: `docker exec --user root toth-network wg show wg0`.

If the container was already running when you stored or changed the config,
restart it to pick up the new mount (same as any other case-mount change,
see "Manage cases" above):

```bash
toth restart network
```

To start `network` *without* attempting to connect (debugging a broken
tunnel without the entrypoint itself getting in the way), set
`TOTH_VPN_DISABLE=1` before starting it:

```bash
TOTH_VPN_DISABLE=1 toth shell network
```

**A WireGuard config with a `PreUp`/`PostUp`/`PreDown`/`PostDown` line is
refused, on purpose** -- those directives are shell commands `wg-quick` runs
as root, and Toth won't auto-run arbitrary commands sourced from a
third-party config file. Strip the line if you control the config and don't
need it, or bring the tunnel up by hand instead
(`TOTH_VPN_DISABLE=1 toth shell network`, then run `wg-quick` yourself with
whatever review you're comfortable with). OpenVPN configs are auto-connected
with `--script-security 1` forced regardless of what the file requests, so
`up`/`down`/`route-up` script directives in an `.ovpn` file are never
executed either.

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
docker run --rm toth-dfir:0.2.0 toth-check
docker run --rm toth-malware:0.2.0 toth-check
docker run --rm toth-network:0.2.0 toth-check
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
  toth-dfir:0.2.0 /bin/bash
```

For the network image, Docker Compose is preferred because the service declares
network capabilities in `docker-compose.yml`.
