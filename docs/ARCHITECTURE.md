# Architecture — Browser tab dock (C4 container)

## Context

On **Linux Ubuntu + GNOME Wayland**, show browser **tab titles, favicons, and cached thumbnails** when the user **hovers** a supported Ubuntu Dock icon (dwell), without changing global dock click-action. At shared-prep, only **Brave** is enabled; the host and Shell are multi-browser-ready via `config/browsers.json`.

## Containers

```text
┌──────────────┐  NM + hello(browserId)  ┌──────────────────┐  D-Bus (browser key)  ┌─────────────────┐
│ Brave MV3    │ ───────────────────────► │ browser-tabs-host│ ◄──────────────────── │ Shell extension │
│ (enabled)    │   stdio via NM           │ daemon (systemd) │   ListTabs(s) /       │ hover-dwell     │
│              │ ◄─────────────────────── │ + Unix socket    │   Activate(s,u)       │ table matcher   │
└──────────────┘                          │ multiplex peers  │                       └─────────────────┘
┌──────────────┐                          └──────────────────┘
│ Chrome MV3…  │  (disabled: no NM JSON)            ▲
│ future peers │                                    │ CLI --browser
└──────────────┘                          browser-tabs-host cli
```

| Container | Tech | Responsibility |
|-----------|------|----------------|
| MV3 extension | Chromium-family `.deb` unpacked | `tabs.query` / `tabs.update`; `connectNative`; **hello** with `browserId` |
| Host daemon | Python3 + Gio, systemd --user | Bus name; multiplex NM peers; registry bind; scoped ListTabs cache/rate-limit |
| Shell extension | GNOME 42 | Hover dwell on matched dock icons; peek strip; raise `Meta.Window` after Activate |
| Registry | `config/browsers.json` | SSOT for id / NM path / desktop+WM match / enabled |
| Ubuntu Dock | Stock | Click-action only (`minimize-or-previews`) — not modified by this product |

## Trust

- Session bus + `$XDG_RUNTIME_DIR` socket = same-UID boundary.
- NM `allowed_origins` single extension ID per written manifest; isolation seam = registry + per-browser NM dirs + per-browser host routing (not separate host processes).

## See also

- [BROWSER-SUPPORT.md](BROWSER-SUPPORT.md)
- [ADR-001](architecture/ADR-001-ipc-and-dock-intercept.md)
- [SECURITY.md](SECURITY.md)
- Design history lives in the maintainer’s private notes; this repo is the release source after publish.
