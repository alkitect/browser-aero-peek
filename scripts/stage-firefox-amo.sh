#!/usr/bin/env bash
# Stage a Firefox-only tree for AMO self-distribution (web-ext lint / sign).
# Does not include Chromium key, favicon permission, or forced-browser-id.js.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${ROOT}/browser-extension"
OUT="${ROOT}/dist/firefox-amo"
FF_ID="$(tr -d '[:space:]' <"${ROOT}/browser-extension/firefox-extension-id.txt")"

rm -rf "${OUT}"
mkdir -p "${OUT}"
cp -a "${SRC}/background.js" "${OUT}/background.js"

python3 - <<PY
import json
from pathlib import Path

root = Path("${ROOT}")
src = json.loads((root / "browser-extension" / "manifest.json").read_text())
ff_id = "${FF_ID}"
out = {
    "manifest_version": 3,
    "name": src.get("name") or "Browser Tab Dock",
    "version": src["version"],
    "author": src.get("author") or "alkitect",
    "description": (
        "Linux/Ubuntu Dock tab peek for GNOME: sends tab titles, favicons, and cached page "
        "thumbnails to a same-UID local native host (org.alkitect.browser_tabs) used by the "
        "Browser Aero Peek Shell extension. Does not send data to Mozilla or other remote servers. "
        "Requires the companion host install from https://github.com/alkitect/browser-aero-peek. "
        "Author: alkitect."
    ),
    "browser_specific_settings": {
        "gecko": {
            "id": ff_id,
            "strict_min_version": "140.0",
            "data_collection_permissions": {
                # Native messaging to local host — counts as transmission outside the add-on.
                "required": ["browsingActivity", "websiteContent"],
            },
        },
        # Built-in consent landed on Android in 142; without this override the linter
        # inherits gecko 140 and warns KEY_FIREFOX_ANDROID_UNSUPPORTED_BY_MIN_VERSION.
        "gecko_android": {
            "strict_min_version": "142.0",
        },
    },
    "permissions": [
        p for p in (src.get("permissions") or [])
        if p not in ("favicon",)
    ],
    "host_permissions": list(src.get("host_permissions") or ["<all_urls>"]),
    "background": {"scripts": ["background.js"]},
    "action": src.get("action") or {"default_title": "Browser tab dock"},
}
# Never ship Chromium MV3 key in the Firefox AMO package.
assert "key" not in out
Path("${OUT}/manifest.json").write_text(json.dumps(out, indent=2) + "\n")
print(f"Staged Firefox AMO tree: ${OUT}")
print(f"  gecko.id={ff_id} strict_min_version=140.0 gecko_android=142.0")
print("  data_collection_permissions.required=[browsingActivity, websiteContent]")
PY
