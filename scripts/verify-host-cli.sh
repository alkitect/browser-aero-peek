#!/usr/bin/env bash
# Daemon + fake NM peers over Unix socket + D-Bus CLI (no browser required).
# Exercises multiplex bind hello, scoped list/activate, foreign-Activate fail-closed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${ROOT}/host/browser_tabs_host.py"
# Prefer distro python3 (PyGObject); conda envs often lack gi.
PYTHON3="/usr/bin/python3"
[[ -x "${PYTHON3}" ]] || PYTHON3="$(command -v python3)"
export PATH="${HOME}/.local/bin:${PATH}"

if [[ ! -x "${HOME}/.local/bin/browser-tabs-host" ]]; then
  echo "Install first: ${ROOT}/scripts/install-to-local.sh --enable-automation" >&2
  exit 1
fi

"${PYTHON3}" -m py_compile "${HOST}"
"${PYTHON3}" -c 'import gi' || {
  echo "verify-host-cli: need PyGObject (python3-gi) on ${PYTHON3}" >&2
  exit 1
}

# Test registry: five enabled chromium peers for multiplex soak.
TMP_REG="$(mktemp)"
export ALKITECT_BROWSERS_JSON="${TMP_REG}"
python3 - <<PY
import json
from pathlib import Path
src = json.loads(Path("${ROOT}/config/browsers.json").read_text())
for e in src["browsers"]:
    e["enabled"] = e["id"] in ("brave", "chrome", "opera", "opera-flatpak", "vivaldi")
Path("${TMP_REG}").write_text(json.dumps(src, indent=2) + "\n")
PY

# Must use a daemon that loads the override (not a live user unit with shipped JSON).
STOPPED_UNIT=0
if systemctl --user is-active --quiet alkitect-browser-tabs.service 2>/dev/null; then
  echo "verify-host-cli: stopping alkitect-browser-tabs.service for registry override" >&2
  systemctl --user stop alkitect-browser-tabs.service || true
  STOPPED_UNIT=1
  sleep 0.3
fi

"${PYTHON3}" "${HOST}" daemon &
DAEMON_PID=$!
sleep 0.5

start_fake_peer() {
  local bid="$1"
  local t1="$2"
  local t2="$3"
  local t3="$4"
  # Do not capture via $() — bash waits for bg children in command substitution.
  "${PYTHON3}" - "$bid" "$t1" "$t2" "$t3" <<'PY' >/dev/null 2>&1 &
import json, os, socket, struct, sys, time
from pathlib import Path

browser_id, t1, t2, t3 = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4])
sock_path = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")) / "alkitect-browser-tabs.sock"
for _ in range(50):
    if sock_path.exists():
        break
    time.sleep(0.05)
s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
s.connect(str(sock_path))

def read_msg():
    hdr = s.recv(4)
    if len(hdr) < 4:
        return None
    (n,) = struct.unpack("<I", hdr)
    body = b""
    while len(body) < n:
        chunk = s.recv(n - len(body))
        if not chunk:
            return None
        body += chunk
    return json.loads(body.decode())

def write_msg(obj):
    payload = json.dumps(obj).encode()
    s.sendall(struct.pack("<I", len(payload)) + payload)

write_msg({"type": "hello", "browserId": browser_id})
tabs = [
    {"id": t1, "title": f"{browser_id}-A", "favIconUrl": ""},
    {"id": t2, "title": f"{browser_id}-B", "favIconUrl": "https://example.com/f.ico"},
    {"id": t3, "title": f"{browser_id}-C", "favIconUrl": ""},
]
ids = {t1, t2, t3}
while True:
    msg = read_msg()
    if msg is None:
        break
    t = msg.get("type")
    if t == "list":
        write_msg({"type": "list", "tabs": tabs})
    elif t == "activate":
        write_msg({"type": "activate", "ok": msg.get("tabId") in ids})
    elif t == "ping":
        write_msg({"type": "pong"})
    else:
        write_msg({"type": "error", "error": "unknown"})
PY
}

start_fake_peer brave 1 2 3
FAKE_BRAVE=$!
start_fake_peer chrome 10 20 30
FAKE_CHROME=$!
start_fake_peer opera 100 200 300
FAKE_OPERA=$!
start_fake_peer opera-flatpak 1000 2000 3000
FAKE_OPERA_FP=$!
start_fake_peer vivaldi 10000 20000 30000
FAKE_VIVALDI=$!

cleanup_all() {
  kill "${FAKE_BRAVE}" "${FAKE_CHROME}" "${FAKE_OPERA}" "${FAKE_OPERA_FP}" "${FAKE_VIVALDI}" 2>/dev/null || true
  kill "${DAEMON_PID}" 2>/dev/null || true
  rm -f "${TMP_REG}"
  if [[ "${STOPPED_UNIT}" -eq 1 ]]; then
    systemctl --user start alkitect-browser-tabs.service 2>/dev/null || true
  fi
}
trap cleanup_all EXIT
sleep 0.5

echo "=== status ==="
STATUS="$(browser-tabs-host cli status)"
echo "${STATUS}"
echo "${STATUS}" | python3 -c 'import json,sys; d=json.load(sys.stdin); p=set(d.get("peers",[])); assert p>={"brave","chrome","opera","opera-flatpak","vivaldi"}, d'

echo "=== list brave ==="
OUT="$(browser-tabs-host cli list --browser brave)"
echo "${OUT}"
OUT="${OUT}" python3 - <<'PY'
import json, os
tabs = json.loads(os.environ["OUT"])
assert len(tabs) >= 3, tabs
assert tabs[0]["title"] == "brave-A"
blob = json.dumps(tabs)
assert "http://" not in blob and "https://example.com/page" not in blob
assert tabs[1]["favicon"].startswith("https://")
print("list brave OK")
PY

echo "=== list chrome ==="
OUT_C="$(browser-tabs-host cli list --browser chrome)"
echo "${OUT_C}"
echo "${OUT_C}" | python3 -c 'import json,sys; t=json.load(sys.stdin); assert t[0]["title"]=="chrome-A", t'

echo "=== list opera ==="
OUT_O="$(browser-tabs-host cli list --browser opera)"
echo "${OUT_O}"
echo "${OUT_O}" | python3 -c 'import json,sys; t=json.load(sys.stdin); assert t[0]["title"]=="opera-A", t'

echo "=== list opera-flatpak ==="
OUT_OF="$(browser-tabs-host cli list --browser opera-flatpak)"
echo "${OUT_OF}"
echo "${OUT_OF}" | python3 -c 'import json,sys; t=json.load(sys.stdin); assert t[0]["title"]=="opera-flatpak-A", t'

echo "=== list vivaldi ==="
OUT_V="$(browser-tabs-host cli list --browser vivaldi)"
echo "${OUT_V}"
echo "${OUT_V}" | python3 -c 'import json,sys; t=json.load(sys.stdin); assert t[0]["title"]=="vivaldi-A", t'

echo "=== activate brave 2 ==="
browser-tabs-host cli activate --browser brave 2

echo "=== foreign Activate (chrome tab via brave key) ==="
if browser-tabs-host cli activate --browser brave 10 2>/tmp/alkitect-foreign-act.err; then
  echo "FAIL: expected foreign Activate to fail" >&2
  exit 1
fi
grep -qiE 'ForeignTab|Failed|Invalid' /tmp/alkitect-foreign-act.err \
  || { echo "FAIL: unexpected error text:"; cat /tmp/alkitect-foreign-act.err >&2; exit 1; }
echo "foreign Activate rejected OK"

echo "=== thumb prune scoped ==="
HOST_PATH="${HOST}" "${PYTHON3}" - <<'PY'
import importlib.util, os
from pathlib import Path
host = os.environ["HOST_PATH"]
spec = importlib.util.spec_from_file_location("browser_tabs_host", host)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)
base = mod.thumb_cache_dir()
for bid in ("brave", "chrome", "opera", "opera-flatpak", "vivaldi"):
    (base / bid).mkdir(parents=True, exist_ok=True)
    (base / bid / "tab-99.png").write_bytes(b"x")
assert mod.prune_thumb_files("brave", {1, 2, 3}) >= 1
assert (base / "chrome" / "tab-99.png").is_file()
assert (base / "opera-flatpak" / "tab-99.png").is_file()
assert (base / "vivaldi" / "tab-99.png").is_file()
for bid in ("chrome", "opera", "opera-flatpak", "vivaldi"):
    (base / bid / "tab-99.png").unlink()
print("thumb prune scoped OK")
PY

echo "PASS verify-host-cli"
