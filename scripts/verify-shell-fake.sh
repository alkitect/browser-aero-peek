#!/usr/bin/env bash
# Fail if Shell extension still contains activate-wrap / focused gate.
# Asserts peek-polish symbols + SSOT matcher (BROWSER_MATCHERS / enabled registry ids).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/shell-extension/extension.js"
META="${ROOT}/shell-extension/metadata.json"
REG="${ROOT}/config/browsers.json"
INST="${HOME}/.local/share/gnome-shell/extensions/browser-tab-dock@alkitect/extension.js"

fail() { echo "FAIL: $*" >&2; exit 1; }
pass() { echo "PASS: $*"; }

[[ -f "$SRC" ]] || fail "missing $SRC"
[[ -f "$REG" ]] || fail "missing $REG"

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
grep -q '_browserWindows' "$SRC" || fail "source missing minimized-capable window list"
grep -q 'BROWSER_MATCHERS' "$SRC" || fail "source missing BROWSER_MATCHERS SSOT table"
grep -q '_matchBrowserApp' "$SRC" || fail "source missing _matchBrowserApp"
if grep -q '_isBraveApp\|_braveWindows' "$SRC"; then
  fail "source still has Brave-only helpers (_isBraveApp / _braveWindows)"
fi
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
  grep -q '"version": 14' "$META" || fail "metadata.json version must be 14"
fi

# Every enabled registry id must appear in extension.js matcher table.
python3 - <<'PY'
import json, sys
from pathlib import Path
root = Path(".")
reg = json.loads((root / "config/browsers.json").read_text())
src = (root / "shell-extension/extension.js").read_text()
for entry in reg["browsers"]:
    if not entry.get("enabled"):
        continue
    bid = entry["id"]
    if f"id: '{bid}'" not in src and f'id: "{bid}"' not in src:
        print(f"FAIL: enabled browser {bid!r} missing from BROWSER_MATCHERS in extension.js", file=sys.stderr)
        sys.exit(1)
print("PASS: enabled registry ids present in extension.js")
PY

CHECK_INST=1
if [[ "${1:-}" == "--source-only" ]]; then
  CHECK_INST=0
fi

pass "source is hover-dwell + peek strip (SSOT matcher)"

if [[ "${CHECK_INST}" -eq 1 && -f "$INST" ]]; then
  if grep -q '_origActivate' "$INST"; then
    fail "installed extension still activate-wrap — re-run install-to-local.sh"
  fi
  grep -q 'notify::hover' "$INST" || fail "installed extension missing hover"
  grep -q '_showPeekStrip' "$INST" || fail "installed extension missing peek strip — re-run install"
  grep -q 'DWELL_MS = 100' "$INST" || fail "installed extension DWELL_MS not 100 — re-run install"
  grep -q 'No preview yet' "$INST" || fail "installed extension missing empty preview — re-run install"
  grep -q '_pointerInLeaveCorridor' "$INST" || fail "installed extension missing corridor — re-run install"
  grep -q 'BROWSER_MATCHERS' "$INST" || fail "installed extension missing BROWSER_MATCHERS — re-run install"
  pass "installed extension matches hover-dwell peek"
elif [[ "${CHECK_INST}" -eq 1 ]]; then
  echo "INFO: not installed under ~/.local/share/gnome-shell/extensions/ yet"
fi

echo "PASS verify-shell-fake (static). Live hover e2e = human_gate after logout."
