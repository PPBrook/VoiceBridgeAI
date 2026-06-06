const healthEl = document.getElementById("health");
const statusEl = document.getElementById("status");
const segmentsEl = document.getElementById("segments");
const hintEl = document.getElementById("hint");
const captureBtn = document.getElementById("capture");
const asrModeEl = document.getElementById("asr-mode");
const partialProviderEl = document.getElementById("partial-provider");
const finalProviderEl = document.getElementById("final-provider");
const reviseModeEl = document.getElementById("revise-mode");
const asrHintBtn = document.getElementById("asr-hint");
const asrHintPop = document.getElementById("asr-hint-pop");
const translateHintBtn = document.getElementById("translate-hint");
const translateHintPop = document.getElementById("translate-hint-pop");
const reviseHintBtn = document.getElementById("revise-hint");
const reviseHintPop = document.getElementById("revise-hint-pop");
const finalHintBtn = document.getElementById("final-hint");
const finalHintPop = document.getElementById("final-hint-pop");
const engineSettingsNoteEl = document.getElementById("engine-settings-note");

function engineProviders(d = {}) {
  return {
    asr: d.asrProvider || d.asrMode || asrModeEl?.value || "local",
    partial:
      d.partialProvider || partialProviderEl?.value || "argos",
    final: d.finalProvider || finalProviderEl?.value || "argos",
  };
}

let syncingEngineSelects = false;

const LLM_PROVIDER_IDS = new Set(["qiniu", "aliyun", "deepseek", "openai"]);
const REPEAT_MT_PROVIDER_IDS = new Set(["argos"]);

function llmProvidersFrom(d) {
  return new Set(d?.engineRules?.llmProviders || LLM_PROVIDER_IDS);
}

function allowsSameLayer(id, llmIds) {
  return llmIds.has(id) || REPEAT_MT_PROVIDER_IDS.has(id);
}

function filterFinalProviders(providers, partialId, llmIds) {
  if (!partialId || allowsSameLayer(partialId, llmIds)) return providers || [];
  const others = (providers || []).filter((p) => p.id !== partialId);
  return others.length ? others : providers || [];
}

function filterPartialProviders(providers, finalId, llmIds) {
  if (!finalId || finalId === "none" || allowsSameLayer(finalId, llmIds)) {
    return providers || [];
  }
  const others = (providers || []).filter((p) => p.id !== finalId);
  return others.length ? others : providers || [];
}

function reconcileEnginePair(d) {
  const llmIds = llmProvidersFrom(d);
  const partialList = filterPartialProviders(
    d.partialProviders,
    d.finalProvider,
    llmIds
  );
  let partialId = d.partialProvider;
  if (partialId && !partialList.some((p) => p.id === partialId)) {
    partialId = partialList[0]?.id;
  }
  const finalList = filterFinalProviders(d.finalProviders, partialId, llmIds);
  let finalId = d.finalProvider;
  if (
    partialId &&
    finalId === partialId &&
    !allowsSameLayer(partialId, llmIds)
  ) {
    finalId = finalList.find((p) => p.id !== partialId)?.id ?? finalId;
  }
  if (finalId && !finalList.some((p) => p.id === finalId)) {
    finalId = finalList[0]?.id;
  }
  return { partialList, finalList, partialId, finalId, llmIds };
}

function syncSelectOptions(selectEl, providers, value) {
  if (!selectEl || !providers?.length) return;
  const ids = providers.map((p) => p.id).join("|");
  if (selectEl.dataset.providerIds !== ids) {
    selectEl.dataset.providerIds = ids;
    selectEl.replaceChildren(
      ...providers.map((m) => {
        const opt = document.createElement("option");
        opt.value = m.id;
        opt.textContent = m.label;
        return opt;
      })
    );
  }
  const pick =
    value && selectEl.querySelector(`option[value="${value}"]`)
      ? value
      : selectEl.options[0]?.value;
  if (pick && selectEl.value !== pick) {
    syncingEngineSelects = true;
    selectEl.value = pick;
    syncingEngineSelects = false;
  }
}

function syncPartialSelect(selectEl, providers, value) {
  syncProviderSelect(selectEl, providers, value, "partial", (v) => {
    syncingEngineSelects = v;
  });
}

function syncFinalSelect(selectEl, providers, value) {
  syncProviderSelect(selectEl, providers, value, "final", (v) => {
    syncingEngineSelects = v;
  });
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
  tencent: "腾讯云",
  openai: "OpenAI",
  local: "本地离线",
};

const PARTIAL_DETAIL = {
  tmt: () => ["腾讯机器翻译，低延迟草稿", "与 ASR 共用腾讯云 Secret"],
  baidu: () => ["百度通用翻译 API", "需在接口配置页填写 AppId + Secret"],
  google: () => ["Google 在线翻译", "免费兜底，需能访问 Google"],
  deepl: () => ["DeepL 机器翻译", "海外高质量 MT，需 DeepL Key"],
  argos: () => ["本机离线英译中", "无需 Key，首次需下载语言包"],
  qiniu: () => ["七牛 AI LLM 快译", "需在接口配置页填写七牛 API Key"],
  aliyun: () => ["阿里云 DashScope LLM 快译", "需在接口配置页填写 DashScope Key"],
  deepseek: () => ["DeepSeek LLM 快译", "国内 OpenAI 兼容接口"],
  openai: () => ["OpenAI LLM 快译", "海外 OpenAI 兼容接口"],
};

const FINAL_DETAIL = {
  tmt: () => ["腾讯机器翻译句末定稿", "与 ASR 共用腾讯云 Secret"],
  baidu: () => ["百度通用翻译句末定稿", "需在接口配置页填写 AppId + Secret"],
  google: () => ["Google 在线翻译句末定稿", "免费兜底，需能访问 Google"],
  deepl: () => ["DeepL 机器翻译句末定稿", "海外高质量 MT，需 DeepL Key"],
  argos: () => ["本机离线英译中句末定稿", "无需 Key，首次需下载语言包"],
  qiniu: () => ["七牛 AI LLM 句末润色", "需在接口配置页填写七牛 API Key"],
  aliyun: () => ["阿里云 DashScope LLM 句末润色", "需在接口配置页填写 DashScope Key"],
  deepseek: () => ["DeepSeek LLM 句末润色", "国内 OpenAI 兼容接口"],
  openai: () => ["OpenAI LLM 句末润色", "海外 OpenAI 兼容接口"],
  none: () => ["句末不再翻译", "定稿时直接沿用句中译文，省 API 调用"],
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
    "需在接口配置页填写 AppId、Secret",
    "适合英文标签页音频",
  ],
  openai: () => [
    "OpenAI Whisper 云端识别",
    "VAD 分句后上传，按句计费",
    "需在接口配置页填写 OpenAI API Key",
    "适合海外网络环境",
  ],
  local: (d) => [
    "本机 Whisper，无需云端 Key",
    "静音自动分句识别",
    "首次运行需下载模型",
    `句内约每 ${d.reviseRefineInterval ?? 0.8} 秒重识别改错`,
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
  for (const btn of [asrHintBtn, translateHintBtn, finalHintBtn, reviseHintBtn]) {
    btn?.setAttribute("aria-expanded", "false");
  }
  for (const pop of [asrHintPop, translateHintPop, finalHintPop, reviseHintPop]) {
    pop?.classList.remove("open", "pinned");
  }
}

function bindHintTriggers() {
  for (const btn of [asrHintBtn, translateHintBtn, finalHintBtn, reviseHintBtn]) {
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
  const p = engineProviders(d);
  const rv = d.reviseMode || reviseModeEl.value || "balanced";

  if (asrHintPop && ASR_DETAIL[p.asr]) {
    setHintLines(asrHintPop, ASR_DETAIL[p.asr](d));
  }
  if (translateHintPop && PARTIAL_DETAIL[p.partial]) {
    const lines = [...PARTIAL_DETAIL[p.partial](d)];
    if (isMtProvider(p.partial)) {
      lines.unshift("推荐句中用 MT：响应快、成本低。");
    } else if (LLM_PROVIDER_IDS.has(p.partial)) {
      lines.unshift("LLM 亦可用句中快译；更推荐 MT + 句末 LLM 组合。");
    }
    setHintLines(translateHintPop, lines);
  }
  if (finalHintPop && FINAL_DETAIL[p.final]) {
    const lines = [...FINAL_DETAIL[p.final](d)];
    if (p.final === "none") {
      lines.unshift("离线默认：定稿沿用句中译文。");
    } else if (LLM_PROVIDER_IDS.has(p.final)) {
      lines.unshift("推荐句末用 LLM：结合句中草稿润色，更自然。");
    } else if (isMtProvider(p.final)) {
      lines.unshift("句末 MT 适合无 LLM 时；有 LLM 时更推荐句末润色。");
    }
    setHintLines(finalHintPop, lines);
  }
  if (reviseHintPop && REVISE_DETAIL[rv]) {
    const lines = [...REVISE_DETAIL[rv](d)];
    if (p.asr === "tencent" && rv !== "speed") {
      lines.push("句末回溯仅本地识别有效");
    }
    setHintLines(reviseHintPop, lines);
  }
}

let lastHealthData = null;
let runtimeHealthError = null;

function layerProviderIds(d, layer) {
  const key =
    layer === "asr"
      ? "asrModes"
      : layer === "partial"
        ? "partialProviders"
        : "finalProviders";
  return (d[key] || []).map((m) => m.id);
}

function providerReady(d, layer, id) {
  if (!id) return false;
  if ((d.verified?.[layer] || []).includes(id)) return true;
  return layerProviderIds(d, layer).includes(id);
}

function providerLabel(d, layer, id) {
  const key =
    layer === "asr"
      ? "asrModes"
      : layer === "partial"
        ? "partialProviders"
        : "finalProviders";
  const found = (d[key] || []).find((m) => m.id === id);
  return found?.label || ASR_MODE_SHORT[id] || id;
}

function collectDiagnostics(d) {
  const issues = [];
  const p = engineProviders(d);

  if (p.asr && !providerReady(d, "asr", p.asr)) {
    issues.push({
      type: "error",
      text: `语音识别「${providerLabel(d, "asr", p.asr)}」未测试通过，请先到接口配置页填写密钥并测试。`,
    });
  }
  if (p.partial && !providerReady(d, "partial", p.partial)) {
    issues.push({
      type: "error",
      text: `句中翻译「${providerLabel(d, "partial", p.partial)}」未测试通过，请先到接口配置页填写密钥并测试。`,
    });
  }
  if (p.final && !providerReady(d, "final", p.final)) {
    issues.push({
      type: "error",
      text: `句末润色「${providerLabel(d, "final", p.final)}」未测试通过，请先到接口配置页填写密钥并测试。`,
    });
  }
  if (p.partial === "google" || p.final === "google") {
    issues.push({
      type: "info",
      text: "Google 翻译需能访问 Google 服务。",
    });
  }
  if (p.partial === "deepl" || p.final === "deepl") {
    issues.push({
      type: "info",
      text: "DeepL 需海外网络或代理。",
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
  const p = engineProviders(d);
  const rv = d.reviseMode || reviseModeEl.value || "balanced";

  updateFieldHints(d);
  closeAllHintPopovers();

  engineSettingsNoteEl.replaceChildren();
  engineSettingsNoteEl.classList.remove("warn");

  const summary = document.createElement("p");
  summary.className = "engine-note-summary";
  summary.textContent = `当前：${ASR_MODE_SHORT[p.asr] || p.asr || "未选"} · 句中 ${d.partialProviderLabel || p.partial || "未选"} · 句末 ${d.finalProviderLabel || p.final || "未选"} · ${REVISE_MODE_SHORT[rv] || rv}`;
  engineSettingsNoteEl.append(summary);

  if (!d.asrModes?.length || !d.partialProviders?.length || !d.finalProviders?.length) {
    const tip = document.createElement("p");
    tip.className = "engine-note-path warn";
    tip.textContent =
      "引擎选项加载异常，请刷新页面；离线默认可用本地 Whisper + Argos。";
    engineSettingsNoteEl.append(tip);
    return;
  }

  const llmIds = llmProvidersFrom(d);
  const tip = document.createElement("p");
  tip.className = "engine-note-path";

  if (isRecommendedMtLlmPair(p.partial, p.final, llmIds)) {
    tip.classList.add("ok");
    tip.textContent = "当前为推荐组合：句中 MT + 句末 LLM。";
  } else if (p.partial === p.final && p.partial === "argos") {
    tip.textContent = "当前为全离线组合：句中 Argos 草稿 + 句末 Argos 再译。";
    tip.classList.add("ok");
  } else if (p.final === "none") {
    tip.textContent =
      "离线默认；配置云端后推荐句中 MT + 句末 LLM（如下拉分组所示）。";
  } else if (p.partial === p.final && allowsSameLayer(p.partial, llmIds)) {
    tip.textContent = "句中快译 + 句末润色（同一 LLM，模式不同）。";
  } else if (d.engineRules?.pairNote) {
    tip.classList.add("warn");
    tip.textContent = d.engineRules.pairNote;
  } else {
    tip.textContent = "推荐：句中选 MT，句末选 LLM（两层不同接口）。";
  }
  engineSettingsNoteEl.append(tip);
}

function engineConfig() {
  return {
    asrMode: asrModeEl.value,
    asrProvider: asrModeEl.value,
    partialProvider: partialProviderEl.value,
    finalProvider: finalProviderEl.value,
    reviseMode: reviseModeEl.value,
  };
}

function setSettingsEnabled(enabled) {
  asrModeEl.disabled = !enabled;
  partialProviderEl.disabled = !enabled;
  finalProviderEl.disabled = !enabled;
  reviseModeEl.disabled = !enabled;
  for (const btn of [asrHintBtn, translateHintBtn, finalHintBtn, reviseHintBtn]) {
    if (btn) btn.disabled = !enabled;
  }
  if (!enabled) closeAllHintPopovers();
}

function applyEngineStatus(d) {
  if (!d) return;
  if (!d.verified && lastHealthData?.verified) {
    d = { ...d, verified: lastHealthData.verified };
  }
  const pair = reconcileEnginePair(d);
  syncSelectOptions(asrModeEl, d.asrModes, d.asrProvider || d.asrMode);
  syncPartialSelect(partialProviderEl, pair.partialList, pair.partialId);
  syncFinalSelect(finalProviderEl, pair.finalList, pair.finalId);
  syncSelectOptions(reviseModeEl, d.reviseModes, d.reviseMode || "balanced");
  engineSettingsNoteEl.classList.remove("warn");
  renderEngineNote({ ...d, partialProvider: pair.partialId, finalProvider: pair.finalId });
  renderHealthPanel({ ...d, partialProvider: pair.partialId, finalProvider: pair.finalId });
  if (
    !active &&
    (pair.partialId !== d.partialProvider || pair.finalId !== d.finalProvider)
  ) {
    scheduleEngineSettings();
  }
}

async function refreshHealth() {
  let d = null;
  try {
    const r = await fetch("/api/health");
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    d = await r.json();
  } catch (err) {
    console.error("health fetch failed:", err);
    renderHealthPanel(null);
    return null;
  }
  try {
    applyEngineStatus(d);
  } catch (err) {
    console.error("health apply failed:", err);
    setRuntimeHealthError(`页面初始化失败：${err.message}`);
    renderHealthPanel(d);
  }
  return d;
}

refreshHealth();

function setStatus(text) {
  statusEl.textContent = text;
}

if (!Capture.supported()) {
  const diag = Capture.diagnose();
  captureBtn.disabled = true;
  hintEl.classList.add("warn");
  hintEl.textContent = diag.message;
  setStatus("不支持：无法捕获标签页音频");
  setRuntimeHealthError(diag.message);
} else if (!Capture.canCaptureAudio()) {
  captureBtn.disabled = true;
  hintEl.classList.add("warn");
  hintEl.textContent = Capture.unsupportedMessage();
  setStatus("不支持：当前浏览器无法捕获音频");
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
    setStatus(`捕获中 · 音量 ${lastLevel}% · 上行 ${kbps} kb/s`);
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
  captureBtn.textContent = "开始捕获";
  segmentsEl.replaceChildren();
  setSettingsEnabled(true);
  setStatus("就绪");
}

async function startCapture() {
  hintEl.classList.remove("warn");
  const d = lastHealthData || {};
  const p = engineProviders(d);

  if (!asrModeEl.value || !partialProviderEl.value || !finalProviderEl.value) {
    hintEl.classList.add("warn");
    hintEl.textContent = "请先完成引擎三层选择。";
    return;
  }

  const checks = [
    ["asr", p.asr],
    ["partial", p.partial],
    ["final", p.final],
  ];
  for (const [layer, id] of checks) {
    if (id && !providerReady(d, layer, id)) {
      hintEl.classList.add("warn");
      hintEl.textContent = `「${providerLabel(d, layer, id)}」尚未测试通过，请先到接口配置页填写密钥并测试。`;
      return;
    }
  }

  captureBtn.disabled = true;
  setSettingsEnabled(false);
  setStatus("正在连接服务…");

  try {
    stream = await navigator.mediaDevices.getDisplayMedia(Capture.constraints());

    if (!stream.getAudioTracks().length) {
      stream.getTracks().forEach((t) => t.stop());
      stream = null;
      captureBtn.disabled = false;
      captureBtn.textContent = "重试";
      setSettingsEnabled(true);
      setStatus(`错误：${Capture.noAudioMessage()}`);
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
      setStatus("已取消");
    } else if (err.name === "NotSupportedError") {
      setStatus(`不支持：${err.message}`);
      setRuntimeHealthError(err.message);
    } else {
      setStatus(`错误：${err.message}`);
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

let engineSettingsTimer = null;
function scheduleEngineSettings() {
  if (syncingEngineSelects) return;
  clearTimeout(engineSettingsTimer);
  engineSettingsTimer = setTimeout(() => {
    postEngineSettings().catch(() => {});
  }, 100);
}

asrModeEl.addEventListener("change", () => {
  if (active) return;
  scheduleEngineSettings();
});

partialProviderEl?.addEventListener("change", () => {
  if (active) return;
  if (lastHealthData) {
    const pair = reconcileEnginePair({
      ...lastHealthData,
      partialProvider: partialProviderEl.value,
      finalProvider: finalProviderEl.value,
    });
    syncFinalSelect(finalProviderEl, pair.finalList, pair.finalId);
    if (partialProviderEl.value !== pair.partialId) {
      syncPartialSelect(partialProviderEl, pair.partialList, pair.partialId);
    }
  }
  scheduleEngineSettings();
});

finalProviderEl?.addEventListener("change", () => {
  if (active) return;
  if (lastHealthData) {
    const pair = reconcileEnginePair({
      ...lastHealthData,
      partialProvider: partialProviderEl.value,
      finalProvider: finalProviderEl.value,
    });
    syncPartialSelect(partialProviderEl, pair.partialList, pair.partialId);
    if (finalProviderEl.value !== pair.finalId) {
      syncFinalSelect(finalProviderEl, pair.finalList, pair.finalId);
    }
  }
  scheduleEngineSettings();
});

reviseModeEl.addEventListener("change", () => {
  if (active) return;
  scheduleEngineSettings();
});

captureBtn.addEventListener("click", () => {
  if (stream) {
    stopCapture();
  } else {
    startCapture();
  }
});

bindHintTriggers();
