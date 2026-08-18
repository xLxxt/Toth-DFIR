# Contributing

Toth is a Blue Team and DFIR Docker distribution. Contributions should keep the
project practical, reproducible, and easy to operate during investigations.

## Contribution types

- Docker image fixes
- New DFIR, malware, or network tools
- Wrapper CLI improvements
- Documentation
- GitHub Actions and CI improvements

## Local checks

Before opening a pull request, run the checks that match your change.

```bash
docker compose config
make build-base
docker run --rm toth-base:0.2.0 bash /opt/toth/scripts/check_tools.sh
```

For profile changes, also build and check the profile image.

```bash
make build-dfir
make build-malware
make build-network
```

## Tool additions

When adding a tool, include:

- why it belongs in Toth
- which profile should contain it
- installation source and license
- architecture limitations
- a validation command such as `tool --version`

Prefer pinned versions or clear build arguments when possible.
