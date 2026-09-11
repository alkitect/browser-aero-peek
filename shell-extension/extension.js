/* SPDX-License-Identifier: GPL-3.0-only
 *
 * Brave tab peek: hover-dwell → horizontal Aero-peek-style strip (thumb + title).
 * Does NOT wrap activate() — stock click-action stays minimize-or-previews.
 * Enable requires logout/in on Wayland after install.
 */

const { Gio, GLib, St, Clutter } = imports.gi;
const Main = imports.ui.main;
const ExtensionUtils = imports.misc.extensionUtils;
const Me = ExtensionUtils.getCurrentExtension();

const BUS_NAME = 'org.alkitect.BrowserTabs1';
const OBJ_PATH = '/org/alkitect/BrowserTabs1';
const IFACE = 'org.alkitect.BrowserTabs1';

const DWELL_MS = 100;
// Leave gap must cover mouse travel: dock icon → app-name tooltip → peek strip.
const LEAVE_MS = 300;
const CORRIDOR_POLL_MS = 50;
const CORRIDOR_PAD_PX = 12;
const CACHE_TTL_MS = 1000;
const REBIND_SEC = 2;
const THUMB_W = 220;
const THUMB_H = 130;
/** Gap between peek strip and the live dock app-name label (not a fixed dock offset). */
const LABEL_GAP_PX = 16;
/** Fallback label height if dock label is not on stage yet. */
const LABEL_FALLBACK_H = 32;
// Match GNOME Dash app-name tooltip fade (DASH_ITEM_LABEL_*_TIME).
const FADE_IN_MS = 150;
const FADE_OUT_MS = 100;
const HEADER_FAV_PX = 16;
const TITLE_MAX = 36;
const PLACEHOLDER_ICON = 'applications-internet-symbolic';
const EMPTY_PREVIEW = 'No preview yet';
const MAX_DATA_BYTES = 256 * 1024;

const BrowserTabsIface = `
<node>
  <interface name="${IFACE}">
    <method name="ListTabs">
      <arg type="s" name="tabs_json" direction="out"/>
    </method>
    <method name="Activate">
      <arg type="u" name="tab_id" direction="in"/>
    </method>
  </interface>
</node>`;

let _proxy = null;

function _getProxy() {
    if (_proxy)
        return _proxy;
    const info = Gio.DBusInterfaceInfo.new_for_xml(BrowserTabsIface);
    _proxy = new Gio.DBusProxy({
        g_connection: Gio.DBus.session,
        g_interface_info: info,
        g_name: BUS_NAME,
        g_object_path: OBJ_PATH,
        g_interface_name: IFACE,
    });
    try {
        _proxy.init(null);
    } catch (e) {
        _proxy = null;
        throw e;
    }
    return _proxy;
}

function _giconFromDataUrl(dataUrl) {
    if (!dataUrl || typeof dataUrl !== 'string' || !dataUrl.startsWith('data:'))
        return null;
    const comma = dataUrl.indexOf(',');
    if (comma < 0 || !dataUrl.substring(5, comma).includes(';base64'))
        return null;
    let raw;
    try {
        raw = GLib.base64_decode(dataUrl.substring(comma + 1));
    } catch (_e) {
        return null;
    }
    if (!raw || raw.length === 0 || raw.length > MAX_DATA_BYTES)
        return null;
    try {
        return Gio.BytesIcon.new(GLib.Bytes.new(raw));
    } catch (_e) {
        return null;
    }
}

function _truncateTitle(title, id) {
    const t = (title || `Tab ${id}`).replace(/\s+/g, ' ').trim();
    if (t.length <= TITLE_MAX)
        return t;
    return `${t.slice(0, TITLE_MAX - 1)}…`;
}

function _thumbCacheDir() {
    return GLib.build_filenamev([GLib.get_user_runtime_dir(), 'alkitect-tab-dock']);
}

/** Drop paint-cache files for closed tabs (keepIds = current ListTabs ids). */
function _pruneThumbCache(keepIds) {
    const dir = _thumbCacheDir();
    let enumerator;
    try {
        enumerator = Gio.File.new_for_path(dir).enumerate_children(
            'standard::name', Gio.FileQueryInfoFlags.NONE, null);
    } catch (_e) {
        return;
    }
    let info;
    while ((info = enumerator.next_file(null)) !== null) {
        const name = info.get_name();
        const m = /^tab-(\d+)\./.exec(name);
        if (!m)
            continue;
        const id = parseInt(m[1], 10);
        if (keepIds.has(id))
            continue;
        try {
            Gio.File.new_for_path(GLib.build_filenamev([dir, name])).delete(null);
        } catch (_e) { /* ignore */ }
    }
}

function _writeThumbFile(dataUrl, tabId) {
    const comma = dataUrl.indexOf(',');
    if (comma < 0 || !dataUrl.substring(5, comma).includes(';base64'))
        return null;
    let raw;
    try {
        raw = GLib.base64_decode(dataUrl.substring(comma + 1));
    } catch (_e) {
        return null;
    }
    if (!raw || raw.length === 0 || raw.length > MAX_DATA_BYTES)
        return null;
    const dir = _thumbCacheDir();
    try {
        GLib.mkdir_with_parents(dir, 0o700);
    } catch (_e) { /* exists */ }
    const ext = dataUrl.startsWith('data:image/png') ? 'png' : 'jpg';
    const path = GLib.build_filenamev([dir, `tab-${tabId}.${ext}`]);
    try {
        Gio.File.new_for_path(path).replace_contents(
            raw, null, false, Gio.FileCreateFlags.REPLACE_DESTINATION, null);
    } catch (_e) {
        return null;
    }
    const other = ext === 'png' ? 'jpg' : 'png';
    try {
        Gio.File.new_for_path(GLib.build_filenamev([dir, `tab-${tabId}.${other}`])).delete(null);
    } catch (_e) { /* none */ }
    return path;
}

/** Widescreen PNG/JPEG → Clutter actor (CSS data: backgrounds do not paint in St). */
function _thumbActorFromDataUrl(dataUrl, tabId) {
    const path = _writeThumbFile(dataUrl, tabId);
    if (!path)
        return null;
    try {
        const themeContext = St.ThemeContext.get_for_stage(global.stage);
        const scale = themeContext.scale_factor || 1;
        const file = Gio.File.new_for_path(path);
        const tex = St.TextureCache.get_default().load_file_async(
            file,
            THUMB_W * scale,
            THUMB_H * scale,
            scale,
            scale);
        tex.set_size(THUMB_W, THUMB_H);
        const wrap = new St.Bin({
            reactive: false,
            style: `width: ${THUMB_W}px; height: ${THUMB_H}px; border-radius: 6px;`,
        });
        wrap.set_child(tex);
        return wrap;
    } catch (_e) {
        return null;
    }
}

function _isBraveApp(app) {
    if (!app)
        return false;
    const id = (app.get_id() || '').toLowerCase();
    if (id === 'brave-browser.desktop' || id === 'brave-browser')
        return true;
    try {
        const info = app.get_app_info();
        const wm = info && info.get_startup_wm_class();
        if (wm && wm.toLowerCase() === 'brave-browser')
            return true;
    } catch (_e) { /* ignore */ }
    return false;
}

/** Include minimized windows (dock getInterestingWindows is fine, but be explicit). */
function _braveWindows(appIcon) {
    if (!appIcon || !appIcon.app)
        return [];
    let windows = [];
    try {
        if (typeof appIcon.getWindows === 'function')
            windows = appIcon.getWindows();
        else
            windows = appIcon.app.get_windows();
    } catch (_e) {
        windows = appIcon.app.get_windows();
    }
    return windows.filter(w => w && !w.skip_taskbar);
}

function _actorBox(actor) {
    const [x, y] = actor.get_transformed_position();
    let w = actor.width;
    let h = actor.height;
    try {
        const [tw, th] = actor.get_transformed_size();
        if (tw > 0)
            w = tw;
        if (th > 0)
            h = th;
    } catch (_e) { /* allocation ok */ }
    return { x, y, w, h };
}

/**
 * Ubuntu Dock / Dash app-name tooltip box (icon.label), if mapped.
 * Ensures showLabel() so geometry matches the bubble the user sees.
 */
function _dockLabelBox(icon) {
    if (!icon)
        return null;
    try {
        if (typeof icon.showLabel === 'function')
            icon.showLabel();
    } catch (_e) { /* ignore */ }
    const label = icon.label;
    if (!label)
        return null;
    try {
        if (typeof label.get_stage === 'function' && !label.get_stage())
            return null;
        const box = _actorBox(label);
        if (!(box.w > 0 && box.h > 0))
            return null;
        return box;
    } catch (_e) {
        return null;
    }
}

function _unionInflate(boxes, pad) {
    let x1 = Infinity;
    let y1 = Infinity;
    let x2 = -Infinity;
    let y2 = -Infinity;
    let any = false;
    for (const b of boxes) {
        if (!b || !(b.w > 0 && b.h > 0))
            continue;
        any = true;
        x1 = Math.min(x1, b.x);
        y1 = Math.min(y1, b.y);
        x2 = Math.max(x2, b.x + b.w);
        y2 = Math.max(y2, b.y + b.h);
    }
    if (!any)
        return null;
    return {
        x: x1 - pad,
        y: y1 - pad,
        w: (x2 - x1) + 2 * pad,
        h: (y2 - y1) + 2 * pad,
    };
}

function _pointInBox(px, py, b) {
    return b && px >= b.x && px <= b.x + b.w && py >= b.y && py <= b.y + b.h;
}

/**
 * Place strip 16px past the dock name label (above / beside depending on dock edge).
 */
function _peekPosition(anchorActor, sw, sh) {
    const [ax, ay] = anchorActor.get_transformed_position();
    const [aw, ah] = anchorActor.get_transformed_size();
    const monitor = Main.layoutManager.findMonitorForActor(anchorActor) ||
        Main.layoutManager.currentMonitor;
    const label = _dockLabelBox(anchorActor);
    const midX = ax + aw / 2;
    const midY = ay + ah / 2;
    let x = Math.round(ax + (aw - sw) / 2);
    let y = Math.round(ay - sh - LABEL_GAP_PX - LABEL_FALLBACK_H);

    if (label) {
        const labelBelow = label.y >= ay + ah - 2;
        const labelRight = label.x >= ax + aw - 2;
        const labelLeft = label.x + label.w <= ax + 2;
        if (labelBelow) {
            x = Math.round(ax + (aw - sw) / 2);
            y = Math.round(label.y + label.h + LABEL_GAP_PX);
        } else if (labelRight) {
            x = Math.round(label.x + label.w + LABEL_GAP_PX);
            y = Math.round(ay + (ah - sh) / 2);
        } else if (labelLeft) {
            x = Math.round(label.x - sw - LABEL_GAP_PX);
            y = Math.round(ay + (ah - sh) / 2);
        } else {
            x = Math.round(ax + (aw - sw) / 2);
            y = Math.round(label.y - sh - LABEL_GAP_PX);
        }
    } else if (monitor) {
        const leftish = midX < monitor.x + monitor.width * 0.25;
        const rightish = midX > monitor.x + monitor.width * 0.75;
        const topish = midY < monitor.y + monitor.height * 0.25;
        if (leftish) {
            x = Math.round(ax + aw + LABEL_GAP_PX + LABEL_FALLBACK_H);
            y = Math.round(ay + (ah - sh) / 2);
        } else if (rightish) {
            x = Math.round(ax - sw - LABEL_GAP_PX - LABEL_FALLBACK_H);
            y = Math.round(ay + (ah - sh) / 2);
        } else if (topish) {
            x = Math.round(ax + (aw - sw) / 2);
            y = Math.round(ay + ah + LABEL_GAP_PX + LABEL_FALLBACK_H);
        }
    }

    if (monitor) {
        x = Math.max(monitor.x + 8, Math.min(x, monitor.x + monitor.width - sw - 8));
        y = Math.max(monitor.y + 8, Math.min(y, monitor.y + monitor.height - sh - 8));
    }
    return [Math.max(0, x), Math.max(0, y)];
}

/** True if pointer is in the transit gap between icon and peek strip (incl. name label). */
function _pointerInLeaveCorridor(anchor, strip) {
    if (!anchor || !strip)
        return false;
    let px, py;
    try {
        [px, py] = global.get_pointer();
    } catch (_e) {
        return false;
    }
    const icon = _actorBox(anchor);
    const peek = _actorBox(strip);
    const label = _dockLabelBox(anchor);
    const union = _unionInflate([icon, peek, label], CORRIDOR_PAD_PX);
    if (!_pointInBox(px, py, union))
        return false;

    // Bottom dock: strip above icon — gap is vertical between them.
    if (peek.y + peek.h <= icon.y + 2) {
        return py >= peek.y + peek.h - CORRIDOR_PAD_PX &&
            py <= icon.y + CORRIDOR_PAD_PX &&
            px >= union.x && px <= union.x + union.w;
    }
    // Top dock: strip below icon.
    if (peek.y >= icon.y + icon.h - 2) {
        return py >= icon.y + icon.h - CORRIDOR_PAD_PX &&
            py <= peek.y + CORRIDOR_PAD_PX &&
            px >= union.x && px <= union.x + union.w;
    }
    // Left dock: strip to the right of icon.
    if (peek.x >= icon.x + icon.w - 2) {
        return px >= icon.x + icon.w - CORRIDOR_PAD_PX &&
            px <= peek.x + CORRIDOR_PAD_PX &&
            py >= union.y && py <= union.y + union.h;
    }
    // Right dock: strip to the left of icon.
    if (peek.x + peek.w <= icon.x + 2) {
        return px >= peek.x + peek.w - CORRIDOR_PAD_PX &&
            px <= icon.x + CORRIDOR_PAD_PX &&
            py >= union.y && py <= union.y + union.h;
    }
    return true;
}

class Extension {
    constructor() {
        this._bindings = new Map();
        this._dwellSource = 0;
        this._leaveSource = 0;
        this._rebindSource = 0;
        this._popup = null;
        this._anchor = null;
        this._fadingStrip = null;
        this._pendingShowIcon = null;
        this._leaveBudgetEnd = 0;
        this._listInFlight = false;
        this._cacheTabs = null;
        this._cacheAt = 0;
        this._warnedNoExt = false;
    }

    enable() {
        this._rebind();
        this._rebindSource = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, REBIND_SEC, () => {
            this._rebind();
            return GLib.SOURCE_CONTINUE;
        });
        log(`${Me.metadata.uuid}: hover-dwell peek strip enabled`);
    }

    disable() {
        this._cancelDwell();
        this._cancelLeave();
        this._destroyPopup(true);
        this._unbindAll();
        if (this._rebindSource) {
            GLib.source_remove(this._rebindSource);
            this._rebindSource = 0;
        }
        _proxy = null;
    }

    _clearPendingShow() {
        this._pendingShowIcon = null;
    }

    _unbindAll() {
        for (const [icon, meta] of this._bindings) {
            try {
                if (meta.hoverId)
                    icon.disconnect(meta.hoverId);
            } catch (_e) { /* destroyed */ }
        }
        this._bindings.clear();
    }

    _getDocks() {
        const em = Main.extensionManager;
        if (!em)
            return [];
        const dockExt = em.lookup('ubuntu-dock@ubuntu.com');
        if (!dockExt || dockExt.state !== ExtensionUtils.ExtensionState.ENABLED)
            return [];
        try {
            const DockManager = dockExt.imports.docking.DockManager;
            return DockManager.allDocks || [];
        } catch (_e) {
            return [];
        }
    }

    _rebind() {
        const still = new Set();
        for (const dock of this._getDocks()) {
            let icons = [];
            try {
                icons = dock.dash.getAppIcons();
            } catch (_e) {
                continue;
            }
            for (const icon of icons) {
                if (!icon || !icon.app || !_isBraveApp(icon.app))
                    continue;
                still.add(icon);
                if (this._bindings.has(icon))
                    continue;
                const hoverId = icon.connect('notify::hover', () => this._onHover(icon));
                this._bindings.set(icon, { hoverId });
            }
        }
        for (const [icon, meta] of [...this._bindings.entries()]) {
            if (still.has(icon))
                continue;
            try {
                icon.disconnect(meta.hoverId);
            } catch (_e) { /* gone */ }
            this._bindings.delete(icon);
        }
    }

    _onHover(icon) {
        if (icon.hover) {
            this._cancelLeave();
            if (this._popup && this._anchor === icon)
                return;
            if (this._pendingShowIcon === icon)
                return;
            if (this._dwellSource)
                return;
            this._scheduleDwell(icon);
        } else {
            this._cancelDwell();
            this._scheduleLeave();
        }
    }

    _scheduleDwell(icon) {
        this._cancelDwellTimer();
        if (this._pendingShowIcon && this._pendingShowIcon !== icon)
            this._clearPendingShow();
        if (this._policyOk(icon))
            this._prefetchList(icon);
        this._dwellSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, DWELL_MS, () => {
            this._dwellSource = 0;
            if (!icon.hover)
                return GLib.SOURCE_REMOVE;
            this._tryPeek(icon);
            return GLib.SOURCE_REMOVE;
        });
    }

    _cancelDwellTimer() {
        if (this._dwellSource) {
            GLib.source_remove(this._dwellSource);
            this._dwellSource = 0;
        }
    }

    _cancelDwell() {
        this._cancelDwellTimer();
        this._clearPendingShow();
    }

    _cancelLeaveSourceOnly() {
        if (this._leaveSource) {
            GLib.source_remove(this._leaveSource);
            this._leaveSource = 0;
        }
    }

    _cancelLeave() {
        this._cancelLeaveSourceOnly();
        this._leaveBudgetEnd = 0;
    }

    _scheduleLeave() {
        this._clearPendingShow();
        this._cancelLeaveSourceOnly();
        if (!this._popup && !this._fadingStrip)
            return;
        const now = GLib.get_monotonic_time() / 1000;
        if (!this._leaveBudgetEnd)
            this._leaveBudgetEnd = now + LEAVE_MS;
        this._armLeaveTick();
    }

    _armLeaveTick() {
        this._cancelLeaveSourceOnly();
        const now = GLib.get_monotonic_time() / 1000;
        const remaining = Math.max(0, this._leaveBudgetEnd - now);
        const wait = Math.min(CORRIDOR_POLL_MS, Math.max(1, Math.ceil(remaining)));
        this._leaveSource = GLib.timeout_add(GLib.PRIORITY_DEFAULT, wait, () => {
            this._leaveSource = 0;
            if (this._popup && this._popup.hover) {
                this._leaveBudgetEnd = 0;
                return GLib.SOURCE_REMOVE;
            }
            if (this._anchor && this._anchor.hover) {
                this._leaveBudgetEnd = 0;
                return GLib.SOURCE_REMOVE;
            }
            const t = GLib.get_monotonic_time() / 1000;
            if (this._popup && this._anchor &&
                _pointerInLeaveCorridor(this._anchor, this._popup) &&
                t < this._leaveBudgetEnd) {
                this._armLeaveTick();
                return GLib.SOURCE_REMOVE;
            }
            this._leaveBudgetEnd = 0;
            this._destroyPopup();
            return GLib.SOURCE_REMOVE;
        });
    }

    _policyOk(icon) {
        if (!_isBraveApp(icon.app))
            return false;
        return _braveWindows(icon).length === 1;
    }

    _prefetchList(icon) {
        if (!this._policyOk(icon))
            return;
        if (this._listInFlight)
            return;
        const now = GLib.get_monotonic_time() / 1000;
        if (this._cacheTabs && (now - this._cacheAt) < CACHE_TTL_MS)
            return;
        this._startListTabs(icon);
    }

    _tryPeek(icon) {
        if (!this._policyOk(icon)) {
            this._clearPendingShow();
            return;
        }
        const now = GLib.get_monotonic_time() / 1000;
        if (this._cacheTabs && (now - this._cacheAt) < CACHE_TTL_MS) {
            if (Array.isArray(this._cacheTabs) && this._cacheTabs.length >= 2) {
                this._pendingShowIcon = icon;
                this._showPeekStrip(this._cacheTabs, icon);
            } else {
                this._clearPendingShow();
            }
            return;
        }
        // Dwell success: may show when ListTabs returns (or when in-flight completes).
        this._pendingShowIcon = icon;
        if (this._listInFlight)
            return;
        this._startListTabs(icon);
    }

    _startListTabs(icon) {
        this._listInFlight = true;
        let proxy;
        try {
            proxy = _getProxy();
        } catch (_e) {
            this._listInFlight = false;
            this._clearPendingShow();
            return;
        }
        proxy.call('ListTabs', null, Gio.DBusCallFlags.NONE, 8000, null, (_p, res) => {
            this._listInFlight = false;
            try {
                const variant = proxy.call_finish(res);
                const [json] = variant.deep_unpack();
                const tabs = JSON.parse(json);
                this._cacheTabs = tabs;
                this._cacheAt = GLib.get_monotonic_time() / 1000;
                if (!Array.isArray(tabs) || tabs.length < 2) {
                    this._clearPendingShow();
                    return;
                }
                // Prefetch alone never shows — only pending-show after dwell.
                if (this._pendingShowIcon === icon && icon.hover)
                    this._showPeekStrip(tabs, icon);
            } catch (e) {
                this._clearPendingShow();
                const msg = String(e);
                log(`${Me.metadata.uuid}: ListTabs failed: ${msg}`);
                if (!this._warnedNoExt && msg.indexOf('NoExtension') !== -1) {
                    this._warnedNoExt = true;
                    Main.notify('Browser Tab Dock',
                        'Brave extension not connected. Open Brave, reload Alkitect Tab Dock, then hover again.');
                }
            }
        });
    }

    _destroyPopup(immediate = false) {
        this._clearPendingShow();
        this._cancelLeaveSourceOnly();
        this._leaveBudgetEnd = 0;

        if (immediate && this._fadingStrip) {
            try {
                this._fadingStrip.remove_all_transitions();
                this._fadingStrip.destroy();
            } catch (_e) { /* ignore */ }
            this._fadingStrip = null;
        }

        if (!this._popup) {
            this._anchor = null;
            return;
        }
        const strip = this._popup;
        this._popup = null;
        this._anchor = null;
        try {
            strip.remove_all_transitions();
        } catch (_e) { /* ignore */ }
        if (immediate) {
            try {
                strip.destroy();
            } catch (_e) { /* ignore */ }
            return;
        }
        try {
            strip.reactive = false;
            this._fadingStrip = strip;
            strip.ease({
                opacity: 0,
                duration: FADE_OUT_MS,
                mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                onComplete: () => {
                    if (this._fadingStrip === strip)
                        this._fadingStrip = null;
                    try {
                        strip.destroy();
                    } catch (_e) { /* ignore */ }
                },
            });
        } catch (_e) {
            this._fadingStrip = null;
            try {
                strip.destroy();
            } catch (_e2) { /* ignore */ }
        }
    }

    _makeCard(tab, onActivate) {
        const card = new St.Button({
            style_class: 'button',
            reactive: true,
            can_focus: true,
            track_hover: true,
            style: 'padding: 6px; margin: 0; border-radius: 8px; background-color: transparent;',
        });
        const col = new St.BoxLayout({
            vertical: true,
            x_expand: false,
            style: 'spacing: 6px;',
        });

        const header = new St.BoxLayout({
            vertical: false,
            x_expand: false,
            style: `spacing: 4px; width: ${THUMB_W}px;`,
        });
        const fav = new St.Icon({
            icon_name: PLACEHOLDER_ICON,
            icon_size: HEADER_FAV_PX,
            y_align: Clutter.ActorAlign.CENTER,
        });
        const gicon = _giconFromDataUrl(tab.favicon || '');
        if (gicon)
            fav.gicon = gicon;
        header.add_child(fav);

        const title = new St.Label({
            text: _truncateTitle(tab.title, tab.id),
            y_align: Clutter.ActorAlign.CENTER,
            style: 'font-size: 11px; padding: 0 2px;',
        });
        try {
            title.clutter_text.ellipsize = imports.gi.Pango.EllipsizeMode.END;
            title.clutter_text.line_wrap = false;
        } catch (_e) { /* pango optional */ }
        header.add_child(title);
        col.add_child(header);

        const frame = new St.Bin({
            reactive: false,
            x_expand: false,
            y_expand: false,
            x_align: Clutter.ActorAlign.CENTER,
            y_align: Clutter.ActorAlign.CENTER,
            style: `width: ${THUMB_W}px; height: ${THUMB_H}px; border-radius: 6px; ` +
                'background-color: #141414; border: 1px solid rgba(255,255,255,0.06);',
        });

        let painted = false;
        const thumbUrl = tab.thumb || '';
        if (thumbUrl.startsWith('data:image/')) {
            const actor = _thumbActorFromDataUrl(thumbUrl, tab.id);
            if (actor) {
                frame.set_child(actor);
                painted = true;
            }
        }
        if (!painted) {
            frame.set_child(new St.Label({
                text: EMPTY_PREVIEW,
                x_align: Clutter.ActorAlign.CENTER,
                y_align: Clutter.ActorAlign.CENTER,
                style: 'font-size: 11px; color: rgba(255,255,255,0.45);',
            }));
        }
        col.add_child(frame);

        card.set_child(col);
        card.connect('notify::hover', () => {
            card.set_style(card.hover
                ? 'padding: 6px; margin: 0; border-radius: 8px; background-color: rgba(255,255,255,0.12);'
                : 'padding: 6px; margin: 0; border-radius: 8px; background-color: transparent;');
        });
        card.connect('clicked', () => onActivate());
        return card;
    }

    _showPeekStrip(tabs, anchorActor) {
        // Never stack over a fading orphan.
        this._destroyPopup(true);
        this._pendingShowIcon = null;
        this._anchor = anchorActor;

        const keep = new Set();
        for (const t of tabs) {
            if (t && t.id != null)
                keep.add(Number(t.id));
        }
        _pruneThumbCache(keep);

        const strip = new St.BoxLayout({
            vertical: false,
            reactive: true,
            track_hover: true,
            opacity: 0,
            style: 'spacing: 4px; padding: 8px; margin: 0; ' +
                'background-color: rgba(20,20,20,0.94); border-radius: 12px; ' +
                'border: 1px solid rgba(255,255,255,0.08);',
        });

        for (const t of tabs) {
            strip.add_child(this._makeCard(t, () => {
                this._activateAndRaise(t.id, anchorActor);
                this._destroyPopup();
            }));
        }

        strip.connect('notify::hover', () => {
            if (strip.hover)
                this._cancelLeave();
            else
                this._scheduleLeave();
        });

        Main.uiGroup.add_child(strip);
        this._popup = strip;

        try {
            if (typeof anchorActor.set_hover === 'function')
                anchorActor.set_hover(true);
        } catch (_e) { /* ignore */ }

        GLib.idle_add(GLib.PRIORITY_DEFAULT_IDLE, () => {
            if (this._popup !== strip)
                return GLib.SOURCE_REMOVE;
            try {
                const [x, y] = _peekPosition(anchorActor, strip.width, strip.height);
                strip.set_position(x, y);
            } catch (_e) {
                const [px, py] = global.get_pointer();
                strip.set_position(Math.max(0, px + 12), Math.max(0, py - strip.height - 12));
            }
            try {
                strip.remove_all_transitions();
                strip.ease({
                    opacity: 255,
                    duration: FADE_IN_MS,
                    mode: Clutter.AnimationMode.EASE_OUT_QUAD,
                });
            } catch (_e) {
                strip.opacity = 255;
            }
            return GLib.SOURCE_REMOVE;
        });
    }

    _activateAndRaise(tabId, appIcon) {
        let proxy;
        try {
            proxy = _getProxy();
        } catch (e) {
            Main.notifyError('Browser Tab Dock', String(e));
            return;
        }
        try {
            proxy.call_sync('Activate', new GLib.Variant('(u)', [tabId]),
                Gio.DBusCallFlags.NONE, 3000, null);
        } catch (e) {
            Main.notifyError('Browser Tab Dock', String(e));
            return;
        }
        const windows = _braveWindows(appIcon);
        if (windows.length === 1) {
            try {
                Main.activateWindow(windows[0]);
            } catch (_e) { /* MV3 focus may still work */ }
        }
    }
}

function init() {
    return new Extension();
}
