# ADR-001 — IPC and dock trigger

## Status

Accepted (amended 2026-09-09 for **hover-dwell**; amended 2026-09-11 for **multi-browser bind hello**).

## Context

Need browser tab titles + favicons in a GNOME dock popup without live page thumbnails. Three pieces: MV3 extension, session host, Shell extension. Stock Ubuntu Dock `click-action` is global and must stay owned by the separate click-minimize topic. Multi-browser support must not last-writer-wins on a single NM connection.

## Decision

1. **D-Bus** iface `org.alkitect.BrowserTabs1` at `/org/alkitect/BrowserTabs1`: `ListTabs(s browser_id)` → JSON `[{id,title,favicon,thumb?}]`, `Activate(s browser_id, u tab_id)`, `Status` → JSON (`peers`, `extension_connected`). No page URLs. Favicon/thumb sensitivity disclosed in SECURITY.md.
2. **Peer UID** — `GetConnectionUnixUser` must equal host UID or deny. Unix socket at `$XDG_RUNTIME_DIR` is a second same-UID boundary (`0600`). Same-UID residual remains.
3. **Host lifecycle** — systemd user unit runs `browser-tabs-host daemon` (Unix socket + bus name). Browser-spawned `browser-tabs-nm` proxies NM stdio to that socket. **Multiplex** peers; first frame **must** be `{"type":"hello","browserId":"<registry id>"}`. Reject unknown/disabled ids. Per-browser list cache + thumb prune under `{browserId}/`.
4. **NM** — `org.alkitect.browser_tabs` with `allowed_origins` = exactly one extension ID (manifest `key` pins ID). Never ship `extension.pem` publicly. Install writes only **enabled** registry `nm_path`s.
5. **MV3 verbs** — `hello` / `list` / `activate` / `ping`. Hello is mandatory before host RPC.
6. **Activate fail-closed** — tab id must belong to the last ListTabs set for that `browser_id` (ForeignTab otherwise).
7. **Dock trigger** — **`hover-dwell`**: Shell matches dock apps via table derived from registry (enabled ids); dwell ~100 ms, leave-delay, async coalesced `ListTabs(browser_id)`. **Do not** wrap `DockAbstractAppIcon.activate`. Stock click = `minimize-or-previews`. Policy: one interesting window, ≥2 tabs; no OS-focus requirement.
8. **Superseded** — `activate-wrap` (Phase 0 spike only); unscoped ListTabs/Activate; single global `_ext_conn`.
9. **Keyboard** — only if hover human_gate FAIL.

## Consequences

- Peek works before click; click ownership stays with global gsettings topic.
- Wayland: enabling Shell extension needs logout/in.
- Same-UID residual risk on D-Bus and Unix socket — SECURITY.md.
- Shared MV3 origin across Chromium-family lanes when multiple browsers enabled — blast-radius note in SECURITY.md.
- CLI: `browser-tabs-host cli list --browser <id>` / `activate --browser <id> <tab>`.
