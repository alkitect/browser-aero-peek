# Tor Browser feasibility — browser-aero-peek

**Verdict: FAIL** (2026-09-13)

## Scope

Spike for Native Messaging + dock tab peek on Tor Browser (Linux). Fail-closed: no README In, no NM install, `tor.enabled: false`.

## Evidence

| Check | Result |
|-------|--------|
| Tor Browser installed on target machine | **No** (`tor-browser` / `/opt/tor-browser*` / Flatpak Tor not present) |
| Durable WebExt + NM on Tor | Not proven; Tor Browser typically restricts unsigned durable extensions |
| Documented NM host dir | Not measured (no install). Stub registry path `tor-browser/native-messaging-hosts` remains disabled |
| Flatpak-only Tor | Would be **FAIL** per plan (no Flatpak-only bridge for Tor) |
| Companion / argv | N/A — no launcher to measure |

## Rubric

| Check | Outcome |
|-------|---------|
| Unsigned / temporary add-on policy | **FAIL** — no durable path proven |
| Native messaging dir | **FAIL** — no usable install to measure |
| Companion / host argv | **FAIL** — not measured |
| Flatpak / sandboxed Tor | **FAIL** — Flatpak-only stays Out |

## Decision

- Registry: keep `tor.enabled: false`
- Install/uninstall: must not write Tor NM JSON (disabled-only)
- Docs: **Out / Planned-blocked** until a future spike on a real Tor Browser install proves durable WebExt + NM
- Revisit: only after Tor Browser is installed and a new spike fills PASS evidence

## NM template (reference only — not installed)

Mozilla-shaped (same as Firefox schema); **do not** ship while FAIL:

- Manifest name: `org.alkitect.browser_tabs`
- `allowed_extensions`: pin TBD on PASS
- Path: absolute host NM bridge (not documented here as live)
