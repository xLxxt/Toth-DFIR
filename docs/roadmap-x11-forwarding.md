# X11 Forwarding Roadmap (Scoping)

This document scopes X11 forwarding support so GUI tools — starting with
Wireshark — can be launched directly from the host terminal, with their
window appearing on the analyst's own desktop: `toth exec network wireshark`
opens a real Wireshark window on the host, not in a browser tab. It is a
planning document, not an implementation: no GUI feature code ships alongside
it. A little scaffolding may be included where it genuinely de-risks the
plan, but the deliverable here is the plan.

Scope note: this assumes `dev` at `7b8f48d`. `docs/known-limitations.md`
already flags the gap this addresses: "GUI-heavy tools such as Autopsy and
Wireshark GUI are not the current runtime focus, even when supporting
packages are present" — `wireshark-common` is already installed in
`images/network/Dockerfile`, but not the GUI package.

> **Amendment (2026-08-16):** this document's "Which profile(s)" section
> scopes X11 forwarding as an opt-in flag on the `network` profile only. The
> maintainer has since clarified that GUI support (both this X11-forwarding
> approach and the noVNC work in `docs/roadmap-phase3.md`) should be
> available across **all** profiles as a cross-cutting capability, not
> confined to one profile or split into a dedicated `gui` profile. The
> mechanics below (mount + env forwarding, `.Xauthority` auth, package
> additions) still apply; re-scope the "which profile(s)" question and the
> corresponding `docker-compose.yml`/Dockerfile changes accordingly before
> implementing.

## Why X11 forwarding, and why not noVNC

`docs/roadmap-phase3.md` (branch `phase3-scoping`, not merged) already scopes
a full noVNC browser-based virtual desktop: Xvfb (virtual X server) +
window manager + x11vnc/TigerVNC + noVNC/websockify, all running inside the
container and reached over a browser tab on a mapped TCP port. That's the
right design when the analyst may be remote from the Docker host (SSH to a
shared analysis box, headless server, etc.).

X11 forwarding is deliberately simpler, chosen here instead of noVNC *for
now*: the container does not run its own display server at all. It shares
the host's already-running X server by bind-mounting the host's X11 socket
directory (`/tmp/.X11-unix`) and pointing the container's `DISPLAY` at it.
The GUI app inside the container draws directly onto the host's X session,
the same way `ssh -X` or a plain `sudo`'d GUI app would.

This trade-off is real, not a footnote:

- **No noVNC/Xvfb/websockify stack needed.** The container needs the GUI
  package itself and an X11 client library (already present transitively via
  Qt5/GTK deps), nothing else.
- **The analyst must be on the same machine as the Docker host.** X11
  forwarding via a bind-mounted Unix socket only works when the container
  and the X server are on the same kernel — it does **not** work over SSH to
  a remote Docker host the way noVNC does. An analyst on a remote/shared
  analysis VM gets nothing from this feature and still needs
  `phase3-scoping`'s noVNC work. This is the single biggest limitation of
  this approach and should be stated plainly in any user-facing docs, not
  buried.
- **This does not need TCP/IP network access at all.** `/tmp/.X11-unix/X0`
  (etc.) is a Unix domain socket, bind-mounted into the container's
  filesystem namespace like any other volume — it is not a network
  connection, and the default `DISPLAY=:0` value resolves to that local
  socket, not a TCP endpoint (X11-over-TCP is a legacy/optional mode most
  modern desktop stacks disable by default). This was verified as part of
  this scoping (see "Verifying the no-network-access claim" below): no
  package required for a working Wireshark GUI needs outbound network access
  to function, and the socket mount itself is filesystem I/O, not sockets in
  the `AF_INET` sense. **This is a genuine advantage over every other
  GUI-adjacent or connectivity item already scoped** (noVNC, VPN profiles,
  threat-intel platform integrations, cloud forensics all want to weaken
  `network_mode: none` for real reasons of their own) — X11 forwarding is the
  first "give the analyst a GUI window" feature that does not touch the
  project's network isolation posture at all.

This document does not re-scope noVNC and does not duplicate
`phase3-scoping`'s work — it is specifically about the terminal-launched,
host-X11-shared approach, which is additive to (not a replacement for) the
noVNC roadmap.

### Verifying the no-network-access claim

Built and ran real Ubuntu 22.04 containers during this scoping (see risk
section 5 below for the closely related dumpcap-capability test, done the
same way) and inspected `apt-cache depends wireshark`:

```
$ apt-cache depends wireshark
  Depends: wireshark-qt
```

`wireshark-qt` pulls in Qt5 GUI libraries (`libqt5widgets5`, `libqt5gui5`,
X11/XCB client libraries, etc.) — all resolved and installed from the same
`apt-get install` step the Dockerfile already runs at build time (which does
need network access, exactly like every other package install already in
the project's Dockerfiles — that's a build-time property of the whole image
build system, unrelated to this feature). At container **runtime**, nothing
Wireshark GUI does to draw its window or talk to the X server involves a
socket that Docker's `network_mode: none` would block: X11 client libraries
connect to the socket named by `DISPLAY`, which for a bind-mounted
`/tmp/.X11-unix` is a Unix domain socket path, not a TCP address. Live
packet capture (a separate concern, covered in section 5) does need
`NET_ADMIN`/`NET_RAW` *capabilities*, which the `network` profile already has
via `cap_add` — but capabilities are not the same axis as `network_mode`, and
`network_mode: none` containers can still hold `NET_ADMIN`/`NET_RAW` for
local interface access. **Conclusion: the claim holds. This feature needs no
change to `network_mode` for any profile.**

---

## 1. X11 socket + auth mechanics

### Socket mount: read-only is enough

`/tmp/.X11-unix:/tmp/.X11-unix:ro` is the standard, widely-used pattern (it's
what most "run a GUI app in Docker" guides use, including Exegol's own X11
mode). The container only needs to *connect* to the existing socket file the
host X server is listening on; it never needs to create, delete, or rebind
sockets in that directory, so read-only is the correct default — read-write
mounts of `/tmp/.X11-unix` are typically documented as needed only for
niche cases the project isn't targeting (e.g. a container-side X server
publishing its own socket back to the host, or specific shared-memory (MIT-
SHM) extension issues on some non-standard driver stacks). Since Toth's use
case is strictly "client connects to host's server," start read-only, and
only revisit if a specific extension is found to need it once real testing
against an actual X session happens (this sandboxed environment has no X
server to validate against — flagged as an open question, not decided here).

### DISPLAY

Pass the host's `DISPLAY` value straight through as a container environment
variable. `wrapper/utils/docker_manager.py`'s `_env()` is exactly the right
place — it already builds the subprocess environment for every `docker`/
`docker compose` invocation (this is the same mechanism `phase2-item1`-style
`TOTH_WORKSPACE` forwarding uses today):

```python
def _env():
    env = os.environ.copy()
    env.setdefault("TOTH_WORKSPACE", config.WORKSPACE)
    return env
```

`os.environ.copy()` already carries the host's `DISPLAY` into the subprocess
environment that `docker compose` runs under. `docker-compose.yml` then only
needs an `environment: [DISPLAY=${DISPLAY}]` entry on the relevant service —
Compose's variable interpolation reads `${DISPLAY}` from that same process
environment, exactly like `${TOTH_WORKSPACE:-./workspace}` already does for
the volume mounts. No new wrapper code is strictly required for this part;
`_env()` already does the necessary passthrough today, and the only change
needed is on the compose file side. If `DISPLAY` is unset on the host (headless
CI, SSH session without `-X`, etc.), the container should fail clearly rather
than silently drop to a blank/absent display — worth a small explicit check
if a `--gui`-style opt-in path is added (see section 4).

### Authentication: mounted `.Xauthority`, not `xhost`, as the default

Two mechanisms exist and this scoping recommends the first as primary:

1. **Mount the host's Xauthority file read-only and set `XAUTHORITY` inside
   the container.** Most desktop X servers require a valid MIT-MAGIC-COOKIE
   from `.Xauthority` (or wherever `$XAUTHORITY` points, falling back to
   `~/.Xauthority`) for any client to connect, regardless of uid. Bind-mount
   it: `${XAUTHORITY:-$HOME/.Xauthority}:/home/analyst/.Xauthority:ro`, and
   set `XAUTHORITY=/home/analyst/.Xauthority` in the container environment.
   Because the cookie is compared byte-for-byte and doesn't depend on the
   connecting process's uid matching anything, this works regardless of
   whether the container's `analyst` (uid 1000) happens to match the host
   user's uid — **the mounted-cookie approach does not require UID
   matching to work**, which is the cleaner property. The X11 client
   library (libX11, linked into Qt/GTK) reads `.Xauthority` directly; the
   `xauth` *CLI tool* is not required inside the container for this to work,
   only for administrative operations (merging/generating cookies), so it
   does not need to be added to `images/network/Dockerfile` for the base
   case to function.
2. **`xhost +local:` (or a more scoped `xhost +si:localuser:<user>`) as a
   host-side escape hatch**, run once outside the container. This works
   without touching `.Xauthority` at all, because `xhost` grants access by
   connection origin rather than by cookie. It's simpler to explain in a
   one-liner but is also the mechanism with the worse security story (see
   section 3) — `xhost +local:` accepts *any* local Unix-socket connection
   from *any* user on the host, not just Toth's container. Note: the
   commonly copy-pasted snippet `xhost +local:docker` is not doing what
   people think — standard `xhost` syntax is `local:` (any local user) or
   `local:<username>` (a specific host username); `docker` is not a magic
   keyword the X server recognizes, so that idiom typically only works
   because the trailing text after `local:` is silently ignored by some
   implementations, not because it scopes to "docker" specifically. Avoid
   propagating that idiom in Toth's docs.

**Recommendation:** ship the mounted-`.Xauthority` approach as the supported
path, wired automatically by the wrapper (mount + env var, no manual host
step). Document `xhost +si:localuser:<user>` only as a fallback for users
whose X server/cookie setup rejects the mounted-cookie approach (some
minimal window managers or non-standard display managers occasionally don't
populate `.Xauthority` the way full desktop environments do) — as a
documented one-time host setup step, not something the wrapper manages
automatically, since it's a broader host-level grant that the user should
consciously opt into rather than have silently applied on their behalf.

---

## 2. Which profile(s)

**Recommendation: an opt-in capability layered onto the `network` profile
first, not a new profile, and not silently on-by-default for every
container.** Wireshark GUI is the concrete, requested case, and it lives in
`images/network/Dockerfile`. The mechanism (X11 socket mount + `DISPLAY` +
Xauthority) is generic enough that other profiles (`malware` running a GUI
hex editor or a future DIE GUI mode) can adopt the identical pattern later
by copying the same compose fragment — but don't build it into `malware` or
`dfir` speculatively now with no concrete GUI tool driving it. This mirrors
`phase3-scoping`'s existing judgment call about not baking heavy/optional
capability into profiles that don't need it by default.

Concretely, this argues for a `docker-compose.yml` **override** (see section
4) applied only when the analyst explicitly asks for GUI-capable startup —
not a change to `toth-network`'s always-on service block. The `network`
service block itself is otherwise unaffected: analysts who never run
Wireshark GUI don't get an X11 socket bind-mounted into their container by
default.

### UID matching

`images/base/Dockerfile` creates `analyst` at a fixed uid/gid 1000
(`groupadd -g 1000 analyst && useradd -m -u 1000 -g analyst ...`). Because
the mounted-`.Xauthority` approach (section 1) authenticates via cookie
rather than uid, **Toth's fixed uid 1000 is not a hard requirement for X11
auth to work** — this removes one class of "works on my machine" bug. UID
1000 does still matter for two smaller, unrelated reasons worth documenting:

- **File permissions on the mounted `.Xauthority`.** If mounted read-only
  with the host file's original ownership preserved (the Docker bind-mount
  default), the container's `analyst` user needs read permission on that
  file's mode bits. Host `.Xauthority` files are normally `0600` owned by
  the host user; if the host user's uid is *not* 1000, the container's
  `analyst` (uid 1000) will fail to read it despite the mount succeeding,
  because standard Unix permission bits, not just presence, gate the read.
  On the common case of a single-user Linux desktop where the first real
  user is also uid 1000, this is a non-issue; it should still be called out
  as a real failure mode with a clear error message rather than a silent
  connection failure, since Toth cannot assume every analyst's host uid is
  1000.
- **`xhost +si:localuser:<user>` (the fallback path)** resolves the
  connecting process's uid to a username via the *host's* NSS (`getpwuid`)
  to match against the granted username — this one genuinely does depend on
  the container's uid resolving to something meaningful on the host, which
  it may not if host uid ≠ 1000. This is another reason to keep it a
  documented fallback, not the primary path.

---

## 3. Security note (real, not hand-waved)

Mounting the host's X11 socket into a container is a materially different
risk category from the network-isolation conversation running through every
other scoping doc in this repo (`phase3-scoping`, `roadmap-vpn.md`). X11 has
essentially no per-client sandboxing: once a client is authenticated to an X
server, it can, by design of the X11 protocol:

- read keystrokes typed into *other* windows on the same X session
  (`XQueryKeymap`/keylogging via the core protocol or the XTest/XRecord
  extensions many window managers and accessibility tools rely on),
- take screenshots of the entire screen or any window, not just its own,
- inject synthetic input (mouse/keyboard events) into other windows.

This is well-documented, long-standing X11 behavior, not something specific
or novel to Docker — it's the same reason `ssh -X` to an untrusted host is a
known bad idea, and it's the standard caveat attached to every "run GUI apps
in Docker via X11" guide. A compromised or malicious process running inside
a Toth container with X11 access inherits all of this against the analyst's
entire desktop session, not just the container's own window. `--net=none`
provides no mitigation here — it's a filesystem socket, not a network
connection, so network isolation and X11 exposure are two independent risk
axes, not the same conversation.

**Mitigations, roughly strongest-to-weakest:**

- **Scope grants narrowly.** Prefer the mounted-`.Xauthority` cookie
  approach (section 1) over any `xhost +` variant — the cookie only
  authorizes processes that can read that specific file, not "every local
  process," and doesn't require a standing host-side `xhost` grant at all.
- If `xhost` is used as a fallback, use `+si:localuser:<user>` (scoped to
  one host user) — never bare `xhost +` (which disables access control
  entirely, for every host and every user) and avoid `+local:` when a
  narrower form is available, since `+local:` still grants any local process
  from any user on the host, not just Toth's container.
- **Document the risk explicitly** in `docs/usage.md` and
  `docs/known-limitations.md` once this ships: running untrusted/malware
  samples through a GUI-X11-enabled container is a different (and worse)
  trust boundary than Toth's existing "malware samples run in an isolated,
  `network_mode: none` container" story — this scoping's target tool
  (Wireshark, for viewing already-captured or live-interface traffic) is not
  itself an untrusted-input-execution tool in the way a `malware` profile
  sample run is, but the *pattern* (X11-enabled container) should not be
  casually extended to profiles that execute attacker-supplied code without
  a fresh look at this exact risk.
- Revoke the grant after use is the correct mental model for the `xhost`
  fallback path specifically (it's a standing host-level ACL until reset);
  the mounted-cookie path doesn't need an explicit revoke step since it's
  scoped to the container's lifetime and file mount, not a host-wide toggle.

This is a real, standing risk trade-off the project is choosing to accept
for a concrete usability win (a real Wireshark window instead of no GUI at
all) — it should be a conscious, documented decision, not an implicit one.

---

## 4. Wrapper changes needed

**Recommendation: a `--gui` opt-in, not a silent always-on capability for
every `network` container**, matching how `phase3-scoping` treated GUI as
something that shouldn't be baked into non-GUI-using analysts' default
containers. Concretely:

- **`docker-compose.yml`**: add a second compose file,
  `docker-compose.gui.yml`, layered via `docker compose -f docker-compose.yml
  -f docker-compose.gui.yml ...` only when GUI mode is requested — not a
  permanent addition to `toth-network`'s block in the base file. It adds, for
  `toth-network` only:
  ```yaml
  services:
    toth-network:
      environment:
        - DISPLAY=${DISPLAY}
      volumes:
        - /tmp/.X11-unix:/tmp/.X11-unix:ro
        - ${XAUTHORITY:-${HOME}/.Xauthority}:/home/analyst/.Xauthority:ro
      environment:
        - XAUTHORITY=/home/analyst/.Xauthority
  ```
  (the two `environment:` keys above would be merged into one block in the
  real file — split here for readability).
- **`wrapper/utils/docker_manager.py`**: `_compose()` needs to conditionally
  add `-f docker-compose.gui.yml` to the compose invocation when GUI mode is
  requested. `_env()` needs no change beyond what's already there —
  `os.environ.copy()` already forwards `DISPLAY`/`XAUTHORITY`/`HOME` from the
  host shell, which is all Compose's `${...}` interpolation needs.
- **`wrapper/toth.py` / a command file**: the cleanest fit is a `--gui` flag
  on the existing `exec`/`shell` subcommands (`add_exec_arguments` in
  `wrapper/toth.py` already centralizes how `exec`/`shell`/`enter` build
  their argparse arguments) rather than a brand-new command — unlike noVNC
  (which needs its own "print me the URL" command because there's a
  fundamentally different post-start step), X11 forwarding is conceptually
  still "run a command in the container," just with a different compose
  file layered in. `toth exec --gui network wireshark` (or making `--gui`
  implicit whenever the target command is a known GUI binary — more magic,
  not recommended for a v1) reads as the natural CLI shape.
- A pre-flight check worth adding either in the wrapper or as a documented
  manual step: verify `DISPLAY` is set and `/tmp/.X11-unix` exists on the
  host before attempting to start a `--gui` container, and fail with a clear
  message (not a confusing X11 connection error from inside the container)
  if not — e.g. running Toth over plain SSH without `-X`/`-Y` won't have a
  usable `DISPLAY`.

This means `docker-compose.yml`'s base file and `_env()` alone are **not**
sufficient for a good experience — a small, real wrapper change (compose
file layering + a flag) is needed for `toth exec network wireshark` to
"just work" as a single command rather than requiring the analyst to
hand-write compose overrides themselves.

---

## 5. Dockerfile changes

### Package

`images/network/Dockerfile` currently installs `wireshark-common` (CLI
libs/shared code, what `tshark` depends on) but not the GUI. Add `wireshark`
(the Debian/Ubuntu metapackage) or `wireshark-qt` directly — verified during
this scoping that on Ubuntu 22.04, `apt-cache depends wireshark` shows
`Depends: wireshark-qt`, i.e. the plain `wireshark` package name is what
pulls in the actual Qt5 GUI (`wireshark-qt`) plus its full X11/Qt dependency
chain. Installing `wireshark` is therefore the right package name to add,
consistent with how the rest of the Dockerfile names packages.

### The non-root packet capture permission dance — confirmed and solved

This is the one genuinely non-obvious mechanical question in this whole
scoping, and it was verified empirically with real Docker builds (Ubuntu
22.04, matching the project's base image) rather than assumed:

- Debian/Ubuntu's `wireshark-common` postinst normally asks (via debconf)
  "Should non-superusers be able to capture packets?" — if answered yes, it
  creates a `wireshark` group and either sets `dumpcap` setuid-root or grants
  it `cap_net_raw`/`cap_net_admin` file capabilities via `setcap`, then
  expects the invoking user to be added to the `wireshark` group.
- With `DEBIAN_FRONTEND=noninteractive` (already project-wide, per
  `ARG DEBIAN_FRONTEND=noninteractive` in every Dockerfile), debconf takes
  the package's **default** answer, which for `wireshark-common` on Ubuntu
  22.04 is **false** — confirmed via `debconf-show wireshark-common` on a
  fresh non-interactive install, which reported
  `wireshark-common/install-setuid: false`, and no `wireshark` group was
  created (`getent group wireshark` → not found). `dumpcap` was installed
  as a plain `-rwxr-xr-x root root` binary with no capabilities set
  (`getcap` returned nothing).
- **Confirmed by direct test that this breaks non-root capture as-is**: in a
  container run with `--cap-add=NET_ADMIN --cap-add=NET_RAW` (exactly what
  `docker-compose.yml`'s `toth-network` service already sets) as a non-root
  `analyst`-equivalent user, `dumpcap -i lo -c 1 -w ...` failed immediately
  with `dumpcap: The capture session could not be initiated ... (You don't
  have permission to capture on that device)`, printing Debian's own
  suggested fix (`dpkg-reconfigure wireshark-common` / add user to
  `wireshark` group). This means **`tshark` in the current `network` image
  likely already has this exact problem for the non-root `analyst` user
  today** — worth flagging as a pre-existing gap this scoping surfaced as a
  side effect, independent of the GUI work, since `tshark`/`dumpcap` share
  the same capture binary and the same permission mechanics as the Wireshark
  GUI would.
- **The fix, also confirmed by direct test**: adding a single explicit
  `RUN setcap cap_net_raw,cap_net_admin+eip /usr/bin/dumpcap` step to the
  Dockerfile (i.e., doing by hand exactly what the interactive postinst path
  would have done) is sufficient. Re-running the identical capture command
  in a container started with `--cap-add=NET_ADMIN --cap-add=NET_RAW` as the
  non-root user succeeded (interface listed via `dumpcap -D`, and a capture
  session opened cleanly with no permission error via `dumpcap -i lo -a
  duration:2 -w ...`, versus the immediate hard permission failure without
  the `setcap` line).
- **Why container capabilities alone aren't enough**: Docker's
  `cap_add: [NET_ADMIN, NET_RAW]` expands the *container's* capability
  bounding set, but a specific non-root binary only gets to use capabilities
  from that set if the binary itself carries matching file capabilities
  (`setcap`) or is setuid-root — this is standard Linux capability
  semantics, not a Docker quirk, and it's exactly why the interactive
  Debian postinst does the `setcap`/setuid step at package-install time in
  the first place. The project's existing `NET_ADMIN`/`NET_RAW` `cap_add`
  on `toth-network` was necessary but not sufficient on its own; the missing
  piece was the file-capability grant on `dumpcap` itself, which
  `DEBIAN_FRONTEND=noninteractive` silently skips.

**Recommended Dockerfile change**, in `images/network/Dockerfile`'s existing
package block:
```dockerfile
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ... \
        wireshark \
    && setcap cap_net_raw,cap_net_admin+eip /usr/bin/dumpcap \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*
```
(`setcap` itself needs `libcap2-bin`, which is not currently installed
anywhere in the project — add it as a build dependency for this step; it's
a tiny package.) This is a clean answer, matching the intuition in the task
brief: the project's existing `NET_ADMIN`/`NET_RAW` `cap_add` is exactly the
right container-level capability for non-root packet capture, and the only
missing piece is the one-line `setcap` the noninteractive build was silently
skipping.

### Smoke checks

Extend the existing `command -v` smoke-check block with `command -v
wireshark` (the GUI launcher binary) alongside the existing `tshark` check,
following the file's established pattern.

---

## Files that would change

- `docker-compose.gui.yml` (new) — GUI-mode compose override: `DISPLAY`,
  X11 socket mount, `.Xauthority` mount, for `toth-network` initially
- `images/network/Dockerfile` — add `wireshark` + `libcap2-bin`, add the
  `setcap cap_net_raw,cap_net_admin+eip /usr/bin/dumpcap` step, extend smoke
  checks
- `wrapper/utils/docker_manager.py` — `_compose()`/`_run()` need a way to
  layer `-f docker-compose.gui.yml` in when GUI mode is requested; `_env()`
  needs no change (already forwards `DISPLAY`/`XAUTHORITY`/`HOME`)
- `wrapper/toth.py` — add a `--gui` flag to the `exec`/`shell` subcommands
  (via `add_exec_arguments`)
- `wrapper/commands/exec.py` / `shell.py` — thread the `--gui` flag through
  to `docker_manager`
- `docs/usage.md` — a "GUI tools (X11 forwarding)" section: prerequisites
  (same-machine requirement, `DISPLAY` must be set), the security note from
  section 3, and the `xhost` fallback as an explicitly-manual step
- `docs/known-limitations.md` — update the "GUI tools" section: retire the
  "Wireshark GUI is not the current runtime focus" line once shipped, keep
  noVNC/Autopsy language for the remote-desktop case, and add the
  same-machine-only limitation
- `docs/architecture.md` — note the X11-forwarding option alongside the
  existing "Runtime model" section, once `phase3-scoping`'s network-policy
  language is also settled, so both GUI paths are documented consistently
- `docs/tools-list.md` — update "Wireshark common files" → "Wireshark
  (CLI + GUI)" under Network

---

## Open design questions

1. **Read-only vs read-write on `/tmp/.X11-unix`** — recommended read-only
   above based on documented general practice, but not validated against a
   real X session from this sandboxed environment (no X server available
   here). Worth a real end-to-end check on a real desktop before shipping;
   if a specific extension Wireshark's Qt UI needs turns out to require
   read-write, that's a one-line change, not a design change.
2. **`--gui` flag vs. auto-detect by binary name** — recommended explicit
   flag for v1 (simpler, no magic); revisit if a list of "known GUI
   binaries" per profile becomes worth maintaining later.
3. **Does `docker-compose.gui.yml` generalize cleanly to other profiles
   later** (e.g. `malware` for a GUI hex editor) as a second override file,
   or should it become a reusable fragment/anchor shared across profiles
   once there's a second real consumer? Don't build the abstraction before
   there's a second concrete GUI tool asking for it.
4. **Should the wrapper attempt to detect a missing/unset `DISPLAY` and
   fail fast with a clear message**, vs. letting the container start and
   fail inside with a less friendly X11 connection error? Recommended:
   fail fast in the wrapper, but it's a small enough addition that it could
   be deferred to a fast-follow rather than blocking v1.
5. **Should `xhost +si:localuser:<user>` ever be run automatically by the
   wrapper** (e.g. as a "first-run setup" step) rather than purely
   documented? Recommended: no — keep it a manual, documented fallback,
   since it's a host-level security-relevant grant that shouldn't happen
   without the user consciously doing it themselves, consistent with the
   caution urged in section 3.

---

## Suggested implementation order

1. **Dockerfile change first, independent of everything else**: add
   `wireshark` + the `setcap` fix to `images/network/Dockerfile`. This alone
   also fixes the latent non-root `tshark`/`dumpcap` capture-permission gap
   this scoping surfaced, so it's worth doing even in isolation, and it's
   the lowest-risk, most mechanically confirmed piece of this whole plan.
2. **`docker-compose.gui.yml` + `.Xauthority`/socket mount**, tested by hand
   against a real desktop X session (something this sandboxed environment
   can't do) — confirm the mounted-cookie approach actually authenticates
   without any `xhost` grant on a real machine before committing to it as
   the documented default.
3. **Wrapper `--gui` flag** wiring `docker_manager` to layer the override
   compose file, plus the `DISPLAY`-unset fail-fast check.
4. **Docs**: `docs/usage.md` GUI section (including the security caveat
   verbatim, not summarized away), `docs/known-limitations.md` update,
   `docs/tools-list.md`/`docs/architecture.md` touch-ups.

## Risk/effort estimate

**Low-medium effort, low risk to the project's existing architecture** —
noticeably lighter than both `roadmap-vpn.md` and `phase3-scoping`'s noVNC
item, and this scoping's own research confirms why: this is the first
GUI-adjacent feature in the roadmap that needs **no change to
`network_mode`, no new runtime layer (no Xvfb/VNC/websocket stack), and no
new profile** — it's a bind-mount, an env var, one `setcap` line, and a
thin wrapper flag, layered onto a profile that already exists. The
mechanically hardest question (non-root packet capture permissions) has
already been identified and solved by direct testing during this scoping
pass, not left as an open risk. The two things that keep this from being
"trivial" are (a) the same-machine-only limitation, which is a real UX
constraint worth clearly documenting rather than a technical risk, and (b)
the X11-exposure security trade-off in section 3, which is a conscious,
documented risk-acceptance decision rather than something more
implementation effort would remove. Rough estimate: 1-2 days for the
Dockerfile + compose + wrapper flag, assuming access to a real desktop X
session for validation (this sandboxed environment cannot provide that);
+0.5 day for docs. This makes it a strong candidate to implement soon,
ahead of the heavier VPN and noVNC items.
