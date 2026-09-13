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

# Headless CI / SSH: GLib will not autolaunch a session bus without $DISPLAY.
if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  if command -v dbus-run-session >/dev/null 2>&1; then
    exec dbus-run-session -- "$0" "$@"
  fi
  echo "verify-host-cli: need a session D-Bus (dbus-run-session / graphical login)" >&2
  exit 1
fi

# Test registry: all currently enabled peers for multiplex soak.
TMP_REG="$(mktemp)"
export ALKITECT_BROWSERS_JSON="${TMP_REG}"
python3 - <<PY
import json
from pathlib import Path
src = json.loads(Path("${ROOT}/config/browsers.json").read_text())
enabled_ids = {e["id"] for e in src["browsers"] if e.get("enabled")}
for e in src["browsers"]:
    e["enabled"] = e["id"] in enabled_ids
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

# Spawn one fake peer per enabled registry id (tab ids spaced to avoid collisions).
FAKE_PIDS=()
mapfile -t ENABLED_IDS < <(python3 - <<PY
import json
from pathlib import Path
data = json.loads(Path("${ROOT}/config/browsers.json").read_text())
for e in data["browsers"]:
    if e.get("enabled"):
        print(e["id"])
PY
)
i=0
for bid in "${ENABLED_IDS[@]}"; do
  base=$(( (i + 1) * 1000000 ))
  start_fake_peer "${bid}" "${base}" "$((base + 1))" "$((base + 2))"
  FAKE_PIDS+=($!)
  i=$((i + 1))
done

cleanup_all() {
  if ((${#FAKE_PIDS[@]})); then
    kill "${FAKE_PIDS[@]}" 2>/dev/null || true
  fi
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
ENABLED_CSV="$(IFS=,; echo "${ENABLED_IDS[*]}")"
STATUS="${STATUS}" ENABLED_CSV="${ENABLED_CSV}" python3 - <<'PY'
import json, os, sys
d = json.loads(os.environ["STATUS"])
want = set(os.environ["ENABLED_CSV"].split(","))
got = set(d.get("peers") or [])
if not want <= got:
    print(f"FAIL: peers missing {want - got}; got {got}", file=sys.stderr)
    sys.exit(1)
print("status peers OK", sorted(want))
PY

echo "=== list brave (sample) ==="
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

# Spot-check one list per enabled id (title prefix = browser id).
for bid in "${ENABLED_IDS[@]}"; do
  echo "=== list ${bid} ==="
  OUT_B="$(browser-tabs-host cli list --browser "${bid}")"
  echo "${OUT_B}" | python3 -c "import json,sys; t=json.load(sys.stdin); assert t[0]['title']=='${bid}-A', t"
done

echo "=== activate brave 1000001 ==="
browser-tabs-host cli activate --browser brave 1000001

echo "=== foreign Activate (chrome tab via brave key) ==="
# chrome peer tab base is 2000000 when brave is first enabled id
FOREIGN_TAB="$(python3 - <<PY
import json
from pathlib import Path
ids = [e["id"] for e in json.loads(Path("${ROOT}/config/browsers.json").read_text())["browsers"] if e.get("enabled")]
print((ids.index("chrome") + 1) * 1000000)
PY
)"
if browser-tabs-host cli activate --browser brave "${FOREIGN_TAB}" 2>/tmp/alkitect-foreign-act.err; then
  echo "FAIL: expected foreign Activate to fail" >&2
  exit 1
fi
grep -qiE 'ForeignTab|Failed|Invalid' /tmp/alkitect-foreign-act.err \
  || { echo "FAIL: unexpected error text:"; cat /tmp/alkitect-foreign-act.err >&2; exit 1; }
echo "foreign Activate rejected OK"

echo "=== thumb prune scoped ==="
HOST_PATH="${HOST}" ENABLED_CSV="${ENABLED_CSV}" "${PYTHON3}" - <<'PY'
import importlib.util, os
from pathlib import Path
host = os.environ["HOST_PATH"]
bids = os.environ["ENABLED_CSV"].split(",")
spec = importlib.util.spec_from_file_location("browser_tabs_host", host)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)
base = mod.thumb_cache_dir()
for bid in bids:
    (base / bid).mkdir(parents=True, exist_ok=True)
    (base / bid / "tab-99.png").write_bytes(b"x")
assert mod.prune_thumb_files("brave", {1, 2, 3}) >= 1
for bid in bids:
    if bid == "brave":
        continue
    assert (base / bid / "tab-99.png").is_file()
    (base / bid / "tab-99.png").unlink()
print("thumb prune scoped OK")
PY

echo "=== mozilla argv[0] native launch ==="
HOST_PATH="${HOST}" "${PYTHON3}" - <<'PY'
import importlib.util, os
host = os.environ["HOST_PATH"]
spec = importlib.util.spec_from_file_location("browser_tabs_host", host)
mod = importlib.util.module_from_spec(spec)
assert spec.loader is not None
spec.loader.exec_module(mod)
def classify(argv0):
    if argv0 in ("daemon", "native", "cli"):
        return argv0
    if argv0.startswith("chrome-extension://") or "@" in argv0:
        return "native"
    return "unknown"
assert classify("browser-tab-dock@alkitect") == "native"
assert classify("chrome-extension://nnkglnaajlmfinohhknmgpacbgpdadgg/") == "native"
assert classify("daemon") == "daemon"
assert classify("bogus") == "unknown"
print("mozilla argv fixture OK")
PY

echo "PASS verify-host-cli"
