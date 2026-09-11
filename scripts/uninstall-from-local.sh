#!/usr/bin/env bash
# Reverse install-to-local.sh (does not remove the Brave extension load).
set -euo pipefail

BIN="${HOME}/.local/bin"
SYSTEMD_USER="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
NM_DIR="${HOME}/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts"

# Under tmp-HOME ci-check: only remove files; do not touch live user systemd / Shell.
if [[ -z "${ALKITECT_CI_TMP:-}" ]]; then
  if command -v systemctl >/dev/null 2>&1; then
    systemctl --user disable --now alkitect-browser-tabs.service 2>/dev/null || true
    systemctl --user daemon-reload 2>/dev/null || true
  fi
fi

rm -f "${SYSTEMD_USER}/alkitect-browser-tabs.service"
rm -f "${NM_DIR}/org.alkitect.browser_tabs.json"
rm -f "${BIN}/browser-tabs-host" "${BIN}/browser-tabs-nm"
if [[ -z "${ALKITECT_CI_TMP:-}" ]]; then
  gnome-extensions disable browser-tab-dock@alkitect 2>/dev/null || true
fi
rm -rf "${HOME}/.local/share/gnome-shell/extensions/browser-tab-dock@alkitect"
echo "Uninstalled host / NM manifest / systemd unit / shell extension files"
