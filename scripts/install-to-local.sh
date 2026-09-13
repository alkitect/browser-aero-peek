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

# Snap Chromium: cannot exec ~/.local/bin or host XDG_RUNTIME_DIR socks (AppArmor).
# Bridge lives under ~/bin (non-hidden). Bake absolute paths — Snap remaps \$HOME to
# ~/snap/chromium/<rev>/ so "\${HOME}/bin/..." resolves inside the snap tree and 404s.
HOME_BIN="${HOME}/bin"
SNAP_SOCK="${HOME}/alkitect-browser-tabs/browser-tabs.sock"
mkdir -p "${HOME_BIN}" "$(dirname "${SNAP_SOCK}")"
install -m0755 "${BIN}/browser-tabs-host" "${HOME_BIN}/browser-tabs-host"
cat >"${HOME_BIN}/browser-tabs-nm-snap" <<EOF
#!/usr/bin/env bash
export ALKITECT_BROWSER_TABS_SOCK="${SNAP_SOCK}"
exec "${HOME_BIN}/browser-tabs-host" native "\$@"
EOF
chmod 0755 "${HOME_BIN}/browser-tabs-nm-snap"

# Stage MV3 copies with forced browserId for confined / ambiguous-UA lanes.
# Native Brave/Chrome/Opera deb use shared browser-extension/ (no forced id).
python3 - <<PY
import json
import shutil
from pathlib import Path

root = Path("${ROOT}")
share = Path("${SHARE_DIR}")
src = root / "browser-extension"
data = json.loads(Path("${BROWSERS_JSON}").read_text())

def needs_stage(entry: dict) -> bool:
    if not entry.get("enabled"):
        return False
    bid = entry["id"]
    if entry.get("nm_schema") == "mozilla":
        return True
    if entry.get("packaging") in ("snap", "flatpak"):
        return True
    if bid in ("vivaldi", "edge"):
        return True
    return False

for entry in data["browsers"]:
    if not needs_stage(entry):
        continue
    bid = entry["id"]
    dest = share / f"mv3-{bid}"
    if dest.exists():
        shutil.rmtree(dest)
    dest.mkdir(parents=True)
    shutil.copytree(src, dest, dirs_exist_ok=True)
    (dest / "forced-browser-id.js").write_text(f'var FORCED_BROWSER_ID = "{bid}";\n')
    manifest_path = dest / "manifest.json"
    m = json.loads(manifest_path.read_text())
    if entry.get("nm_schema") == "mozilla":
        # Firefox Snap: service_worker disabled; Chromium-only favicon rejected.
        m["background"] = {"scripts": ["forced-browser-id.js", "background.js"]}
        m.pop("key", None)
        m["permissions"] = [p for p in (m.get("permissions") or []) if p != "favicon"]
        manifest_path.write_text(json.dumps(m, indent=2) + "\n")
        print(f"Staged {dest.name}: mozilla background.scripts + forced id")
    else:
        print(f"Staged {dest.name}: forced id (service_worker)")
PY

# NM manifests: enabled chromium + mozilla schema browsers.
python3 - <<PY
import json
import os
import sys
from pathlib import Path

root = Path("${ROOT}")
ext_id = "${EXT_ID}"
ff_id = (root / "browser-extension/firefox-extension-id.txt").read_text().strip()
bin_nm = str(Path("${BIN}/browser-tabs-nm").resolve())
bin_nm_flatpak = str(Path("${BIN}/browser-tabs-nm-flatpak").resolve())
bin_nm_snap = str((Path.home() / "bin" / "browser-tabs-nm-snap").resolve())
home = Path.home()
cfg_home = Path(os.environ.get("XDG_CONFIG_HOME") or (home / ".config"))
data = json.loads(Path("${BROWSERS_JSON}").read_text())
tmpl_chromium = json.loads((root / "native-messaging/org.alkitect.browser_tabs.json.template").read_text())
tmpl_mozilla = json.loads((root / "native-messaging/org.alkitect.browser_tabs.mozilla.json.template").read_text())
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

def write_nm_chromium(nm_dir: Path, path: str) -> None:
    harden_dir(nm_dir)
    out = dict(tmpl_chromium)
    out["path"] = path
    out["allowed_origins"] = [f"chrome-extension://{ext_id}/"]
    dest = nm_dir / "org.alkitect.browser_tabs.json"
    dest.write_text(json.dumps(out, indent=2) + "\n")
    print(f"Wrote {dest}")
    print("path:", out["path"])
    print("allowed_origins:", out["allowed_origins"])

def write_nm_mozilla(nm_dir: Path, path: str) -> None:
    harden_dir(nm_dir)
    out = dict(tmpl_mozilla)
    out["path"] = path
    out["allowed_extensions"] = [ff_id]
    if "allowed_origins" in out:
        del out["allowed_origins"]
    dest = nm_dir / "org.alkitect.browser_tabs.json"
    dest.write_text(json.dumps(out, indent=2) + "\n")
    print(f"Wrote {dest}")
    print("path:", out["path"])
    print("allowed_extensions:", out["allowed_extensions"])

def nm_bin_for(entry) -> str:
    # Mozilla lanes share ~/.mozilla portal NM JSON — use home-sock bridge for Snap,
    # Flatpak portal host spawn, and Mozilla .deb (daemon already listens on home sock).
    if entry.get("nm_schema") == "mozilla":
        return bin_nm_snap
    pkg = entry.get("packaging")
    if pkg == "flatpak":
        return bin_nm_flatpak
    if pkg == "snap":
        return bin_nm_snap
    return bin_nm

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
    if schema not in ("chromium", "mozilla"):
        print(f"install: skip enabled unknown schema {bid} (schema={schema})", file=sys.stderr)
        continue
    nm_bin = nm_bin_for(entry)
    if schema == "chromium":
        write_nm_chromium(resolve_nm_dir(entry, nm_path), nm_bin)
        for alias in entry.get("nm_path_aliases") or []:
            write_nm_chromium(resolve_nm_dir(entry, alias), nm_bin)
    else:
        write_nm_mozilla(resolve_nm_dir(entry, nm_path), nm_bin)
        for alias in entry.get("nm_path_aliases") or []:
            write_nm_mozilla(resolve_nm_dir(entry, alias), nm_bin)
    wrote += 1

if wrote < 1:
    print("install: no enabled browsers in registry", file=sys.stderr)
    sys.exit(1)
PY

# Firefox: XDG portal looks up NM under ~/.mozilla/… (Snap + Flatpak).
# Grant webextensions permission for our host name (same store KeePassXC uses).
if command -v flatpak >/dev/null 2>&1; then
  python3 - <<PY
import json, subprocess
from pathlib import Path
data = json.loads(Path("${BROWSERS_JSON}").read_text())
grants = []
for e in data["browsers"]:
    if not e.get("enabled") or e.get("nm_schema") != "mozilla":
        continue
    pkg = e.get("packaging")
    if pkg == "snap":
        grants.append("snap.firefox")
    elif pkg == "flatpak" and e.get("flatpak_id"):
        grants.append(e["flatpak_id"])
for app in dict.fromkeys(grants):
    r = subprocess.run(
        ["flatpak", "permission-set", "webextensions", "org.alkitect.browser_tabs", app, "yes"],
        capture_output=True,
    )
    if r.returncode == 0:
        print(f"flatpak permission-set webextensions org.alkitect.browser_tabs {app} yes")
    else:
        print(f"install: warn — could not set webextensions portal permission for {app}")
PY
fi

# Stage Temporary Add-on .xpi per enabled mozilla lane (Snap needs non-hidden snap-common path).
python3 - <<PY
import json, shutil, zipfile
from pathlib import Path

home = Path.home()
share = Path("${SHARE_DIR}")
data = json.loads(Path("${BROWSERS_JSON}").read_text())
names = ["manifest.json", "forced-browser-id.js", "background.js"]

def write_xpi(src: Path, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(dest, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name in names:
            zf.write(src / name, arcname=name)
    print(f"Staged Firefox Temporary Add-on xpi: {dest}")

for e in data["browsers"]:
    if not e.get("enabled") or e.get("nm_schema") != "mozilla":
        continue
    bid = e["id"]
    staged = share / f"mv3-{bid}"
    if not staged.is_dir():
        continue
    home_dir = home / "alkitect-browser-tabs" / f"mv3-{bid}"
    home_xpi = home / "alkitect-browser-tabs" / f"mv3-{bid}.xpi"
    if home_dir.exists():
        shutil.rmtree(home_dir)
    shutil.copytree(staged, home_dir)
    write_xpi(staged, home_xpi)
    if e.get("packaging") == "snap":
        snap_dir = home / "snap/firefox/common/alkitect-mv3-firefox"
        snap_xpi = home / "snap/firefox/common/alkitect-mv3-firefox.xpi"
        if snap_dir.exists():
            shutil.rmtree(snap_dir)
        shutil.copytree(staged, snap_dir)
        write_xpi(staged, snap_xpi)
        print(f"Staged Snap-visible Firefox MV3 dir: {snap_dir}")
PY

# Firefox Snap: force NM via XDG portal (bug 1930119 / KeePassXC). Pref applies on next Firefox start.
FF_PROFILES="${HOME}/snap/firefox/common/.mozilla/firefox"
if [[ -d "${FF_PROFILES}" ]]; then
  while IFS= read -r -d '' prefs; do
    prof="$(dirname "${prefs}")"
    cat >"${prof}/user.js" <<'EOF'
// browser-aero-peek: Snap native messaging via XDG desktop portal
user_pref("widget.use-xdg-desktop-portal.native-messaging", 2);
EOF
    echo "Wrote ${prof}/user.js (portal native-messaging=2)"
  done < <(find "${FF_PROFILES}" -mindepth 2 -maxdepth 2 -name prefs.js -print0 2>/dev/null)
fi

# Flatpak Firefox: same portal pref on profiles under XDG config inside the app.
FF_FP_PROFILES="${HOME}/.var/app/org.mozilla.firefox/config/mozilla/firefox"
if [[ -d "${FF_FP_PROFILES}" ]]; then
  while IFS= read -r -d '' prefs; do
    prof="$(dirname "${prefs}")"
    cat >"${prof}/user.js" <<'EOF'
// browser-aero-peek: Flatpak native messaging via XDG desktop portal
user_pref("widget.use-xdg-desktop-portal.native-messaging", 2);
EOF
    echo "Wrote ${prof}/user.js (portal native-messaging=2)"
  done < <(find "${FF_FP_PROFILES}" -mindepth 2 -maxdepth 2 -name prefs.js -print0 2>/dev/null)
fi

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
python3 - <<PY
import json
from pathlib import Path
root = Path("${ROOT}")
share = Path("${SHARE_DIR}")
ext_id = "${EXT_ID}"
data = json.loads(Path("${BROWSERS_JSON}").read_text())
print("Next (enabled browsers — load MV3; Tor stays Out until TOR-FEASIBILITY PASS):")
for e in data["browsers"]:
    if not e.get("enabled"):
        continue
    bid = e["id"]
    pkg = e.get("packaging", "native")
    staged = share / f"mv3-{bid}"
    if e.get("nm_schema") == "mozilla":
        home_xpi = Path.home() / "alkitect-browser-tabs" / f"mv3-{bid}.xpi"
        if e.get("packaging") == "snap":
            snap_xpi = Path.home() / "snap/firefox/common/alkitect-mv3-firefox.xpi"
            xpi = snap_xpi if snap_xpi.is_file() else home_xpi
        else:
            xpi = home_xpi
        print(f"  {bid} ({pkg}): about:debugging → Load Temporary Add-on → {xpi}")
        print("       IMPORTANT: load the .xpi (not manifest.json). Snap/Flatpak portals often expose only one file;")
        print("       a folder/manifest pick yields Location /run/user/*/doc/… with no background.js.")
        print(f"       gecko id browser-tab-dock@alkitect; forced browserId={bid}; portal NM ~/.mozilla")
        print("       Temporary add-ons unload when Firefox quits — reload .xpi after every restart")
        print(f"       Then: browser-tabs-host cli list --browser {bid}  (must show tabs before hover works)")
    elif staged.is_dir():
        print(f"  {bid} ({pkg}): extensions → Load unpacked → {staged}")
        print(f"       forced hello browserId={bid}; same Chromium extension ID {ext_id}")
    else:
        print(f"  {bid} ({pkg}): extensions → Load unpacked → {root / 'browser-extension'}")
print(f"  Confirm Chromium-family ID is {ext_id}; fully quit and relaunch each browser")
print("  browser-tabs-host cli status")
ids = "|".join(e["id"] for e in data["browsers"] if e.get("enabled"))
print(f"  browser-tabs-host cli list --browser {ids}")
PY
echo
echo "Next (Shell hover peek — Wayland needs ONE logout/in after this install):"
echo "  gnome-extensions enable ${EXT_UUID}"
echo "  then log out and back in once"
echo "  Hover each installed enabled browser dock icon (1 window, ≥2 tabs)"
echo "  ./scripts/verify-e2e.sh   # human checklist"
