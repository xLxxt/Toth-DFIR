# VPN Profile Support — Scoping

This document scopes per-case VPN profile support for the wrapper, modeled
on how Exegol does it, as referenced in the project's "CTF Blue Team (HackTheBox
Sherlock, CyberDefenders, ...)" use case in `README.md`. It is a planning
document, not an implementation: no VPN feature code ships alongside it.

Scope note: this assumes `dev` at `7b8f48d` plus the not-yet-merged
`phase2-item1-case-management` branch (`toth case new/list/use/current`,
reviewed but not yet in `dev`) as the foundation this builds on, and reads
`phase3-scoping`'s `docs/roadmap-phase3.md` cross-cutting network-policy
section as prior art this should extend rather than re-litigate. Both
branches are unmerged; if either lands in a materially different shape before
this work starts, revisit the assumptions below before implementing.

## Why VPN, and why case-scoped

The "CTF Blue Team" use case (HTB Sherlocks, CyberDefenders boxes, and
similar) requires connecting through a specific VPN per engagement — HTB
issues a per-user `.ovpn` file, and different engagements/labs use different,
mutually exclusive VPN endpoints. This is structurally the same problem
`phase2-item1-case-management` just solved for evidence/output directories:
each engagement needs its own isolated slice of state that the wrapper
switches into and out of via `toth case use <name>`. VPN config should be
another per-case artifact, not a global setting — a global `.env`-style VPN
config (the pattern `roadmap-phase3.md` used for MISP/OpenCTI credentials)
doesn't fit here, because unlike a threat-intel API key, an analyst
routinely holds several *simultaneously valid but mutually exclusive* VPN
configs (one per active box/case) and switches between them constantly,
often within the same day.

Exegol's model confirms the shape to copy: a VPN config mounted read-only at
a fixed in-container path, `NET_ADMIN` + `/dev/net/tun` device access,
`net.ipv6.conf.all.disable_ipv6=0` and `net.ipv4.conf.all.src_valid_mark=1`
sysctls, an entrypoint that auto-detects the mounted config and starts
`openvpn`/`wg-quick` with no manual step, and network isolation that is
never `host` specifically so VPN routes can't leak onto the analyst's own
host network stack.

---

## 1. VPN config storage & case integration

### Recommended approach

Extend `wrapper/utils/case.py`'s `case_paths()` pattern with a third
per-case artifact. Today `case_paths(name)` returns `(cases_dir,
output_dir)` under `<workspace>/cases/<name>` and `<workspace>/output/<name>`.
Add a third root, `<workspace>/vpn/<name>/`, holding at most one active VPN
config per case:

```
~/toth/workspace/vpn/<case-name>/
├── config.ovpn        # OpenVPN, OR
├── config.conf         # WireGuard, mutually exclusive with the above
└── creds.txt            # optional, OpenVPN user/pass auth only
```

A single fixed filename per type (not "first `.ovpn` found in a directory,"
which is what Exegol does for its general case) keeps the mechanics in
section 2 simple — the compose bind-mount source path needs to be
deterministic per case, and a directory-scan-at-runtime is exactly the kind
of dynamic behavior a static `docker-compose.yml` can't express. Enforcing
"one canonical filename" at the `toth vpn add` step is a small trade of
Exegol's flexibility for a mount path that can be hardcoded in the compose
file.

New `wrapper/utils/vpn.py`:

- `vpn_paths(case_name) -> (config_path_or_none, creds_path_or_none, kind)`
  — inspects `<workspace>/vpn/<case-name>/` for `config.ovpn` or
  `config.conf`, returns `kind` as `"openvpn"`, `"wireguard"`, or `None`.
- `add_vpn_config(case_name, source_file, creds_file_or_none)` — validates
  the case exists (reuses `case.is_valid_name` / `case.list_cases()`),
  detects `.ovpn` vs `.conf` by extension, copies (not symlinks — this is a
  credential-bearing file, and a case directory may later be archived or
  handed off independently of wherever the original file lived) into
  `<workspace>/vpn/<case-name>/config.<ext>`, and the optional creds file
  into `creds.txt`. Refuses to overwrite silently — require `--force` or an
  explicit `vpn remove` first, since dropping a live case's VPN config is a
  destructive, easy-to-fat-finger action.
- `remove_vpn_config(case_name)` — deletes the case's VPN dir contents.
- `active_vpn(case_name_or_none)` — convenience wrapper `docker_manager`
  calls to decide mount behavior (see section 2).

New `wrapper/commands/vpn.py`, wired into `wrapper/toth.py` as a `vpn`
subcommand group next to the existing `case` group (same
`sub.add_parser` / `case_sub.add_parser` pattern):

```
toth vpn add <case> <file.ovpn|file.conf> [--creds <file>]
toth vpn remove <case>
toth vpn show [<case>]     # defaults to the active case; prints kind + path, never prints creds contents
```

No `toth vpn use` — VPN is not a separate selectable state from the case
itself; it rides on whatever case is currently active via `toth case use`.
This deliberately keeps a single "what am I working on" mental model (the
active case) rather than two independently-settable pieces of state that
can drift out of sync (e.g., case A active but case B's VPN config
connected).

### `.ovpn` vs WireGuard `.conf` handling

Mirror Exegol's split: `.ovpn` implies OpenVPN, gets mounted for `openvpn`
to consume, optional `creds.txt` passed via `--auth-user-pass`. `.conf`
implies WireGuard, mounted to the fixed path `wg-quick` expects
(`/etc/wireguard/wg0.conf` — WireGuard's tooling is opinionated about this
path and interface-name-matches-filename convention, so this one, unlike
the case-vpn-dir layout above, should follow WireGuard's own convention
rather than inventing a Toth-specific one). No credentials file applies to
WireGuard — auth is embedded in the `.conf` itself (private key + peer
config), which changes the credentials-file question in the next paragraph:
only `.ovpn` has a meaningful separate-credentials case.

### Credentials file handling

OpenVPN username/password auth (as opposed to certificate-only auth, where
everything needed is already inside the `.ovpn`) needs a second file. Follow
Exegol's precedent: a plain-text `creds.txt` (user on line 1, password on
line 2), mounted read-only next to the `.ovpn`, referenced via OpenVPN's own
`--auth-user-pass <path>` flag. This is not a Toth-invented secret store —
same reasoning `roadmap-phase3.md` item 5 used for cloud credentials
("don't invent a Toth-specific secret store"; reuse the tool's own
convention). File permissions on `creds.txt` should be tightened to
`600`/owner-only at write time in `add_vpn_config()`, and the file must
never be printed by `toth vpn show` or logged by the entrypoint script.

---

## 2. The compose static-capability problem

This is the crux of the design, and it does not have as clean an answer as
the case-management symlink-shim (which only needed to redirect a **bind
mount source path** — something Compose already resolves per-invocation via
`${TOTH_WORKSPACE}` in the subprocess environment). VPN needs three things
`docker-compose.yml` would otherwise have to declare per-profile-per-case,
none of which Compose can vary per invocation the way it resolves `${VAR}`
in a volume path: `cap_add: [NET_ADMIN]`, `devices:
["/dev/net/tun:/dev/net/tun"]`, and two `sysctls:` entries.

### Option (a): declare unconditionally, make the tunnel opt-in via the entrypoint

Add `cap_add: [NET_ADMIN]`, the `/dev/net/tun` device, and the two sysctls
to `docker-compose.yml` for the VPN-capable service(s) *unconditionally* —
whether or not the active case actually has a VPN config mounted. The
compose file stays static (no per-case editing, matching the constraint
that made the case-management symlink-shim necessary in the first place).
The entrypoint script (section 4) checks at container start whether a VPN
config happens to be present for the resolved mount path; if not, it's a
silent no-op and the container behaves exactly as it does today. The VPN
config file mount itself reuses the exact same static-path-plus-per-case-
resolved-source trick `docker_manager._resolve_workspace()` already
performs: add a fourth line to the shim, `<mount_root>/vpn` -> symlink to
`<workspace>/vpn/<active-case>/` (or, if the case has no VPN dir yet, a
symlink to an empty placeholder directory so the bind mount doesn't fail
when the source doesn't exist — Docker will happily bind-mount an empty
directory, which is what "no VPN configured for this case" looks like at
the container boundary), then a static compose line:
`${TOTH_WORKSPACE}/vpn:/opt/toth/vpn:ro`.

**Trade-off:** this means `NET_ADMIN` + raw tun device access is granted to
every container of that profile, permanently, regardless of whether that
particular case uses VPN at all — the capability grant is unconditional
even though its use is conditional. This is a real, not cosmetic, security
regression versus today's default-deny posture for any profile it's applied
to, and needs to be weighed against how narrowly VPN support is scoped to
specific profiles (see section 3).

### Option (b): override file or profile variants

Two variants considered:

- **`docker-compose.override.yml`**, conditionally referenced via `docker
  compose -f docker-compose.yml -f docker-compose.vpn.yml ...` only when
  `docker_manager` detects the active case has a VPN config. This keeps the
  base compose file's declared capability surface honest (a container only
  ever gets `NET_ADMIN` when a VPN config is genuinely mounted for it,
  determined by the wrapper *before* invoking compose, not by the container
  discovering it has no work to do after the fact). Mechanically
  straightforward: `_compose()` in `docker_manager.py` already builds an
  `args` list handed to `subprocess`; adding a conditional `-f` pair is a
  small, local change matching the file's existing shape.
- **Separate profile variants** (`dfir` vs `dfir-vpn` as distinct compose
  services/images) — rejected. This is the same shape `roadmap-phase3.md`
  item 2 considered and leaned away from for threat-intel (`dfir-ti`) for
  the same reason: it multiplies the profile matrix (now every VPN-capable
  profile doubles), and unlike TI credentials, VPN is meant to be switched
  per-case within a single profile choice — an analyst doing `toth case use
  <boxA>` then `toth case use <boxB>` on the same `dfir` container shouldn't
  have to also switch which *profile* they're running.

**Trade-off:** the override-file approach means the *set of containers
compose knows about* changes shape depending on wrapper-computed state
(present VPN config or not) at the moment of invocation, which is more
moving parts than option (a)'s "always declared, sometimes idle" approach.
It also means `docker compose up -d <svc>` run by a human directly
(bypassing the wrapper) — which nothing today prevents, since compose files
are meant to be usable standalone — silently loses VPN capability, whereas
option (a)'s unconditional declaration works correctly however compose is
invoked.

### Recommendation

**Option (a)**, with the capability grant scoped to as few profiles as
possible (section 3) rather than applied blanket. The determining factor:
option (b)'s override-file approach reintroduces exactly the kind of
per-invocation compose-file-shape variability that the case-management
branch went out of its way to avoid (its commit message explicitly frames
"docker-compose.yml stays untouched" as the design goal), for a benefit
(capability only present when a config is mounted) that a well-written
entrypoint no-op achieves anyway with no capability-surface change to the
compose file. Option (a) also degrades better under direct `docker compose`
invocation (bypassing the wrapper), which the project doesn't currently
prevent or discourage. The cost — permanent `NET_ADMIN`/tun-device grant on
VPN-capable profiles regardless of per-case use — is real, but it is a
one-time, auditable line in `docker-compose.yml` rather than a
wrapper-computed conditional that has to be gotten right on every
invocation to stay honest. Section 6 elaborates why this cost still
deserves its own sign-off rather than being waved through with this
recommendation.

---

## 3. Network mode

### Which profiles should support VPN at all

Not all four. VPN support should probably ship on `network` first, and
possibly `dfir` — not `base` or `malware`:

- **`network`** — the natural first target. It already runs `bridge` +
  `NET_ADMIN`/`NET_RAW` for packet capture, so VPN's capability
  requirements (`NET_ADMIN` + `/dev/net/tun`) are additive to a profile that
  has already made the "this container can touch the network" decision.
  Zero new network-mode conflict.
- **`dfir`** — the profile that actually matches the CTF/HTB workflow
  (running Hayabusa/Chainsaw/RegRipper/etc. against artifacts pulled off a
  box reached over VPN). This is where the real user-facing win is, but
  it's also `config.DEFAULT_PROFILE` — same highest-stakes-default concern
  `roadmap-phase3.md` item 2 flagged for threat-intel on `dfir`. Recommend
  shipping VPN on `network` first, validate the mechanism end-to-end, then
  extend to `dfir` as a deliberate second step with its own review — not
  bundled into the same change.
- **`malware`** — no clear use case (malware analysis containers should
  generally stay network-isolated for sample-safety reasons that have
  nothing to do with VPN policy) and **`base`** — too generic/foundational
  to carry a capability grant every derived image would inherit unless
  explicitly re-scoped. Both excluded from v1.

### Network mode itself

`bridge`, never `host` — this directly matches Exegol's own reasoning
(explicitly avoiding `host` specifically so VPN routes don't leak onto the
analyst's own host network stack) and is the one point in this document
where Exegol's precedent and Toth's own existing default-deny posture
already agree without needing new argument. `network`'s existing service
already uses `bridge`; extending `dfir` for VPN would mean moving it off
`network_mode: none` to `bridge` specifically when this feature ships for
it — a network-mode change to the default profile, which is exactly the
category of decision `roadmap-phase3.md`'s cross-cutting section says
should be explicit and documented, not incidental.

### Relationship to the Phase 3 cross-cutting network-policy decision

`roadmap-phase3.md`'s cross-cutting section frames the `network_mode: none`
default as a single project-wide policy, and lists noVNC, threat-intel, and
cloud-forensics as three reasons profiles might need to weaken it — all
three needing ordinary outbound HTTPS/websocket access. VPN is a fourth
reason, but it is not the same *kind* of reason, and this document should
say that plainly rather than filing VPN as a fourth bullet under the same
umbrella: **NET_ADMIN plus raw `/dev/net/tun` device access is a
categorically larger capability grant than "this container can make
outbound HTTPS calls."** A compromised process in a `bridge`-with-no-extra-
capabilities container (the noVNC/TI/cloud case) can phone home over
HTTPS; a compromised process in a container with `NET_ADMIN` and tun access
can create arbitrary network interfaces, manipulate routing tables, and
potentially interfere with or redirect traffic at a level none of the other
three features come close to needing. `network`'s existing `NET_ADMIN` +
`NET_RAW` grant is the only real precedent in the codebase for this class
of capability, and it exists for a narrow, well-understood reason (packet
capture) — VPN would be the second, and it should be justified on its own
terms alongside that one, not folded into the noVNC/TI/cloud bucket. The
Phase 3 document's recommendation to record network policy centrally in
`docs/architecture.md`'s "Runtime model" section still applies here — VPN's
entry in that policy should explicitly name `NET_ADMIN` + `/dev/net/tun` as
its own capability tier, separate from the "opt-in outbound HTTPS" tier the
other three features share.

---

## 4. Auto-connect mechanism

### Where the entrypoint lives

`images/base/Dockerfile` is the right place, alongside `toth-check`
(`COPY ... tools/verify/check_tools.sh`, symlinked to `/usr/local/bin/toth-check`)
— every profile inherits from `base`, so an entrypoint added there is
inherited too, and the script itself can be a cheap no-op for profiles that
never mount a VPN config, keeping option (a)'s "no config mounted -> silent
no-op" property self-contained in one script rather than duplicated per
profile.

**Important architectural gap this surfaces:** none of the four current
Dockerfiles declare an `ENTRYPOINT` today — each ends in `USER analyst` /
`CMD ["/bin/bash"]`, and the container simply runs bash as the non-root
`analyst` user (`stdin_open`/`tty` keep it alive; `docker compose
exec`/`up` drive interaction). Starting `openvpn`/`wg-quick` requires root
(creating a tun interface and modifying routing tables needs the
capabilities granted to UID 0 by default; the `analyst` user does not
inherit `cap_add`-granted capabilities just because the container has
them). This means introducing VPN auto-connect is not just "add a script" —
it requires **reintroducing a root-first entrypoint** that:

1. Runs as root (container starts as root by default before any `USER`
   directive takes effect at runtime — the Dockerfile's `USER analyst` only
   sets the default for `CMD`, an `ENTRYPOINT` set with root ownership runs
   before that).
2. Checks `/opt/toth/vpn/` (the mount point from section 2) for
   `config.ovpn` or `config.conf`; no-ops immediately if neither is
   present.
3. If `config.ovpn`: launches `openvpn --config /opt/toth/vpn/config.ovpn
   [--auth-user-pass /opt/toth/vpn/creds.txt] --daemon`.
4. If `config.conf`: copies/links it to `/etc/wireguard/wg0.conf` and runs
   `wg-quick up wg0`.
5. Drops privileges and execs the original `CMD` as the `analyst` user
   (`exec gosu analyst "$@"` or `su-exec` — `gosu` is the more common choice
   in Debian/Ubuntu-based images and should be added as a small `apt-get`
   package addition in `images/base/Dockerfile`).

This is a bigger change to the base image's runtime model than the phrase
"add an entrypoint script" suggests, and should be scoped as its own
sub-task with its own review, not treated as a one-line Dockerfile add.

### Package additions

`images/base/Dockerfile`'s `apt-get install` block needs `openvpn`,
`wireguard-tools` (provides `wg-quick`), and `gosu` (or `su-exec`) added,
plus corresponding `command -v openvpn`, `command -v wg-quick`, `command -v
gosu` smoke checks in the existing pattern right after the install block.
This is the mechanically simplest part of this whole feature — same shape
as every other apt-get addition already in that file — but it does mean
every profile's image grows by these packages even on profiles that never
use VPN, which is a minor argument for keeping the packages themselves in
`base` (cheap, shared) while keeping the *capability grant* itself scoped
narrowly per section 3 (not cheap, not shared).

### Detecting the active case's config

The entrypoint doesn't need to know about cases at all — by the time
`docker compose up` runs, `docker_manager._resolve_workspace()` has already
resolved `TOTH_WORKSPACE` to the per-case shim directory (or the flat
workspace root with no case active), and the static compose mount
`${TOTH_WORKSPACE}/vpn:/opt/toth/vpn:ro` means the entrypoint only ever
needs to look at the fixed in-container path. All the case-awareness lives
in the wrapper (`docker_manager.py`), matching how case-scoped `/cases` and
`/opt/toth/output` already work — the container itself has no concept of
"case," only of fixed mount points, exactly as today.

---

## 5. The `setcase`/`newcase` naming collision

Confirmed real. `config/shell/aliases.sh` (baked into `base`, sourced by
every container's `.bashrc`) defines two in-container-only shell functions:

```sh
setcase() { export CASE="$1"; ... }
newcase() {
    local name="${1:-case_$(date +%Y%m%d)}"
    mkdir -p /cases/$name/{evidence,output/{...},notes}
    export CASE_DIR="/cases/$name"
    ...
}
```

These predate and are entirely disconnected from the new host-level `toth
case new/use/list/current` wrapper commands from
`phase2-item1-case-management`. They operate purely inside the container's
`/cases` mount, know nothing about `.active-case`, `case_paths()`, or the
symlink shim, and — critically — `newcase`'s directory layout
(`/cases/$name/{evidence,output/{volatility,chainsaw,...},notes}`) is a
*subdirectory structure inside whatever `/cases` currently resolves to*,
which today (with `phase2-item1-case-management`, not yet merged) means an
analyst who runs `toth case use boxA` on the host and then `newcase boxB`
inside the container ends up with a case-within-a-case
(`/cases/boxB/...` living inside the already-case-scoped `boxA` mount) —
two independent, differently-scoped notions of "case" that can nest into
each other in a confusing way, and neither warns about the other's
existence.

**Recommendation for VPN:** hook VPN support into the host-level `toth
case` system only (`case_paths()`/`.active-case`, as designed throughout
this document), not the shell-level `setcase`/`newcase` functions. The
wrapper-level system is where case *isolation* actually lives (separate
host directories, separate mounts) — the shell-level functions are a
lighter-weight organizational convenience inside a single mount, not an
isolation mechanism, and VPN's entire value proposition here is isolation
(this case's box, this case's tunnel). Tying VPN to the shell-level
functions would mean VPN config resolution depends on something the analyst
types *inside* the container after it's already running, which cannot work
for this design at all — the VPN config has to be mounted and the tunnel
started *before* the container's shell is reachable, per section 4.

**This collision should be called out as a prerequisite decision, not
silently worked around.** At minimum, before or alongside VPN shipping:
either (a) rename the shell-level functions (e.g. `case-note`/`case-mkdir`)
to stop implying they're the same concept as `toth case`, or (b) make
`newcase`/`setcase` thin wrappers that shell out to `toth case new`/`toth
case use` so there is only one source of truth for "what case is active,"
with the in-container functions becoming convenience aliases rather than a
second competing state machine. Option (b) is the more coherent long-term
fix (one case concept, two entry points) but is out of scope for this VPN
document to design in full — flagging it here is sufficient for VPN
planning purposes, but whoever picks up VPN implementation should not ship
it without at least a decision on which of (a)/(b) applies, since VPN is
the first feature that makes the two systems' disagreement actually harmful
(silently wrong VPN tunnel) rather than merely confusing.

---

## 6. Security note

VPN is being scoped as a fourth item alongside noVNC, threat-intel, and
cloud-forensics in terms of "things that want to weaken `network_mode:
none`," but it is not peer to those three in terms of risk, and this
document is explicit about that rather than letting it blend in: **`NET_ADMIN`
+ raw `/dev/net/tun` device access lets a process create network
interfaces and manipulate host-visible routing state; the other three
features only ever need the container to be able to make outbound
HTTPS/websocket calls.** Concretely:

- `NET_ADMIN` inside a container is a broad grant — it covers interface
  configuration, routing table manipulation, and firewall rule changes, not
  just "create a tun device." Docker's own capability documentation flags
  `NET_ADMIN` as one of the capabilities most likely to enable container
  breakout or host-network interference if the container is compromised.
- `/dev/net/tun` access means a compromised process can create arbitrary
  tunnel interfaces, not just the one the entrypoint intends to bring up.
- This is the second time the codebase has granted this capability tier at
  all (after `network`'s packet-capture use), and the first time it would
  be granted to a profile whose primary purpose (forensic analysis) has
  nothing to do with the reason it needs the capability (a VPN tunnel to
  reach the target). That mismatch — a forensic-analysis container that
  also happens to hold host-routing-table-adjacent privileges — deserves
  its own explicit sign-off from whoever owns the project's security
  posture, separate from and more careful than the noVNC/TI/cloud
  network-mode conversation in `roadmap-phase3.md`, which is comparatively
  low-stakes (outbound HTTPS is a much smaller blast radius than routing
  table access). Recommend treating "grant `NET_ADMIN` + `/dev/net/tun` to
  `network` (and later `dfir`)" as its own line-item decision in whatever
  review process the Phase 3 network-policy write-up (section 3, above)
  goes through — not something approved by reference to "well, we already
  decided profiles can weaken network_mode: none for other reasons."

---

## Files that would change

- `wrapper/utils/vpn.py` (new) — `vpn_paths()`, `add_vpn_config()`,
  `remove_vpn_config()`, `active_vpn()`
- `wrapper/commands/vpn.py` (new) — `add`/`remove`/`show`
- `wrapper/toth.py` — wire the `vpn` subcommand group (same pattern as
  `case`)
- `wrapper/utils/docker_manager.py` — extend `_resolve_workspace()`'s
  symlink shim with a fourth `vpn` symlink; extend `_env()`/`ensure_*()` as
  needed
- `docker-compose.yml` — `cap_add: [NET_ADMIN]`, `devices:
  ["/dev/net/tun:/dev/net/tun"]`, `sysctls:` block, and the
  `${TOTH_WORKSPACE}/vpn:/opt/toth/vpn:ro` mount, scoped initially to
  `toth-network` only (see section 3)
- `images/base/Dockerfile` — `openvpn`, `wireguard-tools`, `gosu` packages;
  new `ENTRYPOINT` script (e.g. `config/entrypoint/vpn-entrypoint.sh`,
  `COPY`'d in and `chmod +x`'d next to the existing `aliases.sh`/
  `check_tools.sh` pattern); smoke checks
- `config/shell/aliases.sh` — resolve the `setcase`/`newcase` collision
  (section 5), at minimum a decision, ideally the (b) thin-wrapper fix
- `docs/architecture.md` — extend "Runtime model" with the VPN capability
  tier (section 3)
- `docs/usage.md` — a "Connect through a VPN" section mirroring the "Manage
  cases" section's style
- `docs/known-limitations.md` — document that VPN is `network`-only in v1
  (and, later, `dfir`)
- `tests/test_commands.sh` — smoke checks for `toth vpn add/remove/show`
  argument parsing (no real tunnel in CI, same spirit as the existing
  command tests)

## Open design questions

1. Does `dfir` get VPN support in v1, or is `network`-only the actual v1
   scope, with `dfir` as an explicit fast-follow? This document recommends
   the latter (section 3), but it's the maintainer's call, not a foregone
   conclusion.
2. Should `toth vpn add` refuse to overwrite an existing config outright, or
   support `--force`? Recommended: refuse by default, `--force` to
   overwrite, matching the "destructive action needs an explicit flag"
   posture used elsewhere in this scoping (e.g. case removal isn't even a
   command yet).
3. `gosu` vs `su-exec` vs `setpriv` for the root-to-analyst privilege drop
   in the entrypoint — `gosu` is the most common in Debian/Ubuntu-based
   images and has the simplest signal handling, but worth a quick check
   that it doesn't reintroduce any of the PID-1 signal-forwarding issues
   `gosu`'s own docs warn about, since Toth containers rely on `docker
   compose exec`/interactive `tty` sessions rather than a signal-sensitive
   daemon workload — likely a non-issue here, but worth confirming rather
   than assuming.
4. Should `toth vpn show` (and the entrypoint's own logging) ever print
   *which* VPN endpoint/server the config points to, for analyst
   sanity-checking ("am I actually connected to the right box"), or is that
   out of scope for v1 and left to `ip addr`/`wg show` run manually inside
   the container? Leaning toward: out of scope for v1, don't parse
   `.ovpn`/`.conf` contents beyond what's needed to detect type.
5. What does `toth case list`/`toth case current` display when a case has a
   VPN config attached — should the case listing surface VPN status,
   or is that purely a `toth vpn show` concern? Minor UX question, not a
   blocker.
6. Does the entrypoint need a `--no-vpn` escape hatch (start the container
   without attempting to connect, even if a config is mounted) for
   debugging a broken tunnel without a chicken-and-egg problem where the
   only way into the container is through the entrypoint that's failing?
   Recommend yes — an env var (`TOTH_VPN_DISABLE=1`) the wrapper can inject
   is cheap insurance and avoids a support dead-end.

---

## Suggested implementation order

1. **Resolve the `setcase`/`newcase` collision decision** (section 5) —
   cheap, and avoids VPN work landing on top of an already-confusing case
   concept. Does not need to be the full reconciliation, just a decision on
   direction.
2. **`wrapper/utils/vpn.py` + `wrapper/commands/vpn.py`** (`add`/`remove`/
   `show`, no container changes yet) — pure filesystem/CLI work, fully
   testable without Docker, de-risks the case-integration and validation
   logic independently of the harder compose/entrypoint work.
3. **`docker_manager.py` symlink-shim extension** — small, mechanically
   follows the existing three-line pattern for `cases`/`output`.
4. **`docker-compose.yml` capability/device/sysctl additions, scoped to
   `toth-network` only** — the actual security-relevant change; this is
   where section 6's sign-off should happen, before step 5, not after.
5. **`images/base/Dockerfile` entrypoint + package additions** — the
   riskiest step technically (root-first entrypoint is new to every image),
   should be validated manually against a real OpenVPN and a real WireGuard
   config before considering this feature done.
6. **Docs** (`architecture.md`, `usage.md`, `known-limitations.md`) and
   `tests/test_commands.sh` smoke checks.
7. **`dfir` extension**, as a separate, later change with its own review —
   not bundled into the initial `network`-only ship.

## Risk/effort estimate

**Medium-high overall**, concentrated in two places rather than spread
evenly:

- The `vpn.py` utils/commands layer (steps 1-3 above) is low risk and
  mirrors `case.py` closely — roughly 1-2 days including tests.
- The entrypoint/capability work (steps 4-5) is where the real risk and
  effort live: introducing a root-first `ENTRYPOINT` is new to this
  codebase's runtime model (today every image runs `CMD` directly as
  `analyst`), the `gosu`-based privilege drop needs to be gotten right
  (open question 3), and testing genuinely requires a live VPN endpoint
  (OpenVPN and WireGuard both) rather than being mockable — this is the
  part of the estimate with the most uncertainty. Rough estimate: 3-5 days,
  including manual verification against real HTB/CyberDefenders-style VPN
  configs of both kinds.
- The security sign-off in section 6 is a process step, not an engineering
  task, but should be treated as a hard gate before step 4 ships, not a
  formality after the fact.

Total: **roughly 1-1.5 weeks** for the `network`-only v1 scoped here,
before any `dfir` extension.
