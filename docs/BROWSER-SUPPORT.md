# Browser support

Release-source matrix for **browser-aero-peek**. Runtime enablement is controlled by `config/browsers.json` (`enabled: true|false`). This document is the human-facing In/Out view.

## At this tag

| Browser | Status | Notes |
|---------|--------|--------|
| **Brave** (`.deb` / native) | **In** | `enabled: true` |
| **Google Chrome** (`.deb` / native) | **In** | `enabled: true`; `.desktop` `google-chrome.desktop` / `google-chrome`; WM `google-chrome` / `Google-chrome`; NM under `google-chrome/NativeMessagingHosts` |
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

## Chrome notes

- Same unpacked MV3 + same extension id as Brave (shared `allowed_origins`). Isolation = registry + per-browser NM dir + host routing by `browserId`.
- Load the add-on in Chrome via `chrome://extensions` → Load unpacked → `browser-extension/`. Quit/relaunch Chrome after install.
- Hover the **Chrome** dock icon (one window, ≥2 tabs) for Chrome tabs only; Brave hover stays Brave-only.

## Packaging

Native `.deb` / distro packages only for In browsers. Flatpak and Snap are Out until a dedicated plan says otherwise.

## See also

- [SECURITY.md](SECURITY.md) — concurrent-browser trust plane
- [ARCHITECTURE.md](ARCHITECTURE.md) — multi-browser C4
- Parent roadmap lives in the maintainer’s umbrella plan (not shipped here)
