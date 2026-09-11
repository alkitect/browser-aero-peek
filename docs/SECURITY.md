# Security

## Trust boundary

- Session D-Bus: host checks `GetConnectionUnixUser` == own UID on `ListTabs` / `Activate` / `Status`.
- **Unix socket** `$XDG_RUNTIME_DIR/alkitect-browser-tabs.sock` (`0600`): any **same-UID** process can speak NM framing to the daemon (bypasses D-Bus peer check). Residual risk: malware at your UID.
- Residual D-Bus risk: any same-UID caller can see tab **titles**, **favicon** data, and **thumb** PNGs (not page URLs).
- **Same-UID cannot D-Bus-deny self** — peer UID checks stop other users, not other processes at your UID.

## Concurrent browsers

- One daemon multiplexes NM peers. First frame on each socket **must** be bind hello `{"type":"hello","browserId":"<registry id>"}`. Unknown or **disabled** ids are rejected/closed. Unbound peers get no ListTabs/Activate.
- `ListTabs` / `Activate` require a registry browser key. Activate with a tab id that was not listed for that browser → **ForeignTab** (fail-closed). This prevents cross-browser bleed when tab numeric ids collide.
- Thumb/runtime paint paths are prefixed `{browserId}/tab-{tabId}` on host and Shell.
- **If routing is wrong** (last-writer-wins, shared global tab cache, missing browser key), same-UID callers can see or activate the wrong browser’s tabs — treat concurrent-browser routing as a trust-plane control, not a convenience.
- **Shared MV3 blast radius:** one pinned extension id / `allowed_origins` origin is reused across Chromium-family NM dirs when multiple browsers are enabled (Brave + Chrome + Opera `.deb` + Opera Flatpak + Vivaldi today). Compromise of that origin affects every enabled Chromium NM lane. Do not widen origins; do not fork keys casually. Five-NM: five profile dirs (including Flatpak `.var/app/...` + alias), one shared origin, host routes by `browserId` on the same-UID socket. Staged copies (`mv3-opera-flatpak`, `mv3-vivaldi`) only force the hello `browserId`; they keep the same id/key.
- **Flatpak Opera spawn boundary:** Flatpak cannot see the host Unix socket (`$XDG_RUNTIME_DIR/...sock`) and cannot import host PyGObject. NM JSON for `opera-flatpak` therefore points at `~/.local/bin/browser-tabs-nm-flatpak`, which runs `flatpak-spawn --host` → `browser-tabs-nm` on the real host. Install applies `filesystem=~/.local/bin:ro`, `filesystem=~/.local/share/alkitect-browser-tabs:ro` (durable Load unpacked path; avoid ephemeral `/run/flatpak/doc/…` portal grants), and `--talk-name=org.freedesktop.Flatpak`. Residual trust: same-UID Flatpak app with those overrides can spawn the host NM bridge; uninstall documents removing them.
- **Snap Chromium spawn boundary:** strict Chromium cannot exec `~/.local/bin` (hidden) or connect to host `$XDG_RUNTIME_DIR` socks. NM JSON points at `~/bin/browser-tabs-nm-snap` (non-hidden), which runs a stdlib-only native bridge against a **baked absolute** home sock (`…/alkitect-browser-tabs/browser-tabs.sock`). Install must not use `$HOME/…` inside the wrapper — Snap remaps `$HOME` to `~/snap/chromium/<rev>/`, which 404s the host binary. Daemon also listens on that home sock. Load unpacked from the staged share path (not ephemeral `/run/user/*/doc/…` portal grants). Residual trust: same-UID processes that can write `~/bin` or the home sock dir.

## Favicon URLs / thumbnails

ListTabs carries inlined `data:` **favicon** PNGs and optional **thumb** PNGs (last capture while that tab was visible). Page URLs are **not** exported on D-Bus; the MV3 worker may read `tab.url` only to query `chrome://favicon2` / fetch favicons / `captureVisibleTab` (`host_permissions: <all_urls>` + `storage` for session thumb cache).

**Thumbs are page-content screenshots** (more sensitive than titles). Same-UID callers on D-Bus or the Unix socket can read them. Do not log full `tabs_json` on the hover path.

## Native messaging

- Manifest `allowed_origins` = exactly one `chrome-extension://<id>/` per written NM JSON.
- Install writes NM only for `enabled` registry rows (`nm_base` `xdg_config` or `home`); disabled `nm_path` / alias dirs stay empty of this manifest.
- Host binary under `~/.local/bin` mode `0755`; never world-writable install dirs.
- Flatpak-staged MV3 may set `FORCED_BROWSER_ID` so hello binds as `opera-flatpak` (same extension id as native).
- **Do not** publish `extension.pem` or `manifest-key.txt`. The MV3 manifest `key` field (and `extension-id.txt`) are **public** and pin the extension ID; they are not the private signing key.

## Hover abuse

Shell dwell + host in-flight dedup + TTL cache + min interval limit `ListTabs` → extension RPC spam while scrubbing the dock.

## Do not

- Put tokens or profile secrets in manifests or logs.
- Widen `allowed_origins` to `chrome-extension://*/`.
- Rely on D-Bus peer UID alone to isolate two browsers for the same user.
