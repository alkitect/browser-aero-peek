# Architecture — Browser tab dock (C4 container)

## Context

On **Linux Ubuntu + GNOME Wayland**, show browser **tab titles, favicons, and cached thumbnails** when the user **hovers** a supported Ubuntu Dock icon (dwell), without changing global dock click-action. Enabled peers today: Brave / Chrome / Opera / Opera GX / Vivaldi / Chromium (Snap+native deb+Flatpak) / Edge / Firefox packaging variants — via `config/browsers.json` (`nm_schema` chromium or mozilla).

## Containers

```text
┌──────────────┐  NM + hello(browserId)  ┌──────────────────┐  D-Bus (browser key)  ┌─────────────────┐
│ Brave/Chrome │ ───────────────────────► │ browser-tabs-host│ ◄──────────────────── │ Shell extension │
│ Opera deb MV3│   stdio via NM           │ daemon (systemd) │   ListTabs(s) /       │ hover-dwell     │
│              │ ◄─────────────────────── │ + Unix socket    │   Activate(s,u)       │ table matcher   │
└──────────────┘                          │ multiplex peers  │                       └─────────────────┘
┌──────────────┐                          └──────────────────┘
│ Opera Flatpak│  (forced browserId)                 ▲
│ staged MV3   │  + host ~/.local/bin:ro             │ CLI --browser
└──────────────┘                          browser-tabs-host cli
```

| Container | Tech | Responsibility |
|-----------|------|----------------|
| MV3 extension | Chromium-family `.deb` or Flatpak-staged unpack | `tabs.query` / `tabs.update`; `connectNative`; **hello** with `browserId` |
| Host daemon | Python3 + Gio, systemd --user | Bus name; multiplex NM peers; registry bind; scoped ListTabs cache/rate-limit |
| Shell extension | GNOME 42 | Hover dwell on matched dock icons; peek strip; raise `Meta.Window` after Activate |
| Registry | `config/browsers.json` | SSOT for id / `nm_base`+path / packaging / desktop+WM match / enabled |
| Ubuntu Dock | Stock | Click-action only (`minimize-or-previews`) — not modified by this product |

## Trust

- Session bus + `$XDG_RUNTIME_DIR` socket = same-UID boundary.
- NM `allowed_origins` single extension ID per written manifest; isolation seam = registry + per-browser NM dirs + per-browser host routing (not separate host processes). **Multi-NM (Brave + Chrome + Opera deb + Opera Flatpak + Vivaldi + Chromium Snap):** same MV3 id written into per-browser NativeMessagingHosts dirs (Flatpak under `~/.var/app/...`, Snap under `~/snap/...`); ListTabs/Activate carry the browser key so same-UID socket traffic stays lane-scoped. Flatpak NM JSON uses `browser-tabs-nm-flatpak` → `flatpak-spawn --host`. Snap Chromium uses `~/bin/browser-tabs-nm-snap` with **install-time absolute** host + home-sock paths (Snap remaps `$HOME`; strict snap cannot use host runtime-dir socks / `~/.local/bin`).

## See also

- [BROWSER-SUPPORT.md](BROWSER-SUPPORT.md)
- [ADR-001](architecture/ADR-001-ipc-and-dock-intercept.md)
- [SECURITY.md](SECURITY.md)
- Design history lives in the maintainer’s private notes; this repo is the release source after publish.
