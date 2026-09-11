# ADR-001 — IPC and dock trigger

## Status

Accepted (amended 2026-09-09 for **hover-dwell**).

## Context

Need Brave tab titles + favicons in a GNOME dock popup without live page thumbnails. Three pieces: MV3 extension, session host, Shell extension. Stock Ubuntu Dock `click-action` is global and must stay owned by [ubuntu-dock-click-minimize](../../../ubuntu-dock-click-minimize/README.md).

## Decision

1. **D-Bus** iface `org.alkitect.BrowserTabs1` at `/org/alkitect/BrowserTabs1`: `ListTabs` → JSON `[{id,title,favicon}]`, `Activate(u)`, `Status` → JSON. No page URLs in v0.1. Favicon URLs are metadata (disclose in SECURITY.md).
2. **Peer UID** — `GetConnectionUnixUser` must equal host UID or deny. Unix socket at `$XDG_RUNTIME_DIR` is a second same-UID boundary (`0600`).
3. **Host lifecycle** — systemd user unit runs `browser-tabs-host daemon` (Unix socket + bus name). Brave-spawned `browser-tabs-nm` proxies NM stdio to that socket. `ListTabs` uses in-flight dedup + short TTL cache + min interval.
4. **NM** — `org.alkitect.browser_tabs` with `allowed_origins` = exactly one extension ID (manifest `key` pins ID). Never ship `extension.pem` publicly.
5. **MV3 verbs** — `list` / `activate` / `ping` only.
6. **Dock trigger** — **`hover-dwell`**: Shell connects to Brave dock icon `notify::hover`, dwell ~300 ms, leave-delay, async coalesced `ListTabs`. **Do not** wrap `DockAbstractAppIcon.activate`. Stock click = `minimize-or-previews`. Policy: one interesting window, ≥2 tabs; no OS-focus requirement.
7. **Superseded** — `activate-wrap` (Phase 0 spike only).
8. **Keyboard** — TODO-001b only if hover human_gate FAIL.

## Consequences

- Peek works before click; click ownership stays with global gsettings topic.
- Wayland: enabling Shell extension needs logout/in.
- Same-UID residual risk on D-Bus and Unix socket — SECURITY.md.
