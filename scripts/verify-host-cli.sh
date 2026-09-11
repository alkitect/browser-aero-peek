#!/usr/bin/env bash
# Phase 1: daemon + fake extension over Unix socket + D-Bus CLI (no Brave required).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOST="${ROOT}/host/browser_tabs_host.py"
export PATH="${HOME}/.local/bin:${PATH}"

if [[ ! -x "${HOME}/.local/bin/browser-tabs-host" ]]; then
  echo "Install first: ${ROOT}/scripts/install-to-local.sh --enable-automation" >&2
  exit 1
fi

python3 -m py_compile "${HOST}"

# Prefer installed unit; fall back to foreground daemon for CI/tmp.
STARTED_LOCAL=0
if ! systemctl --user is-active --quiet alkitect-browser-tabs.service 2>/dev/null; then
  python3 "${HOST}" daemon &
  DAEMON_PID=$!
  STARTED_LOCAL=1
  cleanup() {
    kill "${DAEMON_PID}" 2>/dev/null || true
  }
  trap cleanup EXIT
  sleep 0.4
fi

# Fake extension: answer list/activate on the daemon socket
python3 - <<'PY' &
import json, os, socket, struct, time
from pathlib import Path

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

tabs = [
    {"id": 1, "title": "Alpha", "favIconUrl": ""},
    {"id": 2, "title": "Beta", "favIconUrl": "https://example.com/f.ico"},
    {"id": 3, "title": "Gamma", "favIconUrl": ""},
]
while True:
    msg = read_msg()
    if msg is None:
        break
    t = msg.get("type")
    if t == "list":
        write_msg({"type": "list", "tabs": tabs})
    elif t == "activate":
        write_msg({"type": "activate", "ok": msg.get("tabId") in (1, 2, 3)})
    elif t == "ping":
        write_msg({"type": "pong"})
    else:
        write_msg({"type": "error", "error": "unknown"})
PY
FAKE_PID=$!

cleanup_all() {
  kill "${FAKE_PID}" 2>/dev/null || true
  if [[ "${STARTED_LOCAL}" -eq 1 ]]; then
    kill "${DAEMON_PID}" 2>/dev/null || true
  fi
}
trap cleanup_all EXIT
sleep 0.3

echo "=== status ==="
browser-tabs-host cli status
echo "=== list ==="
OUT="$(browser-tabs-host cli list)"
echo "${OUT}"
OUT="${OUT}" python3 - <<'PY'
import json, os
tabs = json.loads(os.environ["OUT"])
assert len(tabs) >= 3, tabs
assert tabs[0]["title"] == "Alpha"
blob = json.dumps(tabs)
assert "http://" not in blob and "https://example.com/page" not in blob
assert tabs[1]["favicon"].startswith("https://")
print("list OK")
PY

echo "=== activate 2 ==="
browser-tabs-host cli activate 2

echo "=== peer deny smoke (optional) ==="
# Same UID always passes; document negative path in SECURITY later.
echo "PASS verify-host-cli"
