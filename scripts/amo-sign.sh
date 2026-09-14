#!/usr/bin/env bash
# Sign dist/firefox-amo using AMO JWT credentials from GNOME Keyring.
# Secrets are loaded into this process only via env (WEB_EXT_*); never written to disk
# and never passed as argv (ps would expose them).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SERVICE="alkitect-browser-aero-peek"
KEY_ISSUER="amo-jwt-issuer"
KEY_SECRET="amo-jwt-secret"
CHANNEL="${AMO_CHANNEL:-unlisted}"
# 0 = return as soon as the signed file is available (do not hang on long approval polls).
# Override e.g. AMO_APPROVAL_TIMEOUT_MS=600000 to wait up to 10 minutes.
APPROVAL_TIMEOUT_MS="${AMO_APPROVAL_TIMEOUT_MS:-0}"

if ! command -v secret-tool >/dev/null 2>&1; then
  echo "Need libsecret-tools: sudo apt install libsecret-tools" >&2
  exit 1
fi

issuer="$(secret-tool lookup service "${SERVICE}" key "${KEY_ISSUER}" 2>/dev/null || true)"
secret="$(secret-tool lookup service "${SERVICE}" key "${KEY_SECRET}" 2>/dev/null || true)"
# Keyring paste often leaves a trailing space; JWT HS256 then fails with "Error decoding signature".
issuer="${issuer%"${issuer##*[![:space:]]}"}"
secret="${secret%"${secret##*[![:space:]]}"}"
issuer="${issuer#"${issuer%%[![:space:]]*}"}"
secret="${secret#"${secret%%[![:space:]]*}"}"
if [[ -z "${issuer}" || -z "${secret}" ]]; then
  echo "AMO JWT not in GNOME Keyring. Store once:" >&2
  echo "  ${ROOT}/scripts/amo-keyring.sh store" >&2
  echo "Then: ${ROOT}/scripts/amo-keyring.sh status" >&2
  exit 1
fi

"${ROOT}/scripts/stage-firefox-amo.sh"
mkdir -p "${ROOT}/dist/firefox-amo-signed"

# Env only — web-ext reads WEB_EXT_API_KEY / WEB_EXT_API_SECRET (do not pass --api-* on argv).
export WEB_EXT_API_KEY="${issuer}"
export WEB_EXT_API_SECRET="${secret}"
unset issuer secret

echo "Signing (channel=${CHANNEL}) via web-ext — credentials from keyring (env only), not logged."
echo "If this sits on 'Waiting for approval…', that is normal: AMO is reviewing. No terminal input needed."
echo "You can watch https://addons.mozilla.org/developers/ — Ctrl-C here is OK; download .xpi from Hub later."

npx --yes web-ext@8 sign \
  --source-dir "${ROOT}/dist/firefox-amo" \
  --channel "${CHANNEL}" \
  --artifacts-dir "${ROOT}/dist/firefox-amo-signed" \
  --approval-timeout "${APPROVAL_TIMEOUT_MS}"

echo "Done. Artifacts under dist/firefox-amo-signed/ (gitignored)."
ls -la "${ROOT}/dist/firefox-amo-signed/"
