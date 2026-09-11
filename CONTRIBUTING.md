# Contributing

## README conventions

Public README required H2s (exact strings; enforced by `./scripts/ci-check.sh`):

```text
## What this does
## Who this is for
## Quick start
## Check it works
## Uninstall
## Limits & safety
## License
```

Put the beginner path (install / verify / uninstall) above limits. Do not put private monorepo paths or the token `SSOT` in README prose — say “release source” instead.

Also enforced by `./scripts/ci-check.sh`:

- `.github/FUNDING.yml` with `ko_fi: alkitect`
- README Ko-fi GitHub button (`githubbutton_sm.svg` → tip-panel `https://ko-fi.com/alkitect/?hidefeed=true&widget=true&embed=true`) in `## Support my work` (Support section after Check it works / before Uninstall)
- README soft tip containing `ko-fi.com/alkitect` (after License)
- README must not link Patreon or Buy Me a Coffee
- No `extension.pem` / `manifest-key.txt` / `private/` in the tree
- Manifest `key` + `extension-id.txt` are **public** (ID pin); never commit the private signing key

Gate: `./scripts/ci-check.sh`.

## Versioning

First public tag is recorded in `docs/PUBLISH.md` (`First public tag:`). This product tags **`v` + MV3 `browser-extension/manifest.json` `version`**. Never copy another alkitect repo’s tag (including `brave-aero-peek`). Use `RC-BEFORE-1.0` in PUBLISH only for an intentional 0.9.x RC. After the first tag, bump MV3 version then CHANGELOG, then tag. Shell `metadata.json` `version` is a separate GNOME integer. Maintainers: `./scripts/ci-check.sh` must pass before tag.

## Bug reports

Please include:

- Distro / GNOME Shell version / Wayland vs X11
- Brave `.deb` version (not Flatpak/Snap) — until other browsers ship
- `browser-tabs-host cli status` (redact nothing sensitive beyond titles if pasting lists)
- Whether Shell extension is enabled

## Sync policy (dual maintenance)

- **Release source (after publish):** this GitHub repository (multi-browser daily driver).
- **Brave-only lane:** [alkitect/brave-aero-peek](https://github.com/alkitect/brave-aero-peek) — maintenance only; does not receive Wave Chromium+ commits.
- **Never** sync private Cursor plans, machine journals, or `extension.pem` / `manifest-key.txt` into this repo.

## Behavior changes

If you change D-Bus verbs or hover policy, update [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), [ADR-001](docs/architecture/ADR-001-ipc-and-dock-intercept.md), and [docs/SECURITY.md](docs/SECURITY.md).

```bash
find scripts -type f -name '*.sh' -print0 | xargs -0 -r bash -n
./scripts/ci-check.sh
```
