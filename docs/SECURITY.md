# Security

## Trust boundary

- Session D-Bus: host checks `GetConnectionUnixUser` == own UID on `ListTabs` / `Activate` / `Status`.
- **Unix socket** `$XDG_RUNTIME_DIR/alkitect-browser-tabs.sock` (`0600`): any **same-UID** process can speak NM framing to the daemon (bypasses D-Bus peer check). Residual risk: malware at your UID.
- Residual D-Bus risk: any same-UID caller can see tab **titles**, **favicon** data, and **thumb** PNGs (not page URLs).

## Favicon URLs / thumbnails

ListTabs carries inlined `data:` **favicon** PNGs and optional **thumb** PNGs (last capture while that tab was visible). Page URLs are **not** exported on D-Bus; the MV3 worker may read `tab.url` only to query `chrome://favicon2` / fetch favicons / `captureVisibleTab` (`host_permissions: <all_urls>` + `storage` for session thumb cache).

**Thumbs are page-content screenshots** (more sensitive than titles). Same-UID callers on D-Bus or the Unix socket can read them. Do not log full `tabs_json` on the hover path.

## Native messaging

- Manifest `allowed_origins` = exactly one `chrome-extension://<id>/`.
- Host binary under `~/.local/bin` mode `0755`; never world-writable install dirs.
- **Do not** publish `extension.pem` or `manifest-key.txt`. The MV3 manifest `key` field (and `extension-id.txt`) are **public** and pin the extension ID; they are not the private signing key.

## Hover abuse

Shell dwell + host in-flight dedup + TTL cache + min interval limit `ListTabs` → extension RPC spam while scrubbing the dock.

## Do not

- Put tokens or profile secrets in manifests or logs.
- Widen `allowed_origins` to `chrome-extension://*/`.
