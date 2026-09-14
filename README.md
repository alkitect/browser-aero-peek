# Browser Aero peek

Hover the Ubuntu Dock icon for tab titles and thumbnails when you run one browser window with many tabs. Window peeks on hover stay stock when you have several windows.

[Quick start](#quick-start) · [BROWSER-SUPPORT](docs/BROWSER-SUPPORT.md) · [Releases](https://github.com/alkitect/browser-aero-peek/releases) · [License](#license)

Latest release notes: [CHANGELOG.md](CHANGELOG.md) and [GitHub Releases](https://github.com/alkitect/browser-aero-peek/releases). A plain `git clone` follows the default branch tip unless you check out a tag; prefer a tagged release for day-to-day use.

## What this does

With several windows of the same browser, Ubuntu Dock already peeks those windows when you hover the icon. With a single window and a pile of tabs, hover still does nothing for tabs: you have to dig through the tab strip inside the browser.

![Browser tab peek on Ubuntu Dock - hover a browser icon to see title and thumbnail cards](docs/images/ubuntu-dock-brave-aero-peek.png)

This adds the missing piece: hover the dock icon and you get tab titles, favicons, and cached page thumbnails. Click a card to bring that tab forward. Dock click stays stock; tab peek is hover-only.

Thumbnails are screenshots from the last time that tab was visible on screen. Browsers cannot give live shots of background tabs, so treat thumbs like page content on your local session bus (see Limits & safety).

## Who this is for

This is for Ubuntu 22.04 with GNOME on Wayland and the Ubuntu Dock (`systemd --user`, permission to enable Shell extensions). You already run at least one browser from the table below (`.deb`, Snap, or Flatpak where the vendor ships it), and you often keep many tabs in one window.

It is not for Tor Browser, GNOME Web, beta/dev/nightly builds, Windows or macOS, or desktops that are not GNOME with Ubuntu Dock. Those stay out of scope.

### Supported browsers

| Browser  | `.deb` | Snap | Flatpak |
| -------- |:------:|:----:|:-------:|
| Brave    | Yes    | Yes  | Yes     |
| Chrome   | Yes    | N/A  | Yes     |
| Opera    | Yes    | Yes  | Yes     |
| Opera GX | Yes    | Yes  | Yes     |
| Vivaldi  | Yes    | Yes  | Yes     |
| Chromium | Yes    | Yes  | Yes     |
| Edge     | Yes    | N/A  | Yes     |
| Firefox  | Yes    | Yes  | Yes     |

N/A = vendor does not ship that channel (Chrome Snap and Edge Snap do not exist). Full matrix: [docs/BROWSER-SUPPORT.md](docs/BROWSER-SUPPORT.md).

<details>
<summary>Chromium on Ubuntu: Snap vs .deb</summary>

If you installed Chromium from Ubuntu Software or as a Snap, use the Snap column. Ubuntu’s old `chromium-browser` apt package only redirects to Snap and is not a separate `.deb` lane here. “Chromium `.deb`” means a native Debian-style package that owns `~/.config/chromium`, not that transitional apt package.

</details>

## Quick start

Install puts three layers on your user account: a small background host, native-messaging hooks (JSON files that let each browser start that host), and a GNOME Shell extension. On hover, that extension can draw a tab peek strip when you have one window of that browser with enough tabs. `--enable-automation` turns on the user systemd unit so the host starts with your session; it is not sudoers and not system-wide.

Then: [Install](#install) → [Load the browser add-on](#1-load-the-browser-add-on) → [Enable the Shell extension](#2-enable-the-shell-extension) → [Try hover](#3-try-hover).

### Install

Needs: Ubuntu 22.04 with GNOME on Wayland and Ubuntu Dock, `systemd --user`, and permission to enable Shell extensions.

Stable path: clone or download a release tag from [Releases](https://github.com/alkitect/browser-aero-peek/releases), then run the install script below. Tip of `main` is fine for contributors tracking unreleased work.

```bash
git clone https://github.com/alkitect/browser-aero-peek.git
cd browser-aero-peek
# optional: git checkout vX.Y.Z   # pin to a release tag
chmod +x scripts/*.sh
./scripts/install-to-local.sh --enable-automation
```

The script starts `alkitect-browser-tabs.service`, writes native-messaging hooks for each enabled browser row in `config/browsers.json` (whether or not that app is installed yet), and installs Shell extension `browser-tab-dock@alkitect`.

> You still load the browser add-on yourself and enable the Shell extension. Wayland needs one logout after enable.

### 1. Load the browser add-on

Open that browser’s extensions page (for example `brave://extensions`, `chrome://extensions`, or `about:addons` on Firefox). Turn on Developer mode when the page offers it. “Load unpacked” means pick a folder from disk; Firefox uses Install Add-on From File and a signed `.xpi` instead.

| If you use…                                                                                                            | Load this                                                                                   |
| ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------- |
| Brave / Chrome / Opera `.deb`                                                                                          | Repo folder `browser-extension/`                                                            |
| Brave Snap / Flatpak, Chrome Flatpak, Edge, Vivaldi, Opera GX, Chromium Snap/Flatpak/native `.deb`, Opera Snap/Flatpak | `~/.local/share/alkitect-browser-tabs/mv3-<id>/` (for example `mv3-brave-snap`, `mv3-edge`) |
| Firefox (Snap, Mozilla `.deb`, or Flatpak)                                                                             | `~/alkitect-browser-tabs/browser-tab-dock-signed.xpi` via Install Add-on From File          |

Only Brave / Chrome / Opera `.deb` use the shared `browser-extension/` folder. Snap or Flatpak Brave must use the staged `mv3-brave-snap` or `mv3-brave-flatpak` path, not the repo folder.

Do not load a Flatpak “portal” path under `/run/.../doc/...`; those folders disappear. Install creates the `mv3-<id>` folders for you.

Firefox’s signed `.xpi` can lag the git product tag when only host/Shell/docs changed; see [CHANGELOG](CHANGELOG.md) and [AMO-FIREFOX.md](docs/AMO-FIREFOX.md).

For Chromium-based browsers, confirm the extension ID matches `browser-extension/extension-id.txt`. Fully quit that browser (all windows) and open it again, then check the host can see the add-on. Pass the registry id for that packaging (`brave`, `brave-snap`, `firefox`, `firefox-flatpak`, and so on; see [BROWSER-SUPPORT.md](docs/BROWSER-SUPPORT.md)):

```bash
browser-tabs-host cli list --browser brave
```

### 2. Enable the Shell extension

On Wayland, GNOME often needs a full logout/login before a new Shell extension actually runs. Enable, then log out and back in once:

```bash
gnome-extensions enable browser-tab-dock@alkitect
# log out and back in once
```

### 3. Try hover

Open one window of that browser with at least two normal (non-private) tabs. Pause briefly on the dock icon (a short dwell is enough). You should see a strip of title/favicon/thumbnail cards; click a card to select that tab and bring its window forward. Dock click stays unchanged. Several windows open instead? Stock hover still shows window peeks.

## Check it works

The real test is hover on one window with two or more tabs: the tab strip appears, a card click focuses that tab, and dock click still behaves like stock. If the strip never shows up, you probably skipped the logout, or the Shell extension is not enabled. If `cli list` says no extension, reload the add-on and fully quit the browser before trying again.

<details>
<summary>Optional confirmation scripts</summary>

Host CLI, D-Bus, a fake Shell hover, then a human e2e checklist after logout:

```bash
./scripts/verify-host-cli.sh
./scripts/verify-dbus.sh
./scripts/verify-shell-fake.sh
# After logout/in:
./scripts/verify-e2e.sh
```

</details>

Questions or a stuck install: open a GitHub [Issue](https://github.com/alkitect/browser-aero-peek/issues) or see [CONTRIBUTING.md](CONTRIBUTING.md).

## Support my work

Tip jar for the next desktop fix. Or a coffee so the next script stays boring on purpose.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/alkitect/?hidefeed=true&widget=true&embed=true)

## Uninstall

```bash
./scripts/uninstall-from-local.sh
```

That removes the user daemon, native-messaging hooks, and the Shell extension files from your account. Browser add-ons stay until you remove them yourself (Load unpacked or Install from File). After Shell uninstall, log out once if the old peek strip still appears.

## How it works

A browser add-on lists tabs and caches visible-page thumbs. `browser-tabs-host` bridges native messaging to session D-Bus (the local bus for your desktop login). On hover dwell, the Shell extension asks for that list and draws the tab strip; choosing a card activates the tab in the browser and raises its window.

Names on disk: `browser-tabs-host`, `alkitect-browser-tabs.service`, Shell `browser-tab-dock@alkitect`, add-on “Browser Tab Dock”.

More detail: [ARCHITECTURE](docs/ARCHITECTURE.md), [ADR-001](docs/architecture/ADR-001-ipc-and-dock-intercept.md), [SECURITY](docs/SECURITY.md), [Firefox AMO](docs/AMO-FIREFOX.md).

## Limits & safety

- Linux + Ubuntu Dock only. Browsers outside the table (and Tor / GNOME Web / beta) stay unsupported.
- Tab peek needs one window per browser with at least two tabs. Several windows: stock hover window peeks still apply.
- Thumbnails stay stale until you actually view that tab again; they are not live views of background tabs.
- Private / incognito windows are not listed and not thumbnailed.
- Thumbnails are page screenshots. Anything with your UID on D-Bus or the host socket can read them ([SECURITY.md](docs/SECURITY.md)).
- Do not install [brave-aero-peek](https://github.com/alkitect/brave-aero-peek) alongside this. Same unit and UUID; last install wins. That repo is frozen.
- This repo is the release source for tags and public docs ([CHANGELOG.md](CHANGELOG.md), [Releases](https://github.com/alkitect/browser-aero-peek/releases), [CONTRIBUTING.md](CONTRIBUTING.md)).

## License

GPL-3.0-only. See [LICENSE](LICENSE).

Copyright (C) 2026 alkitect

Optional tip jar: [ko-fi.com/alkitect](https://ko-fi.com/alkitect/?hidefeed=true&widget=true&embed=true)
