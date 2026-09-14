# Browser support

Release-source matrix for **browser-aero-peek**. Runtime enablement is controlled by `config/browsers.json` (`enabled: true|false`). This document is the human-facing In/Out view.

## At this tip (Unreleased / packaging delta)

| Browser | Packaging | Status | Notes |
|---------|-----------|--------|--------|
| **Brave** | `.deb` | **In** | Shared `browser-extension/`; NM under Brave profile |
| **Brave** | Snap | **In** (registry) | `brave-snap`; staged `mv3-brave-snap/` |
| **Brave** | Flatpak `com.brave.Browser` | **In** (registry) | `brave-flatpak` |
| **Chrome** | `.deb` | **In** | Shared `browser-extension/` |
| **Chrome** | Flatpak `com.google.Chrome` | **In** (registry) | `chrome-flatpak` |
| **Opera** | `.deb` / Flatpak / Snap | **In** | Shared WM `Opera`; Shell Opera family matchers |
| **Opera GX** | `.deb` / Snap / Flatpak `com.opera.opera-gx` | **In** (registry) | Family `opera-gx`; GX matchers **before** Opera; see [GX-MEASURE.md](GX-MEASURE.md) |
| **Vivaldi** | `.deb` / Snap / Flatpak | **In** (registry) | |
| **Chromium** | Snap | **In** | Snap path only (no `.config/chromium` alias) |
| **Chromium** | Native `.deb` (Debian-style) | **In** (registry) | `chromium-deb` owns `~/.config/chromium/…`; not Ubuntu transitional apt |
| **Chromium** | Flatpak | **In** (registry) | `chromium-flatpak` |
| **Edge** | `.deb` / Flatpak | **In** (registry) | Live HV if installed |
| **Firefox** | Snap / Mozilla `.deb` / Flatpak | **In** | Durable AMO `.xpi` (signed add-on may lag tip; see CHANGELOG) |
| **Tor Browser** | — | **Out** | [TOR-FEASIBILITY.md](TOR-FEASIBILITY.md) **FAIL** |
| GNOME Web | — | **Out** | Not planned |

### Official packaging N/A (not gaps)

| Browser | Channel | Why |
|---------|---------|-----|
| Google Chrome | Snap | Google does not publish a Chrome Snap |
| Chromium | Ubuntu transitional `.deb` | `chromium-browser` apt → Snap only |
| Microsoft Edge | Snap | Microsoft does not publish Edge on Snapcraft |

### Channel Out (this product)

| Channel | Status |
|---------|--------|
| Beta / Dev / Nightly / Canary / `com.google.ChromeDev` | **Out** — not enabled |

### RPM parity (native)

Vendor **RPM** packages for Brave / Chrome / Edge / Opera / Vivaldi / Firefox / Opera GX that write the same `~/.config/<profile>/NativeMessagingHosts` paths as the `packaging: deb` registry rows are covered by those native ids — **no** separate `packaging: rpm` registry entries. On Fedora: install the product, run `install-to-local`, confirm NM JSON under the vendor profile path, then hover. Verify the RPM owns that profile directory before treating the lane as live.

## Enabled vs disabled

- **Enabled:** install writes Native Messaging JSON under that browser’s profile-relative `nm_path` (and aliases) with schema-correct allowlists. Install **fail-closes** if two enabled lanes resolve to the same NM directory.
- **Disabled:** install **must not** create NM JSON (Tor).
- **Wrong-lane:** do not alternate with deprecated `brave-aero-peek`.

## Load paths

- **Native** Brave / Chrome / Opera deb: Load unpacked → `browser-extension/` (unless staged — see forced-id).
- **Forced-id Chromium lanes** (Snap, Flatpak, Vivaldi, Edge, Opera GX all packagings, `chromium-deb`): Load unpacked → `~/.local/share/alkitect-browser-tabs/mv3-<id>/`.
- **Firefox (durable):** Install Add-on From File → `~/alkitect-browser-tabs/browser-tab-dock-signed.xpi`. See [AMO-FIREFOX.md](AMO-FIREFOX.md).

## Packaging notes

Shell: Opera GX family before Opera; Chromium Snap desktop before native deb. Sibling `NoExtension` retry stays **within** family (`opera-gx` does not fall back to `opera`). Logout/in after Shell metadata bumps.

## Follow-ups (not tag blockers)

| Item | Notes |
|------|--------|
| Live HV | Edge / GX / chromium-deb / packaging variants only when installed |
| Fedora RPM checklist | Non-blocking human verify on RPM hosts |

## See also

- [SECURITY.md](SECURITY.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [GX-MEASURE.md](GX-MEASURE.md) · [TOR-FEASIBILITY.md](TOR-FEASIBILITY.md)
