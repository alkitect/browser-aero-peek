# Changelog

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
- Brave remains the only `enabled` browser; CLI: `browser-tabs-host cli list --browser brave`.

## 0.2.9

- Product rename: multi-browser **release source** (`browser-aero-peek`); Brave `.deb` still the only supported runtime at this tag.
- README: Who-this-is-for matrix (In / Planned / Out) + Related dual-lane + Install clash with `brave-aero-peek`.
- Support tip: stock desktop line (dock tip remains Brave-only lane).
- Docs: PUBLISH V-001 count, tag-blocker matrix, browser backlog.

## 0.2.8

- Hover dwell peek strip on Ubuntu Dock for Brave (favicon + title above cached PNG thumbs).
- MV3: inline favicons, `captureVisibleTab` thumb cache, native messaging bridge.
- Host: session D-Bus + Unix socket; systemd `WantedBy=graphical-session.target`.
- Shell metadata integer 9: soft dwell, leave corridor, card header, empty “No preview yet”.
- First public extract scaffolding (GPL-3.0-only) under sibling product name.
