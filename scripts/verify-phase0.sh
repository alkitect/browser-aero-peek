#!/usr/bin/env bash
# Phase 0 checks: Brave NM path + Ubuntu Dock activate hook surface.
# Non-destructive; does not enable Shell extensions or restart anything.
set -euo pipefail

fail=0
pass() { printf 'PASS  %s\n' "$*"; }
fail_() { printf 'FAIL  %s\n' "$*"; fail=1; }
info() { printf 'INFO  %s\n' "$*"; }

NM_DIR="${HOME}/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
DOCK_APPICONS="/usr/share/gnome-shell/extensions/ubuntu-dock@ubuntu.com/appIcons.js"

echo "=== Phase 0 verify ($(date -Iseconds)) ==="

if [[ -d "$NM_DIR" ]]; then
  pass "Brave NM dir exists: $NM_DIR"
else
  fail_ "Brave NM dir missing: $NM_DIR (is Brave .deb installed / profile created?)"
fi

if [[ -d "$NM_DIR" ]] && [[ -w "$NM_DIR" ]]; then
  probe="${NM_DIR}/.alkitect-phase0-write-probe"
  if touch "$probe" 2>/dev/null; then
    rm -f "$probe"
    pass "Brave NM dir is writable"
  else
    fail_ "Brave NM dir not writable"
  fi
fi

if command -v brave-browser >/dev/null 2>&1 || [[ -x /opt/brave.com/brave/brave-browser ]]; then
  pass "Brave .deb binary present"
else
  fail_ "brave-browser binary not found"
fi

if [[ -f "$DOCK_APPICONS" ]]; then
  pass "Ubuntu Dock appIcons.js present"
else
  fail_ "Ubuntu Dock appIcons.js missing"
fi

if [[ -f "$DOCK_APPICONS" ]]; then
  if grep -q 'MINIMIZE_OR_PREVIEWS' "$DOCK_APPICONS" \
    && grep -q 'activate(button)' "$DOCK_APPICONS" \
    && grep -q 'DockAbstractAppIcon' "$DOCK_APPICONS"; then
    pass "Dock hook surface: activate + MINIMIZE_OR_PREVIEWS + DockAbstractAppIcon"
  else
    fail_ "Dock appIcons.js missing expected activate / MINIMIZE_OR_PREVIEWS symbols"
  fi
fi

click="$(gsettings get org.gnome.shell.extensions.dash-to-dock click-action 2>/dev/null || true)"
if [[ "$click" == *"minimize-or-previews"* ]]; then
  pass "click-action is minimize-or-previews ($click)"
else
  info "click-action is '$click' (topic ubuntu-dock-click-minimize expects minimize-or-previews)"
fi

info "Shell: $(gnome-shell --version 2>/dev/null || echo unknown)"
info "Session: ${XDG_SESSION_TYPE:-unknown}"
info "Live dock-click test deferred (Wayland Shell reload = logout)"

echo "=== result: $([[ $fail -eq 0 ]] && echo OK || echo FAILED) ==="
exit "$fail"
