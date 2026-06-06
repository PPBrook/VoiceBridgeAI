/** Floating subtitle overlay — previous line + current line. */

(() => {
  const BOOT = "__vbaSubtitleBoot";
  const runtimeAlive = () => {
    try {
      return Boolean(chrome.runtime?.id);
    } catch {
      return false;
    }
  };

  if (globalThis[BOOT] && runtimeAlive()) {
    chrome.runtime.sendMessage({ type: "CONTENT_READY" }).catch(() => {});
    return;
  }
  globalThis[BOOT] = true;

  const HOST_ID = "voicebridgeai-subtitle-host";
  const MAX_LINES = 2;

  let shadow = null;
  let rootEl = null;
  let linesEl = null;
  let statusEl = null;
  let panelEl = null;
  let segments = new Map();
  let lineEls = new Map();
  let showEnglish = true;
  let drag = null;
  let wired = false;
  let partialTimer = null;

  function mergeTranslation(incoming, prev) {
    if (incoming != null && String(incoming).trim() !== "") {
      return String(incoming);
    }
    return prev?.translation ?? "";
  }

  function bindControls() {
    if (wired || !rootEl) return;
    wired = true;

    rootEl.querySelector('[data-action="close"]').addEventListener("click", () => {
      chrome.runtime.sendMessage({ type: "STOP_CAPTURE" }).catch(() => {});
    });
    rootEl.querySelector('[data-action="toggle-en"]').addEventListener("click", () => {
      showEnglish = !showEnglish;
      rootEl.classList.toggle("no-en", !showEnglish);
      paintLines(true);
    });
    rootEl.querySelector('[data-action="compact"]').addEventListener("click", () => {
      rootEl.classList.toggle("compact");
    });

    const toolbar = rootEl.querySelector(".vba-toolbar");
    toolbar.addEventListener("pointerdown", (ev) => {
      if (ev.target.closest(".vba-btn")) return;
      const rect = rootEl.getBoundingClientRect();
      drag = {
        startX: ev.clientX,
        startY: ev.clientY,
        originLeft: rect.left,
        originTop: rect.top,
      };
      toolbar.setPointerCapture(ev.pointerId);
    });
    toolbar.addEventListener("pointermove", (ev) => {
      if (!drag) return;
      rootEl.style.left = `${drag.originLeft + (ev.clientX - drag.startX)}px`;
      rootEl.style.top = `${drag.originTop + (ev.clientY - drag.startY)}px`;
      rootEl.style.bottom = "auto";
      rootEl.style.transform = "none";
    });
    toolbar.addEventListener("pointerup", () => {
      drag = null;
    });
  }

  function attachToShadow(sh) {
    shadow = sh;
    rootEl = shadow.querySelector(".vba-root");
    panelEl = shadow.querySelector(".vba-panel");
    linesEl = shadow.querySelector(".vba-lines");
    statusEl = shadow.querySelector(".vba-status");
    lineEls.clear();
    for (const line of linesEl?.querySelectorAll(".vba-line[data-segment-id]") || []) {
      lineEls.set(line.dataset.segmentId, {
        line,
        zh: line.querySelector(".vba-zh"),
        en: line.querySelector(".vba-en"),
      });
    }
    bindControls();
  }

  function removeDuplicateHosts() {
    const all = document.querySelectorAll(`#${HOST_ID}`);
    for (let i = 1; i < all.length; i++) all[i].remove();
  }

  function ensureOverlay() {
    removeDuplicateHosts();

    if (panelEl && linesEl) return;

    const existing = document.getElementById(HOST_ID);
    if (existing?.shadowRoot?.querySelector(".vba-lines")) {
      attachToShadow(existing.shadowRoot);
      return;
    }
    if (existing) existing.remove();

    const host = document.createElement("div");
    host.id = HOST_ID;
    document.documentElement.appendChild(host);
    shadow = host.attachShadow({ mode: "open" });

    const style = document.createElement("link");
    style.rel = "stylesheet";
    style.href = chrome.runtime.getURL("content/subtitle-overlay.css");
    shadow.append(style);

    rootEl = document.createElement("div");
    rootEl.className = "vba-root";
    rootEl.innerHTML = `
      <div class="vba-panel">
        <div class="vba-toolbar">
          <span class="vba-brand">VoiceBridgeAI</span>
          <span class="vba-toolbar-btns">
            <button type="button" class="vba-btn" data-action="toggle-en" title="切换英文">EN</button>
            <button type="button" class="vba-btn" data-action="compact" title="字号">A</button>
            <button type="button" class="vba-btn" data-action="close" title="停止字幕">×</button>
          </span>
        </div>
        <div class="vba-lines">
          <div class="vba-empty">等待字幕…</div>
        </div>
        <div class="vba-status"></div>
      </div>
    `;
    shadow.append(rootEl);

    panelEl = rootEl.querySelector(".vba-panel");
    linesEl = rootEl.querySelector(".vba-lines");
    statusEl = rootEl.querySelector(".vba-status");
    bindControls();
  }

  function orderedSegments() {
    return [...segments.values()].sort((a, b) => Number(a.id) - Number(b.id));
  }

  function visibleSegments() {
    return orderedSegments().slice(-MAX_LINES);
  }

  function pruneSegments() {
    const keep = new Set(visibleSegments().map((s) => s.id));
    for (const id of [...segments.keys()]) {
      if (!keep.has(id)) segments.delete(id);
    }
    for (const [id, els] of [...lineEls.entries()]) {
      if (!keep.has(id)) {
        els.line.remove();
        lineEls.delete(id);
      }
    }
  }

  function displayText(seg) {
    const en = seg.text || "";
    const zh = seg.translation || "";
    if (zh) return { zh, en: showEnglish ? en : "" };
    if (en && !showEnglish) return { zh: en, en: "" };
    return { zh: "", en: showEnglish ? en : "" };
  }

  function ensureLineEl(segId) {
    let els = lineEls.get(segId);
    if (els) return els;

    const line = document.createElement("div");
    line.className = "vba-line";
    line.dataset.segmentId = segId;
    const zh = document.createElement("div");
    zh.className = "vba-zh";
    const en = document.createElement("div");
    en.className = "vba-en";
    line.append(zh, en);
    linesEl.append(line);
    els = { line, zh, en };
    lineEls.set(segId, els);
    return els;
  }

  function clearDisplay() {
    segments.clear();
    lineEls.clear();
    clearTimeout(partialTimer);
    partialTimer = null;
    if (linesEl) {
      for (const node of [...linesEl.querySelectorAll(".vba-line")]) node.remove();
      const empty = linesEl.querySelector(".vba-empty");
      if (empty) empty.hidden = false;
    }
  }

  function showWaiting(text) {
    if (!linesEl) return;
    const empty = linesEl.querySelector(".vba-empty");
    if (empty) {
      empty.hidden = false;
      empty.textContent = text || "等待字幕…";
    }
    for (const { line } of lineEls.values()) line.hidden = true;
  }

  function paintLines() {
    if (!linesEl) return;
    const visible = visibleSegments();
    if (!visible.length) {
      showWaiting(statusEl?.dataset.waiting || "等待字幕…");
      return;
    }

    const empty = linesEl.querySelector(".vba-empty");
    if (empty) empty.hidden = true;

    const visibleIds = new Set(visible.map((s) => s.id));
    for (const [id, els] of lineEls.entries()) {
      if (!visibleIds.has(id)) {
        els.line.remove();
        lineEls.delete(id);
      }
    }

    visible.forEach((seg, idx) => {
      const isCurrent = idx === visible.length - 1;
      const { zh, en } = displayText(seg);
      const els = ensureLineEl(seg.id);
      els.line.hidden = !(zh || en);
      els.line.classList.toggle("history", !isCurrent);
      els.line.classList.toggle("current", isCurrent);
      els.line.classList.toggle("partial", isCurrent && !!seg.partial && !seg.final);

      if (zh) {
        if (els.zh.textContent !== zh) els.zh.textContent = zh;
        els.zh.hidden = false;
      } else if (isCurrent && els.zh.textContent) {
        /* revise 间隙保留已有中文 */
      } else {
        els.zh.textContent = "";
        els.zh.hidden = true;
      }

      if (els.en) {
        if (showEnglish && en) {
          if (els.en.textContent !== en) els.en.textContent = en;
          els.en.hidden = false;
        } else {
          els.en.hidden = true;
        }
      }
    });

    for (const seg of visible) {
      const els = lineEls.get(seg.id);
      if (els) linesEl.append(els.line);
    }
  }

  function schedulePaint(isFinal) {
    if (isFinal) {
      clearTimeout(partialTimer);
      partialTimer = null;
      paintLines();
      return;
    }
    clearTimeout(partialTimer);
    partialTimer = setTimeout(() => paintLines(), 180);
  }

  function applySegment(msg) {
    ensureOverlay();
    panelEl.classList.remove("hidden");
    if (statusEl) {
      statusEl.textContent = "";
      statusEl.className = "vba-status";
      delete statusEl.dataset.waiting;
    }

    const id = String(msg.segmentId ?? segments.size);
    const prev = segments.get(id);
    const translation = mergeTranslation(msg.translation, prev);

    segments.set(id, {
      id,
      text: msg.text || prev?.text || "",
      translation,
      partial: !!msg.partial && !msg.final,
      final: !!msg.final,
    });

    pruneSegments();

    if (!prev) {
      clearTimeout(partialTimer);
      partialTimer = null;
      paintLines();
      return;
    }
    schedulePaint(!!msg.final);
  }

  function resetOverlay() {
    ensureOverlay();
    clearDisplay();
    if (statusEl) {
      statusEl.textContent = "";
      statusEl.className = "vba-status";
      statusEl.dataset.waiting = "正在聆听…";
    }
    showWaiting(statusEl?.dataset.waiting);
    if (panelEl) panelEl.classList.remove("hidden");
  }

  function hideOverlay() {
    clearDisplay();
    if (panelEl) panelEl.classList.add("hidden");
    if (statusEl) delete statusEl.dataset.waiting;
  }

  function showError(message) {
    ensureOverlay();
    if (!panelEl) return;
    panelEl.classList.remove("hidden");
    if (statusEl) {
      statusEl.className = "vba-error";
      statusEl.textContent = message;
      delete statusEl.dataset.waiting;
    }
    showWaiting("");
  }

  chrome.runtime.onMessage.addListener((msg) => {
    if (msg.type === "subtitle" || msg.type === "asr") applySegment(msg);
    if (msg.type === "subtitle-reset") resetOverlay();
    if (msg.type === "subtitle-hide") hideOverlay();
    if (msg.type === "subtitle-error") showError(msg.message || "出错");
    if (msg.type === "subtitle-ping") {
      chrome.runtime.sendMessage({ type: "CONTENT_READY" }).catch(() => {});
    }
  });

  removeDuplicateHosts();
  chrome.runtime.sendMessage({ type: "CONTENT_READY" }).catch(() => {});
})();
