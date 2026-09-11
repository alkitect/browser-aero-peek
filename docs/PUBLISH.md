# Publish notes

Before tag: README must pass `./scripts/ci-check.sh` (required H2s + README ban tokens + Ko-fi `FUNDING.yml` / tip link + secret-file bans). See [CONTRIBUTING.md](../CONTRIBUTING.md) § README conventions.

README variant: B

## First public tag (V-001)

**First public tag: v0.2.9**

**Current tag: v0.6.1**

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

Version triad (current): PUBLISH `Current tag: v0.6.1` · MV3 `0.6.1` · CHANGELOG `## 0.6.1`. First public tag line stays `v0.2.9`.

Never copy another alkitect repo’s tag. Use `RC-BEFORE-1.0` in this file only for an intentional 0.9.x RC.

```bash
./scripts/ci-check.sh
git tag -a v0.6.1 -m "v0.6.1"
git push origin main
git push origin v0.6.1
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

Priority order:

1. Brave — **supported**
2. Google Chrome — **supported**
3. Opera `.deb` — **supported** (`v0.4.0`)
4. Opera Flatpak (`opera-flatpak`) — **supported** (`v0.4.0`; packaging pilot)
5. Vivaldi — **supported** (`v0.5.0`; Flatpak/Snap Out)
6. Chromium Snap — **supported** (`v0.6.0`; Flatpak deferred)
7. Microsoft Edge
8. Mozilla Firefox
9. Tor Browser (feasibility gate)
10. GNOME Web — **Out**

## Human gate

Published through **v0.6.1** (Brave + Chrome + Opera deb + Opera Flatpak + Vivaldi `.deb` + Chromium Snap; Brave sibling lane deprecated). Optional soak: logout/in + `./scripts/verify-e2e.sh` scrub/corridor/header checklist (does not block the tag).

## GitHub About

| Field | Value |
|-------|--------|
| Description | Linux Ubuntu Dock: multi-browser tab thumbnail strip on hover (GNOME Shell); Brave + Chrome + Opera + Vivaldi + Chromium Snap supported |
| Website | _(empty — tip via README Ko-fi badge)_ |
| Topics | `linux`, `ubuntu`, `gnome`, `wayland`, `brave`, `chrome`, `opera`, `vivaldi`, `chromium`, `gnome-shell-extension`, `dock` |

```bash
gh repo edit alkitect/browser-aero-peek \
  --description "Linux Ubuntu Dock: multi-browser tab thumbnail strip on hover (GNOME Shell); Brave + Chrome + Opera + Vivaldi + Chromium Snap supported" \
  --homepage "" \
  --add-topic linux --add-topic ubuntu --add-topic gnome \
  --add-topic wayland --add-topic brave --add-topic chromium --add-topic gnome-shell-extension \
  --add-topic dock
```

Sidebar (manual if shown): Releases ✓ · Packages ✗ · Deployments ✗
