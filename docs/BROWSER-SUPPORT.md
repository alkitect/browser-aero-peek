# Browser support

Release-source matrix for **browser-aero-peek**. Runtime enablement is controlled by `config/browsers.json` (`enabled: true|false`). This document is the human-facing In/Out view.

## At this tag

| Browser | Status | Notes |
|---------|--------|--------|
| **Brave** (`.deb` / native) | **In** | Only browser with `enabled: true` after shared-prep |
| Chrome | Planned | Disabled stub in registry; Wave Chromium child plan |
| Opera | Planned | Disabled stub |
| Vivaldi | Planned | Disabled stub |
| Chromium | Planned | Disabled stub |
| Edge | Planned | Disabled stub |
| Firefox | Planned | `nm_schema: mozilla` reserved; packaging gate before NM |
| Tor Browser | Feasibility gate | Spike then PASS/FAIL; fail-closed on FAIL |
| GNOME Web (Epiphany) | **Out** | Not planned |
| Flatpak / Snap browsers | **Out** | Out of scope for now |

## Enabled vs disabled

- **Enabled:** install writes Native Messaging JSON under that browser’s profile-relative `nm_path` with exactly one `allowed_origins` (shared extension id).
- **Disabled:** install **must not** create NM JSON under that `nm_path` (even briefly). Uninstall still removes orphans if any exist.
- **Wrong-lane:** installing the Brave-only maintenance product (`brave-aero-peek`) overwrites the same host UUID / unit / NM basename — do not alternate. Rollback: reinstall from the lane you want.

## Packaging

Native `.deb` / distro packages only for In browsers. Flatpak and Snap are Out until a dedicated plan says otherwise.

## See also

- [SECURITY.md](SECURITY.md) — concurrent-browser trust plane
- [ARCHITECTURE.md](ARCHITECTURE.md) — multi-browser C4
- Parent roadmap lives in the maintainer’s umbrella plan (not shipped here)
