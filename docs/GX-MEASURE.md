# Opera GX measure notes

Vendor packaging probe for **PKG-DELTA-GX-001** (host may not have GX installed). Values below are from Snap Store / Flathub / apt package naming — confirm on install before HV.

| Packaging | Registry id | Desktop id(s) | WM (expected) | NM path | Notes |
|-----------|-------------|---------------|---------------|---------|-------|
| Snap | `opera-gx-snap` | `opera-gx_opera-gx.desktop`, `opera-gx_opera-gx` | `opera` / `Opera` (shared with Opera) | `snap/opera-gx/common/opera/NativeMessagingHosts` | Snap Store: `opera-gx` (publisher Opera) |
| Flatpak | `opera-gx-flatpak` | `com.opera.opera-gx.desktop` | (Flatpak app id) | `.var/app/com.opera.opera-gx/config/opera/NativeMessagingHosts` (+ google-chrome alias) | Flathub `com.opera.opera-gx` |
| `.deb` | `opera-gx` | `opera-gx.desktop`, `opera-gx-stable.desktop`, `opera-gx` | `opera` / `Opera` | `opera-gx/NativeMessagingHosts` (`xdg_config`) | apt package `opera-gx-stable` |

## Confinement

- Snap: reuse `browser-tabs-nm-snap` absolute host + home-sock pattern (same as Opera Snap).
- Flatpak: reuse Opera Flatpak `flatpak-spawn --host` + filesystem `~/.local/bin:ro` + share dir + talk-name.

## Collision

Opera and Opera GX share StartupWMClass `Opera`. Shell must run `_matchOperaGxFamily` **before** `_matchOperaFamily`, and exclude GX ids from Opera `skipFamily` fall-through.
