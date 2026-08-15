# Phase 3 Roadmap (Scoping)

This document scopes the work tracked for Phase 3, as referenced in
[docs/known-limitations.md](known-limitations.md) ("Browser-accessible desktop
support with noVNC is planned for Phase 3") and
[docs/tools-list.md](tools-list.md) ("Not installed yet"). It is a planning
document, not an implementation plan that has been built yet — no Phase 3
feature code ships alongside it.

Today's model: four profiles (`base`, `dfir`, `malware`, `network`), each a
`images/<profile>/{Dockerfile,build.sh}` pair registered in
`wrapper/utils/config.py`'s `PROFILES` dict and given a service block in
`docker-compose.yml`. Every profile runs `network_mode: none` except
`network`, which uses `bridge` plus `NET_ADMIN`/`NET_RAW` because tools like
`tcpdump` and Suricata need packet access. That default-deny network posture
is a deliberate security property of the project today, and three of the five
items below want to weaken it for different reasons. That tension is called
out as a single cross-cutting decision below rather than three separate ones.

---

## 1. Browser-accessible GUI via noVNC

> **Amendment (2026-08-16):** the maintainer has clarified that GUI support
> (this noVNC work, and the X11-forwarding work in
> `docs/roadmap-x11-forwarding.md`) should be available across **all**
> profiles as a cross-cutting capability, not split into a dedicated `gui`
> profile as recommended below. Re-scope the profile/layering approach
> accordingly before implementing; the rest of this section's technical
> content (Xvfb/noVNC stack, auth, risk notes) still applies.

**Problem.** Toth is CLI-first by design, but GUI-only tools (Autopsy,
Wireshark's GUI) have no place to run. `docs/known-limitations.md` already
commits to noVNC support in Phase 3.

**Recommended approach (superseded on profile scoping, see amendment above).**
A new `images/gui/` profile, not a flag on existing
profiles. GUI tooling (Xvfb, a lightweight window manager such as openbox,
x11vnc or TigerVNC, noVNC + websockify) is a distinct, heavy layer that
doesn't belong baked into `dfir`/`malware`/`network` for analysts who never
use it. Build `toth-gui` `FROM toth-dfir:0.1.0` (or `toth-base`, TBD — see
open questions) so it inherits case-relevant tools, then layer:
- Xvfb + a minimal WM
- x11vnc (or TigerVNC) bound to the virtual display
- noVNC + websockify, serving a browser client on a container port
- A startup script (entrypoint or supervisord) that brings up the stack in
  order and stays foregrounded for `docker compose up`

New `docker-compose.yml` service `toth-gui`, with `network_mode: bridge` and
a port mapping bound to loopback by default (`127.0.0.1:6080:6080`), not a
LAN-exposed port. This is the concrete instance of the network policy
conflict: noVNC is only reachable over TCP, so `network_mode: none` is
incompatible with this profile's entire purpose.

The wrapper needs a way to expose "started, here's the URL" rather than just
dropping into a shell. Either a new `wrapper/commands/browse.py` (prints/opens
`http://localhost:<port>` once the container is up) or a `--gui` behavior
added to `start.py`. Given the wrapper is intentionally minimal today, a
dedicated command that mirrors the existing `start`/`stop`/`exec` shape reads
more consistent than overloading `start`.

**Files/dirs to touch.**
- `images/gui/Dockerfile`, `images/gui/build.sh` (new)
- `docker-compose.yml` — new `toth-gui` service
- `wrapper/utils/config.py` — register `gui` in `PROFILES`
- `wrapper/commands/browse.py` (new) or changes to `start.py`
- `Makefile` — `build-gui` target
- `docs/usage.md`, `docs/architecture.md`, `README.md` profile table
- `docs/known-limitations.md` — retire the noVNC line once shipped, keep the
  Autopsy/Wireshark-GUI caveat until item 3 is also resolved

**Open design questions.**
- Should `toth-gui` build `FROM toth-dfir` (bundled forensic tools available
  in the same GUI session) or stay minimal and be treated as a pure display
  sidecar that mounts the same `/cases` and `/opt/toth/output` volumes? The
  former is more useful but doubles the image's blast radius; the latter is
  more in line with the project's lean-image philosophy so far.
- VNC/noVNC authentication: a password baked into the image is unacceptable;
  a generated-per-run password via env var is workable but needs a place to
  live (ties into the credential-storage question in item 2).
- Should the wrapper auto-launch a browser tab, or only print the URL? Many
  analysts run Toth over SSH on a remote box, where auto-launch is wrong.
  Recommend: print the URL, never auto-launch.
- Loopback-only binding by default is the safe choice, but some team setups
  want LAN-reachable noVNC (shared analysis VM). If that's ever supported it
  should be an explicit opt-in flag, not a config toggle buried in `.env`.

**Risk/effort.** Medium-high. This introduces an entirely new runtime layer
(X11 + VNC + websocket bridge) that nothing in the codebase does today, and
it's the item most likely to bloat image size and slow down `toth update`.
The security surface is real: an open VNC/websocket port is a genuine target,
especially on a shared analyst workstation. Rough estimate: 3-5 days for an
MVP (Xvfb + WM + noVNC + Wireshark GUI only), +2-3 days to fold in Autopsy
once item 3 confirms it's worth doing.

---

## 2. Threat intel platform integrations (MISP, OpenCTI, TheHive)

**Problem.** `misp-cli`/PyMISP, `opencti-client`, and `thehive-cli` are
clients for platforms an analyst's org already runs remotely — they need an
API URL and an API key, and Toth has no case- or workspace-scoped
configuration mechanism today to hold that kind of secret.

**Recommended approach.** These are lightweight pip/CLI installs, not a new
runtime layer — add them to `images/dfir/Dockerfile` rather than inventing a
new profile. `dfir` is already the default profile
(`config.DEFAULT_PROFILE = "dfir"`), which makes credential and network
handling here the highest-stakes version of this problem: whatever is decided
here becomes the default analyst experience, not an opt-in extra.

Config should not be baked into the image. Reuse the pattern already in
`wrapper/utils/config.py` (`_load_dotenv` reading `.env` at the repo root) by
extending it with threat-intel keys (`MISP_URL`, `MISP_KEY`, `OPENCTI_URL`,
`OPENCTI_TOKEN`, `THEHIVE_URL`, `THEHIVE_APIKEY`), passed into the container
via `docker-compose.yml` `environment:` entries sourced from the host
`.env`/shell environment — never committed, never baked into the image layer.

**Files/dirs to touch.**
- `images/dfir/Dockerfile` — `pip3 install pymisp thehive4py ...`,
  `opencti-client`/`pycti`, plus smoke checks matching the existing pattern
  (`command -v ...` / `python3 -c "import pymisp"`)
- `docker-compose.yml` — `environment:` passthrough for the TI env vars on
  `toth-dfir`, and the network-mode decision below
- `wrapper/utils/config.py` — surface the new `.env` keys if the wrapper
  needs to validate/print them (e.g. a future `toth doctor`-style check)
- `docs/usage.md` — a "Threat intel examples" section
- `docs/tools-list.md`

**Open design questions.**
- **Credential storage is the real blocker, not the pip installs.** A single
  global `.env`-based credential works for a solo analyst with one org's
  MISP instance, but breaks down the moment there's more than one case or
  more than one org (rotating API keys per engagement, multiple TheHive
  instances for different clients). If Phase 2 scoping introduces case- or
  workspace-scoped configuration, threat-intel credentials should live there
  instead of a global `.env` — **flag this as a possible Phase 2 dependency**
  and avoid building a second, competing credential-storage mechanism here.
  If Phase 2 case management is not imminent, ship the global-`.env` version
  as good-enough for v1 and revisit.
- Same `network_mode: none` conflict as items 1 and 5: `dfir` today has no
  network access at all. Should the default `dfir` profile silently gain
  bridge networking (weakening the default profile's security posture for
  every analyst, whether or not they use threat intel), or should TI network
  access be gated behind an explicit opt-in (a `docker-compose.override.yml`
  activated only when TI env vars are present, or a separate `dfir-ti`
  profile variant)? Recommend **not** changing `dfir`'s default network
  posture silently — treat this as an explicit opt-in.
- Do all three integrations ship together, or incrementally as each is
  validated against a real instance? PyMISP is the most mature/stable of the
  three; OpenCTI and TheHive client libraries churn faster.

**Risk/effort.** Low-medium technical effort — the installs themselves are a
half-day of Dockerfile work. The actual cost is the credential-storage and
network-policy design conversation, which is a prerequisite, not an
implementation detail.

---

## 3. Volatility 2 and Autopsy

**Problem.** Both are listed "Not installed yet" in `docs/tools-list.md`.
Volatility 2 is Python 2-based and effectively legacy; Autopsy is GUI-heavy
and depends on item 1.

**Volatility 2 recommendation: drop it.** Vol3 is already installed and
covers modern Windows/Linux/Mac memory analysis. Vol2 exists almost
exclusively for legacy XP/Server 2003-era profiles that Vol3 doesn't support,
which is a shrinking and largely EOL'd case population. Adding it means
introducing Python 2 into an image that has no Python 2 anywhere today
(`images/base/Dockerfile` only installs `python3*`), plus its own legacy
dependency tree — pure maintenance liability for a use case the project
hasn't validated demand for. This is exactly the kind of speculative build
this project explicitly wants to avoid. Recommendation: **do not build a
dedicated Vol2 install path.** Document that legacy-profile memory analysis
is out of scope, and revisit only if a specific, real case need surfaces.

**Autopsy recommendation: defer, don't build standalone.** Autopsy's core
workflow is a Java Swing GUI application — it has no meaningful
CLI-first mode for the primary use case, so building it before item 1's GUI
profile exists would mean either shipping a tool nobody can use headlessly or
building a one-off GUI mechanism just for Autopsy that gets thrown away when
item 1 lands properly. Fold Autopsy into the `images/gui/` roadmap instead of
treating it as separate work.

**A smaller, independent win worth pulling forward:** Sleuth Kit (`tsk`)
command-line tools (`fls`, `icat`, `mmls`, `mmcat`, etc.) back a large part of
what Autopsy does, are pure CLI, have no GUI dependency, and would slot
directly into `images/dfir/Dockerfile` next to the existing forensic tools
with no policy questions attached. Recommend evaluating this as a fast-follow
regardless of what happens with full Autopsy.

**Files/dirs to touch (if the Sleuth Kit slice is pursued).**
- `images/dfir/Dockerfile` — `apt-get install sleuthkit`, smoke checks
- `docs/tools-list.md`, `docs/usage.md`

**Open design questions.**
- Is there an actual case backlog needing Volatility 2 / legacy Windows
  memory analysis? Worth a quick check with real users before ruling it out
  permanently, but the working assumption here is no.
- Does Autopsy's ingest pipeline have a usable non-GUI automation mode
  (batch ingest + report generation) that would justify installing it ahead
  of the full GUI profile? Worth a short spike before committing either way,
  but treat this as secondary to the Sleuth Kit CLI win.

**Risk/effort.** Volatility 2: low effort, but recommendation is to not
spend it. Autopsy (full GUI): high effort, inherits all of item 1's risk.
Sleuth Kit CLI: low effort, low risk, no dependency on any other Phase 3 item
— good fast-track candidate.

---

## 4. Zimmerman tools

**Problem.** Eric Zimmerman's suite (EvtxECmd, RECmd, MFTECmd, PECmd, LECmd,
JLECmd, SBECmd, AmcacheParser, etc.) is the de facto standard for Windows
artifact parsing, but it's .NET-based and nothing in any current image pulls
in a .NET runtime.

**Recommended approach — install selectively, not the whole suite.** The
"Chainsaw/Hayabusa already cover this" framing is only true for the EVTX
slice: EvtxECmd overlaps meaningfully with Chainsaw/Hayabusa's EVTX
hunting/timeline capability, so it's a reasonable one to skip. The rest of
the suite (MFTECmd for `$MFT`, PECmd for Prefetch, LECmd/JLECmd for LNK
files and jumplists, SBECmd for shellbags, AmcacheParser) parses artifacts
nothing currently in `images/dfir/Dockerfile` touches at all — RegRipper
covers some registry ground, so RECmd's value depends on how much richer its
output is versus RegRipper's, worth a direct comparison before deciding.

For the runtime: Eric Zimmerman now publishes self-contained `linux-x64`
release builds for most tools, meaning no system-wide `dotnet-runtime` apt
package is needed — just curl the release archive, unpack, symlink into
`/usr/local/bin`, following the exact same pattern already used for Chainsaw
and Hayabusa in `images/dfir/Dockerfile`. This keeps the image lean and
avoids introducing .NET as a first-class runtime dependency project-wide.

**Files/dirs to touch.**
- `images/dfir/Dockerfile` — per-tool `curl`/`unzip` blocks matching the
  existing Chainsaw/Hayabusa pattern, `ARG` version pins per tool, smoke
  checks
- `docs/tools-list.md`, `docs/usage.md`

**Open design questions.**
- Full suite vs. selective subset — recommend selective (skip EvtxECmd,
  evaluate RECmd against RegRipper's existing coverage before deciding).
- **arm64 availability.** Zimmerman tools have historically shipped `win-x64`
  and `linux-x64` builds; arm64 Linux builds are not guaranteed to exist.
  README commits to "Images build natively on `amd64` and `arm64`" as a
  project invariant, and `diec` (Detect It Easy) is already an amd64-only
  carve-out documented in `known-limitations.md`. If Zimmerman tools have no
  arm64 build, this becomes a second documented arch carve-out, gated by
  `TARGETARCH` in the Dockerfile the same way Chainsaw/Hayabusa already are.
- License/redistribution terms for automated download in a public build —
  Zimmerman tools are free to use but worth a quick check that automated
  `curl` in a Dockerfile doesn't violate distribution terms the way vendored
  binaries sometimes do.

**Risk/effort.** Low-medium. Mechanically this is the most template-following
item in this roadmap — it's the same shape as work already done for
Chainsaw/Hayabusa. The only real risk is the arm64 gap, which would need to
be confirmed early since it affects the recommendation, not just the
implementation.

---

## 5. Cloud forensics profile

**Problem.** `aws-cli`, `azure-cli`, `pwsh`, `trailscraper`, `stormspotter`,
`o365-investigator` — querying live cloud provider APIs is a fundamentally
different workflow from Toth's current offline-evidence-analysis model, and
needs real outbound network access.

**Recommended approach.** Agree with the framing in the task: this should be
a brand-new `images/cloud/` profile, not bolted onto `dfir`. Build `FROM
toth-base` (not `dfir`/`malware`/`network` — it needs none of their
forensic-parsing or packet-capture tooling, just a shell and case/output
mount points). New `docker-compose.yml` service `toth-cloud` with
`network_mode: bridge` and no special capabilities (`NET_ADMIN`/`NET_RAW` are
for packet-level access, which this profile doesn't need — plain outbound
HTTPS is enough). Because this is a new, explicitly opt-in profile rather
than a change to an existing default, the network policy relaxation here is
lower-stakes than the same question for `dfir` in item 2: nobody gets bridge
networking who didn't choose the `cloud` profile.

Credentials: don't invent a Toth-specific secret store. `aws-cli` and
`azure-cli` already have established local credential conventions
(`~/.aws/credentials`, `~/.azure/`) that integrate with SSO/MFA/temporary STS
tokens most orgs already use — mount the host's cloud config directories as
read-only volumes rather than managing API keys inside Toth. This sidesteps
the credential-storage question raised in item 2, though the two should
probably be designed together rather than independently, since they're the
same category of problem (where do secrets that talk to the outside world
live).

`pwsh` is a meaningfully large addition (the PowerShell runtime itself, plus
whichever Az/Exchange Online modules specific tools need) — worth confirming
which of the six named tools actually require it versus have Python/CLI
equivalents before installing the full runtime by default.

**Files/dirs to touch.**
- `images/cloud/Dockerfile`, `images/cloud/build.sh` (new)
- `docker-compose.yml` — new `toth-cloud` service, volume mounts for host
  cloud config dirs
- `wrapper/utils/config.py` — register `cloud` in `PROFILES`
- `Makefile` — `build-cloud` target
- `docs/usage.md`, `docs/tools-list.md`, `docs/architecture.md`, README.md
  profile table

**Open design questions.**
- Network policy: is `bridge` with no extra capabilities an acceptable
  default for this profile, given it's opt-in by construction (unlike
  `dfir`, this is not `DEFAULT_PROFILE`)? Recommend yes, since it doesn't
  touch the default analyst experience — but this should still be recorded
  as part of the single project-wide network-policy decision below, not
  decided in isolation.
- Credential mounting strategy (read-only host mounts vs. env vars vs. a
  future shared Toth secrets approach) — tie this to the same conversation
  as item 2's credential question rather than solving it twice.
- Which tools actually need `pwsh` vs. can be done with `aws-cli`/`azure-cli`
  native tooling alone.
- **Tool maintenance risk.** `trailscraper`, `stormspotter`, and
  `o365-investigator` are smaller community projects than `aws-cli`/
  `azure-cli`; verify each is still maintained and functional before locking
  it into the Dockerfile. If one is abandoned, drop it from the initial
  profile rather than shipping a broken/stale tool — `aws-cli`/`azure-cli`
  alone still deliver most of the value.

**Risk/effort.** Medium. The profile scaffolding itself is low-risk and
mechanically well-understood (it mirrors the existing four profiles almost
exactly). The risk is concentrated in the network-policy decision and in
verifying the three niche tools are worth packaging at all.

---

## Cross-cutting decision: the `network_mode: none` conflict

Items 1, 2, and 5 all need real network access, and this is one decision, not
three. Today's invariant is effectively "no profile talks to the network
unless it's doing raw packet capture" (the `network` profile's justification
for `bridge` + `NET_ADMIN`/`NET_RAW`). Phase 3 introduces a second, different
reason a profile might need network access: talking to an external service
over ordinary HTTPS/websocket (noVNC's browser bridge, TI platform APIs,
cloud provider APIs). That's a materially different risk profile than raw
packet capture, and conflating the two would blur a security property users
currently get "for free" — most Toth containers cannot exfiltrate case data
even if a tool inside them were compromised.

**Recommendation:** make this an explicit, written policy rather than
deciding it Dockerfile-by-Dockerfile:
- `network_mode: none` remains the default for every profile, including any
  future ones.
- A profile may declare network access only when its core function requires
  talking to a non-packet-capture external endpoint, and each such exception
  must be documented in `docs/known-limitations.md` and the profile's own
  doc section — not silently introduced.
- The default profile (`dfir`) should not have its network posture changed
  by an incidental feature (threat-intel integration) — network access
  should be opt-in there (override file or a distinct profile variant), even
  though it's acceptable as an unconditional default in brand-new,
  explicitly-opt-in profiles (`gui`, `cloud`).

Once decided, record it in `docs/architecture.md`'s "Runtime model" section
so it's a citable project policy, not something re-litigated per feature.

---

## Recommended sequencing

1. **Decide and document the network policy above.** Nothing here needs new
   code to resolve, and it blocks clean design of items 1, 2, and 5.
2. **Zimmerman tools (selective subset)** — no network-policy or GUI
   dependency, mechanically follows the existing Chainsaw/Hayabusa pattern,
   confirm arm64 availability early.
3. **Sleuth Kit CLI** (pulled out of the Autopsy discussion in item 3) — same
   reasoning: cheap, independent, no blockers.
4. **Threat intel CLI installs (item 2)** — once the network policy is
   settled, this is mostly pip installs plus docs; ship with a global `.env`
   credential model for v1 rather than waiting on Phase 2 case management,
   and revisit storage once/if Phase 2 lands.
5. **Cloud forensics profile (item 5)** — well-understood profile scaffolding,
   but gate on the maintenance check for `trailscraper`/`stormspotter`/
   `o365-investigator` before locking in the toolset.
6. **noVNC GUI profile (item 1)**, with Autopsy riding on top of it rather
   than shipped separately. Largest effort and most novel to the codebase —
   sequence last so the network-policy and credential-storage groundwork
   from earlier items is already in place.

## Deprioritize or drop

- **Volatility 2** — drop. Vol3 already covers the realistic case backlog;
  Python 2 is a maintenance and security liability for a shrinking, largely
  EOL'd use case. Revisit only if a specific case need surfaces.
- **EvtxECmd** (from the Zimmerman suite) — skip. Redundant with
  Chainsaw/Hayabusa's existing EVTX-hunting coverage.
- **Full Autopsy as standalone work** — don't build it ahead of item 1; fold
  it into the GUI profile roadmap so it isn't duplicated effort, and
  reassess afterward whether the GUI cost is worth it versus the CLI/Sleuth
  Kit slice already covering most triage needs.
- **Any of `trailscraper` / `stormspotter` / `o365-investigator`** found to
  be unmaintained during item 5's investigation — drop from the initial
  cloud profile and ship with `aws-cli`/`azure-cli`/`pwsh` only.
