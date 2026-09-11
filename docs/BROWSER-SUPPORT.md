# Browser support

Release-source matrix for **browser-aero-peek**. Runtime enablement is controlled by `config/browsers.json` (`enabled: true|false`). This document is the human-facing In/Out view.

## At this tag

| Browser | Status | Notes |
|---------|--------|--------|
| **Brave** (`.deb` / native) | **In** | `enabled: true` |
| **Google Chrome** (`.deb` / native) | **In** | `enabled: true`; `.desktop` `google-chrome.desktop` / `google-chrome`; WM `google-chrome` / `Google-chrome`; NM under `google-chrome/NativeMessagingHosts` |
| **Opera** (`.deb` / native) | **In** | Registry id `opera`; `.desktop` `opera.desktop` / `opera` / `opera-browser.desktop`; WM `opera` / `Opera`; NM under `opera/NativeMessagingHosts` |
| **Opera** (Flatpak `com.opera.Opera`) | **In** | Registry id `opera-flatpak` (`family: opera`); `.desktop` `com.opera.Opera.desktop`; **no WM class match** (avoids clash with native); NM under `~/.var/app/com.opera.Opera/config/opera/NativeMessagingHosts` (+ alias `…/google-chrome/NativeMessagingHosts`) via `browser-tabs-nm-flatpak` → `flatpak-spawn --host`; install stages MV3 at `~/.local/share/alkitect-browser-tabs/mv3-opera-flatpak/` with forced `browserId`; overrides: `~/.local/bin:ro`, share dir `:ro`, talk `org.freedesktop.Flatpak` |
| Vivaldi | Planned | Disabled stub |
| Chromium | Planned | Disabled stub |
| Edge | Planned | Disabled stub |
| Firefox | Planned | `nm_schema: mozilla` reserved; packaging gate before NM |
| Tor Browser | Feasibility gate | Spike then PASS/FAIL; fail-closed on FAIL |
| GNOME Web (Epiphany) | **Out** | Not planned |
| Snap / Opera GX / other Flatpaks | **Out** | Out of scope unless a later plan matches their profile paths |

## Enabled vs disabled

- **Enabled:** install writes Native Messaging JSON under that browser’s profile-relative `nm_path` (and `nm_path_aliases` when set) with exactly one `allowed_origins` (shared extension id). `nm_base` is `xdg_config` (default) or `home` (Flatpak sandbox under `~/.var/...`).
- **Disabled:** install **must not** create NM JSON under that `nm_path` (even briefly). Uninstall still removes orphans if any exist.
- **Wrong-lane:** installing the Brave-only maintenance product (`brave-aero-peek`) overwrites the same host UUID / unit / NM basename — do not alternate. Rollback: reinstall from the lane you want.

## Chrome / Opera notes

- Same unpacked MV3 + same extension id as Brave (shared `allowed_origins`). Isolation = registry + per-browser NM dir + host routing by `browserId`.
- **Native** Brave / Chrome / Opera: Load unpacked → `browser-extension/`. Quit/relaunch after install.
- **Opera Flatpak:** Load unpacked → staged `~/.local/share/alkitect-browser-tabs/mv3-opera-flatpak/` (same id; `forced-browser-id.js` so hello binds as `opera-flatpak`). After logout/reboot, **remove** any old load that still points at `/run/flatpak/doc/…` and load the staged path again (install grants that share dir `:ro`). NM uses `flatpak-spawn --host` (talk-name + `~/.local/bin:ro`).
- Hover that browser’s dock icon (one window, ≥2 tabs) for **that** browser’s tabs only. Flatpak dock matching uses desktop id `com.opera.Opera.desktop` first; both packages share `StartupWMClass=Opera`, so Shell 14 also disambiguates via `Exec` and retries the sibling peer on `NoExtension`.

## Packaging

Native `.deb` / distro packages for Brave, Chrome, and Opera. **Opera Flatpak** is the first packaging-variant pilot (`opera-flatpak`). Snap and other Flatpak browsers stay Out until a dedicated plan says otherwise.

## See also

- [SECURITY.md](SECURITY.md) — concurrent-browser trust plane + Flatpak spawn boundary
- [ARCHITECTURE.md](ARCHITECTURE.md) — multi-browser C4
- Parent roadmap lives in the maintainer’s umbrella plan (not shipped here)
