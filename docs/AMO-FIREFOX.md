# Firefox AMO submit (self-distribution)

Durable Firefox WebExt for **Browser Tab Dock** (gecko id `browser-tab-dock@alkitect`). Maintainer tracking: FIREFOX-DURABLE / firefox durable child plan (private notes).

## Distribution choice

- **On your own** (self-distribution / unlisted signed `.xpi`).
- Not required to list publicly on addons.mozilla.org for durable install.
- Ban: `xpinstall.signatures.required=false`.

## Stage package (before Hub upload / `web-ext sign`)

```bash
cd public/browser-aero-peek   # or clone of alkitect/browser-aero-peek
chmod +x scripts/stage-firefox-amo.sh
./scripts/stage-firefox-amo.sh
# optional:
npx --yes web-ext@8 lint --source-dir dist/firefox-amo
```

Staged tree: `dist/firefox-amo/`

| Item | Value |
|------|--------|
| Gecko id | `browser-tab-dock@alkitect` |
| `strict_min_version` (gecko) | `140.0` (desktop built-in data consent) |
| `strict_min_version` (gecko_android) | `142.0` (Android consent support; clears AMO linter warning) |
| `data_collection_permissions.required` | `browsingActivity`, `websiteContent` |
| Background | `background.scripts` (no `service_worker`) |
| Absent | Chromium `key`, `favicon` permission, `forced-browser-id.js` |

Consent text users see is driven by those taxonomy keys: we transmit tab titles/URL-derived favicon data and page thumbnail pixels to a **same-UID local** native host — not to Mozilla cloud. Description in the staged manifest states this explicitly.

## Tester notes (paste into AMO submission)

1. **Platform:** Linux (Ubuntu 22.04+ GNOME Wayland recommended). Windows/macOS: extension may load but dock peek will not work.
2. **Companion host required:** clone https://github.com/alkitect/browser-aero-peek and run `./scripts/install-to-local.sh --enable-automation`. Native Messaging host name: `org.alkitect.browser_tabs`.
3. **Without the host:** `connectNative` fails; no tabs on `browser-tabs-host cli list`.
4. **Verify:** open ≥2 normal (non-private) tabs → `browser-tabs-host cli list --browser firefox` → optional Shell extension hover.
5. **Private windows:** deliberately excluded (not listed / not thumbnailed).
6. **Firefox packaging:** one signed `.xpi` for Snap, Mozilla `.deb`, and Flatpak. Default hello id `firefox`. Concurrent multi-packaging: set `storage.local` key `alkitect.firefoxBrowserId` to `firefox` | `firefox-deb` | `firefox-flatpak`.

## Sign (GNOME Keyring — preferred)

Do **not** put JWT issuer/secret in `.env` / plaintext files. Store them in the unlocked GNOME Keyring (same pattern as other alkitect Linux tooling):

```bash
# One-time (prompts twice; paste issuer then secret — nothing is echoed to the repo)
./scripts/amo-keyring.sh store
./scripts/amo-keyring.sh status   # issuer: present / secret: present

# Sign (loads secrets into process env only — never argv / never disk)
./scripts/amo-sign.sh
# artifacts → dist/firefox-amo-signed/*.xpi  (gitignored)
```

`Waiting for validation…` / `Waiting for approval…` means AMO is processing — **no terminal input**. When done you’ll see `Signed xpi downloaded: …`. You can also open https://addons.mozilla.org/developers/ and download from the Hub. Typing `y` does nothing.

If a previous run exposed credentials in `ps` (argv), **revoke/regenerate** the JWT at https://addons.mozilla.org/developers/addon/api/key/ then `./scripts/amo-keyring.sh clear && ./scripts/amo-keyring.sh store`.

`Error decoding signature` / Unauthorized on upload usually means a bad secret (often a **trailing space** from paste). `amo-sign.sh` trims Keyring values; re-`store` if trim alone does not help.

Keyring attributes: `service=alkitect-browser-aero-peek`, keys `amo-jwt-issuer` / `amo-jwt-secret`.

Or upload a zip of `dist/firefox-amo` via Developer Hub (On your own) without API keys.

## Install durable `.xpi`

Firefox → `about:addons` → gear → **Install Add-on From File** → signed `.xpi`.  
Quit and relaunch: add-on must remain enabled (unlike Temporary Add-on).

## When to re-sign on AMO

Re-run `./scripts/amo-sign.sh` (new AMO submission) **only** if `dist/firefox-amo/` WebExt sources change (`background.js`, Firefox manifest permissions/consent, gecko id). **Do not** re-sign for:

- Shell extension / metadata bumps
- Host / install script / docs-only changes
- Product triad bumps that do not change the signed add-on zip contents

The GitHub Release may attach a signed `.xpi` whose internal `version` lags the product tag until the next AMO sign.

- [ ] Display name **alkitect** (not typo)
- [ ] `./scripts/stage-firefox-amo.sh` fresh
- [ ] `web-ext lint` clean
- [ ] Description mentions local native host + no remote telemetry
- [ ] Tester notes pasted
- [ ] JWT not in git
