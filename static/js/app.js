const healthEl = document.getElementById("health");
const statusEl = document.getElementById("status");
const segmentsEl = document.getElementById("segments");
const hintEl = document.getElementById("hint");
const captureBtn = document.getElementById("capture");
const asrModeEl = document.getElementById("asr-mode");
const translateModeEl = document.getElementById("translate-mode");
const reviseModeEl = document.getElementById("revise-mode");
const asrHintBtn = document.getElementById("asr-hint");
const asrHintPop = document.getElementById("asr-hint-pop");
const translateHintBtn = document.getElementById("translate-hint");
const translateHintPop = document.getElementById("translate-hint-pop");
const reviseHintBtn = document.getElementById("revise-hint");
const reviseHintPop = document.getElementById("revise-hint-pop");
const engineSettingsNoteEl = document.getElementById("engine-settings-note");
const tencentAppIdEl = document.getElementById("tencent-app-id");
const tencentSecretIdEl = document.getElementById("tencent-secret-id");
const tencentSecretKeyEl = document.getElementById("tencent-secret-key");
const tencentEngineEl = document.getElementById("tencent-engine");
const tencentTmtRegionEl = document.getElementById("tencent-tmt-region");
const tencentTmtProjectIdEl = document.getElementById("tencent-tmt-project-id");
const qiniuApiKeyEl = document.getElementById("qiniu-api-key");
const qiniuBaseUrlEl = document.getElementById("qiniu-base-url");
const qiniuModelEl = document.getElementById("qiniu-model");
const saveCloudBtn = document.getElementById("save-cloud");
const cloudSettingsNoteEl = document.getElementById("cloud-settings-note");
const toggleCloudBtn = document.getElementById("toggle-cloud");
const cloudSettingsEl = document.getElementById("cloud-settings");
const toggleCloudAdvancedBtn = document.getElementById("toggle-cloud-advanced");
const cloudAdvancedEl = document.getElementById("cloud-advanced");

const cloudInputs = [
  tencentAppIdEl,
  tencentSecretIdEl,
  tencentSecretKeyEl,
  tencentEngineEl,
  tencentTmtRegionEl,
  tencentTmtProjectIdEl,
  qiniuApiKeyEl,
  qiniuBaseUrlEl,
  qiniuModelEl,
  saveCloudBtn,
  toggleCloudAdvancedBtn,
];

let cloudPanelOpen = false;
let cloudAdvancedOpen = false;

function setCloudPanelOpen(open) {
  cloudPanelOpen = open;
  cloudSettingsEl.hidden = !open;
  toggleCloudBtn.textContent = open ? "收起 API 配置 ▴" : "API 配置 ▾";
  if (!open) setCloudAdvancedOpen(false);
}

function setCloudAdvancedOpen(open) {
  cloudAdvancedOpen = open;
  cloudAdvancedEl.hidden = !open;
  toggleCloudAdvancedBtn.textContent = open
    ? "收起高级选项 ▴"
    : "高级选项 ▾";
}

function cloudNeedsTencent(d) {
  return d.asrMode === "tencent" || d.translateMode === "dual";
}

function cloudNeedsQiniu(d) {
  return d.translateMode === "dual";
}

let stream = null;
let audioCtx = null;
let analyser = null;
let ws = null;
let levelTimer = null;
let sentBytes = 0;
let lastLevel = 0;
let pumpTask = null;
let active = false;

const ASR_MODE_SHORT = {
  tencent: "云端流式",
  local: "本地离线",
};

const TRANSLATE_MODE_SHORT = {
  dual: "云端双擎",
  argos: "本地离线",
  local: "联网免费",
};

const REVISE_MODE_SHORT = {
  speed: "实时优先",
  balanced: "标准纠正",
  accuracy: "精准纠正",
};

const ASR_DETAIL = {
  tencent: () => [
    "腾讯云流式识别，延迟最低",
    "边说边出字，停顿后定稿",
    "需在 API 配置填写 AppId、Secret",
    "适合英文标签页音频",
  ],
  local: (d) => [
    "本机 Whisper，无需云端 Key",
    "静音自动分句识别",
    "首次运行需下载模型",
    `句内约每 ${d.reviseRefineInterval ?? 0.8} 秒重识别改错`,
  ],
};

const TRANSLATE_DETAIL = {
  dual: () => [
    "句中：腾讯机器翻译出草稿",
    "句末：七牛大模型润色定稿",
    "需腾讯云 Secret + 七牛 Key",
  ],
  argos: () => [
    "本机离线英译中",
    "数据不出电脑，无需密钥",
    "首次运行需下载语言包",
  ],
  local: () => [
    "Google 在线翻译",
    "免费兜底，无需 Key",
    "需能访问 Google",
  ],
};

const REVISE_DETAIL = {
  speed: (d) => [
    `草稿翻译约 ${d.reviseDebounce ?? 0.35} 秒合并一次`,
    "请求更少，延迟更低",
    "不做句末回溯",
    "适合路径 A 云端演示",
  ],
  balanced: (d) => [
    "句内改错，字幕原地更新",
    `本地识别：句末回溯 ${d.reviseLookback ?? 2} 句边界`,
    "速度与准确度兼顾（推荐）",
  ],
  accuracy: (d) => [
    `草稿约 ${d.reviseDebounce ?? 0.15} 秒、句内约 ${d.reviseRefineInterval ?? 0.55} 秒重识别`,
    `句末回溯 ${d.reviseLookback ?? 3} 句`,
    "更准，CPU 占用更高",
    "适合路径 B 全本地",
  ],
};

const PATH_HINT = {
  "tencent-dual": "路径 A：云端识别 + 双擎翻译，建议选「实时优先」。",
  "local-argos": "路径 B：全离线，无需 Key，建议「标准」或「精准」纠正。",
  "local-local": "路径 C：本地识别 + 联网翻译，仅需网络。",
  "tencent-argos": "混合：云端识别 + 本地翻译（识别需 Key）。",
  "tencent-local": "混合：云端识别 + Google 翻译（均需联网）。",
  "local-dual": "混合：本地识别 + 云端双擎（翻译需 Key）。",
};

function setHintLines(popEl, lines) {
  if (!popEl) return;
  popEl.replaceChildren();
  const ul = document.createElement("ul");
  for (const line of lines) {
    const li = document.createElement("li");
    li.textContent = line;
    ul.append(li);
  }
  popEl.append(ul);
}

function closeAllHintPopovers() {
  for (const btn of [asrHintBtn, translateHintBtn, reviseHintBtn]) {
    btn?.setAttribute("aria-expanded", "false");
  }
  for (const pop of [asrHintPop, translateHintPop, reviseHintPop]) {
    pop?.classList.remove("open", "pinned");
  }
}

function bindHintTriggers() {
  for (const btn of [asrHintBtn, translateHintBtn, reviseHintBtn]) {
    if (!btn) continue;
    btn.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      const pop = btn.nextElementSibling;
      if (!pop?.classList.contains("hint-popover")) return;
      const willOpen = !pop.classList.contains("pinned");
      closeAllHintPopovers();
      if (willOpen) {
        pop.classList.add("open", "pinned");
        btn.setAttribute("aria-expanded", "true");
      }
    });
  }
  document.addEventListener("click", () => closeAllHintPopovers());
}

function updateFieldHints(d) {
  const asr = d.asrMode || asrModeEl.value || "local";
  const tr = d.translateMode || translateModeEl.value || "local";
  const rv = d.reviseMode || reviseModeEl.value || "balanced";

  if (asrHintPop && ASR_DETAIL[asr]) {
    setHintLines(asrHintPop, ASR_DETAIL[asr](d));
  }
  if (translateHintPop && TRANSLATE_DETAIL[tr]) {
    setHintLines(translateHintPop, TRANSLATE_DETAIL[tr](d));
  }
  if (reviseHintPop && REVISE_DETAIL[rv]) {
    const lines = [...REVISE_DETAIL[rv](d)];
    if (asr === "tencent" && rv !== "speed") {
      lines.push("句末回溯仅本地识别有效");
    }
    setHintLines(reviseHintPop, lines);
  }
}

let lastHealthData = null;
let runtimeHealthError = null;

function collectDiagnostics(d) {
  const issues = [];
  const asr = d.asrMode || "local";
  const tr = d.translateMode || "local";

  if (asr === "tencent" && !d.tencentConfigured) {
    issues.push({
      type: "error",
      text: "语音识别：未配置腾讯云，请展开 API 配置填写 AppId 与 Secret。",
    });
  }
  if (tr === "dual") {
    if (!d.tmtConfigured) {
      issues.push({
        type: "error",
        text: "翻译：双擎模式缺少腾讯 TMT（与 ASR 共用 Secret）。",
      });
    }
    if (!d.qiniuConfigured) {
      issues.push({
        type: "error",
        text: "翻译：双擎模式缺少七牛 API Key。",
      });
    }
  }
  if (tr === "local") {
    issues.push({
      type: "info",
      text: "翻译：联网模式需能访问 Google。",
    });
  }
  return issues;
}

function renderHealthPanel(d) {
  if (d) lastHealthData = d;
  healthEl.replaceChildren();
  healthEl.className = "health-panel";

  if (runtimeHealthError) {
    healthEl.hidden = false;
    healthEl.classList.add("err");
    const title = document.createElement("p");
    title.className = "health-title";
    title.textContent = "运行错误";
    healthEl.append(title);
    const p = document.createElement("p");
    p.textContent = runtimeHealthError;
    healthEl.append(p);
    appendHealthDetails(d || lastHealthData);
    return;
  }

  if (!d) {
    healthEl.hidden = false;
    healthEl.classList.add("err");
    const title = document.createElement("p");
    title.className = "health-title";
    title.textContent = "服务不可用";
    healthEl.append(title);
    const p = document.createElement("p");
    p.textContent = "无法连接后端，请确认已运行 ./run.sh 并打开 http://127.0.0.1:8765";
    healthEl.append(p);
    return;
  }

  const issues = collectDiagnostics(d);
  const errors = issues.filter((i) => i.type === "error");
  const infos = issues.filter((i) => i.type === "info");

  if (!errors.length && !infos.length) {
    healthEl.hidden = true;
    return;
  }

  healthEl.hidden = false;
  healthEl.classList.add(errors.length ? "warn" : "info");

  const title = document.createElement("p");
  title.className = "health-title";
  title.textContent = errors.length ? "配置未完成" : "提示";
  healthEl.append(title);

  const ul = document.createElement("ul");
  for (const item of [...errors, ...infos]) {
    const li = document.createElement("li");
    li.textContent = item.text;
    ul.append(li);
  }
  healthEl.append(ul);
  appendHealthDetails(d);
}

function appendHealthDetails(d) {
  if (!d) return;
  const details = document.createElement("details");
  details.className = "health-details";
  const summary = document.createElement("summary");
  summary.textContent = "技术详情";
  const pre = document.createElement("pre");
  pre.textContent = JSON.stringify(d, null, 2);
  details.append(summary, pre);
  healthEl.append(details);
}

function setRuntimeHealthError(message) {
  runtimeHealthError = message || null;
  renderHealthPanel(lastHealthData);
}

function clearRuntimeHealthError() {
  runtimeHealthError = null;
  renderHealthPanel(lastHealthData);
}

function renderEngineNote(d) {
  const asr = d.asrMode || asrModeEl.value || "local";
  const tr = d.translateMode || translateModeEl.value || "local";
  const rv = d.reviseMode || reviseModeEl.value || "balanced";

  updateFieldHints(d);
  closeAllHintPopovers();

  engineSettingsNoteEl.replaceChildren();
  engineSettingsNoteEl.classList.remove("warn");

  const summary = document.createElement("p");
  summary.className = "engine-note-summary";
  summary.textContent = `当前：${ASR_MODE_SHORT[asr] || asr} · ${TRANSLATE_MODE_SHORT[tr] || tr} · ${REVISE_MODE_SHORT[rv] || rv}`;
  engineSettingsNoteEl.append(summary);

  const pathKey = `${asr}-${tr}`;
  if (PATH_HINT[pathKey]) {
    const p = document.createElement("p");
    p.className = "engine-note-path";
    p.textContent = PATH_HINT[pathKey];
    engineSettingsNoteEl.append(p);
  }
}

function engineConfig() {
  return {
    asrMode: asrModeEl.value,
    translateMode: translateModeEl.value,
    reviseMode: reviseModeEl.value,
  };
}

function setSettingsEnabled(enabled) {
  asrModeEl.disabled = !enabled;
  translateModeEl.disabled = !enabled;
  reviseModeEl.disabled = !enabled;
  for (const btn of [asrHintBtn, translateHintBtn, reviseHintBtn]) {
    if (btn) btn.disabled = !enabled;
  }
  if (!enabled) closeAllHintPopovers();
  toggleCloudBtn.disabled = !enabled;
  cloudInputs.forEach((el) => {
    if (el) el.disabled = !enabled;
  });
}

function applyCloudStatus(d) {
  const t = d.tencent || {};
  const q = d.qiniu || {};
  if (t.appId) tencentAppIdEl.value = t.appId;
  if (t.engine) tencentEngineEl.value = t.engine;
  if (t.tmtRegion) tencentTmtRegionEl.value = t.tmtRegion;
  if (t.tmtProjectId) tencentTmtProjectIdEl.value = t.tmtProjectId;
  tencentSecretIdEl.placeholder = t.hasSecretId
    ? "已配置，留空不修改"
    : "粘贴 SecretId";
  tencentSecretKeyEl.placeholder = t.hasSecretKey
    ? "已配置，留空不修改"
    : "粘贴 SecretKey";
  if (q.baseUrl) qiniuBaseUrlEl.value = q.baseUrl;
  if (q.model) qiniuModelEl.value = q.model;
  qiniuApiKeyEl.placeholder = q.hasApiKey ? "已配置，留空不修改" : "粘贴 API Key";

  const issues = [];
  if (cloudNeedsTencent(d)) {
    if (d.asrMode === "tencent" && !t.asrConfigured) {
      issues.push("腾讯云 ASR 未配置（AppId + Secret）");
    }
    if (cloudNeedsQiniu(d) && !t.tmtConfigured) {
      issues.push("腾讯云 TMT 未配置（SecretId + SecretKey）");
    }
  }
  if (cloudNeedsQiniu(d) && !q.configured) {
    issues.push("七牛 Key 未配置");
  }

  let line = "";
  let warn = false;
  if (issues.length) {
    line = issues.join(" · ");
    warn = true;
  } else if (d.asrMode === "tencent" && d.translateMode === "dual") {
    line = "演示路径就绪：云端流式识别 + 双擎翻译";
  } else if (cloudNeedsQiniu(d)) {
    line = "云端双擎翻译已就绪";
  } else if (cloudNeedsTencent(d) && t.asrConfigured) {
    line = "腾讯云 ASR 已配置";
  } else {
    line = "当前引擎组合无需云端 Key";
  }
  cloudSettingsNoteEl.textContent = line;
  cloudSettingsNoteEl.classList.toggle("warn", warn);
  if (!cloudPanelOpen) {
    toggleCloudBtn.title = issues.length ? issues[0] : line;
  }
}

function applyEngineStatus(d) {
  if (d.asrModes?.length) {
    asrModeEl.replaceChildren(
      ...d.asrModes.map((m) => {
        const opt = document.createElement("option");
        opt.value = m.id;
        opt.textContent = m.label;
        return opt;
      })
    );
    asrModeEl.value = d.asrMode || asrModeEl.options[0]?.value || "local";
  }
  if (d.translateModes?.length) {
    translateModeEl.replaceChildren(
      ...d.translateModes.map((m) => {
        const opt = document.createElement("option");
        opt.value = m.id;
        opt.textContent = m.label;
        return opt;
      })
    );
    translateModeEl.value =
      d.translateMode || translateModeEl.options[0]?.value || "local";
  }
  if (d.reviseModes?.length) {
    reviseModeEl.replaceChildren(
      ...d.reviseModes.map((m) => {
        const opt = document.createElement("option");
        opt.value = m.id;
        opt.textContent = m.label;
        return opt;
      })
    );
    reviseModeEl.value =
      d.reviseMode || reviseModeEl.options[1]?.value || "balanced";
  }
  engineSettingsNoteEl.classList.remove("warn");
  renderEngineNote(d);
  applyCloudStatus(d);
  renderHealthPanel(d);
}

fetch("/api/health")
  .then((r) => r.json())
  .then((d) => {
    applyEngineStatus(d);
  })
  .catch(() => {
    renderHealthPanel(null);
  });

function setStatus(text) {
  statusEl.textContent = text;
}

if (!Capture.supported()) {
  const diag = Capture.diagnose();
  captureBtn.disabled = true;
  hintEl.classList.add("warn");
  hintEl.textContent = diag.message;
  setStatus("unsupported: getDisplayMedia");
  setRuntimeHealthError(diag.message);
} else if (!Capture.canCaptureAudio()) {
  captureBtn.disabled = true;
  hintEl.classList.add("warn");
  hintEl.textContent = Capture.unsupportedMessage();
  setStatus("unsupported: no audio capture");
  setRuntimeHealthError(Capture.unsupportedMessage());
} else {
  hintEl.textContent = Capture.hint();
}

function wsUrl() {
  const proto = location.protocol === "https:" ? "wss:" : "ws:";
  return `${proto}//${location.host}/ws`;
}

function applySegment(msg) {
  const id = String(msg.segmentId ?? segmentsEl.children.length);
  let li = segmentsEl.querySelector(`li[data-segment-id="${id}"]`);
  const isNew = !li;
  if (!li) {
    li = document.createElement("li");
    li.dataset.segmentId = id;
    const en = document.createElement("div");
    en.className = "seg-en";
    const zh = document.createElement("div");
    zh.className = "seg-zh";
    li.append(en, zh);
    segmentsEl.appendChild(li);
  }
  if (msg.text) {
    li.querySelector(".seg-en").textContent = msg.text;
  }
  const zhEl = li.querySelector(".seg-zh");
  if (msg.translation) {
    zhEl.textContent = msg.translation;
    zhEl.classList.remove("placeholder");
  } else if (!msg.final) {
    if (!zhEl.textContent || zhEl.classList.contains("placeholder")) {
      zhEl.textContent = "…";
      zhEl.classList.add("placeholder");
    }
  }
  li.classList.toggle("partial", !!msg.partial && !msg.final);
  li.classList.toggle("final", !!msg.final);
  if (msg.revise && !isNew) {
    li.classList.remove("revise-flash", "lookback-flash");
    void li.offsetWidth;
    li.classList.add(msg.lookback ? "lookback-flash" : "revise-flash");
  }
}

function connectWs(sampleRate) {
  return new Promise((resolve, reject) => {
    let settled = false;
    ws = new WebSocket(wsUrl());
    ws.binaryType = "arraybuffer";
    ws.onmessage = (ev) => {
      if (typeof ev.data !== "string") return;
      try {
        const msg = JSON.parse(ev.data);
        if (msg.type === "error") {
          setRuntimeHealthError(msg.message || "服务端错误");
          if (!settled) {
            settled = true;
            reject(new Error(msg.message || "server error"));
          }
          return;
        }
        if (msg.type === "asrReady") {
          if (!settled) {
            settled = true;
            resolve();
          }
          return;
        }
        if (msg.type === "asr" && msg.text) {
          applySegment(msg);
        }
      } catch {
        /* ignore */
      }
    };
    ws.onopen = () => {
      ws.send(JSON.stringify({ type: "config", sampleRate, ...engineConfig() }));
    };
    ws.onerror = () => {
      setRuntimeHealthError("WebSocket 连接失败");
      if (!settled) {
        settled = true;
        reject(new Error("websocket failed"));
      }
    };
  });
}

function closeWs() {
  if (ws) {
    ws.close();
    ws = null;
  }
  sentBytes = 0;
}

function stopLevelMonitor() {
  if (levelTimer) {
    clearInterval(levelTimer);
    levelTimer = null;
  }
  analyser = null;
  lastLevel = 0;
}

function startLevelMonitor() {
  stopLevelMonitor();
  let tickBytes = sentBytes;
  const buf = analyser ? new Uint8Array(analyser.fftSize) : null;

  levelTimer = setInterval(() => {
    if (analyser && buf) {
      analyser.getByteTimeDomainData(buf);
      let sum = 0;
      for (let i = 0; i < buf.length; i++) {
        const v = (buf[i] - 128) / 128;
        sum += v * v;
      }
      lastLevel = Math.min(100, Math.round(Math.sqrt(sum / buf.length) * 400));
    }
    const kbps = Math.round(((sentBytes - tickBytes) * 8) / 1024);
    tickBytes = sentBytes;
    setStatus(`capturing · level ${lastLevel}% · ↑${kbps} kb/s`);
  }, 1000);
}

function stopPump() {
  pumpTask = null;
}

async function pumpWithProcessor(track) {
  const processor = new MediaStreamTrackProcessor({ track });
  const reader = processor.readable.getReader();
  pumpTask = reader;

  try {
    while (reader === pumpTask) {
      const { value, done } = await reader.read();
      if (done) break;

      const n = value.numberOfFrames;
      const f32 = new Float32Array(n);
      value.copyTo(f32, { planeIndex: 0 });
      value.close();

      let sum = 0;
      const int16 = new Int16Array(n);
      for (let i = 0; i < n; i++) {
        sum += f32[i] * f32[i];
        const s = Math.max(-1, Math.min(1, f32[i]));
        int16[i] = s < 0 ? s * 32768 : s * 32767;
      }
      lastLevel = Math.min(100, Math.round(Math.sqrt(sum / n) * 400));

      if (ws?.readyState === WebSocket.OPEN) {
        ws.send(int16.buffer);
        sentBytes += int16.byteLength;
      }
    }
  } finally {
    reader.releaseLock();
    if (active) stopCapture();
  }
}

async function pumpWithWorklet(mediaStream, sampleRate) {
  audioCtx = new AudioContext();
  if (audioCtx.state === "suspended") await audioCtx.resume();

  const src = audioCtx.createMediaStreamSource(mediaStream);
  const silent = audioCtx.createGain();
  silent.gain.value = 0;

  analyser = audioCtx.createAnalyser();
  analyser.fftSize = 2048;
  src.connect(analyser);
  analyser.connect(silent);

  await audioCtx.audioWorklet.addModule("/static/js/pcm-processor.js");
  const node = new AudioWorkletNode(audioCtx, "pcm-processor");
  node.port.onmessage = (ev) => {
    if (ws?.readyState !== WebSocket.OPEN) return;
    ws.send(ev.data);
    sentBytes += ev.data.byteLength;
  };
  src.connect(node);
  node.connect(silent);
  silent.connect(audioCtx.destination);

  startLevelMonitor();
}

function stopCapture() {
  if (!active) return;
  active = false;
  stopPump();
  stopLevelMonitor();
  closeWs();
  stream?.getTracks().forEach((t) => t.stop());
  stream = null;
  audioCtx?.close();
  audioCtx = null;
  captureBtn.disabled = false;
  captureBtn.textContent = "捕获音频";
  segmentsEl.replaceChildren();
  setSettingsEnabled(true);
  setStatus("idle");
}

async function startCapture() {
  captureBtn.disabled = true;
  setCloudPanelOpen(false);
  setSettingsEnabled(false);
  setStatus("loading asr…");

  try {
    stream = await navigator.mediaDevices.getDisplayMedia(Capture.constraints());

    if (!stream.getAudioTracks().length) {
      stream.getTracks().forEach((t) => t.stop());
      stream = null;
      captureBtn.disabled = false;
      captureBtn.textContent = "重试";
      setSettingsEnabled(true);
      setStatus(`error: ${Capture.noAudioMessage()}`);
      return;
    }

    stream.getVideoTracks().forEach((t) => t.stop());
    const audioTrack = stream.getAudioTracks()[0];
    audioTrack.onended = () => stopCapture();

    const settings = audioTrack.getSettings();
    const sampleRate = settings.sampleRate || 48000;
    await connectWs(sampleRate);
    clearRuntimeHealthError();
    active = true;
    segmentsEl.replaceChildren();

    if (typeof MediaStreamTrackProcessor !== "undefined") {
      startLevelMonitor();
      pumpWithProcessor(audioTrack);
    } else {
      await pumpWithWorklet(stream, sampleRate);
    }

    captureBtn.disabled = false;
    captureBtn.textContent = "停止";
  } catch (err) {
    if (stream || ws) {
      active = true;
      stopCapture();
    }
    captureBtn.disabled = false;
    setSettingsEnabled(true);
    if (err.name === "NotAllowedError") {
      setStatus("cancelled");
    } else if (err.name === "NotSupportedError") {
      setStatus("unsupported: " + err.message);
      setRuntimeHealthError(err.message);
    } else {
      setStatus(`error: ${err.message}`);
      setRuntimeHealthError(err.message);
    }
  }
}

async function postEngineSettings() {
  const r = await fetch("/api/engine/settings", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(engineConfig()),
  });
  applyEngineStatus(await r.json());
}

asrModeEl.addEventListener("change", () => {
  if (active) return;
  postEngineSettings().catch(() => {});
});

translateModeEl.addEventListener("change", () => {
  if (active) return;
  postEngineSettings().catch(() => {});
});

reviseModeEl.addEventListener("change", () => {
  if (active) return;
  postEngineSettings().catch(() => {});
});

function cloudConfigPayload() {
  const tencent = {};
  const appId = tencentAppIdEl.value.trim();
  const engine = tencentEngineEl.value.trim();
  const tmtRegion = tencentTmtRegionEl.value.trim();
  const tmtProjectId = tencentTmtProjectIdEl.value.trim();
  if (appId) tencent.appId = appId;
  if (engine) tencent.engine = engine;
  if (tmtRegion) tencent.tmtRegion = tmtRegion;
  if (tmtProjectId) tencent.tmtProjectId = tmtProjectId;
  const secretId = tencentSecretIdEl.value.trim();
  const secretKey = tencentSecretKeyEl.value.trim();
  if (secretId) tencent.secretId = secretId;
  if (secretKey) tencent.secretKey = secretKey;

  const qiniu = {};
  const baseUrl = qiniuBaseUrlEl.value.trim();
  const model = qiniuModelEl.value.trim();
  if (baseUrl) qiniu.baseUrl = baseUrl;
  if (model) qiniu.model = model;
  const qKey = qiniuApiKeyEl.value.trim();
  if (qKey) qiniu.apiKey = qKey;
  return {
    ...engineConfig(),
    tencent,
    qiniu,
  };
}

async function postCloudSettings() {
  const r = await fetch("/api/cloud/settings", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(cloudConfigPayload()),
  });
  const d = await r.json();
  applyEngineStatus(d);
  applyCloudStatus(d);
  tencentSecretIdEl.value = "";
  tencentSecretKeyEl.value = "";
  qiniuApiKeyEl.value = "";
  cloudSettingsNoteEl.textContent += " · 已保存";
}

saveCloudBtn.addEventListener("click", () => {
  if (active) return;
  postCloudSettings().catch(() => {
    cloudSettingsNoteEl.textContent = "保存失败";
    cloudSettingsNoteEl.classList.add("warn");
  });
});

toggleCloudBtn.addEventListener("click", () => {
  if (active) return;
  setCloudPanelOpen(!cloudPanelOpen);
});

toggleCloudAdvancedBtn.addEventListener("click", () => {
  if (active) return;
  setCloudAdvancedOpen(!cloudAdvancedOpen);
});

captureBtn.addEventListener("click", () => {
  if (stream) {
    stopCapture();
  } else {
    startCapture();
  }
});

bindHintTriggers();
