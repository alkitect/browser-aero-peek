# Architecture — Browser tab dock (C4 container)

## Context

On **Linux Ubuntu + GNOME Wayland**, show Brave **tab titles, favicons, and cached thumbnails** when the user **hovers** the Brave Ubuntu Dock icon (dwell), without changing global dock click-action.

## Containers

```text
┌─────────────┐  native messaging   ┌──────────────────┐  D-Bus session   ┌─────────────────┐
│ Brave MV3   │ ──────────────────► │ browser-tabs-host│ ◄─────────────── │ Shell extension │
│ extension   │   stdio via NM      │ daemon (systemd) │   ListTabs /     │ hover-dwell     │
│             │ ◄────────────────── │ + Unix socket    │   Activate       │                 │
└─────────────┘                     └──────────────────┘                  └─────────────────┘
        │                                      ▲
        │                                      │ CLI (same bus)
        ▼                                      │
   Brave windows                     browser-tabs-host cli
```

| Container | Tech | Responsibility |
|-----------|------|----------------|
| MV3 extension | Brave `.deb` unpacked | `tabs.query` / `tabs.update`; long-lived `connectNative` |
| Host daemon | Python3 + Gio, systemd --user | Own bus name; NM bridge; peer-UID; ListTabs cache/rate-limit |
| Shell extension | GNOME 42 | Hover dwell on Brave dock icon; popup; raise `Meta.Window` after Activate |
| Ubuntu Dock | Stock | Click-action only (`minimize-or-previews`) — not modified by this product |

## Trust

- Session bus + `$XDG_RUNTIME_DIR` socket = same-UID boundary.
- NM `allowed_origins` single extension ID.

## See also

- [ADR-001](architecture/ADR-001-ipc-and-dock-intercept.md)
- [SECURITY.md](SECURITY.md)
- Design history lives in the maintainer’s private notes; this repo is the release source after publish.
