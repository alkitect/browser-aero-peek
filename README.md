# Browser Aero peek

Hover your browser on the Ubuntu Dock and pick a **tab** from thumbnails — Aero-style peek for Linux.


## What this does

Ubuntu Dock shows **window** previews when you click a browser. Tabs? Hover does nothing — so you restore the window and hunt the strip.

Pause on the dock icon and you get titles, favicons, and **cached** page thumbnails. Click a card; that tab comes forward.

Thumbnails are screenshots from the last time that tab was visible — Chromium can’t capture background tabs live. Treat them like page content on the local session bus (details under **Limits & safety**).

![Brave Aero peek on Ubuntu Dock — hover the Brave icon to see tab title and thumbnail cards](docs/images/ubuntu-dock-brave-aero-peek.png)

Dock **click** stays stock minimize-or-previews. Peek is hover-only.

**At this release, Brave, Google Chrome, Opera `.deb`, Opera Flatpak, and Vivaldi `.deb` are supported.** Other browsers stay on the roadmap — other Flatpak/Snap products stay Out.

## Who this is for

See **[docs/BROWSER-SUPPORT.md](docs/BROWSER-SUPPORT.md)** for the full In / Planned / Out matrix and enabled/disabled NM semantics.

- **In:** Ubuntu 22.04 + GNOME Shell 42 **Wayland**, Ubuntu Dock, and **Brave**, **Google Chrome**, **Opera** `.deb`, **Opera Flatpak** (`com.opera.Opera`), and/or **Vivaldi** `.deb`
- **In:** You keep several tabs open and want to pick one from the dock without guessing
- **Planned (not enabled yet):** Chromium → Edge; then Firefox; then Tor Browser (feasibility gate)
- **Out:** GNOME Web (Epiphany); Snap browsers; other Flatpak browsers; Opera GX unless matched later; non-GNOME desktops; replacing the global dock click-action

## Quick start

```bash
git clone https://github.com/alkitect/browser-aero-peek.git
cd browser-aero-peek
chmod +x scripts/*.sh
./scripts/install-to-local.sh --enable-automation
```

**What you installed:** three pieces — a user daemon (`alkitect-browser-tabs.service`), native-messaging hooks for **each enabled** browser (Brave + Chrome + Opera deb + Opera Flatpak + Vivaldi), and Shell extension `browser-tab-dock@alkitect`. The host starts with your graphical session. You still load the add-on in each browser and enable the Shell extension yourself. `--enable-automation` enables the **systemd user** unit only (not sudoers / system-wide).

**1. Brave** — open `brave://extensions` → Developer mode → Load unpacked → `browser-extension/`. Confirm the ID matches `browser-extension/extension-id.txt`. Fully quit and relaunch Brave, then run `browser-tabs-host cli list --browser brave`.

**1b. Chrome** — open `chrome://extensions` → Developer mode → Load unpacked → same `browser-extension/` folder (same ID). Fully quit and relaunch Chrome, then `browser-tabs-host cli list --browser chrome`.

**1c. Opera (`.deb`)** — open `opera://extensions` → Developer mode → Load unpacked → same `browser-extension/` folder. Fully quit and relaunch Opera, then `browser-tabs-host cli list --browser opera`.

**1d. Opera (Flatpak)** — open `opera://extensions` in Flatpak Opera → **Remove** any copy still pointing at `/run/flatpak/doc/…` → Load unpacked → `~/.local/share/alkitect-browser-tabs/mv3-opera-flatpak/` (must be that path, not a portal temp). Quit/relaunch Flatpak Opera, then `browser-tabs-host cli list --browser opera-flatpak`.

**1e. Vivaldi** — open `vivaldi://extensions` → **Remove** any load from the shared `browser-extension/` folder → Load unpacked → `~/.local/share/alkitect-browser-tabs/mv3-vivaldi/` (forced `browserId=vivaldi`; Vivaldi’s reduced UA otherwise binds as `chrome`). Fully quit and relaunch Vivaldi, then `browser-tabs-host cli list --browser vivaldi`.

**2. Shell** — Wayland needs a logout after enable (and after Shell metadata / matcher changes):

```bash
gnome-extensions enable browser-tab-dock@alkitect
# log out and back in
```

**3. Try it** — open one Brave, Chrome, Opera (deb or Flatpak), or Vivaldi window with at least two tabs. Hover that browser’s dock icon briefly; click a card to activate that tab. Clicking the icon itself still minimize-or-previews.

**Needs:** Ubuntu GNOME Wayland, Brave and/or Chrome and/or Opera `.deb` and/or Opera Flatpak and/or Vivaldi `.deb`, `systemd --user`, and a session where you can enable GNOME Shell extensions.

## Check it works

You want the hover strip to appear, a card click to focus that tab, and dock click unchanged.

```bash
./scripts/verify-host-cli.sh
./scripts/verify-dbus.sh
./scripts/verify-shell-fake.sh
# After Shell reload / logout, human checklist:
./scripts/verify-e2e.sh
```

- If `cli list` says no extension: reload the unpacked add-on, quit Brave fully, relaunch, try again.
- If hover does nothing after enable: confirm Wayland logout/in, then that `browser-tab-dock@alkitect` is enabled.

Maintainers: `./scripts/ci-check.sh`.

## Support my work

Tip jar for the next desktop fix. Or a coffee so the next script stays boring on purpose.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/alkitect/?hidefeed=true&widget=true&embed=true)

## Uninstall

```bash
./scripts/uninstall-from-local.sh
```

Remove the add-on in `brave://extensions` if you loaded it unpacked. That step is manual.

## How it works

Three small pieces share tab state with the dock:

| Piece | Role |
|-------|------|
| Brave MV3 add-on | Lists / activates tabs; inlines favicons; caches visible-tab PNG thumbs |
| `browser-tabs-host` | Native messaging ↔ session D-Bus |
| Shell extension | Hover dwell on the Ubuntu Dock → peek strip; raise the window after Activate |

Installed names: `browser-tabs-host`, `alkitect-browser-tabs.service`, Shell “Browser Aero Peek” (`browser-tab-dock@alkitect`, author: alkitect), browser add-on “Browser Tab Dock” (author: alkitect).

Versions: MV3 `browser-extension/manifest.json` (git tags track this) · Shell `metadata.json` integer (GNOME scheme). Deeper reading: [ARCHITECTURE](docs/ARCHITECTURE.md) · [ADR-001](docs/architecture/ADR-001-ipc-and-dock-intercept.md) · [SECURITY](docs/SECURITY.md).

## Related

- **Brave-only maintenance lane:** [alkitect/brave-aero-peek](https://github.com/alkitect/brave-aero-peek) — same host UUID/service; does **not** receive multi-browser (Wave Chromium+) commits.
- **Install clash:** Installing either product overwrites the same unit/UUID/NM hook. Do not alternate. After cutover, daily driver = **this** repo only. Rollback: reinstall from `brave-aero-peek`.

## Limits & safety

- **Linux + Ubuntu Dock + Brave/Chrome/Opera (`.deb` + Flatpak)/Vivaldi (`.deb`) at this tag** — other OSes, docks, and browsers stay unsupported until their roadmap wave ships.
- **One window per browser** with ≥2 tabs for peek; several windows of the same browser → no tab strip (stock window previews still work).
- **Thumbnails are page screenshots** (more sensitive than titles). Same-UID processes on D-Bus or the host socket can read them — details in [SECURITY.md](docs/SECURITY.md).
- Hover dwell and host rate limits reduce spam while scrubbing past the icon.
- This GitHub repo is the **release source** for tagged releases and public docs — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

GPL-3.0-only — see [LICENSE](LICENSE).

Copyright (C) 2026 alkitect

Optional tip jar: [ko-fi.com/alkitect](https://ko-fi.com/alkitect/?hidefeed=true&widget=true&embed=true)
