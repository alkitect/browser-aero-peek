// SPDX-License-Identifier: GPL-3.0-only
// MV3 service worker: nativeMessaging + favicon inline + tab thumb cache (Aero-peek style).

const HOST = "org.alkitect.browser_tabs";
const ALARM = "alkitect-tab-dock-keepalive";
const FAVICON_MAX_BYTES = 48 * 1024;
const FAVICON_PX = 16;
const THUMB_W = 220; // must match shell-extension THUMB_W
const THUMB_H = 130; // must match shell-extension THUMB_H
// PNG at frame size: UI/text stays sharp (JPEG blocks ruin interfaces).
const THUMB_MAX_BYTES = 192 * 1024;

// Optional: install stages forced-browser-id.js for Flatpak unpacked copies.
try {
  importScripts("forced-browser-id.js");
} catch (_) {
  /* shared native tree has no forced id */
}

let port = null;
/** @type {Map<number, string>} tabId → data:image/png (frame-sized) */
const thumbCache = new Map();
let lastCaptureError = "";
let connectAttempt = 0;
let reconnectTimer = null;

function bytesToBase64(bytes) {
  let s = "";
  const chunk = 0x8000;
  for (let i = 0; i < bytes.length; i += chunk) {
    s += String.fromCharCode.apply(null, bytes.subarray(i, i + chunk));
  }
  return btoa(s);
}

function dataUrlToBlob(dataUrl) {
  const comma = dataUrl.indexOf(",");
  if (comma < 0) {
    throw new Error("bad data url");
  }
  const header = dataUrl.slice(0, comma);
  const b64 = dataUrl.slice(comma + 1);
  const mime = (header.match(/data:([^;,]+)/) || [null, "image/jpeg"])[1];
  const bin = atob(b64);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) {
    bytes[i] = bin.charCodeAt(i);
  }
  return new Blob([bytes], { type: mime });
}

function _smooth2d(ctx) {
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = "high";
}

/**
 * Cover-fit crop → stepwise downscale (≤0.5 per step) → exact WxH.
 * Canvas has no true bicubic API; imageSmoothingQuality 'high' is the closest.
 */
async function scaleToDataUrl(src, w, h, type, quality) {
  try {
    const blob = typeof src === "string" ? dataUrlToBlob(src) : src;
    if (!blob || blob.size === 0) {
      return "";
    }
    if (typeof createImageBitmap !== "function" || typeof OffscreenCanvas === "undefined") {
      return "";
    }
    const bmp = await createImageBitmap(blob);
    // Cover-fit source rect (center crop, no letterboxing).
    const fit = Math.max(w / bmp.width, h / bmp.height);
    const sw = w / fit;
    const sh = h / fit;
    const sx = (bmp.width - sw) / 2;
    const sy = (bmp.height - sh) / 2;

    let cw = Math.max(1, Math.round(sw));
    let ch = Math.max(1, Math.round(sh));
    let canvas = new OffscreenCanvas(cw, ch);
    let ctx = canvas.getContext("2d");
    _smooth2d(ctx);
    ctx.drawImage(bmp, sx, sy, sw, sh, 0, 0, cw, ch);
    bmp.close();

    // Stepwise: halve until near target (reduces aliasing vs one huge jump).
    while (cw > w * 2 || ch > h * 2) {
      const nw = Math.max(w, Math.floor(cw / 2));
      const nh = Math.max(h, Math.floor(ch / 2));
      const next = new OffscreenCanvas(nw, nh);
      const nctx = next.getContext("2d");
      _smooth2d(nctx);
      nctx.drawImage(canvas, 0, 0, cw, ch, 0, 0, nw, nh);
      canvas = next;
      cw = nw;
      ch = nh;
    }

    if (cw !== w || ch !== h) {
      const final = new OffscreenCanvas(w, h);
      const fctx = final.getContext("2d");
      _smooth2d(fctx);
      fctx.drawImage(canvas, 0, 0, cw, ch, 0, 0, w, h);
      canvas = final;
    }

    const opts =
      type === "image/jpeg" && quality != null ? { type, quality } : { type };
    const out = await canvas.convertToBlob(opts);
    if (!out || out.size === 0) {
      return "";
    }
    const max = type === "image/png" || type === "image/jpeg" ? THUMB_MAX_BYTES : FAVICON_MAX_BYTES;
    if (out.size > max) {
      return "";
    }
    const buf = new Uint8Array(await out.arrayBuffer());
    return `data:${type};base64,${bytesToBase64(buf)}`;
  } catch (_) {
    return "";
  }
}

async function toPngDataUrl(src) {
  return scaleToDataUrl(src, FAVICON_PX, FAVICON_PX, "image/png", 1);
}

async function tryInlineUrl(url) {
  if (!url) {
    return "";
  }
  if (url.startsWith("data:image/png")) {
    return url.length <= FAVICON_MAX_BYTES * 2 ? url : "";
  }
  if (url.startsWith("data:")) {
    return toPngDataUrl(url);
  }
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 800);
    let r;
    try {
      r = await fetch(url, { signal: ctrl.signal });
    } finally {
      clearTimeout(timer);
    }
    if (!r.ok) {
      return "";
    }
    const blob = await r.blob();
    if (blob.size === 0 || blob.size > FAVICON_MAX_BYTES * 4) {
      return "";
    }
    const ct = (blob.type || r.headers.get("content-type") || "").split(";")[0].trim();
    if (ct === "image/png" && blob.size <= FAVICON_MAX_BYTES) {
      const buf = new Uint8Array(await blob.arrayBuffer());
      return `data:image/png;base64,${bytesToBase64(buf)}`;
    }
    return toPngDataUrl(blob);
  } catch (_) {
    return "";
  }
}

async function inlineFavicon(favIconUrl, pageUrl) {
  const candidates = [];
  if (favIconUrl) {
    candidates.push(favIconUrl);
  }
  if (pageUrl && (pageUrl.startsWith("http://") || pageUrl.startsWith("https://"))) {
    candidates.push(
      `chrome://favicon2/?size=32&scale_factor=1x&url=${encodeURIComponent(pageUrl)}`
    );
    candidates.push(`chrome://favicon/size/16@1x/${pageUrl}`);
  }
  for (const u of candidates) {
    const data = await tryInlineUrl(u);
    if (data) {
      return data;
    }
  }
  return "";
}

function captureVisibleTabP(windowId) {
  return new Promise((resolve, reject) => {
    const opts = { format: "png" };
    const done = (dataUrl) => {
      const err = chrome.runtime.lastError;
      if (err) {
        reject(new Error(err.message));
        return;
      }
      if (!dataUrl) {
        reject(new Error("empty capture"));
        return;
      }
      resolve(dataUrl);
    };
    try {
      if (windowId != null) {
        chrome.tabs.captureVisibleTab(windowId, opts, done);
      } else {
        chrome.tabs.captureVisibleTab(opts, done);
      }
    } catch (e) {
      reject(e);
    }
  });
}

async function persistThumb(tabId, dataUrl) {
  thumbCache.set(tabId, dataUrl);
  try {
    await chrome.storage.session.set({ ["t" + tabId]: dataUrl });
  } catch (_) {
    /* optional */
  }
}

async function loadThumb(tabId) {
  if (thumbCache.has(tabId)) {
    return thumbCache.get(tabId) || "";
  }
  try {
    const key = "t" + tabId;
    const got = await chrome.storage.session.get(key);
    if (got[key]) {
      thumbCache.set(tabId, got[key]);
      return got[key];
    }
  } catch (_) {
    /* ignore */
  }
  return "";
}

async function captureThumb(windowId, tabId) {
  if (tabId == null) {
    return;
  }
  try {
    let raw;
    try {
      raw = await captureVisibleTabP(windowId);
    } catch (_e1) {
      raw = await captureVisibleTabP(undefined);
    }
    // High-quality stepwise downscale; PNG encode (no lossy UI artifacts).
    const scaled = await scaleToDataUrl(raw, THUMB_W, THUMB_H, "image/png");
    if (!scaled) {
      lastCaptureError = "scale produced empty thumb";
      return;
    }
    lastCaptureError = "";
    await persistThumb(tabId, scaled);
  } catch (e) {
    lastCaptureError = String(e && e.message ? e.message : e);
    console.warn("captureThumb failed", lastCaptureError);
  }
}

function scheduleReconnect(reason) {
  if (reconnectTimer != null) {
    return;
  }
  const delay = Math.min(20000, 800 * Math.pow(1.6, connectAttempt));
  connectAttempt += 1;
  console.warn("NM reconnect in", Math.round(delay), "ms:", reason || "");
  reconnectTimer = setTimeout(() => {
    reconnectTimer = null;
    if (!port) {
      connect();
    }
  }, delay);
}

function connect() {
  if (port) {
    try {
      port.disconnect();
    } catch (_) {
      /* ignore */
    }
    port = null;
  }
  try {
    port = chrome.runtime.connectNative(HOST);
  } catch (e) {
    console.warn("connectNative failed", e);
    port = null;
    scheduleReconnect(String(e));
    return;
  }
  port.onMessage.addListener(onHostMessage);
  port.onDisconnect.addListener(() => {
    const err = chrome.runtime.lastError;
    port = null;
    scheduleReconnect(err && err.message ? err.message : "disconnect");
  });
  connectAttempt = 0;
  console.info("NM connected", HOST);
  // Mandatory bind hello — host rejects unbound peers (PREP-002).
  try {
    port.postMessage({ type: "hello", browserId: detectBrowserId() });
  } catch (e) {
    console.warn("hello failed", e);
    port = null;
    scheduleReconnect("hello failed");
  }
}

/** Registry id for NM bind; Brave-first UA heuristics (shared MV3 blast radius). */
function detectBrowserId() {
  // Optional install-staged file for Flatpak (or other) unpacked copies.
  if (typeof FORCED_BROWSER_ID === "string" && FORCED_BROWSER_ID) {
    return FORCED_BROWSER_ID;
  }
  try {
    if (navigator.brave && typeof navigator.brave.isBrave === "function") {
      return "brave";
    }
  } catch (_) {
    /* ignore */
  }
  // userAgentData brands first — reduced UA often drops "Vivaldi/…" in SW.
  try {
    const brands = (navigator.userAgentData && navigator.userAgentData.brands) || [];
    for (const b of brands) {
      const brand = String((b && b.brand) || "");
      if (/vivaldi/i.test(brand)) {
        return "vivaldi";
      }
      if (/opera/i.test(brand)) {
        return "opera";
      }
      if (/microsoft edge/i.test(brand)) {
        return "edge";
      }
      if (/brave/i.test(brand)) {
        return "brave";
      }
    }
  } catch (_) {
    /* ignore */
  }
  const ua = navigator.userAgent || "";
  if (/Edg\//.test(ua)) {
    return "edge";
  }
  if (/OPR\//.test(ua) || /Opera\//.test(ua)) {
    return "opera";
  }
  if (/Vivaldi\//i.test(ua) || /\bVivaldi\b/i.test(ua)) {
    return "vivaldi";
  }
  if (/Brave[ /]/.test(ua) || /\bBrave\b/.test(ua)) {
    return "brave";
  }
  if (/Firefox\//.test(ua)) {
    return "firefox";
  }
  if (/Chromium\//.test(ua)) {
    return "chromium";
  }
  if (/Chrome\//.test(ua)) {
    return "chrome";
  }
  return "brave";
}

function ensureConnected() {
  if (!port) {
    connect();
  }
}

function onHostMessage(msg) {
  if (!msg || typeof msg !== "object") {
    return;
  }
  const type = msg.type;
  if (type === "list") {
    chrome.windows.getAll({ populate: true, windowTypes: ["normal"] }, (windows) => {
      const err = chrome.runtime.lastError;
      if (err) {
        reply({ type: "list", tabs: [], error: err.message });
        return;
      }
      const wins = windows || [];
      // Prefer focused Brave window; else visible; else minimized (still list tabs).
      const win =
        wins.find((w) => w.focused) ||
        wins.find((w) => w.state !== "minimized") ||
        wins[0];
      if (!win) {
        reply({ type: "list", tabs: [] });
        return;
      }
      const list = (win.tabs || []).filter((t) => t.id != null);
      (async () => {
        const active = list.find((t) => t.active);
        // captureVisibleTab fails while minimized — use cache only.
        if (active && win.state !== "minimized") {
          await captureThumb(win.id, active.id);
        }
        const build = Promise.all(
          list.map(async (t) => ({
            id: t.id,
            title: t.title || "",
            favIconUrl: await inlineFavicon(t.favIconUrl || "", t.url || ""),
            thumb: (await loadThumb(t.id)) || "",
          }))
        );
        // Stay under host ListTabs timeout (5s) — hung favicon/capture must not drop the peer.
        let out;
        try {
          out = await Promise.race([
            build,
            new Promise((_, rej) => setTimeout(() => rej(new Error("list-budget")), 3500)),
          ]);
        } catch (_) {
          out = list.map((t) => ({
            id: t.id,
            title: t.title || "",
            favIconUrl: "",
            thumb: thumbCache.get(t.id) || "",
          }));
        }
        reply({
          type: "list",
          tabs: out,
          window_state: win.state || "",
          capture_error: lastCaptureError || undefined,
        });
      })();
    });
    return;
  }
  if (type === "activate") {
    const tabId = msg.tabId;
    if (typeof tabId !== "number") {
      reply({ type: "activate", ok: false, error: "InvalidTab" });
      return;
    }
    chrome.tabs.update(tabId, { active: true }, (tab) => {
      const err = chrome.runtime.lastError;
      if (err || !tab) {
        reply({ type: "activate", ok: false, error: err?.message || "InvalidTab" });
        return;
      }
      const done = () => {
        reply({ type: "activate", ok: true });
        setTimeout(() => captureThumb(tab.windowId, tab.id), 350);
      };
      if (tab.windowId != null) {
        chrome.windows.update(tab.windowId, { focused: true }, done);
      } else {
        done();
      }
    });
    return;
  }
  if (type === "ping") {
    reply({
      type: "pong",
      thumbs: thumbCache.size,
      capture_error: lastCaptureError || "",
    });
    return;
  }
  reply({ type: "error", error: "unknown" });
}

function reply(obj) {
  if (!port) {
    return;
  }
  try {
    port.postMessage(obj);
  } catch (e) {
    console.warn("postMessage failed", e);
    port = null;
    scheduleReconnect("postMessage failed");
  }
}

chrome.tabs.onActivated.addListener((info) => {
  ensureConnected();
  setTimeout(() => captureThumb(info.windowId, info.tabId), 300);
});

chrome.tabs.onRemoved.addListener((tabId) => {
  thumbCache.delete(tabId);
  try {
    chrome.storage.session.remove("t" + tabId);
  } catch (_) {
    /* ignore */
  }
});

chrome.alarms.create(ALARM, { periodInMinutes: 1 });
chrome.alarms.onAlarm.addListener((a) => {
  if (a.name === ALARM) {
    ensureConnected();
  }
});

chrome.runtime.onInstalled.addListener(connect);
chrome.runtime.onStartup.addListener(connect);
connect();
