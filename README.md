# Browser Aero peek

Hover your browser on the Ubuntu Dock and pick a **tab** from thumbnails — Aero-style peek for Linux.


## What this does

Ubuntu Dock shows **window** previews when you click a browser. Tabs? Hover does nothing — so you restore the window and hunt the strip.

Pause on the dock icon and you get titles, favicons, and **cached** page thumbnails. Click a card; that tab comes forward.

Thumbnails are screenshots from the last time that tab was visible — Chromium can’t capture background tabs live. Treat them like page content on the local session bus (details under **Limits & safety**).

![Brave Aero peek on Ubuntu Dock — hover the Brave icon to see tab title and thumbnail cards](docs/images/ubuntu-dock-brave-aero-peek.png)

Dock **click** stays stock minimize-or-previews. Peek is hover-only.

**At this cutover tag, only Brave `.deb` is supported.** Other browsers are on the roadmap below — this release does not ship Chrome/Firefox/Tor install paths yet.

## Who this is for

See **[docs/BROWSER-SUPPORT.md](docs/BROWSER-SUPPORT.md)** for the full In / Planned / Out matrix and enabled/disabled NM semantics.

- **In:** Ubuntu 22.04 + GNOME Shell 42 **Wayland**, Ubuntu Dock, and the **Brave `.deb`** (only `enabled` browser after shared-prep)
- **In:** You keep several Brave tabs open and want to pick one from the dock without guessing
- **Planned (not enabled yet):** Chrome → Opera → Vivaldi → Chromium → Edge; then Firefox; then Tor Browser (feasibility gate)
- **Out:** GNOME Web (Epiphany); Flatpak or Snap browsers; non-GNOME desktops; replacing the global dock click-action

## Quick start

```bash
git clone https://github.com/alkitect/browser-aero-peek.git
cd browser-aero-peek
chmod +x scripts/*.sh
./scripts/install-to-local.sh --enable-automation
```

**What you installed:** three pieces — a user daemon (`alkitect-browser-tabs.service`), Brave’s native-messaging hook, and Shell extension `browser-tab-dock@alkitect`. The host starts with your graphical session. You still load the Brave add-on and enable the Shell extension yourself. `--enable-automation` enables the **systemd user** unit only (not sudoers / system-wide).

**1. Brave** — open `brave://extensions` → Developer mode → Load unpacked → `browser-extension/`. Confirm the ID matches `browser-extension/extension-id.txt`. Fully quit and relaunch Brave, then run `browser-tabs-host cli list --browser brave`.

**2. Shell** — Wayland needs a logout after enable (and after Shell metadata name/url changes):

```bash
gnome-extensions enable browser-tab-dock@alkitect
# log out and back in
```

**3. Try it** — open one Brave window with at least two tabs. Hover the Brave dock icon briefly; click a card to activate that tab. Clicking the icon itself still minimize-or-previews.

**Needs:** Ubuntu GNOME Wayland, Brave `.deb`, `systemd --user`, and a session where you can enable GNOME Shell extensions.

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

Installed names: `browser-tabs-host`, `alkitect-browser-tabs.service`, Shell uuid `browser-tab-dock@alkitect`, Brave add-on “Alkitect Browser Tab Dock”.

Versions: MV3 `browser-extension/manifest.json` (git tags track this) · Shell `metadata.json` integer (GNOME scheme). Deeper reading: [ARCHITECTURE](docs/ARCHITECTURE.md) · [ADR-001](docs/architecture/ADR-001-ipc-and-dock-intercept.md) · [SECURITY](docs/SECURITY.md).

## Related

- **Brave-only maintenance lane:** [alkitect/brave-aero-peek](https://github.com/alkitect/brave-aero-peek) — same host UUID/service; does **not** receive multi-browser (Wave Chromium+) commits.
- **Install clash:** Installing either product overwrites the same unit/UUID/NM hook. Do not alternate. After cutover, daily driver = **this** repo only. Rollback: reinstall from `brave-aero-peek`.

## Limits & safety

- **Linux + Ubuntu Dock + Brave `.deb` only at this tag** — other OSes, docks, and browsers are unsupported until their roadmap wave ships.
- **One Brave window** with ≥2 tabs for peek; several Brave windows → no tab strip (stock window previews still work).
- **Thumbnails are page screenshots** (more sensitive than titles). Same-UID processes on D-Bus or the host socket can read them — details in [SECURITY.md](docs/SECURITY.md).
- Hover dwell and host rate limits reduce spam while scrubbing past the icon.
- This GitHub repo is the **release source** for tagged releases and public docs — see [CONTRIBUTING.md](CONTRIBUTING.md).

## License

GPL-3.0-only — see [LICENSE](LICENSE).

Copyright (C) 2026 alkitect

Optional tip jar: [ko-fi.com/alkitect](https://ko-fi.com/alkitect/?hidefeed=true&widget=true&embed=true)
