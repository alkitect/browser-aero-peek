#!/usr/bin/env bash
# Install browser-tabs host + NM manifest(s) + systemd user unit.
# Usage: install-to-local.sh [--enable-automation]
# Writes NM only for enabled entries in config/browsers.json (never disabled nm_path).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${HOME}/.local/bin"
SYSTEMD_USER="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
CFG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/alkitect-browser-tabs"
EXT_ID_FILE="${ROOT}/browser-extension/extension-id.txt"
BROWSERS_JSON="${ROOT}/config/browsers.json"
ENABLE_AUTOMATION=0

for arg in "$@"; do
  case "${arg}" in
    --enable-automation) ENABLE_AUTOMATION=1 ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--enable-automation]"
      exit 0
      ;;
    *)
      echo "Unknown option: ${arg}" >&2
      exit 2
      ;;
  esac
done

if [[ ! -f "${EXT_ID_FILE}" ]]; then
  echo "Missing ${EXT_ID_FILE} (generate key first)" >&2
  exit 1
fi
if [[ ! -f "${BROWSERS_JSON}" ]]; then
  echo "Missing ${BROWSERS_JSON}" >&2
  exit 1
fi
EXT_ID="$(tr -d '[:space:]' <"${EXT_ID_FILE}")"

mkdir -p "${BIN}" "${SYSTEMD_USER}" "${CFG_DIR}"

# Fail if install targets are group/world-writable
for d in "${BIN}" "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"; do
  [[ -d "$d" ]] || continue
  mode="$(stat -c '%a' "$d" 2>/dev/null || true)"
  if [[ -n "$mode" && "$((8#${mode} & 8#022))" -ne 0 ]]; then
    echo "Refusing install: ${d} is group/world-writable (mode ${mode})" >&2
    exit 1
  fi
done

install -m0755 "${ROOT}/host/browser_tabs_host.py" "${BIN}/browser-tabs-host"
install -m0644 "${BROWSERS_JSON}" "${CFG_DIR}/browsers.json"

# Chromium NM entry must take no required args
cat >"${BIN}/browser-tabs-nm" <<EOF
#!/usr/bin/env bash
exec "${BIN}/browser-tabs-host" native "\$@"
EOF
chmod 0755 "${BIN}/browser-tabs-nm"

# NM manifests: only enabled chromium-schema browsers (mozilla reserved for later waves).
python3 - <<PY
import json
import os
import sys
from pathlib import Path

root = Path("${ROOT}")
ext_id = "${EXT_ID}"
bin_nm = str(Path("${BIN}/browser-tabs-nm").resolve())
cfg_home = Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config"))
data = json.loads(Path("${BROWSERS_JSON}").read_text())
tmpl = json.loads((root / "native-messaging/org.alkitect.browser_tabs.json.template").read_text())
wrote = 0
for entry in data["browsers"]:
    bid = entry["id"]
    schema = entry.get("nm_schema")
    enabled = bool(entry.get("enabled"))
    nm_path = entry.get("nm_path") or ""
    if nm_path.startswith("/") or nm_path.startswith("~") or ".." in Path(nm_path).parts:
        print(f"install: bad nm_path for {bid}", file=sys.stderr)
        sys.exit(1)
    if not enabled:
        continue
    if schema != "chromium":
        print(f"install: skip enabled non-chromium {bid} (schema={schema})", file=sys.stderr)
        continue
    nm_dir = cfg_home / nm_path
    nm_dir.mkdir(parents=True, exist_ok=True)
    mode = oct(nm_dir.stat().st_mode)[-3:]
    if int(mode, 8) & 0o022:
        print(f"Refusing install: {nm_dir} is group/world-writable (mode {mode})", file=sys.stderr)
        sys.exit(1)
    out = dict(tmpl)
    out["path"] = bin_nm
    out["allowed_origins"] = [f"chrome-extension://{ext_id}/"]
    dest = nm_dir / "org.alkitect.browser_tabs.json"
    dest.write_text(json.dumps(out, indent=2) + "\n")
    print(f"Wrote {dest}")
    print("allowed_origins:", out["allowed_origins"])
    wrote += 1
if wrote < 1:
    print("install: no enabled chromium browsers in registry", file=sys.stderr)
    sys.exit(1)
PY

install -m0644 \
  "${ROOT}/systemd/user/alkitect-browser-tabs.service.example" \
  "${SYSTEMD_USER}/alkitect-browser-tabs.service"

# Shell extension files (enable after logout/in — Wayland)
EXT_UUID="browser-tab-dock@alkitect"
EXT_DST="${HOME}/.local/share/gnome-shell/extensions/${EXT_UUID}"
mkdir -p "${EXT_DST}"
install -m0644 "${ROOT}/shell-extension/metadata.json" "${EXT_DST}/metadata.json"
install -m0644 "${ROOT}/shell-extension/extension.js" "${EXT_DST}/extension.js"

if [[ -z "${ALKITECT_CI_TMP:-}" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload
  if [[ "${ENABLE_AUTOMATION}" -eq 1 ]]; then
    systemctl --user enable --now alkitect-browser-tabs.service
    echo "Enabled alkitect-browser-tabs.service"
  else
    echo "Units installed; enable with: systemctl --user enable --now alkitect-browser-tabs.service"
    echo "Or re-run: $0 --enable-automation"
  fi
elif [[ -n "${ALKITECT_CI_TMP:-}" ]]; then
  echo "ALKITECT_CI_TMP=1: skipped systemctl (unit file installed under tmp HOME only)"
fi

echo
echo "Next (Brave — only enabled browser at shared-prep):"
echo "  1. brave://extensions → Developer mode → Load unpacked:"
echo "       ${ROOT}/browser-extension"
echo "  2. Confirm extension ID is ${EXT_ID}"
echo "  3. Fully quit and relaunch Brave"
echo "  4. browser-tabs-host cli status && browser-tabs-host cli list --browser brave"
echo
echo "Next (Shell hover peek — Wayland needs logout/in):"
echo "  gnome-extensions enable ${EXT_UUID}"
echo "  then log out and back in"
echo "  Hover Brave dock icon (1 window, ≥2 tabs) → tab list"
echo "  Click icon → still minimize-or-previews (unchanged)"
echo "  ./scripts/verify-e2e.sh   # human checklist"
