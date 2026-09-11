#!/usr/bin/python3
# SPDX-License-Identifier: GPL-3.0-only
"""alkitect browser-tabs host: D-Bus daemon + native-messaging proxy + CLI.

daemon  — systemd user unit; owns org.alkitect.BrowserTabs1; Unix socket for NM bridge
native  — spawned by the browser; proxies length-prefixed JSON stdio <-> daemon socket
cli     — ListTabs / Activate over session D-Bus (scoped by --browser)
"""
from __future__ import annotations

import argparse
import json
import os
import socket
import struct
import sys
import threading
import time
from pathlib import Path
from typing import Any, Optional

import gi

gi.require_version("Gio", "2.0")
gi.require_version("GLib", "2.0")
from gi.repository import Gio, GLib  # noqa: E402

BUS_NAME = "org.alkitect.BrowserTabs1"
OBJ_PATH = "/org/alkitect/BrowserTabs1"
IFACE = "org.alkitect.BrowserTabs1"
SOCK_NAME = "alkitect-browser-tabs.sock"
ALLOWED_NM_SCHEMAS = frozenset({"chromium", "mozilla"})

INTROSPECT_XML = f"""
<node>
  <interface name="{IFACE}">
    <method name="ListTabs">
      <arg type="s" name="browser_id" direction="in"/>
      <arg type="s" name="tabs_json" direction="out"/>
    </method>
    <method name="Activate">
      <arg type="s" name="browser_id" direction="in"/>
      <arg type="u" name="tab_id" direction="in"/>
    </method>
    <method name="Status">
      <arg type="s" name="status_json" direction="out"/>
    </method>
  </interface>
</node>
"""


def runtime_sock() -> Path:
    base = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return Path(base) / SOCK_NAME


def thumb_cache_dir() -> Path:
    """Shell TextureCache paint dir (same path as shell-extension)."""
    base = os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}"
    return Path(base) / "alkitect-tab-dock"


def browsers_json_path() -> Path:
    override = os.environ.get("ALKITECT_BROWSERS_JSON")
    if override:
        return Path(override)
    # Source tree (host/browser_tabs_host.py → ../config/browsers.json).
    here = Path(__file__).resolve().parent.parent / "config" / "browsers.json"
    if here.is_file():
        return here
    # Installed copy (install-to-local.sh).
    cfg_home = Path(os.environ.get("XDG_CONFIG_HOME") or (Path.home() / ".config"))
    installed = cfg_home / "alkitect-browser-tabs" / "browsers.json"
    if installed.is_file():
        return installed
    raise FileNotFoundError(
        "browsers.json not found (set ALKITECT_BROWSERS_JSON or re-run install-to-local.sh)"
    )


def load_registry() -> dict[str, dict[str, Any]]:
    path = browsers_json_path()
    data = json.loads(path.read_text(encoding="utf-8"))
    browsers = data.get("browsers")
    if not isinstance(browsers, list):
        raise ValueError("browsers.json: missing browsers list")
    out: dict[str, dict[str, Any]] = {}
    for entry in browsers:
        if not isinstance(entry, dict):
            raise ValueError("browsers.json: entry must be object")
        unknown = set(entry) - {
            "id",
            "enabled",
            "nm_schema",
            "nm_path",
            "desktop_ids",
            "wm_classes",
        }
        if unknown:
            raise ValueError(f"browsers.json: unknown keys {sorted(unknown)}")
        bid = entry.get("id")
        if not isinstance(bid, str) or not bid:
            raise ValueError("browsers.json: id required")
        schema = entry.get("nm_schema")
        if schema not in ALLOWED_NM_SCHEMAS:
            raise ValueError(f"browsers.json: bad nm_schema {schema!r}")
        nm_path = entry.get("nm_path")
        if not isinstance(nm_path, str) or not nm_path:
            raise ValueError(f"browsers.json: nm_path required for {bid}")
        if nm_path.startswith("/") or nm_path.startswith("~"):
            raise ValueError(f"browsers.json: nm_path must be profile-relative ({bid})")
        if ".." in Path(nm_path).parts:
            raise ValueError(f"browsers.json: nm_path must not contain .. ({bid})")
        out[bid] = entry
    return out


def prune_thumb_files(browser_id: str, keep_ids: set[int]) -> int:
    """Remove {browserId}/tab-*.{png,jpg} not in keep_ids. Returns unlink count."""
    d = thumb_cache_dir() / browser_id
    if not d.is_dir():
        return 0
    removed = 0
    for p in d.iterdir():
        if not p.is_file() or not p.name.startswith("tab-"):
            continue
        stem = p.name[4:]
        id_part = stem.rsplit(".", 1)[0]
        try:
            tid = int(id_part)
        except ValueError:
            continue
        if tid in keep_ids:
            continue
        try:
            p.unlink()
            removed += 1
        except OSError:
            pass
    return removed


def read_nm_message(fp) -> Optional[dict[str, Any]]:
    raw_len = fp.read(4)
    if not raw_len or len(raw_len) < 4:
        return None
    (n,) = struct.unpack("<I", raw_len)
    if n > 10_000_000:
        raise ValueError(f"native message too large: {n}")
    data = fp.read(n)
    if len(data) < n:
        return None
    return json.loads(data.decode("utf-8"))


def write_nm_message(fp, obj: dict[str, Any]) -> None:
    payload = json.dumps(obj, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
    fp.write(struct.pack("<I", len(payload)))
    fp.write(payload)
    fp.flush()


def peer_uid_ok(connection: Gio.DBusConnection, sender: Optional[str]) -> bool:
    if not sender:
        return False
    try:
        reply = connection.call_sync(
            "org.freedesktop.DBus",
            "/org/freedesktop/DBus",
            "org.freedesktop.DBus",
            "GetConnectionUnixUser",
            GLib.Variant("(s)", (sender,)),
            GLib.VariantType("(u)"),
            Gio.DBusCallFlags.NONE,
            2000,
            None,
        )
        (uid,) = reply.unpack()
        return int(uid) == os.getuid()
    except GLib.Error:
        return False


class Daemon:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._registry = load_registry()
        self._peers: dict[str, socket.socket] = {}
        self._loop = GLib.MainLoop()
        self._owner_id = 0
        self._sock_srv: Optional[socket.socket] = None
        # Per-browser list cache / inflight
        self._list_inflight: dict[str, bool] = {}
        self._list_cache: dict[str, str] = {}
        self._list_cache_mono: dict[str, float] = {}
        self._tabs_by_browser: dict[str, set[int]] = {}
        self._list_min_interval = 0.5
        self._list_cache_ttl = 1.0

    def run(self) -> int:
        path = runtime_sock()
        if path.exists():
            path.unlink()
        self._sock_srv = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._sock_srv.bind(str(path))
        os.chmod(path, 0o600)
        self._sock_srv.listen(8)
        self._sock_srv.setblocking(False)
        GLib.io_add_watch(self._sock_srv.fileno(), GLib.IO_IN, self._on_accept)

        self._owner_id = Gio.bus_own_name(
            Gio.BusType.SESSION,
            BUS_NAME,
            Gio.BusNameOwnerFlags.NONE,
            self._on_bus_acquired,
            None,
            self._on_name_lost,
        )
        try:
            self._loop.run()
        finally:
            if self._owner_id:
                Gio.bus_unown_name(self._owner_id)
            if self._sock_srv:
                self._sock_srv.close()
            if path.exists():
                path.unlink(missing_ok=True)
        return 0

    def _on_name_lost(self, *_args) -> None:
        sys.stderr.write(f"browser-tabs-host: lost bus name {BUS_NAME}\n")
        self._loop.quit()

    def _on_bus_acquired(self, connection: Gio.DBusConnection, _name: str) -> None:
        node = Gio.DBusNodeInfo.new_for_xml(INTROSPECT_XML)
        iface = node.interfaces[0]
        connection.register_object(
            OBJ_PATH,
            iface,
            self._on_method,
            None,
            None,
        )

    def _on_accept(self, _fd, _cond) -> bool:
        assert self._sock_srv is not None
        try:
            conn, _ = self._sock_srv.accept()
        except BlockingIOError:
            return True
        conn.setblocking(True)
        threading.Thread(target=self._bind_peer, args=(conn,), daemon=True).start()
        return True

    def _recv_exact(self, conn: socket.socket, n: int) -> bytes:
        buf = b""
        while len(buf) < n:
            chunk = conn.recv(n - len(buf))
            if not chunk:
                raise OSError("eof")
            buf += chunk
        return buf

    def _bind_peer(self, conn: socket.socket) -> None:
        """First NM frame MUST be hello with enabled registry browserId."""
        try:
            conn.settimeout(5.0)
            hdr = self._recv_exact(conn, 4)
            (n,) = struct.unpack("<I", hdr)
            if n > 10_000_000 or n < 2:
                raise OSError("bad hello size")
            body = self._recv_exact(conn, n)
            msg = json.loads(body.decode("utf-8"))
            if not isinstance(msg, dict) or msg.get("type") != "hello":
                raise OSError("expected hello")
            browser_id = msg.get("browserId")
            if not isinstance(browser_id, str) or not browser_id:
                raise OSError("missing browserId")
            entry = self._registry.get(browser_id)
            if entry is None or not entry.get("enabled"):
                raise OSError(f"unknown or disabled browserId: {browser_id}")
            conn.settimeout(None)
        except Exception as e:
            sys.stderr.write(f"browser-tabs-host: reject NM peer: {e}\n")
            try:
                conn.close()
            except OSError:
                pass
            return

        with self._lock:
            old = self._peers.get(browser_id)
            if old is not None and old is not conn:
                try:
                    old.close()
                except OSError:
                    pass
            self._peers[browser_id] = conn

        def _hup(_fd, _cond, c=conn, bid=browser_id):
            with self._lock:
                if self._peers.get(bid) is c:
                    del self._peers[bid]
            try:
                c.close()
            except OSError:
                pass
            return False

        def _attach_hup():
            GLib.io_add_watch(conn.fileno(), GLib.IO_HUP | GLib.IO_ERR, _hup)
            return False

        GLib.idle_add(_attach_hup)

    def _rpc_to_extension(
        self, browser_id: str, request: dict[str, Any], timeout: float = 5.0
    ) -> dict[str, Any]:
        payload = json.dumps(request, separators=(",", ":")).encode("utf-8")
        with self._lock:
            conn = self._peers.get(browser_id)
            if conn is None:
                raise RuntimeError("NoExtension")
            try:
                conn.sendall(struct.pack("<I", len(payload)) + payload)
                conn.settimeout(timeout)
                hdr = self._recv_exact(conn, 4)
                (n,) = struct.unpack("<I", hdr)
                if n > 10_000_000:
                    raise OSError("reply too large")
                body = self._recv_exact(conn, n)
                conn.settimeout(None)
            except (OSError, TimeoutError) as e:
                try:
                    conn.close()
                except OSError:
                    pass
                if self._peers.get(browser_id) is conn:
                    del self._peers[browser_id]
                raise RuntimeError("Timeout") from e
            return json.loads(body.decode("utf-8"))

    def _on_method(
        self,
        connection: Gio.DBusConnection,
        sender: Optional[str],
        _object_path: str,
        _interface_name: str,
        method_name: str,
        parameters: GLib.Variant,
        invocation: Gio.DBusMethodInvocation,
    ) -> None:
        if not peer_uid_ok(connection, sender):
            invocation.return_dbus_error(
                "org.alkitect.BrowserTabs1.Error.Denied",
                "peer UID mismatch",
            )
            return
        try:
            if method_name == "Status":
                with self._lock:
                    peers = sorted(self._peers.keys())
                invocation.return_value(
                    GLib.Variant(
                        "(s)",
                        (
                            json.dumps(
                                {
                                    "extension_connected": bool(peers),
                                    "peers": peers,
                                }
                            ),
                        ),
                    )
                )
                return
            if method_name == "ListTabs":
                (browser_id,) = parameters.unpack()
                if not isinstance(browser_id, str) or not browser_id:
                    raise RuntimeError("InvalidBrowser")
                if browser_id not in self._registry or not self._registry[browser_id].get(
                    "enabled"
                ):
                    raise RuntimeError("InvalidBrowser")
                now = time.monotonic()
                with self._lock:
                    cached = None
                    cache_mono = self._list_cache_mono.get(browser_id, 0.0)
                    list_cache = self._list_cache.get(browser_id)
                    if list_cache is not None and (now - cache_mono) < self._list_cache_ttl:
                        cached = list_cache
                    elif self._list_inflight.get(browser_id):
                        invocation.return_dbus_error(
                            "org.alkitect.BrowserTabs1.Error.Busy",
                            "ListTabs in flight",
                        )
                        return
                    elif list_cache is not None and (now - cache_mono) < self._list_min_interval:
                        cached = list_cache
                    elif (now - cache_mono) < self._list_min_interval:
                        invocation.return_dbus_error(
                            "org.alkitect.BrowserTabs1.Error.Busy",
                            "ListTabs rate limited",
                        )
                        return
                    if cached is not None:
                        invocation.return_value(GLib.Variant("(s)", (cached,)))
                        return
                    self._list_inflight[browser_id] = True
                try:
                    resp = self._rpc_to_extension(browser_id, {"type": "list"})
                    tabs = resp.get("tabs", [])
                    if not isinstance(tabs, list):
                        raise RuntimeError("bad tabs payload")
                    out = []
                    for t in tabs:
                        out.append(
                            {
                                "id": int(t["id"]),
                                "title": str(t.get("title") or ""),
                                "favicon": str(
                                    t.get("favIconUrl") or t.get("favicon") or ""
                                ),
                                "thumb": str(t.get("thumb") or t.get("thumbnail") or ""),
                            }
                        )
                    payload = json.dumps(out)
                    keep = {int(t["id"]) for t in out}
                    prune_thumb_files(browser_id, keep)
                    with self._lock:
                        self._list_cache[browser_id] = payload
                        self._list_cache_mono[browser_id] = time.monotonic()
                        self._tabs_by_browser[browser_id] = keep
                    invocation.return_value(GLib.Variant("(s)", (payload,)))
                finally:
                    with self._lock:
                        self._list_inflight[browser_id] = False
                return
            if method_name == "Activate":
                browser_id, tab_id = parameters.unpack()
                if not isinstance(browser_id, str) or not browser_id:
                    raise RuntimeError("InvalidBrowser")
                if browser_id not in self._registry or not self._registry[browser_id].get(
                    "enabled"
                ):
                    raise RuntimeError("InvalidBrowser")
                tab_id = int(tab_id)
                with self._lock:
                    known = self._tabs_by_browser.get(browser_id)
                    peer = self._peers.get(browser_id)
                if peer is None:
                    raise RuntimeError("NoExtension")
                if known is not None and tab_id not in known:
                    raise RuntimeError("ForeignTab")
                resp = self._rpc_to_extension(
                    browser_id, {"type": "activate", "tabId": tab_id}
                )
                if not resp.get("ok"):
                    raise RuntimeError(resp.get("error") or "InvalidTab")
                invocation.return_value(None)
                return
            invocation.return_dbus_error(
                "org.alkitect.BrowserTabs1.Error.UnknownMethod",
                method_name,
            )
        except RuntimeError as e:
            name = str(e)
            err = {
                "NoExtension": "org.alkitect.BrowserTabs1.Error.NoExtension",
                "Timeout": "org.alkitect.BrowserTabs1.Error.Timeout",
                "InvalidTab": "org.alkitect.BrowserTabs1.Error.InvalidTab",
                "ForeignTab": "org.alkitect.BrowserTabs1.Error.ForeignTab",
                "InvalidBrowser": "org.alkitect.BrowserTabs1.Error.InvalidBrowser",
            }.get(name, "org.alkitect.BrowserTabs1.Error.Failed")
            invocation.return_dbus_error(err, name)
            with self._lock:
                # Clear any stuck inflight if ListTabs failed mid-flight
                for bid in list(self._list_inflight):
                    if self._list_inflight.get(bid):
                        self._list_inflight[bid] = False


def run_native() -> int:
    """Browser-spawned bridge: stdio NM <-> Unix socket to daemon."""
    path = runtime_sock()
    if not path.exists():
        sys.stderr.write(f"browser-tabs-host: daemon socket missing: {path}\n")
        return 1
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(str(path))

    def sock_to_stdout() -> None:
        buf = b""
        try:
            while True:
                chunk = sock.recv(65536)
                if not chunk:
                    break
                buf += chunk
                while len(buf) >= 4:
                    (n,) = struct.unpack("<I", buf[:4])
                    if len(buf) < 4 + n:
                        break
                    frame = buf[: 4 + n]
                    buf = buf[4 + n :]
                    sys.stdout.buffer.write(frame)
                    sys.stdout.buffer.flush()
        except OSError:
            pass
        finally:
            try:
                sys.stdin.close()
            except OSError:
                pass

    t = threading.Thread(target=sock_to_stdout, daemon=True)
    t.start()
    try:
        while True:
            raw_len = sys.stdin.buffer.read(4)
            if not raw_len or len(raw_len) < 4:
                break
            (n,) = struct.unpack("<I", raw_len)
            body = sys.stdin.buffer.read(n)
            if len(body) < n:
                break
            sock.sendall(raw_len + body)
    except (OSError, BrokenPipeError):
        pass
    finally:
        try:
            sock.close()
        except OSError:
            pass
    return 0


def dbus_call(method: str, params: Optional[GLib.Variant] = None, timeout_ms: int = 5000) -> Any:
    bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
    reply = bus.call_sync(
        BUS_NAME,
        OBJ_PATH,
        IFACE,
        method,
        params,
        None,
        Gio.DBusCallFlags.NONE,
        timeout_ms,
        None,
    )
    return None if reply is None else reply.unpack()


def run_cli(argv: list[str]) -> int:
    p = argparse.ArgumentParser(prog="browser-tabs-cli")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    list_p = sub.add_parser("list")
    list_p.add_argument("--browser", required=True, help="registry browser id")
    act = sub.add_parser("activate")
    act.add_argument("--browser", required=True, help="registry browser id")
    act.add_argument("tab_id", type=int)
    args = p.parse_args(argv)
    try:
        if args.cmd == "status":
            (s,) = dbus_call("Status")
            print(s)
            return 0
        if args.cmd == "list":
            (s,) = dbus_call("ListTabs", GLib.Variant("(s)", (args.browser,)))
            print(s)
            tabs = json.loads(s)
            if not tabs:
                sys.stderr.write("browser-tabs-cli: empty tab list\n")
                return 1
            return 0
        if args.cmd == "activate":
            dbus_call(
                "Activate",
                GLib.Variant("(su)", (args.browser, args.tab_id)),
            )
            return 0
    except GLib.Error as e:
        sys.stderr.write(f"browser-tabs-cli: {e.message}\n")
        return 1
    return 2


def main(argv: Optional[list[str]] = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if argv and argv[0] in ("-h", "--help"):
        print("Usage: browser-tabs-host daemon|native|cli ...", file=sys.stderr)
        return 2
    # Chromium may launch the NM binary with no args (or chrome-extension:// origin).
    if not argv or argv[0].startswith("chrome-extension://"):
        return run_native()
    mode = argv[0]
    if mode == "daemon":
        return Daemon().run()
    if mode == "native":
        return run_native()
    if mode == "cli":
        return run_cli(argv[1:])
    print(f"unknown mode: {mode}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main())
