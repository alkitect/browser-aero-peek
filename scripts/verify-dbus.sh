#!/usr/bin/env bash
# D-Bus happy path + document negatives (peer deny / wrong NM origin).
set -euo pipefail

export PATH="${HOME}/.local/bin:${PATH}"

if ! systemctl --user is-active --quiet alkitect-browser-tabs.service 2>/dev/null; then
  echo "alkitect-browser-tabs.service not active" >&2
  exit 1
fi

echo "=== Status ==="
gdbus call --session \
  --dest org.alkitect.BrowserTabs1 \
  --object-path /org/alkitect/BrowserTabs1 \
  --method org.alkitect.BrowserTabs1.Status

# ListTabs requires extension (or fake) connected — use verify-host-cli for full path.
# Here: Status must succeed for same-UID caller.
echo "=== peer deny (documented) ==="
echo "Same-UID processes always pass GetConnectionUnixUser. True cross-UID deny"
echo "needs a second user session — residual risk is documented in docs/SECURITY.md."
echo "Unix socket same-UID bypass of D-Bus gate is also documented there."

echo "=== wrong NM origin (documented) ==="
echo "Chromium rejects connectNative when allowed_origins lacks the extension ID."
echo "Manifest: ~/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts/org.alkitect.browser_tabs.json"

echo "PASS verify-dbus (Status OK; negatives documented)"
