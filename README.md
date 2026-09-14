# Browser Aero peek

Hover your browser on the Ubuntu Dock and pick a **tab** from thumbnails — Aero-style peek for Linux.


## What this does

Ubuntu Dock shows **window** previews when you click a browser. Tabs? Hover does nothing — so you restore the window and hunt the strip.

Pause on the dock icon and you get titles, favicons, and **cached** page thumbnails. Click a card; that tab comes forward.

Thumbnails are screenshots from the last time that tab was visible — Chromium can’t capture background tabs live. Treat them like page content on the local session bus (details under **Limits & safety**).

![Brave Aero peek on Ubuntu Dock — hover the Brave icon to see tab title and thumbnail cards](docs/images/ubuntu-dock-brave-aero-peek.png)

Dock **click** stays stock minimize-or-previews. Peek is hover-only.

**At this tip (`v0.10.0`), the registry also enables Opera GX (deb/Snap/Flatpak) and native Chromium `.deb` (`chromium-deb`).** Tor Browser stays **Out** ([TOR-FEASIBILITY.md](docs/TOR-FEASIBILITY.md) FAIL). Live hover only works for packages you actually install.

## Who this is for

See **[docs/BROWSER-SUPPORT.md](docs/BROWSER-SUPPORT.md)** for the full In / Planned / Out matrix and enabled/disabled NM semantics.

- **In (registry):** Brave / Chrome / Opera / Opera GX / Vivaldi / Chromium / Edge packaging rows in `config/browsers.json`; Firefox Snap / Mozilla `.deb` / Flatpak
- **In (this machine):** whatever of those packages you have installed — NM JSON is written for all enabled rows; Flatpak overrides apply only when the Flatpak app exists
- **Out:** Tor Browser (feasibility FAIL); GNOME Web; beta/dev/nightly channels; Chrome Snap / Edge Snap / Ubuntu transitional Chromium deb (N/A)
- **Shell:** Ubuntu 22.04 + GNOME Shell 42 **Wayland**, Ubuntu Dock; **one** logout/in after Shell matcher changes (metadata **22**)

## Quick start

```bash
git clone https://github.com/alkitect/browser-aero-peek.git
cd browser-aero-peek
chmod +x scripts/*.sh
./scripts/install-to-local.sh --enable-automation
```

**What you installed:** a user daemon (`alkitect-browser-tabs.service`), Native Messaging hooks for **each enabled** registry browser, staged MV3 folders under `~/.local/share/alkitect-browser-tabs/mv3-<id>/` where forced `browserId` is required, and Shell extension `browser-tab-dock@alkitect`. You still load the add-on in each browser and enable the Shell extension yourself.

**Load the add-on (pick what you run):**

| Browser | Extensions page | Load path |
|---------|-----------------|-----------|
| Brave / Chrome / Opera **deb** | `brave://` / `chrome://` / `opera://extensions` | repo `browser-extension/` |
| Edge **deb** | `edge://extensions` | staged `~/.local/share/alkitect-browser-tabs/mv3-edge/` |
| Vivaldi **deb** | `vivaldi://extensions` | staged `mv3-vivaldi/` (forced id — reduced UA looks like Chrome) |
| Snap / Flatpak Chromium-family | that browser’s extensions page | staged `mv3-<id>/` (remove portal `/run/…/doc/…` loads) |
| Firefox Snap | `about:addons` | **Install Add-on From File** → `~/alkitect-browser-tabs/browser-tab-dock-signed.xpi` (AMO-signed; survives quit). Temporary fallback: `~/snap/firefox/common/alkitect-mv3-firefox.xpi` |
| Firefox Mozilla `.deb` | same | Same durable `.xpi` (restart Firefox once after first install if NM was cold) |
| Firefox Flatpak | same | Same durable `.xpi`; Shell peer-fallback maps dock → `firefox` NM peer |

Confirm Chromium-family ID matches `browser-extension/extension-id.txt`. Fully quit/relaunch each browser, then `browser-tabs-host cli list --browser <id>`.

**Shell** — Wayland needs **one** logout after enable (and after Shell metadata / matcher changes):

```bash
gnome-extensions enable browser-tab-dock@alkitect
# log out and back in once
```

**Try it** — one window per installed browser with ≥2 tabs; hover that dock icon; click a card. Dock click stays stock.

**Needs:** Ubuntu GNOME Wayland, at least one enabled browser package, `systemd --user`, and permission to enable GNOME Shell extensions.

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

Versions: MV3 `browser-extension/manifest.json` (git tags track this) · Shell `metadata.json` integer (GNOME scheme). Deeper reading: [ARCHITECTURE](docs/ARCHITECTURE.md) · [ADR-001](docs/architecture/ADR-001-ipc-and-dock-intercept.md) · [SECURITY](docs/SECURITY.md) · [Firefox AMO](docs/AMO-FIREFOX.md).

## Related

- **Deprecated Brave-only lane:** [alkitect/brave-aero-peek](https://github.com/alkitect/brave-aero-peek) — frozen; same host UUID/service. Do not use for new installs.
- **Install clash:** Installing either product overwrites the same unit/UUID/NM hook. Do not alternate. Daily driver = **this** repo only.

## Limits & safety

- **Linux + Ubuntu Dock + Brave/Chrome/Opera (`.deb` + Flatpak)/Vivaldi (`.deb`)/Chromium (Snap)/Firefox (Snap + Mozilla `.deb` + Flatpak) at this tip** — other OSes, docks, and browsers stay unsupported until their roadmap wave ships.
- **One window per browser** with ≥2 tabs for peek; several windows of the same browser → no tab strip (stock window previews still work).
- **Thumbnails are page screenshots** (more sensitive than titles). Same-UID processes on D-Bus or the host socket can read them — details in [SECURITY.md](docs/SECURITY.md).
- Hover dwell and host rate limits reduce spam while scrubbing past the icon.
- This GitHub repo is the **release source** for tagged releases and public docs — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

GPL-3.0-only — see [LICENSE](LICENSE).

Copyright (C) 2026 alkitect

Optional tip jar: [ko-fi.com/alkitect](https://ko-fi.com/alkitect/?hidefeed=true&widget=true&embed=true)
