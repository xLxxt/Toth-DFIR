# GHCR Publication

Toth images are published to GitHub Container Registry under:

```text
ghcr.io/xlxxt/toth-base
ghcr.io/xlxxt/toth-dfir
ghcr.io/xlxxt/toth-malware
ghcr.io/xlxxt/toth-network
```

The wrapper pulls these images with `toth update` and retags them locally as
`toth-*:0.1.0` so Docker Compose can keep using short local image names.

## Current image tag

The current public image tag is:

```text
0.1.0
```

The wrapper itself is currently `0.2.0-dev`, but image tags stay on `0.1.0`
until the next image release is ready.

The first GHCR publication targets `linux/amd64` only. `linux/arm64` is planned
for a later hardening pass because some DFIR dependencies compile from source
and are slow or fragile under QEMU emulation in GitHub Actions.

## Publish manually

From GitHub:

1. Open `Actions`.
2. Select `publish-image`.
3. Click `Run workflow`.
4. Use `image_tag=0.1.0`.
5. Keep `push_latest=true` for the public default tag.

This publishes:

```text
ghcr.io/xlxxt/toth-base:0.1.0
ghcr.io/xlxxt/toth-dfir:0.1.0
ghcr.io/xlxxt/toth-malware:0.1.0
ghcr.io/xlxxt/toth-network:0.1.0
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
git tag -a v0.1.0 -m "Toth images v0.1.0"
git push origin v0.1.0
```

This publishes image tag `0.1.0` and `latest`.

## Verify pulls

After the workflow succeeds, verify direct Docker pulls from an amd64 host:

```bash
docker pull ghcr.io/xlxxt/toth-base:0.1.0
docker pull ghcr.io/xlxxt/toth-dfir:0.1.0
docker pull ghcr.io/xlxxt/toth-malware:0.1.0
docker pull ghcr.io/xlxxt/toth-network:0.1.0
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
