# Publish notes

Before tag: README must pass `./scripts/ci-check.sh` (required H2s + README ban tokens + Ko-fi `FUNDING.yml` / tip link + secret-file bans). See [CONTRIBUTING.md](../CONTRIBUTING.md) § README conventions.

README variant: B

## First public tag (V-001)

**First public tag: v0.2.9**

**Current tag: v0.10.0**

**V-001 count (organic, not invent / not copy):**

| Input | Value |
|-------|--------|
| Parent lineage | `alkitect/brave-aero-peek` through published `v0.2.8` (+ tip README polish on `main`) |
| This product | Multi-browser **release source** fork at cutover; Brave still the only supported runtime at first tag |
| Why not `v0.2.8` | Already Brave’s first public tag — do not copy sibling tags |
| Why not greenfield `v0.1.0` | Same installable stack as Brave tip; cutover is rename + dual-lane docs + browser roadmap matrix (no new browser runtime feats) → **patch** after inherited `0.2.8` |
| `v0.2.10` | Shared-prep (registry SSOT, multiplex bind hello, scoped D-Bus/CLI, multi-NM ci) — patch; Brave still only `enabled` browser |
| `v0.3.0` | First non-Brave enable: Google Chrome `.deb` — **minor** |
| `v0.4.0` | Opera `.deb` + Opera Flatpak (packaging-variant pilot) + Shell 14 WM-class disambiguation — **minor** |
| `v0.5.0` | Vivaldi `.deb` (staged MV3 forced `browserId`; Flatpak/Snap Out) + NM reconnect-on-daemon-death — **minor** |
| `v0.6.0` | Chromium Snap (absolute-path NM wrapper; home sock; staged forced `browserId`; Flatpak deferred) — **minor** |
| `v0.6.1` | Docs: deprecate Brave-only sibling lane pointers — **patch** |
| `v0.7.0` | Firefox Snap (mozilla NM + Temporary `.xpi`) + Edge/packaging registry batch + Shell 19 thumb fade — **minor** |
| `v0.8.0` | Firefox Mozilla `.deb` + Flatpak (`firefox-deb` / `firefox-flatpak`) + Shell 20 family matcher — **minor** |
| `v0.9.0` | Firefox durable AMO-signed `.xpi` + Shell 21 sibling peer-fallback — **minor** |
| `v0.9.1` | Fix durable `.xpi` install path discovery — **patch** |
| `v0.9.2` | AMO re-sign durable Firefox `.xpi` to match product triad — **patch** |
| `v0.9.4` | Docs: packaging N/A matrix (Chrome Snap / Ubuntu Chromium deb / Edge Snap) + beta Out — **patch** |
| `v0.10.0` | Packaging delta: Opera GX trio + `chromium-deb` + Shell 22 + NM fail-closed — **minor** |
| `v0.9.3` | Clear AMO Android `data_collection_permissions` min-version warning (`gecko_android` 142) — **patch** |

Version triad (current): PUBLISH `Current tag: v0.10.0` · MV3 `0.10.0` · CHANGELOG `## 0.10.0`. First public tag line stays `v0.2.9`. Durable AMO `.xpi` remains **0.9.3** until next resign.

Never copy another alkitect repo’s tag. Use `RC-BEFORE-1.0` in this file only for an intentional 0.9.x RC.

```bash
./scripts/ci-check.sh
git tag -a v0.10.0 -m "v0.10.0"
git push origin main
git push origin v0.10.0
```

Repo URL: `https://github.com/alkitect/browser-aero-peek`

**Do not** ship `extension.pem` or `manifest-key.txt`.

## Tag blockers

| Gate | Blocks tag? |
|------|-------------|
| `./scripts/ci-check.sh` exit 0 | **Yes** (hard) |
| PII `--history` scrub PASS | **Yes** (before first push) |
| `./scripts/verify-e2e.sh` | **No** — optional human soak after logout/in |

## Human gate kinds

| Gate | Kind | When |
|------|------|------|
| Publish (tag/push/About) | `human_gate` | After scrub + ci-check PASS |
| Live host overwrite + e2e | `human_verify` | After submodule pin; no live uninstall during publish |
| Humanize Lane B | `human_verify` | Green ci-check ≠ voice done |

## Browser backlog (post-cutover)

Priority order (**2026-09-13** — Linux-share for uncovered browsers first, then packaging expansions):

1. Brave `.deb` — **supported**
2. Google Chrome `.deb` — **supported**
3. Opera `.deb` + Flatpak — **supported** (`v0.4.0`)
4. Vivaldi `.deb` — **supported** (`v0.5.0`)
5. Chromium Snap — **supported** (`v0.6.0`)
6. Firefox Snap — **supported** (`v0.7.0+`; durable AMO `.xpi` from `v0.9.0`)
7. Edge + packaging expansions — **registry In** (`v0.7.0`; live HV when installed)
8. Firefox Mozilla `.deb` + Flatpak — **supported** (`v0.8.0+`; durable from `v0.9.0`)
9. Tor Browser — **Out** ([TOR-FEASIBILITY.md](TOR-FEASIBILITY.md) FAIL)
10. Firefox durable (AMO-signed `.xpi`) — **supported** (`v0.9.0`; see [AMO-FIREFOX.md](AMO-FIREFOX.md))
11. Packaging delta — Opera GX + `chromium-deb` + N/A locks — **supported** (`v0.10.0`; live HV when installed)
12. GNOME Web — **Out**
13. Beta/dev/nightly channels — **Out**

## Human gate

Published through **v0.10.0** (Opera GX + chromium-deb; durable AMO `.xpi` still 0.9.3).

## GitHub About

| Field | Value |
|-------|--------|
| Description | Linux Ubuntu Dock: multi-browser tab thumbnail strip on hover (GNOME Shell); Brave + Chrome + Opera + Vivaldi + Chromium + Firefox (Snap/deb/Flatpak) |
| Website | _(empty — tip via README Ko-fi badge)_ |
| Topics | `linux`, `ubuntu`, `gnome`, `wayland`, `brave`, `chrome`, `opera`, `vivaldi`, `chromium`, `firefox`, `gnome-shell-extension`, `dock` |

```bash
gh repo edit alkitect/browser-aero-peek \
  --description "Linux Ubuntu Dock: multi-browser tab thumbnail strip on hover (GNOME Shell); Brave + Chrome + Opera + Vivaldi + Chromium + Firefox (Snap/deb/Flatpak)" \
  --homepage "" \
  --add-topic linux --add-topic ubuntu --add-topic gnome \
  --add-topic wayland --add-topic brave --add-topic chromium --add-topic gnome-shell-extension \
  --add-topic dock
```

Sidebar (manual if shown): Releases ✓ · Packages ✗ · Deployments ✗
