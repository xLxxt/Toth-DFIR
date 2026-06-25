# Release Checklist

This checklist is the pre-release gate for Toth. It is designed to be run before
publishing a public version, opening a release tag, or announcing a new image
set.

## 1. Repository state

Start from a clean worktree on the release branch:

```bash
git status -sb
git pull --ff-only
```

Verify the user-facing version references are coherent:

```bash
grep -R "0.1.0" README.md docs wrapper images .github/workflows
```

If the release changes the version, update these areas together:

- `wrapper/utils/config.py`
- Docker image tags in build scripts and workflows
- `README.md`
- `docs/usage.md`
- `docs/release-checklist.md`

## 2. Local Docker checks

Validate Docker and Compose first:

```bash
docker version
docker compose version
docker compose config
```

Build all images from a clean local clone:

```bash
make build-all
```

Why: Toth images inherit from `toth-base`. Building all profiles catches broken
base dependencies before they affect DFIR, malware, or network workflows.

## 3. Tool inventory checks

Run the embedded tool checks for every built image:

```bash
docker run --rm toth-base:0.1.0 toth-check
docker run --rm toth-dfir:0.1.0 toth-check
docker run --rm toth-malware:0.1.0 toth-check
docker run --rm toth-network:0.1.0 toth-check
```

Alternatively, from an installed Toth wrapper:

```bash
toth exec base toth-check
toth exec dfir toth-check
toth exec malware toth-check
toth exec network toth-check
```

## 4. Wrapper smoke checks

Run the local command checks:

```bash
bash tests/test_commands.sh
```

Then verify one profile manually:

```bash
toth update --build dfir
toth exec dfir vol3 -h
toth stop dfir
```

## 5. Installation checks

Public repository check:

```bash
git clone --branch dev https://github.com/xLxxt/Toth-DFIR.git /tmp/toth-public-test
```

Private/development repository check:

```bash
git clone git@github.com:xLxxt/Toth-DFIR.git /tmp/toth-private-test
cd /tmp/toth-private-test
TOTH_REPO_URL=git@github.com:xLxxt/Toth-DFIR.git ./install.sh
```

Installer behavior to verify:

- It refuses to run with `sudo`.
- It installs under the normal user, not `/root`.
- It creates `~/.local/bin/toth`.
- It creates the workspace under `~/toth/workspace` by default.
- It adds `~/.local/bin` to Bash or Zsh profile when needed.

## 6. GitHub Actions checks

Before tagging, verify these workflows pass on the release branch or PR:

- `lint`
- `test-tools`
- `build-image` when manually triggered

For image publication, verify `publish-image` on a test tag or manual dispatch
before announcing the release.

## 7. Documentation checks

Review the public entry points:

- `README.md`
- `docs/installation.md`
- `docs/usage.md`
- `docs/tools-list.md`
- `docs/known-limitations.md`

The documentation should clearly state:

- supported profiles: `base`, `dfir`, `malware`, `network`
- default workspace: `~/toth/workspace`
- evidence mount: `/cases`
- output mount: `/opt/toth/output`
- current private/public install behavior
- known architecture limitations

## 8. Tagging

When the release is ready:

```bash
git tag -a v0.1.0 -m "Toth v0.1.0"
git push origin v0.1.0
```

GitHub Actions publishes images to GHCR on `v*` tags.
