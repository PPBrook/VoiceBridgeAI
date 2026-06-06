/** Watch YouTube on-page captions and forward English text to the extension. */

(() => {
  const BOOT = "__vbaYoutubeCaptions";

  let segmentId = 0;
  let currentLine = "";
  let active = false;
  let observer = null;
  let pollTimer = null;
  let bodyObserver = null;
  let lastSentAt = 0;

  function queryDeep(selector, root = document) {
    const found = [];
    const visit = (node) => {
      if (!node) return;
      if (node.querySelectorAll) {
        node.querySelectorAll(selector).forEach((el) => found.push(el));
        node.querySelectorAll("*").forEach((el) => {
          if (el.shadowRoot) visit(el.shadowRoot);
        });
      }
    };
    visit(root);
    return found;
  }

  function readCaptionText() {
    const segs = queryDeep(".ytp-caption-segment");
    if (!segs.length) return "";
    return segs
      .map((el) => el.textContent.trim())
      .filter(Boolean)
      .join(" ");
  }

  function findCaptionRoot() {
    const roots = queryDeep(".ytp-caption-window-container, .caption-window");
    return roots[0] || null;
  }

  function send(type, extra = {}) {
    chrome.runtime.sendMessage({ type, ...extra }).catch(() => {});
  }

  function sendSegment(text, final) {
    if (!active) return;
    const t = String(text || "").trim();
    if (!t) return;
    lastSentAt = Date.now();
    send("CAPTION_SEGMENT", {
      text: t,
      segmentId,
      final: Boolean(final),
    });
  }

  function finalizeCurrentLine() {
    if (!currentLine) return;
    sendSegment(currentLine, true);
    segmentId += 1;
    currentLine = "";
  }

  function onCaptionChange() {
    if (!active) return;
    const text = readCaptionText();
    if (!text) {
      finalizeCurrentLine();
      return;
    }
    if (text === currentLine) return;

    const extendsLine =
      text.startsWith(currentLine) ||
      currentLine.startsWith(text) ||
      !currentLine;

    if (currentLine && !extendsLine) {
      finalizeCurrentLine();
    }

    currentLine = text;
    sendSegment(text, false);
  }

  function attachObserver() {
    const root = findCaptionRoot();
    if (!root) return false;
    observer?.disconnect();
    observer = new MutationObserver(onCaptionChange);
    observer.observe(root, {
      childList: true,
      subtree: true,
      characterData: true,
    });
    onCaptionChange();
    return true;
  }

  function ensureBodyWatch() {
    if (bodyObserver) return;
    bodyObserver = new MutationObserver(() => {
      if (attachObserver()) {
        bodyObserver?.disconnect();
        bodyObserver = null;
      }
    });
    bodyObserver.observe(document.body, { childList: true, subtree: true });
  }

  function startPolling() {
    if (pollTimer) return;
    pollTimer = setInterval(onCaptionChange, 200);
  }

  function stopPolling() {
    if (!pollTimer) return;
    clearInterval(pollTimer);
    pollTimer = null;
  }

  function startWatching() {
    lastSentAt = 0;
    if (!attachObserver()) {
      ensureBodyWatch();
    }
    startPolling();
    setTimeout(() => {
      if (!active) return;
      if (!lastSentAt && !readCaptionText()) {
        send("CAPTION_NO_SIGNAL", {
          message: "未检测到 YouTube 字幕，请确认已开启 CC 且为英文字幕",
        });
      }
    }, 6000);
  }

  function stopWatching() {
    active = false;
    stopPolling();
    observer?.disconnect();
    observer = null;
    bodyObserver?.disconnect();
    bodyObserver = null;
    finalizeCurrentLine();
    segmentId = 0;
    currentLine = "";
  }

  function onStart() {
    active = true;
    segmentId = 0;
    currentLine = "";
    startWatching();
  }

  if (!globalThis[BOOT]) {
    globalThis[BOOT] = { onStart, stopWatching };
    chrome.runtime.onMessage.addListener((msg) => {
      if (msg.type === "caption-start") onStart();
      if (msg.type === "caption-stop") stopWatching();
    });
    send("CAPTION_READY");
  } else {
    send("CAPTION_READY");
    if (active) {
      globalThis[BOOT].stopWatching();
      globalThis[BOOT].onStart();
    }
  }
})();
