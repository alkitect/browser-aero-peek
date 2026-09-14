#!/usr/bin/env bash
# Store / show status for AMO JWT credentials in GNOME Keyring (Secret Service).
# Never prints secret values. Never writes credentials to disk.
#
# One-time store (you will be prompted twice — paste issuer, then secret):
#   ./scripts/amo-keyring.sh store
#
# Check presence (exit 0 if both keys exist):
#   ./scripts/amo-keyring.sh status
#
# Remove:
#   ./scripts/amo-keyring.sh clear
set -euo pipefail

SERVICE="alkitect-browser-aero-peek"
KEY_ISSUER="amo-jwt-issuer"
KEY_SECRET="amo-jwt-secret"

need_secret_tool() {
  if ! command -v secret-tool >/dev/null 2>&1; then
    echo "Need libsecret-tools: sudo apt install libsecret-tools" >&2
    exit 1
  fi
}

cmd="${1:-}"
case "${cmd}" in
  store)
    need_secret_tool
    echo "Paste AMO JWT issuer (API key), then Enter. Input is hidden by secret-tool."
    secret-tool store --label="AMO JWT issuer (alkitect browser-aero-peek)" \
      service "${SERVICE}" key "${KEY_ISSUER}"
    echo "Paste AMO JWT secret, then Enter."
    secret-tool store --label="AMO JWT secret (alkitect browser-aero-peek)" \
      service "${SERVICE}" key "${KEY_SECRET}"
    echo "Stored in GNOME Keyring (service=${SERVICE})."
    ;;
  status)
    need_secret_tool
    ok=1
    if secret-tool lookup service "${SERVICE}" key "${KEY_ISSUER}" >/dev/null 2>&1; then
      echo "issuer: present"
    else
      echo "issuer: MISSING"
      ok=0
    fi
    if secret-tool lookup service "${SERVICE}" key "${KEY_SECRET}" >/dev/null 2>&1; then
      echo "secret: present"
    else
      echo "secret: MISSING"
      ok=0
    fi
    [[ "${ok}" -eq 1 ]]
    ;;
  clear)
    need_secret_tool
    secret-tool clear service "${SERVICE}" key "${KEY_ISSUER}" 2>/dev/null || true
    secret-tool clear service "${SERVICE}" key "${KEY_SECRET}" 2>/dev/null || true
    echo "Cleared AMO JWT entries for service=${SERVICE} (if they existed)."
    ;;
  *)
    echo "Usage: $0 {store|status|clear}" >&2
    exit 2
    ;;
esac
