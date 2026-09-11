#!/usr/bin/env bash
# Reverse install-to-local.sh (does not remove browser extension loads).
# Removes NM JSON for every registry nm_path (+ aliases); drops staged Flatpak MV3 copy.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${HOME}/.local/bin"
SYSTEMD_USER="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
CFG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/alkitect-browser-tabs"
SHARE_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/alkitect-browser-tabs"
BROWSERS_JSON="${ROOT}/config/browsers.json"

# Under tmp-HOME ci-check: only remove files; do not touch live user systemd / Shell.
if [[ -z "${ALKITECT_CI_TMP:-}" ]]; then
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now alkitect-browser-tabs.service 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
  fi
fi

rm -f "${SYSTEMD_USER}/alkitect-browser-tabs.service"
rm -f "${BIN}/browser-tabs-host" "${BIN}/browser-tabs-nm" "${BIN}/browser-tabs-nm-flatpak"
rm -rf "${CFG_DIR}"
rm -rf "${SHARE_DIR}/mv3-opera-flatpak"
rm -rf "${SHARE_DIR}/mv3-vivaldi"

if [[ -f "${BROWSERS_JSON}" ]]; then
  python3 - <<PY
import json, os
from pathlib import Path
home = Path.home()
cfg_home = Path(os.environ.get("XDG_CONFIG_HOME") or (home / ".config"))
data = json.loads(Path("${BROWSERS_JSON}").read_text())

def resolve(entry, rel):
    base = entry.get("nm_base") or "xdg_config"
    if base == "home":
        return home / rel
    return cfg_home / rel

for entry in data["browsers"]:
    paths = [entry.get("nm_path") or ""] + list(entry.get("nm_path_aliases") or [])
    for nm_path in paths:
        if not nm_path or nm_path.startswith("/") or ".." in Path(nm_path).parts:
            continue
        dest = resolve(entry, nm_path) / "org.alkitect.browser_tabs.json"
        try:
            dest.unlink()
            print(f"Removed {dest}")
        except FileNotFoundError:
            pass
PY
fi

if [[ -z "${ALKITECT_CI_TMP:-}" ]]; then
  gnome-extensions disable browser-tab-dock@alkitect 2>/dev/null || true
fi
rm -rf "${HOME}/.local/share/gnome-shell/extensions/browser-tab-dock@alkitect"
echo "Uninstalled host / NM manifest(s) / systemd unit / shell extension files"
echo "Note: Flatpak overrides left in place if set; reset with:"
echo "  flatpak override --user --nofilesystem=~/.local/bin --nofilesystem=~/.local/share/alkitect-browser-tabs --no-talk-name=org.freedesktop.Flatpak com.opera.Opera"
