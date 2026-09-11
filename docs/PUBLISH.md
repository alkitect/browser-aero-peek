# Publish notes

Before tag: README must pass `./scripts/ci-check.sh` (required H2s + README ban tokens + Ko-fi `FUNDING.yml` / tip link + secret-file bans). See [CONTRIBUTING.md](../CONTRIBUTING.md) § README conventions.

README variant: B

## First public tag (V-001)

**First public tag: v0.2.9**

**Current tag: v0.2.10**

**V-001 count (organic, not invent / not copy):**

| Input | Value |
|-------|--------|
| Parent lineage | `alkitect/brave-aero-peek` through published `v0.2.8` (+ tip README polish on `main`) |
| This product | Multi-browser **release source** fork at cutover; Brave still the only supported runtime at first tag |
| Why not `v0.2.8` | Already Brave’s first public tag — do not copy sibling tags |
| Why not greenfield `v0.1.0` | Same installable stack as Brave tip; cutover is rename + dual-lane docs + browser roadmap matrix (no new browser runtime feats) → **patch** after inherited `0.2.8` |
| `v0.2.10` | Shared-prep (registry SSOT, multiplex bind hello, scoped D-Bus/CLI, multi-NM ci) — patch; Brave still only `enabled` browser |

Version triad (current): PUBLISH `Current tag: v0.2.10` · MV3 `0.2.10` · CHANGELOG `## 0.2.10`. First public tag line stays `v0.2.9`.

Never copy another alkitect repo’s tag. Use `RC-BEFORE-1.0` in this file only for an intentional 0.9.x RC.

```bash
./scripts/ci-check.sh
git tag -a v0.2.10 -m "v0.2.10"
git push origin main
git push origin v0.2.10
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

Priority order (cutover does **not** ship these install paths):

1. Brave — **supported** at cutover
2. Google Chrome
3. Opera
4. Vivaldi
5. Chromium
6. Microsoft Edge
7. Mozilla Firefox
8. Tor Browser (feasibility gate)
9. GNOME Web — **Out**

## Human gate

Published through **v0.2.10** (shared-prep). Optional soak: logout/in + `./scripts/verify-e2e.sh` scrub/corridor/header checklist (does not block the tag).

## GitHub About

| Field | Value |
|-------|--------|
| Description | Linux Ubuntu Dock: multi-browser tab thumbnail strip on hover (GNOME Shell); Brave supported at cutover |
| Website | _(empty — tip via README Ko-fi badge)_ |
| Topics | `linux`, `ubuntu`, `gnome`, `wayland`, `brave`, `gnome-shell-extension`, `dock` |

```bash
gh repo edit alkitect/browser-aero-peek \
  --description "Linux Ubuntu Dock: multi-browser tab thumbnail strip on hover (GNOME Shell); Brave supported at cutover" \
  --homepage "" \
  --add-topic linux --add-topic ubuntu --add-topic gnome \
  --add-topic wayland --add-topic brave --add-topic gnome-shell-extension \
  --add-topic dock
```

Sidebar (manual if shown): Releases ✓ · Packages ✗ · Deployments ✗
