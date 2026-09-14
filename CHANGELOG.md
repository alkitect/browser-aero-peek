# Changelog

## 0.9.4

- Docs: packaging coverage N/A table (Chrome Snap / Ubuntu Chromium `.deb` / Edge Snap) and beta/channel Out follow-ups.
- Durable AMO-signed `.xpi` remains **0.9.3** (no resign for docs-only tip).

## 0.9.3

- Clear AMO Android min-version warning: set `gecko_android.strict_min_version` to `142.0` (desktop stays `140.0` for built-in data consent).
- Re-sign durable Firefox `.xpi` as 0.9.3 (Hub already had 0.9.2).

## 0.9.2

- AMO re-sign durable Firefox `.xpi` so the signed add-on version matches the product triad (attach `browser-tab-dock-signed.xpi` on the GitHub Release).
- `amo-sign.sh`: trim whitespace from Keyring JWT values (trailing space caused AMO `Error decoding signature`).

## 0.9.1

- Fix install durable `.xpi` discovery (`ROOT` expansion) so `dist/firefox-amo-signed/*.xpi` is copied to `~/alkitect-browser-tabs/browser-tab-dock-signed.xpi`.

## 0.9.0

- Firefox durable: AMO self-distributed signed `.xpi` (FF140+ `data_collection_permissions`); `stage-firefox-amo` / `amo-keyring` / `amo-sign`; install prefers `~/alkitect-browser-tabs/browser-tab-dock-signed.xpi`; private browsing excluded from list/thumb cache.
- Shell **21**: peer-fallback tries all Firefox packaging siblings so Flatpak/deb dock icons work with the single durable NM peer (`firefox`).

## 0.8.0

- Enable Firefox Mozilla `.deb` (`firefox-deb`) and Flatpak `org.mozilla.firefox` (`firefox-flatpak`): shared portal NM `~/.mozilla/…` + home-sock bridge; per-lane Temporary `.xpi`; Shell family matcher (metadata **20**).

## 0.7.0

- Enable Firefox (Snap): mozilla NM (`allowed_extensions` = gecko id `browser-tab-dock@alkitect`); portal path `~/.mozilla/native-messaging-hosts` + snap-tree alias; Temporary Add-on **`.xpi`**; home sock + `browser-tabs-nm-snap`; staged forced `browserId=firefox`; profile `user.js` portal pref. Durable AMO-signed install deferred.
- Batch packaging + Edge: enable Brave Snap/Flatpak, Chrome Flatpak, Opera Snap, Vivaldi Snap/Flatpak, Chromium Flatpak, Edge deb+Flatpak in registry; generalized staged `mv3-<id>`; Shell family matchers (metadata **18**→**19**).
- Tor Browser: feasibility **FAIL** — stay `enabled: false` ([TOR-FEASIBILITY.md](docs/TOR-FEASIBILITY.md)).
- Shell 19: sync GdkPixbuf thumb paint — no per-thumb TextureCache fade (strip fade only).
- Docs: Temporary `.xpi` residual; Firefox `.deb`/Flatpak → later expansion.

## 0.6.1

- Docs: mark `brave-aero-peek` as deprecated in Related + BROWSER-SUPPORT wrong-lane note; this repo remains the only daily driver.

## 0.6.0

- Enable Chromium (Snap): registry `chromium` with `packaging: snap`; Shell matcher (metadata 16); NM under snap profile + `~/bin` host bridge + home sock (strict snap AppArmor); staged MV3 forced `browserId`; Flatpak Chromium deferred.
- Fix Snap NM wrapper: bake absolute host/sock paths (Snap remaps `$HOME` to `~/snap/chromium/<rev>/`, so `${HOME}/bin/browser-tabs-host` 404s).
- Host: lazy-import gi so Snap-spawned native bridge is stdlib-only; daemon listens on `$XDG_RUNTIME_DIR` and `$HOME/alkitect-browser-tabs/browser-tabs.sock`.

## 0.5.0

- Enable Vivaldi (`.deb`): registry `vivaldi.enabled`; Shell matcher (metadata 15); NM under `vivaldi/NativeMessagingHosts`; staged MV3 with forced `browserId=vivaldi` (reduced UA otherwise binds as Chrome); Flatpak/Snap Out for this wave.
- Native bridge: exit when daemon socket dies so Chromium-family browsers (incl. Vivaldi) reconnect after host restart.
- MV3 / Shell: drop “Alkitect” from display names; credit `alkitect` as author in metadata/description.

## 0.4.0

- Enable Opera dual packaging: registry `opera` (`.deb`) + `opera-flatpak` (Flatpak `com.opera.Opera`); home-based NM + aliases; staged MV3 with forced `browserId`; Shell matcher Flatpak-before-native.
- Opera Flatpak: NM via `browser-tabs-nm-flatpak` → `flatpak-spawn --host`; overrides for `~/.local/bin:ro`, staged MV3 share `:ro`, talk `org.freedesktop.Flatpak`; docs warn against ephemeral `/run/flatpak/doc/…` Load unpacked.
- Shell 14: disambiguate shared `StartupWMClass=Opera` (Exec + NoExtension sibling retry); MV3 list budget + favicon fetch timeout so hung list cannot drop the NM peer.

## 0.3.0

- Enable Google Chrome (`.deb`): registry `chrome.enabled`, Shell matcher, dual NM install/ci, BROWSER-SUPPORT / README In.
- Install: chmod group-writable Chromium NM dirs we own (Chrome profile often 775).

## 0.2.10

- Shared-prep: `config/browsers.json` SSOT; host multiplex + bind hello; D-Bus/CLI scoped by `--browser`; Shell table matcher; multi-NM ci (enabled positive / disabled absent); BROWSER-SUPPORT + concurrent-browser SECURITY/ADR notes.

## 0.2.9

- First public multi-browser release-source tag (Brave-capable tip at cutover).
