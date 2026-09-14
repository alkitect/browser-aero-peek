# Browser support

Release-source matrix for **browser-aero-peek**. Runtime enablement is controlled by `config/browsers.json` (`enabled: true|false`). This document is the human-facing In/Out view.

## At this tip (`v0.9.1`)

| Browser | Packaging | Status | Notes |
|---------|-----------|--------|--------|
| **Brave** | `.deb` | **In** | Shared `browser-extension/`; NM under Brave profile |
| **Brave** | Snap | **In** (registry) | `brave-snap`; staged `mv3-brave-snap/`; snap NM + home sock; live HV only if Snap installed |
| **Brave** | Flatpak `com.brave.Browser` | **In** (registry) | `brave-flatpak`; staged MV3; `flatpak-spawn --host`; override skip if app missing |
| **Chrome** | `.deb` | **In** | Shared `browser-extension/` |
| **Chrome** | Flatpak `com.google.Chrome` | **In** (registry) | `chrome-flatpak`; same Flatpak pattern as Opera |
| **Opera** | `.deb` | **In** | Shared `browser-extension/` |
| **Opera** | Flatpak `com.opera.Opera` | **In** | `opera-flatpak`; staged MV3; aliases under Flatpak google-chrome NM path |
| **Opera** | Snap | **In** (registry) | `opera-snap`; Shell disambiguates shared WM `Opera` |
| **Vivaldi** | `.deb` | **In** | Staged `mv3-vivaldi/` (forced id — reduced UA) |
| **Vivaldi** | Snap / Flatpak | **In** (registry) | `vivaldi-snap` / `vivaldi-flatpak` |
| **Chromium** | Snap | **In** | `chromium`; staged MV3; `~/bin/browser-tabs-nm-snap` |
| **Chromium** | Flatpak `org.chromium.Chromium` | **In** (registry) | `chromium-flatpak` |
| **Edge** | `.deb` | **In** (registry) | `edge`; staged `mv3-edge/`; live HV if Edge installed |
| **Edge** | Flatpak `com.microsoft.Edge` | **In** (registry) | `edge-flatpak` |
| **Firefox** | Snap | **In** | Durable AMO-signed `.xpi` (`~/alkitect-browser-tabs/browser-tab-dock-signed.xpi`); NM portal `~/.mozilla/…`. Temporary forced-id `.xpi` remains as fallback. |
| **Firefox** | Mozilla `.deb` | **In** | Same durable `.xpi`; Shell matcher `firefox-deb` → peer `firefox` |
| **Firefox** | Flatpak `org.mozilla.firefox` | **In** | Same durable `.xpi`; Shell matcher `firefox-flatpak` → peer `firefox` (metadata **21**) |
| **Tor Browser** | — | **Out** | [TOR-FEASIBILITY.md](TOR-FEASIBILITY.md) **FAIL** — stay `enabled: false` |
| GNOME Web | — | **Out** | Not planned |

## Enabled vs disabled

- **Enabled:** install writes Native Messaging JSON under that browser’s profile-relative `nm_path` (and aliases) with schema-correct allowlists (Chromium `allowed_origins` or Mozilla `allowed_extensions`). `nm_base` is `xdg_config` or `home` (Flatpak `.var/...` / Snap `snap/...`).
- **Disabled:** install **must not** create NM JSON (Tor). Uninstall still removes orphans.
- **Wrong-lane:** do not alternate with deprecated `brave-aero-peek`.

## Load paths

- **Native** Brave / Chrome / Opera deb: Load unpacked → `browser-extension/`.
- **Forced-id Chromium lanes** (Snap, Flatpak, Vivaldi, Edge): Load unpacked → `~/.local/share/alkitect-browser-tabs/mv3-<id>/`.
- **Firefox (durable):** `about:addons` → Install Add-on From File → `~/alkitect-browser-tabs/browser-tab-dock-signed.xpi` (after `install-to-local` or GitHub Release asset). See [AMO-FIREFOX.md](AMO-FIREFOX.md).
- **Firefox Temporary fallback:** `~/snap/firefox/common/alkitect-mv3-firefox.xpi` / `mv3-firefox-*.xpi` — unloads on quit.
- Flatpak / Snap: remove ephemeral portal loads (`/run/flatpak/doc/…`, `/run/user/*/doc/…`) after logout.

## Packaging notes

Shell matchers put Flatpak/Snap before native when WM classes overlap (Opera / Brave / Vivaldi). Sibling `NoExtension` retry walks the packaging family. **One Wayland logout/in** after Shell metadata bumps covers all enabled lanes.

## Follow-ups (not this tip’s tag blockers)

| Item | Notes |
|------|--------|
| Firefox durable install | Stage `./scripts/stage-firefox-amo.sh` → AMO **On your own** sign ([AMO-FIREFOX.md](AMO-FIREFOX.md)); FF140+; same gecko id |
| Firefox `.deb` / Flatpak | `FIREFOX-PKG-EXPAND` after Snap lane |
| Edge / packaging live HV | Only when that package is installed; registry already In |

## See also

- [SECURITY.md](SECURITY.md) — concurrent-browser trust plane + Flatpak/Snap spawn boundaries
- [ARCHITECTURE.md](ARCHITECTURE.md) — multi-browser C4
- [TOR-FEASIBILITY.md](TOR-FEASIBILITY.md) — Tor FAIL evidence
