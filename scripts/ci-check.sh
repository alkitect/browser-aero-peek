#!/usr/bin/env bash
# Release gate for browser-aero-peek (local + CI).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# Patterns encoded so this file is not a false positive.
_p1='Python/'
_p2='Linux'
_p3='.cursor/plans'
_p4='topics/gnome-browser-tab-dock'
_p5='topics/gnome-browser-aero-peek'
FORBIDDEN_RE="${_p1}${_p2}|${_p3}|${_p4}|${_p5}"

hits="$(grep -rE "${FORBIDDEN_RE}" \
  --include='*.sh' --include='*.md' --include='*.js' --include='*.py' --include='*.json' --include='*.example' --include='*.template' . \
  --exclude-dir=.git --exclude-dir=__pycache__ \
  --exclude='ci-check.sh' 2>/dev/null || true)"
if [[ -n "${hits}" ]]; then
  echo "ci-check: forbidden path refs found:" >&2
  echo "${hits}" >&2
  exit 1
fi

REQUIRED_H2=(
  "## What this does"
  "## Who this is for"
  "## Quick start"
  "## Check it works"
  "## Uninstall"
  "## Limits & safety"
  "## License"
)
for h in "${REQUIRED_H2[@]}"; do
  grep -qFx "${h}" README.md || { echo "ci-check: README missing H2: ${h}" >&2; exit 1; }
done
if grep -qE '\bSSOT\b' README.md; then
  echo "ci-check: README must not use SSOT; say release source" >&2
  exit 1
fi

[[ -f .github/FUNDING.yml ]] || { echo "ci-check: missing .github/FUNDING.yml" >&2; exit 1; }
grep -qE '^[[:space:]]*ko_fi:[[:space:]]*alkitect[[:space:]]*$' .github/FUNDING.yml \
  || { echo "ci-check: .github/FUNDING.yml must set ko_fi: alkitect" >&2; exit 1; }
grep -qF 'ko-fi.com/alkitect' README.md \
  || { echo "ci-check: README must include Ko-fi tip link ko-fi.com/alkitect" >&2; exit 1; }
grep -qF 'ko-fi.com/img/githubbutton_sm.svg' README.md \
  || { echo "ci-check: README must include Ko-fi GitHub button (githubbutton_sm.svg)" >&2; exit 1; }
if grep -qiE 'patreon\.com|buymeacoffee\.com' README.md; then
  echo "ci-check: README must not link Patreon or Buy Me a Coffee" >&2
  exit 1
fi

grep -qF 'GPL-3.0' README.md || { echo "ci-check: README License must mention GPL-3.0" >&2; exit 1; }
[[ -f LICENSE ]] || { echo "ci-check: missing LICENSE" >&2; exit 1; }
[[ -f docs/SECURITY.md ]] || { echo "ci-check: missing docs/SECURITY.md" >&2; exit 1; }
grep -qF 'Trust boundary' docs/SECURITY.md \
  || { echo "ci-check: SECURITY.md missing Trust boundary" >&2; exit 1; }
grep -qF 'allowed_origins' docs/SECURITY.md \
  || { echo "ci-check: SECURITY.md missing allowed_origins" >&2; exit 1; }
if grep -qi 'interim' docs/SECURITY.md; then
  echo "ci-check: SECURITY.md must not say interim" >&2
  exit 1
fi

# Secrets must not exist in the tree
if find . \( -name '*.pem' -o -name 'manifest-key.txt' \) -o \( -type d -name private \) \
  ! -path './.git/*' | grep -q .; then
  echo "ci-check: forbidden secret paths present:" >&2
  find . \( -name '*.pem' -o -name 'manifest-key.txt' \) -o \( -type d -name private \) ! -path './.git/*' >&2 || true
  exit 1
fi

# NM template: single origin, no wildcard
tmpl=native-messaging/org.alkitect.browser_tabs.json.template
[[ -f "${tmpl}" ]] || { echo "ci-check: missing ${tmpl}" >&2; exit 1; }
if grep -qF 'chrome-extension://*/' "${tmpl}"; then
  echo "ci-check: NM template must not use wildcard allowed_origins" >&2
  exit 1
fi
grep -qF 'EXT_ID_PLACEHOLDER' "${tmpl}" \
  || { echo "ci-check: NM template missing EXT_ID_PLACEHOLDER" >&2; exit 1; }

# Version triad: First public tag stays v0.2.9; current release must match MV3 + CHANGELOG
grep -qF 'First public tag: v0.2.9' docs/PUBLISH.md \
  || { echo "ci-check: docs/PUBLISH.md must record First public tag: v0.2.9" >&2; exit 1; }
grep -qF 'Current tag: v0.4.0' docs/PUBLISH.md \
  || { echo "ci-check: docs/PUBLISH.md must record Current tag: v0.4.0" >&2; exit 1; }
python3 - <<'PY'
import json, sys
from pathlib import Path
v = json.loads(Path("browser-extension/manifest.json").read_text())["version"]
if v != "0.4.0":
    print(f"ci-check: MV3 version {v!r} != 0.4.0", file=sys.stderr)
    sys.exit(1)
PY
grep -qE '^## 0\.4\.0' CHANGELOG.md \
  || { echo "ci-check: CHANGELOG missing ## 0.4.0" >&2; exit 1; }

# Absolute home paths (any username) must not appear in shipped sources.
# Encoded so this script does not embed a concrete account name.
if grep -rE '/home/[A-Za-z0-9._-]+' --include='*.md' --include='*.sh' --include='*.py' --include='*.js' \
  --include='*.json' --include='*.example' --include='*.template' . \
  --exclude-dir=.git --exclude='ci-check.sh' >/dev/null 2>&1; then
  echo "ci-check: must not contain absolute /home/<user> paths" >&2
  grep -rE '/home/[A-Za-z0-9._-]+' --include='*.md' --include='*.sh' --include='*.py' --include='*.js' \
    --include='*.json' --include='*.example' --include='*.template' . \
    --exclude-dir=.git --exclude='ci-check.sh' >&2 || true
  exit 1
fi
# Also ban macOS-style absolute user homes
if grep -rE '/Users/[A-Za-z0-9._-]+' --include='*.md' --include='*.sh' --include='*.py' --include='*.js' . \
  --exclude-dir=.git --exclude='ci-check.sh' >/dev/null 2>&1; then
  echo "ci-check: must not contain absolute /Users/<user> paths" >&2
  exit 1
fi

if [[ -f docs/PUBLISH.md ]] && grep -qF 'RC-BEFORE-1.0' docs/PUBLISH.md; then
  :
else
  if grep -qE '^## 0\.9\.0' CHANGELOG.md; then
    echo "ci-check: CHANGELOG ## 0.9.0 needs RC-BEFORE-1.0 in PUBLISH" >&2
    exit 1
  fi
  for _vf in docs/PUBLISH.md README.md; do
    if [[ -f "${_vf}" ]] && grep -qE 'v0\.9\.0' "${_vf}"; then
      echo "ci-check: ${_vf} mentions v0.9.0 without RC-BEFORE-1.0" >&2
      exit 1
    fi
  done
fi

[[ -f config/browsers.json ]] || { echo "ci-check: missing config/browsers.json" >&2; exit 1; }
[[ -f docs/BROWSER-SUPPORT.md ]] || { echo "ci-check: missing docs/BROWSER-SUPPORT.md" >&2; exit 1; }

# Registry SSOT: schema, relative nm_path, Brave+Chrome+Opera deb+Flatpak enabled
python3 - <<'PY'
import json, sys
from pathlib import Path
ALLOWED = {"chromium", "mozilla"}
ALLOWED_KEYS = {
    "id", "enabled", "nm_schema", "nm_path", "nm_base", "nm_path_aliases",
    "desktop_ids", "wm_classes", "family", "packaging", "flatpak_id", "flatpak_filesystem",
    "flatpak_talk_names",
}
data = json.loads(Path("config/browsers.json").read_text())
browsers = data.get("browsers")
if not isinstance(browsers, list) or not browsers:
    print("ci-check: browsers.json empty", file=sys.stderr)
    sys.exit(1)
enabled = []
for e in browsers:
    unknown = set(e) - ALLOWED_KEYS
    if unknown:
        print(f"ci-check: unknown keys {sorted(unknown)}", file=sys.stderr)
        sys.exit(1)
    bid = e.get("id")
    schema = e.get("nm_schema")
    nm_path = e.get("nm_path") or ""
    nm_base = e.get("nm_base") or "xdg_config"
    if nm_base not in ("xdg_config", "home"):
        print(f"ci-check: bad nm_base {nm_base!r} for {bid}", file=sys.stderr)
        sys.exit(1)
    if schema not in ALLOWED:
        print(f"ci-check: bad nm_schema {schema!r} for {bid}", file=sys.stderr)
        sys.exit(1)
    if nm_path.startswith("/") or nm_path.startswith("~") or ".." in Path(nm_path).parts:
        print(f"ci-check: nm_path must be profile-relative ({bid})", file=sys.stderr)
        sys.exit(1)
    for alias in e.get("nm_path_aliases") or []:
        if alias.startswith("/") or alias.startswith("~") or ".." in Path(alias).parts:
            print(f"ci-check: bad nm_path_aliases for {bid}", file=sys.stderr)
            sys.exit(1)
    # Wrong-schema negative: chromium must not use mozilla path shape.
    if schema == "chromium" and "native-messaging-hosts" in nm_path.replace("\\", "/"):
        print(f"ci-check: chromium entry {bid} must not use mozilla nm_path shape", file=sys.stderr)
        sys.exit(1)
    if schema == "mozilla" and nm_path.rstrip("/").endswith("NativeMessagingHosts"):
        print(f"ci-check: mozilla entry {bid} must not use Chromium NativeMessagingHosts path", file=sys.stderr)
        sys.exit(1)
    if e.get("enabled"):
        enabled.append(bid)
if enabled != ["brave", "chrome", "opera", "opera-flatpak"]:
    print(f"ci-check: enabled browsers must be exactly ['brave', 'chrome', 'opera', 'opera-flatpak'], got {enabled!r}", file=sys.stderr)
    sys.exit(1)
print("ci-check: browsers.json OK")
PY

find scripts -type f -name '*.sh' -print0 | xargs -0 -r bash -n
python3 -m py_compile host/browser_tabs_host.py

# Source-only shell-fake (before install; ignore stale real-HOME install)
./scripts/verify-shell-fake.sh --source-only

tmp="$(mktemp -d)"
cleanup() { rm -rf "${tmp}"; }
trap cleanup EXIT
export HOME="${tmp}"
export XDG_CONFIG_HOME="${tmp}/.config"
export XDG_STATE_HOME="${tmp}/.local/state"
export XDG_RUNTIME_DIR="${tmp}/run"
mkdir -p "${XDG_CONFIG_HOME}" "${XDG_STATE_HOME}" "${XDG_RUNTIME_DIR}" \
  "${tmp}/.local/bin" \
  "${tmp}/.local/share/gnome-shell/extensions" \
  "${tmp}/.config/systemd/user"
# Pre-create parent dirs for ALL registry nm_paths (enabled + disabled) so absence asserts are meaningful.
python3 - <<'PY'
import json, os, stat
from pathlib import Path
home = Path(os.environ["HOME"])
cfg = Path(os.environ["XDG_CONFIG_HOME"])
data = json.loads(Path("config/browsers.json").read_text())

def resolve(e, rel):
    base = e.get("nm_base") or "xdg_config"
    return (home / rel) if base == "home" else (cfg / rel)

for e in data["browsers"]:
    rels = [e["nm_path"]] + list(e.get("nm_path_aliases") or [])
    for rel in rels:
        resolve(e, rel).mkdir(parents=True, exist_ok=True)
for root in (cfg, home / ".var"):
    if not root.exists():
        continue
    for dirpath, _dirnames, _filenames in os.walk(root):
        mode = os.stat(dirpath).st_mode
        if mode & (stat.S_IWGRP | stat.S_IWOTH):
            os.chmod(dirpath, 0o755)
PY
chmod 755 "${tmp}" "${tmp}/.local" "${tmp}/.local/bin" "${tmp}/.config" \
  "${tmp}/.local/share" "${tmp}/.local/share/gnome-shell" \
  "${tmp}/.local/share/gnome-shell/extensions" \
  "${tmp}/.config/systemd" "${tmp}/.config/systemd/user" \
  "${XDG_CONFIG_HOME}" "${XDG_STATE_HOME}"
chmod 700 "${XDG_RUNTIME_DIR}"
export ALKITECT_CI_TMP=1
export PATH="${tmp}/.local/bin:${PATH}"

"${ROOT}/scripts/install-to-local.sh"
test -x "${tmp}/.local/bin/browser-tabs-host"
test -f "${tmp}/.config/alkitect-browser-tabs/browsers.json"
test -f "${tmp}/.local/share/gnome-shell/extensions/browser-tab-dock@alkitect/extension.js"
test -f "${tmp}/.config/systemd/user/alkitect-browser-tabs.service"
test -f "${tmp}/.local/share/alkitect-browser-tabs/mv3-opera-flatpak/forced-browser-id.js"
test -f "${tmp}/.local/share/alkitect-browser-tabs/mv3-opera-flatpak/manifest.json"

# Installed path must satisfy shell-fake greps
./scripts/verify-shell-fake.sh

# Multi-NM: enabled positive (single origin) + disabled absent after install
python3 - <<'PY'
import json, os, sys
from pathlib import Path
ext = Path("browser-extension/extension-id.txt").read_text().strip()
home = Path(os.environ["HOME"])
cfg = Path(os.environ["XDG_CONFIG_HOME"])
data = json.loads(Path("config/browsers.json").read_text())

def resolve(e, rel):
    base = e.get("nm_base") or "xdg_config"
    return (home / rel) if base == "home" else (cfg / rel)

for e in data["browsers"]:
    rels = [e["nm_path"]] + list(e.get("nm_path_aliases") or [])
    for rel in rels:
        dest = resolve(e, rel) / "org.alkitect.browser_tabs.json"
        if e.get("enabled"):
            if not dest.is_file():
                print(f"ci-check: missing NM for enabled {e['id']}: {dest}", file=sys.stderr)
                sys.exit(1)
            nm = json.loads(dest.read_text())
            origins = nm.get("allowed_origins") or []
            if origins != [f"chrome-extension://{ext}/"]:
                print(f"ci-check: allowed_origins {origins!r} != single id {ext}", file=sys.stderr)
                sys.exit(1)
            if any("*" in o for o in origins):
                print("ci-check: wildcard origin forbidden", file=sys.stderr)
                sys.exit(1)
        else:
            if dest.exists():
                print(f"ci-check: disabled browser {e['id']} must not have NM JSON after install: {dest}", file=sys.stderr)
                sys.exit(1)
print("ci-check: multi-NM enabled/disabled OK")
PY

# Host CLI multiplex + foreign-Activate (requires python3-gi)
./scripts/verify-host-cli.sh

"${ROOT}/scripts/uninstall-from-local.sh"
test ! -e "${tmp}/.local/bin/browser-tabs-host"
test ! -e "${tmp}/.config/alkitect-browser-tabs/browsers.json"
test ! -e "${tmp}/.local/share/gnome-shell/extensions/browser-tab-dock@alkitect"
test ! -e "${tmp}/.local/share/alkitect-browser-tabs/mv3-opera-flatpak"
python3 - <<'PY'
import json, os, sys
from pathlib import Path
home = Path(os.environ["HOME"])
cfg = Path(os.environ["XDG_CONFIG_HOME"])
data = json.loads(Path("config/browsers.json").read_text())

def resolve(e, rel):
    base = e.get("nm_base") or "xdg_config"
    return (home / rel) if base == "home" else (cfg / rel)

for e in data["browsers"]:
    rels = [e["nm_path"]] + list(e.get("nm_path_aliases") or [])
    for rel in rels:
        dest = resolve(e, rel) / "org.alkitect.browser_tabs.json"
        if dest.exists():
            print(f"ci-check: NM left after uninstall: {dest}", file=sys.stderr)
            sys.exit(1)
print("ci-check: uninstall cleared all NM JSON")
PY

echo "ci-check: PASS"
