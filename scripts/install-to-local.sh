#!/usr/bin/env bash
# Install browser-tabs host + NM manifest + systemd user unit.
# Usage: install-to-local.sh [--enable-automation]
# Does not load the Brave extension (manual: brave://extensions → Load unpacked).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${HOME}/.local/bin"
SYSTEMD_USER="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
NM_DIR="${HOME}/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"
EXT_ID_FILE="${ROOT}/browser-extension/extension-id.txt"
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
EXT_ID="$(tr -d '[:space:]' <"${EXT_ID_FILE}")"

mkdir -p "${BIN}" "${SYSTEMD_USER}" "${NM_DIR}"

# Fail if install targets are group/world-writable (TODO-006)
for d in "${BIN}" "${NM_DIR}" "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"; do
  [[ -d "$d" ]] || continue
  mode="$(stat -c '%a' "$d" 2>/dev/null || true)"
  if [[ -n "$mode" && "$((8#${mode} & 8#022))" -ne 0 ]]; then
    echo "Refusing install: ${d} is group/world-writable (mode ${mode})" >&2
    exit 1
  fi
done

install -m0755 "${ROOT}/host/browser_tabs_host.py" "${BIN}/browser-tabs-host"
# Chromium NM entry must take no required args
cat >"${BIN}/browser-tabs-nm" <<EOF
#!/usr/bin/env bash
exec "${BIN}/browser-tabs-host" native "\$@"
EOF
chmod 0755 "${BIN}/browser-tabs-nm"

# NM manifest: absolute path, single allowed_origins id
NM_JSON="${NM_DIR}/org.alkitect.browser_tabs.json"
python3 - <<PY
import json
from pathlib import Path
tmpl = Path("${ROOT}/native-messaging/org.alkitect.browser_tabs.json.template")
data = json.loads(tmpl.read_text())
data["path"] = str(Path("${BIN}/browser-tabs-nm").resolve())
data["allowed_origins"] = [f"chrome-extension://${EXT_ID}/"]
Path("${NM_JSON}").write_text(json.dumps(data, indent=2) + "\n")
print("Wrote ${NM_JSON}")
print("allowed_origins:", data["allowed_origins"])
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
echo "Next (Brave):"
echo "  1. brave://extensions → Developer mode → Load unpacked:"
echo "       ${ROOT}/browser-extension"
echo "  2. Confirm extension ID is ${EXT_ID}"
echo "  3. Fully quit and relaunch Brave"
echo "  4. browser-tabs-host cli status && browser-tabs-host cli list"
echo
echo "Next (Shell hover peek — Wayland needs logout/in):"
echo "  gnome-extensions enable ${EXT_UUID}"
echo "  then log out and back in"
echo "  Hover Brave dock icon (1 window, ≥2 tabs) → tab list"
echo "  Click icon → still minimize-or-previews (unchanged)"
echo "  ./scripts/verify-e2e.sh   # human checklist"
