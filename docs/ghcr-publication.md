# GHCR Publication

Toth images are published to GitHub Container Registry under:

```text
ghcr.io/xlxxt/toth-base
ghcr.io/xlxxt/toth-dfir
ghcr.io/xlxxt/toth-malware
ghcr.io/xlxxt/toth-network
```

The wrapper pulls these images with `toth update` and retags them locally as
`toth-*:0.2.0` so Docker Compose can keep using short local image names.

## Current image tag

The current public image tag is:

```text
0.2.0
```

The wrapper version and the image tag are kept in lockstep at each release;
both are currently `0.2.0`.

The first GHCR publication targets `linux/amd64` only. `linux/arm64` is planned
for a later hardening pass because some DFIR dependencies compile from source
and are slow or fragile under QEMU emulation in GitHub Actions.

### arm64 experiment (not part of the release process)

`.github/workflows/arm64-experiment.yml` is a separate, `workflow_dispatch`-only
workflow that measures how slow the arm64 concern above actually is, instead of
leaving it as an assumption. It never runs automatically and does not modify
`publish-image.yml` or `build-image.yml`. To trigger it: open `Actions`, select
`arm64-experiment`, click `Run workflow`. It runs two independent jobs and does
not push any images:

- `qemu-cross-build`: builds the base and DFIR images for `linux/arm64` under
  QEMU emulation on a normal `ubuntu-latest` runner (the same approach
  `publish-image.yml` would use if `linux/arm64` were added to `PLATFORMS`) and
  reports wall-clock timing for each stage, including the three from-source
  builds (`bulk_extractor`, `libbfio`, `libpff`) that are the actual risk.
- `native-arm64-runner`: attempts the same builds on GitHub's hosted
  `ubuntu-24.04-arm` runner, with no QEMU involved, as a native-arm64 timing
  baseline. If that runner type isn't available for this repository/plan, the
  job simply fails to schedule -- which answers the "is a native arm64 runner
  usable here" question on its own.

Trigger it manually, review the timing in the job summaries (and whether
`native-arm64-runner` scheduled at all), and use those real numbers -- not this
paragraph -- to decide whether/how to add `linux/arm64` to the actual publish
path in `publish-image.yml`.

## Publish manually

From GitHub:

1. Open `Actions`.
2. Select `publish-image`.
3. Click `Run workflow`.
4. Use `image_tag=0.2.0`.
5. Keep `push_latest=true` for the public default tag.

This publishes:

```text
ghcr.io/xlxxt/toth-base:0.2.0
ghcr.io/xlxxt/toth-dfir:0.2.0
ghcr.io/xlxxt/toth-malware:0.2.0
ghcr.io/xlxxt/toth-network:0.2.0
```

and, if enabled:

```text
ghcr.io/xlxxt/toth-base:latest
ghcr.io/xlxxt/toth-dfir:latest
ghcr.io/xlxxt/toth-malware:latest
ghcr.io/xlxxt/toth-network:latest
```

## Publish with a Git tag

A pushed Git tag starting with `v` also triggers publication. The Docker image
tag is derived from the Git tag without the leading `v`:

```bash
git tag -a v0.2.0 -m "Toth images v0.2.0"
git push origin v0.2.0
```

This publishes image tag `0.2.0` and `latest`.

## Verify pulls

After the workflow succeeds, verify direct Docker pulls from an amd64 host:

```bash
docker pull ghcr.io/xlxxt/toth-base:0.2.0
docker pull ghcr.io/xlxxt/toth-dfir:0.2.0
docker pull ghcr.io/xlxxt/toth-malware:0.2.0
docker pull ghcr.io/xlxxt/toth-network:0.2.0
```

Then verify the wrapper path:

```bash
toth update dfir
toth list
toth shell dfir
```

If `docker pull` fails with a permissions error, open the package settings on
GitHub and make the GHCR package public.

## Development fallback

If the images are not published yet, build locally:

```bash
toth update --build dfir
```
