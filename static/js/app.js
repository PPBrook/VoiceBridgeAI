const healthEl = document.getElementById("health");
const statusEl = document.getElementById("status");
const segmentsEl = document.getElementById("segments");
const hintEl = document.getElementById("hint");
const captureBtn = document.getElementById("capture");
const asrModeEl = document.getElementById("asr-mode");
const translateModeEl = document.getElementById("translate-mode");
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

function engineConfig() {
  return { asrMode: asrModeEl.value, translateMode: translateModeEl.value };
}

function setSettingsEnabled(enabled) {
  asrModeEl.disabled = !enabled;
  translateModeEl.disabled = !enabled;
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
    line = "演示路径就绪：腾讯云 ASR + TMT + 七牛润色";
  } else if (cloudNeedsQiniu(d)) {
    line = "双引擎就绪";
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
  engineSettingsNoteEl.classList.remove("warn");
  const parts = [];
  if (d.asrMode === "tencent") {
    parts.push(`识别：腾讯云 ${d.asrEngine || "16k_en"}`);
  } else {
    parts.push(`识别：本地 Whisper ${d.whisperModel || "tiny.en"}`);
  }
  parts.push(
    `翻译：${d.translatePartial || "?"} → ${d.translateFinal || "?"}`
  );
  engineSettingsNoteEl.textContent = parts.join(" · ");
  if (!d.tencentConfigured && d.asrMode !== "tencent") {
    /* local asr only — ok */
  } else if (!d.tencentConfigured) {
    engineSettingsNoteEl.classList.add("warn");
    engineSettingsNoteEl.textContent += " · 未配置腾讯云 ASR";
  }
  if (d.translateMode === "local") {
    engineSettingsNoteEl.textContent += " · 翻译需联网";
  } else if (d.offlineTranslate) {
    engineSettingsNoteEl.textContent += " · 离线翻译";
  }
  if (d.asrMode === "local" && d.offlineTranslate) {
    engineSettingsNoteEl.textContent += " · ✅ 全本地（识别+翻译）";
  } else if (d.translateMode === "dual" && (!d.tmtConfigured || !d.qiniuConfigured)) {
    engineSettingsNoteEl.classList.add("warn");
  }
  applyCloudStatus(d);
}

fetch("/api/health")
  .then((r) => r.json())
  .then((d) => {
    applyEngineStatus(d);
    healthEl.textContent = JSON.stringify(d);
    healthEl.classList.add("ok");
  })
  .catch(() => {
    healthEl.textContent = "offline";
    healthEl.classList.add("err");
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
} else if (!Capture.canCaptureAudio()) {
  captureBtn.disabled = true;
  hintEl.classList.add("warn");
  hintEl.textContent = Capture.unsupportedMessage();
  setStatus("unsupported: no audio capture");
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
    li.classList.remove("revise-flash");
    void li.offsetWidth;
    li.classList.add("revise-flash");
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
    } else {
      setStatus(`error: ${err.message}`);
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
