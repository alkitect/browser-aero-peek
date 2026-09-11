#!/usr/bin/env bash
# Install browser-tabs host + NM manifest(s) + systemd user unit.
# Usage: install-to-local.sh [--enable-automation]
# Writes NM only for enabled entries in config/browsers.json (never disabled nm_path).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${HOME}/.local/bin"
SYSTEMD_USER="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
CFG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/alkitect-browser-tabs"
SHARE_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/alkitect-browser-tabs"
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

mkdir -p "${BIN}" "${SYSTEMD_USER}" "${CFG_DIR}" "${SHARE_DIR}"

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

# Flatpak sandbox: no host Unix socket + no system gi — re-exec NM on the host.
cat >"${BIN}/browser-tabs-nm-flatpak" <<EOF
#!/usr/bin/env bash
exec flatpak-spawn --host "${BIN}/browser-tabs-nm" "\$@"
EOF
chmod 0755 "${BIN}/browser-tabs-nm-flatpak"

# Stage Flatpak-oriented MV3 copy with forced browser id (same extension-id / key).
FLATPAK_EXT="${SHARE_DIR}/mv3-opera-flatpak"
rm -rf "${FLATPAK_EXT}"
mkdir -p "${FLATPAK_EXT}"
cp -a "${ROOT}/browser-extension/." "${FLATPAK_EXT}/"
printf '%s\n' 'var FORCED_BROWSER_ID = "opera-flatpak";' >"${FLATPAK_EXT}/forced-browser-id.js"

# Vivaldi: reduced UA often looks like Chrome in the SW — stage forced id (same key/id).
VIVALDI_EXT="${SHARE_DIR}/mv3-vivaldi"
rm -rf "${VIVALDI_EXT}"
mkdir -p "${VIVALDI_EXT}"
cp -a "${ROOT}/browser-extension/." "${VIVALDI_EXT}/"
printf '%s\n' 'var FORCED_BROWSER_ID = "vivaldi";' >"${VIVALDI_EXT}/forced-browser-id.js"

# NM manifests: only enabled chromium-schema browsers (mozilla reserved for later waves).
python3 - <<PY
import json
import os
import sys
from pathlib import Path

root = Path("${ROOT}")
ext_id = "${EXT_ID}"
bin_nm = str(Path("${BIN}/browser-tabs-nm").resolve())
bin_nm_flatpak = str(Path("${BIN}/browser-tabs-nm-flatpak").resolve())
home = Path.home()
cfg_home = Path(os.environ.get("XDG_CONFIG_HOME") or (home / ".config"))
data = json.loads(Path("${BROWSERS_JSON}").read_text())
tmpl = json.loads((root / "native-messaging/org.alkitect.browser_tabs.json.template").read_text())
ALLOWED_KEYS = {
    "id", "enabled", "nm_schema", "nm_path", "nm_base", "nm_path_aliases",
    "desktop_ids", "wm_classes", "family", "packaging", "flatpak_id", "flatpak_filesystem",
    "flatpak_talk_names",
}
wrote = 0

def resolve_nm_dir(entry, rel: str) -> Path:
    base = entry.get("nm_base") or "xdg_config"
    if base == "xdg_config":
        return cfg_home / rel
    if base == "home":
        return home / rel
    raise ValueError(f"bad nm_base {base!r}")

def harden_dir(nm_dir: Path) -> None:
    nm_dir.mkdir(parents=True, exist_ok=True)
    mode = nm_dir.stat().st_mode
    if mode & 0o022:
        try:
            nm_dir.chmod(0o755)
        except OSError as e:
            print(f"Refusing install: {nm_dir} is group/world-writable and chmod failed ({e})", file=sys.stderr)
            sys.exit(1)
        if nm_dir.stat().st_mode & 0o022:
            print(f"Refusing install: {nm_dir} is still group/world-writable after chmod", file=sys.stderr)
            sys.exit(1)

def write_nm(nm_dir: Path, path: str) -> None:
    harden_dir(nm_dir)
    out = dict(tmpl)
    out["path"] = path
    out["allowed_origins"] = [f"chrome-extension://{ext_id}/"]
    dest = nm_dir / "org.alkitect.browser_tabs.json"
    dest.write_text(json.dumps(out, indent=2) + "\n")
    print(f"Wrote {dest}")
    print("path:", out["path"])
    print("allowed_origins:", out["allowed_origins"])

for entry in data["browsers"]:
    unknown = set(entry) - ALLOWED_KEYS
    if unknown:
        print(f"install: unknown keys {sorted(unknown)}", file=sys.stderr)
        sys.exit(1)
    bid = entry["id"]
    schema = entry.get("nm_schema")
    enabled = bool(entry.get("enabled"))
    nm_path = entry.get("nm_path") or ""
    if nm_path.startswith("/") or nm_path.startswith("~") or ".." in Path(nm_path).parts:
        print(f"install: bad nm_path for {bid}", file=sys.stderr)
        sys.exit(1)
    for alias in entry.get("nm_path_aliases") or []:
        if alias.startswith("/") or alias.startswith("~") or ".." in Path(alias).parts:
            print(f"install: bad nm_path_aliases for {bid}", file=sys.stderr)
            sys.exit(1)
    if not enabled:
        continue
    if schema != "chromium":
        print(f"install: skip enabled non-chromium {bid} (schema={schema})", file=sys.stderr)
        continue
    nm_bin = bin_nm_flatpak if entry.get("packaging") == "flatpak" else bin_nm
    write_nm(resolve_nm_dir(entry, nm_path), nm_bin)
    for alias in entry.get("nm_path_aliases") or []:
        write_nm(resolve_nm_dir(entry, alias), nm_bin)
    wrote += 1

if wrote < 1:
    print("install: no enabled chromium browsers in registry", file=sys.stderr)
    sys.exit(1)
PY

# Flatpak: host NM re-exec (talk-name) + staged MV3 path (documented in SECURITY.md).
if command -v flatpak >/dev/null 2>&1; then
  python3 - <<PY
import json, subprocess
from pathlib import Path
data = json.loads(Path("${BROWSERS_JSON}").read_text())
for entry in data["browsers"]:
    if not entry.get("enabled") or entry.get("packaging") != "flatpak":
        continue
    fid = entry.get("flatpak_id")
    if not fid:
        continue
    probe = subprocess.run(["flatpak", "info", fid], capture_output=True)
    if probe.returncode != 0:
        print(f"install: flatpak {fid} not installed — NM written; skip override")
        continue
    for fs in entry.get("flatpak_filesystem") or []:
        subprocess.run(["flatpak", "override", "--user", f"--filesystem={fs}", fid], check=False)
        print(f"flatpak override --user --filesystem={fs} {fid}")
    for name in entry.get("flatpak_talk_names") or []:
        subprocess.run(["flatpak", "override", "--user", f"--talk-name={name}", fid], check=False)
        print(f"flatpak override --user --talk-name={name} {fid}")
PY
fi

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
echo "Next (enabled browsers — Brave + Chrome + Opera deb + Opera Flatpak + Vivaldi):"
echo "  Brave:  brave://extensions  → Load unpacked → ${ROOT}/browser-extension"
echo "  Chrome: chrome://extensions → Load unpacked → ${ROOT}/browser-extension"
echo "  Opera (.deb): opera://extensions → Load unpacked → ${ROOT}/browser-extension"
echo "  Opera (Flatpak): opera://extensions → Remove portal loads → Load unpacked → ${FLATPAK_EXT}"
echo "       (forced hello browserId=opera-flatpak; NM via flatpak-spawn --host; same extension ID ${EXT_ID})"
echo "  Vivaldi: vivaldi://extensions → Remove shared-folder load → Load unpacked → ${VIVALDI_EXT}"
echo "       (forced hello browserId=vivaldi; same extension ID ${EXT_ID} — reduced UA looks like Chrome)"
echo "  Confirm ID is ${EXT_ID}; fully quit and relaunch each browser"
echo "  browser-tabs-host cli status"
echo "  browser-tabs-host cli list --browser brave|chrome|opera|opera-flatpak|vivaldi"
echo
echo "Next (Shell hover peek — Wayland needs logout/in):"
echo "  gnome-extensions enable ${EXT_UUID}"
echo "  then log out and back in"
echo "  Hover Brave / Chrome / Opera (.deb or Flatpak) / Vivaldi dock icon (1 window, ≥2 tabs)"
echo "  ./scripts/verify-e2e.sh   # human checklist"
