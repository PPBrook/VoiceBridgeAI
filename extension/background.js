/** Service worker: tab capture orchestration + subtitle relay. */

const DEFAULT_CONFIG = {
  serverUrl: "http://127.0.0.1:8765",
  asrMode: "tencent",
  asrProvider: "tencent",
  partialProvider: "tmt",
  finalProvider: "qiniu",
  reviseMode: "balanced",
  showEnglish: true,
};

let capturingTabId = null;

async function getConfig() {
  const stored = await chrome.storage.sync.get(DEFAULT_CONFIG);
  return { ...DEFAULT_CONFIG, ...stored };
}

async function ensureOffscreen() {
  const existing = await chrome.runtime.getContexts({
    contextTypes: ["OFFSCREEN_DOCUMENT"],
  });
  if (existing.length > 0) return;
  await chrome.offscreen.createDocument({
    url: "offscreen.html",
    reasons: ["USER_MEDIA"],
    justification: "Capture tab audio for real-time subtitle translation",
  });
}

async function closeOffscreenDocument() {
  const existing = await chrome.runtime.getContexts({
    contextTypes: ["OFFSCREEN_DOCUMENT"],
  });
  if (existing.length === 0) return;
  await chrome.offscreen.closeDocument();
}

/** Stop tracks and close offscreen so Chrome releases tabCapture lock. */
async function releaseCaptureLock(previousTabId = null) {
  try {
    await ensureOffscreen();
    await chrome.runtime.sendMessage({ target: "offscreen", type: "RELEASE_CAPTURE" });
  } catch {
    /* offscreen may not exist */
  }
  await closeOffscreenDocument();
  if (previousTabId != null) {
    await chrome.action.setBadgeText({ text: "", tabId: previousTabId });
  }
  await new Promise((r) => setTimeout(r, 200));
}

function friendlyCaptureError(message) {
  const text = String(message || "");
  if (/active stream/i.test(text)) {
    return "该标签页音频仍被占用：请点「停止」或刷新视频页后再试";
  }
  return text || "启动捕获失败";
}

async function getStreamId(tabId) {
  const opts = { targetTabId: tabId };
  try {
    return await chrome.tabCapture.getMediaStreamId(opts);
  } catch (err) {
    if (/active stream/i.test(String(err?.message || err))) {
      await releaseCaptureLock(null);
      await new Promise((r) => setTimeout(r, 350));
      return chrome.tabCapture.getMediaStreamId(opts);
    }
    throw err;
  }
}

function waitForContentScript(tabId, timeoutMs = 2000) {
  return new Promise((resolve) => {
    let done = false;
    const finish = (ok) => {
      if (done) return;
      done = true;
      chrome.runtime.onMessage.removeListener(onReady);
      clearTimeout(timer);
      resolve(ok);
    };
    const onReady = (msg, sender) => {
      if (msg.type !== "CONTENT_READY") return;
      if (sender.tab?.id != null && sender.tab.id !== tabId) return;
      finish(true);
    };
    chrome.runtime.onMessage.addListener(onReady);
    sendToTab(tabId, { type: "subtitle-ping" });
    const timer = setTimeout(() => finish(false), timeoutMs);
  });
}

async function injectOverlay(tabId) {
  await chrome.scripting.insertCSS({
    target: { tabId },
    files: ["content/subtitle-overlay.css"],
  });

  await chrome.scripting.executeScript({
    target: { tabId },
    files: ["content/subtitle-overlay.js"],
  });
  await waitForContentScript(tabId);
}

function isCapturableUrl(url) {
  if (!url) return false;
  return !(
    url.startsWith("chrome://") ||
    url.startsWith("chrome-extension://") ||
    url.startsWith("edge://") ||
    url.startsWith("about:") ||
    url.startsWith("devtools://")
  );
}

async function sendToTab(tabId, message) {
  try {
    await chrome.tabs.sendMessage(tabId, message);
  } catch {
    /* content script may not be ready */
  }
}

function relaySubtitle(tabId, payload) {
  const { type: _wsType, ...segment } = payload || {};
  sendToTab(tabId, { type: "subtitle", ...segment });
}

async function startCapture(tabId) {
  if (capturingTabId != null && capturingTabId !== tabId) {
    throw new Error("已在其他标签页捕获中，请先停止");
  }

  const tab = await chrome.tabs.get(tabId);
  if (!isCapturableUrl(tab.url)) {
    throw new Error("无法在此页面捕获音频，请打开视频网页后再试");
  }

  const config = await getConfig();
  const health = await fetch(`${config.serverUrl}/api/health`, {
    cache: "no-store",
  }).catch(() => null);
  if (!health?.ok) {
    throw new Error("无法连接 VoiceBridgeAI 服务，请先运行 ./run.sh");
  }

  const previousTabId = capturingTabId;
  capturingTabId = null;
  await releaseCaptureLock(previousTabId);

  await injectOverlay(tabId);
  await sendToTab(tabId, { type: "subtitle-reset" });

  const streamId = await getStreamId(tabId);
  await ensureOffscreen();

  const res = await chrome.runtime.sendMessage({
    target: "offscreen",
    type: "START_CAPTURE",
    streamId,
    tabId,
    config,
  });

  if (!res?.ok) {
    throw new Error(res?.error || "启动捕获失败");
  }

  capturingTabId = tabId;
  await chrome.action.setBadgeText({ text: "ON", tabId });
  await chrome.action.setBadgeBackgroundColor({ color: "#1a73e8", tabId });
  return { ok: true, tabId };
}

async function stopCapture() {
  const tabId = capturingTabId;
  capturingTabId = null;

  if (tabId != null) {
    await sendToTab(tabId, { type: "subtitle-hide" });
  }

  await releaseCaptureLock(tabId);
  return { ok: true };
}

async function getStatus() {
  const config = await getConfig();
  let serverOk = false;
  try {
    const r = await fetch(`${config.serverUrl}/api/health`, { cache: "no-store" });
    serverOk = r.ok;
  } catch {
    serverOk = false;
  }
  return {
    capturing: capturingTabId != null,
    capturingTabId,
    serverOk,
    config,
  };
}

chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg.type === "GET_STATUS") {
    getStatus().then(sendResponse);
    return true;
  }
  if (msg.type === "START_CAPTURE") {
    const tabId = msg.tabId ?? sender.tab?.id;
    startCapture(tabId)
      .then(sendResponse)
      .catch((err) =>
        sendResponse({ ok: false, error: friendlyCaptureError(err.message) })
      );
    return true;
  }
  if (msg.type === "STOP_CAPTURE") {
    if (
      sender.tab?.id != null &&
      capturingTabId != null &&
      capturingTabId !== sender.tab.id
    ) {
      sendResponse({ ok: false, error: "捕获运行在其他标签页" });
      return true;
    }
    stopCapture().then(sendResponse);
    return true;
  }
  if (msg.type === "ASR_SEGMENT" && msg.tabId != null) {
    relaySubtitle(msg.tabId, msg.payload);
    return;
  }
  if (msg.type === "CAPTURE_STARTED" && msg.tabId != null) {
    sendToTab(msg.tabId, { type: "subtitle-reset" });
    return;
  }
  if (msg.type === "CAPTURE_ERROR" && msg.tabId != null) {
    sendToTab(msg.tabId, {
      type: "subtitle-error",
      message: msg.message || "捕获出错",
    });
    stopCapture();
  }
  if (msg.type === "CAPTURE_STOPPED") {
    if (msg.tabId === capturingTabId) {
      capturingTabId = null;
      chrome.action.setBadgeText({ text: "", tabId: msg.tabId });
    }
  }
});

chrome.tabs.onRemoved.addListener((tabId) => {
  if (tabId === capturingTabId) stopCapture();
});

chrome.tabs.onUpdated.addListener((tabId, info) => {
  if (tabId === capturingTabId && info.url && !isCapturableUrl(info.url)) {
    stopCapture();
  }
});
