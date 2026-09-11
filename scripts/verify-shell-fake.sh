#!/usr/bin/env bash
# Fail if Shell extension still contains activate-wrap / focused gate.
# Also asserts peek-polish batch symbols (dwell 100, corridor, empty preview, pending-show).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/shell-extension/extension.js"
META="${ROOT}/shell-extension/metadata.json"
INST="${HOME}/.local/share/gnome-shell/extensions/browser-tab-dock@alkitect/extension.js"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

[[ -f "$SRC" ]] || fail "missing $SRC"

if grep -q 'proto\.activate\s*=' "$SRC" || grep -q '_origActivate' "$SRC"; then
  fail "source still patches activate (activate-wrap)"
fi
if grep -q 'appIcon\.focused' "$SRC" || grep -q 'icon\.focused' "$SRC"; then
  fail "source still requires focused"
fi
grep -q 'notify::hover' "$SRC" || fail "source missing notify::hover"
grep -q 'DWELL_MS' "$SRC" || fail "source missing DWELL_MS"
grep -q 'DWELL_MS = 100' "$SRC" || fail "source DWELL_MS must be 100"
grep -q '_showPeekStrip\|_makeCard' "$SRC" || fail "source missing peek strip"
grep -q 'load_file_async\|TextureCache' "$SRC" || fail "source missing TextureCache thumb paint"
grep -q '_braveWindows' "$SRC" || fail "source missing minimized-capable window list"
grep -q 'BytesIcon' "$SRC" || fail "source missing BytesIcon path"
grep -q 'No preview yet' "$SRC" || fail "source missing empty preview copy"
grep -q '_pendingShowIcon\|_clearPendingShow' "$SRC" || fail "source missing pending-show SM"
grep -q '_pointerInLeaveCorridor\|_armLeaveTick' "$SRC" || fail "source missing leave corridor"
grep -q 'HEADER_FAV_PX\|_listInFlight' "$SRC" || fail "source missing header fav / list coalesce"
grep -q '_prefetchList' "$SRC" || fail "source missing prefetch"
# No PopupMenu ornament column (was the large left gap before favicons).
if grep -q 'PopupImageMenuItem\|PopupMenuItem' "$SRC"; then
  fail "source still uses PopupMenuItem (ornament padding)"
fi
if [[ -f "$META" ]]; then
  grep -q '"version": 9' "$META" || fail "metadata.json version must be 9"
fi
pass "source is hover-dwell + peek strip (polish batch)"

if [[ -f "$INST" ]]; then
  if grep -q '_origActivate' "$INST"; then
    fail "installed extension still activate-wrap — re-run install-to-local.sh"
  fi
  grep -q 'notify::hover' "$INST" || fail "installed extension missing hover"
  grep -q '_showPeekStrip' "$INST" || fail "installed extension missing peek strip — re-run install"
  grep -q 'DWELL_MS = 100' "$INST" || fail "installed extension DWELL_MS not 100 — re-run install"
  grep -q 'No preview yet' "$INST" || fail "installed extension missing empty preview — re-run install"
  grep -q '_pointerInLeaveCorridor' "$INST" || fail "installed extension missing corridor — re-run install"
  pass "installed extension matches hover-dwell peek"
else
  echo "INFO: not installed under ~/.local/share/gnome-shell/extensions/ yet"
fi

echo "PASS verify-shell-fake (static). Live hover e2e = human_gate after logout."
