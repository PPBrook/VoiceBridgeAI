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
const aliyunApiKeyEl = document.getElementById("aliyun-api-key");
const aliyunBaseUrlEl = document.getElementById("aliyun-base-url");
const aliyunModelEl = document.getElementById("aliyun-model");
const baiduAppIdEl = document.getElementById("baidu-app-id");
const baiduSecretKeyEl = document.getElementById("baidu-secret-key");
const deeplApiKeyEl = document.getElementById("deepl-api-key");
const deepseekApiKeyEl = document.getElementById("deepseek-api-key");
const deepseekBaseUrlEl = document.getElementById("deepseek-base-url");
const deepseekModelEl = document.getElementById("deepseek-model");
const openaiApiKeyEl = document.getElementById("openai-api-key");
const openaiBaseUrlEl = document.getElementById("openai-base-url");
const openaiModelEl = document.getElementById("openai-model");
const openaiAsrModelEl = document.getElementById("openai-asr-model");
const saveCloudBtn = document.getElementById("save-cloud");
const cloudSettingsNoteEl = document.getElementById("cloud-settings-note");
const capRows = () => Array.from(document.querySelectorAll(".cap-row"));
const testButtons = () => Array.from(document.querySelectorAll(".btn-test"));

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
  aliyunApiKeyEl,
  aliyunBaseUrlEl,
  aliyunModelEl,
  baiduAppIdEl,
  baiduSecretKeyEl,
  deeplApiKeyEl,
  deepseekApiKeyEl,
  deepseekBaseUrlEl,
  deepseekModelEl,
  openaiApiKeyEl,
  openaiBaseUrlEl,
  openaiModelEl,
  openaiAsrModelEl,
  saveCloudBtn,
];

function applyVerifiedStatus(verified = {}) {
  for (const row of capRows()) {
    const layer = row.dataset.layer;
    const id = row.dataset.id;
    const statusEl = row.querySelector(".cap-status");
    if (!statusEl || statusEl.dataset.pending) continue;
    const passed = Boolean(layer && id && verified[layer]?.includes(id));
    if (passed) {
      statusEl.classList.remove("err");
      statusEl.classList.add("ok");
      if (!statusEl.dataset.custom) {
        statusEl.textContent = "已通过";
      }
    } else if (!statusEl.classList.contains("err") && !statusEl.dataset.custom) {
      statusEl.classList.remove("ok");
      statusEl.textContent = "";
    }
  }
}

function expandVerifiedFolds() {
  for (const row of capRows()) {
    const statusEl = row.querySelector(".cap-status");
    if (!statusEl?.classList.contains("ok")) continue;
    let el = row.closest("details");
    while (el) {
      el.open = true;
      el = el.parentElement?.closest("details") ?? null;
    }
  }
}

function engineProviders(d = {}) {
  return {
    asr: d.asrProvider || d.asrMode || asrModeEl?.value || "local",
    partial:
      d.partialProvider || partialProviderEl?.value || "google",
    final: d.finalProvider || finalProviderEl?.value || "google",
  };
}

let syncingEngineSelects = false;

const LLM_PROVIDER_IDS = new Set(["qiniu", "aliyun", "deepseek", "openai"]);

function llmProvidersFrom(d) {
  return new Set(d?.engineRules?.llmProviders || LLM_PROVIDER_IDS);
}

function allowsSameLayer(id, llmIds) {
  return llmIds.has(id);
}

function filterFinalProviders(providers, partialId, llmIds) {
  if (!partialId || allowsSameLayer(partialId, llmIds)) return providers || [];
  const others = (providers || []).filter((p) => p.id !== partialId && p.id !== "none");
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
  baidu: () => ["百度通用翻译 API", "需在 API 配置填写 AppId + Secret"],
  google: () => ["Google 在线翻译", "免费兜底，需能访问 Google"],
  deepl: () => ["DeepL 机器翻译", "海外高质量 MT，需 DeepL Key"],
  argos: () => ["本机离线英译中", "无需 Key，首次需下载语言包"],
  qiniu: () => ["七牛 AI LLM 快译", "需在 API 配置填写七牛 API Key"],
  aliyun: () => ["阿里云 DashScope LLM 快译", "需在 API 配置填写 DashScope Key"],
  deepseek: () => ["DeepSeek LLM 快译", "国内 OpenAI 兼容接口"],
  openai: () => ["OpenAI LLM 快译", "海外 OpenAI 兼容接口"],
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
  openai: () => [
    "OpenAI Whisper 云端识别",
    "VAD 分句后上传，按句计费",
    "需填写 OpenAI API Key",
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
  const p = engineProviders(d);
  const rv = d.reviseMode || reviseModeEl.value || "balanced";

  if (asrHintPop && ASR_DETAIL[p.asr]) {
    setHintLines(asrHintPop, ASR_DETAIL[p.asr](d));
  }
  if (translateHintPop && PARTIAL_DETAIL[p.partial]) {
    setHintLines(translateHintPop, PARTIAL_DETAIL[p.partial](d));
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

function collectDiagnostics(d) {
  const issues = [];
  const p = engineProviders(d);

  if (p.asr && !providerReady(d, "asr", p.asr)) {
    issues.push({ type: "error", text: "语音识别：请先在接口配置中测试通过。" });
  }
  if (p.partial && !providerReady(d, "partial", p.partial)) {
    issues.push({ type: "error", text: "句中翻译：请先在接口配置中测试通过。" });
  }
  if (p.final && !providerReady(d, "final", p.final)) {
    issues.push({ type: "error", text: "句末润色：请先在接口配置中测试通过。" });
  }
  if (!d.asrModes?.length) {
    issues.push({ type: "info", text: "尚未测试通过任何语音识别接口。" });
  }
  if (!d.partialProviders?.length) {
    issues.push({ type: "info", text: "尚未测试通过任何句中翻译接口。" });
  }
  if (!d.finalProviders?.length) {
    issues.push({ type: "info", text: "尚未测试通过任何句末润色接口。" });
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
      "请先在「接口配置」填写并保存，再点击测试；通过后会出现在此。";
    engineSettingsNoteEl.append(tip);
    return;
  }

  const llmIds = llmProvidersFrom(d);
  if (p.partial !== p.final || allowsSameLayer(p.partial, llmIds)) {
    const tip = document.createElement("p");
    tip.className = "engine-note-path";
    tip.textContent =
      p.partial === p.final && allowsSameLayer(p.partial, llmIds)
        ? "句中快译 + 句末润色（同一 LLM，模式不同）。"
        : "推荐：句中用机器翻译/快译，句末用 LLM 润色。";
    engineSettingsNoteEl.append(tip);
  } else if (d.engineRules?.pairNote) {
    const tip = document.createElement("p");
    tip.className = "engine-note-path warn";
    tip.textContent = d.engineRules.pairNote;
    engineSettingsNoteEl.append(tip);
  }
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
  for (const btn of [asrHintBtn, translateHintBtn, reviseHintBtn]) {
    if (btn) btn.disabled = !enabled;
  }
  if (!enabled) closeAllHintPopovers();
  cloudInputs.forEach((el) => {
    if (el) el.disabled = !enabled;
  });
  testButtons().forEach((btn) => {
    btn.disabled = !enabled;
  });
}

function applyCloudStatus(d) {
  const t = d.tencent || {};
  const q = d.qiniu || {};
  const a = d.aliyun || {};
  applyVerifiedStatus(d.verified || {});
  expandVerifiedFolds();

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
  if (a.baseUrl) aliyunBaseUrlEl.value = a.baseUrl;
  if (a.model) aliyunModelEl.value = a.model;
  aliyunApiKeyEl.placeholder = a.hasApiKey ? "已配置，留空不修改" : "粘贴 API Key";
  if (d.baidu?.appId) baiduAppIdEl.value = d.baidu.appId;
  baiduSecretKeyEl.placeholder = d.baidu?.hasSecretKey
    ? "已配置，留空不修改"
    : "粘贴 Secret Key";
  deeplApiKeyEl.placeholder = d.deepl?.hasApiKey
    ? "已配置，留空不修改"
    : "粘贴 API Key";
  if (d.deepseek?.baseUrl) deepseekBaseUrlEl.value = d.deepseek.baseUrl;
  if (d.deepseek?.model) deepseekModelEl.value = d.deepseek.model;
  deepseekApiKeyEl.placeholder = d.deepseek?.hasApiKey
    ? "已配置，留空不修改"
    : "粘贴 API Key";
  if (d.openai?.baseUrl) openaiBaseUrlEl.value = d.openai.baseUrl;
  if (d.openai?.model) openaiModelEl.value = d.openai.model;
  if (d.openai?.asrModel) openaiAsrModelEl.value = d.openai.asrModel;
  openaiApiKeyEl.placeholder = d.openai?.hasApiKey
    ? "已配置，留空不修改"
    : "粘贴 API Key";

  const ready = d.verified || {};
  const parts = [
    ...(ready.asr || []).map((id) => `识别·${id}`),
    ...(ready.partial || []).map((id) => `句中·${id}`),
    ...(ready.final || []).map((id) => `句末·${id}`),
  ];
  cloudSettingsNoteEl.classList.remove("warn");
  cloudSettingsNoteEl.textContent = parts.length
    ? `已测试通过：${parts.join("、")}`
    : "填写密钥后保存，再点击各能力的「测试」";
}

function applyEngineStatus(d) {
  if (!d) return;
  if (!d.verified && lastHealthData?.verified) {
    d = { ...d, verified: lastHealthData.verified };
  }
  const pair = reconcileEnginePair(d);
  syncSelectOptions(asrModeEl, d.asrModes, d.asrProvider || d.asrMode);
  syncSelectOptions(partialProviderEl, pair.partialList, pair.partialId);
  syncSelectOptions(finalProviderEl, pair.finalList, pair.finalId);
  syncSelectOptions(reviseModeEl, d.reviseModes, d.reviseMode || "balanced");
  engineSettingsNoteEl.classList.remove("warn");
  renderEngineNote({ ...d, partialProvider: pair.partialId, finalProvider: pair.finalId });
  applyCloudStatus(d);
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
  if (!asrModeEl.value || !partialProviderEl.value || !finalProviderEl.value) {
    hintEl.classList.add("warn");
    hintEl.textContent = "请先在接口配置中保存并测试通过，并在引擎设置中选择三层接口。";
    return;
  }
  captureBtn.disabled = true;
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
    syncSelectOptions(finalProviderEl, pair.finalList, pair.finalId);
    if (partialProviderEl.value !== pair.partialId) {
      syncSelectOptions(partialProviderEl, pair.partialList, pair.partialId);
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
    syncSelectOptions(partialProviderEl, pair.partialList, pair.partialId);
    if (finalProviderEl.value !== pair.finalId) {
      syncSelectOptions(finalProviderEl, pair.finalList, pair.finalId);
    }
  }
  scheduleEngineSettings();
});

reviseModeEl.addEventListener("change", () => {
  if (active) return;
  scheduleEngineSettings();
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

  const aliyun = {};
  const aBase = aliyunBaseUrlEl.value.trim();
  const aModel = aliyunModelEl.value.trim();
  if (aBase) aliyun.baseUrl = aBase;
  if (aModel) aliyun.model = aModel;
  const aKey = aliyunApiKeyEl.value.trim();
  if (aKey) aliyun.apiKey = aKey;

  const baidu = {};
  const bAppId = baiduAppIdEl.value.trim();
  if (bAppId) baidu.appId = bAppId;
  const bSecret = baiduSecretKeyEl.value.trim();
  if (bSecret) baidu.secretKey = bSecret;

  const deepl = {};
  const dKey = deeplApiKeyEl.value.trim();
  if (dKey) deepl.apiKey = dKey;

  const deepseek = {};
  const dsBase = deepseekBaseUrlEl.value.trim();
  const dsModel = deepseekModelEl.value.trim();
  if (dsBase) deepseek.baseUrl = dsBase;
  if (dsModel) deepseek.model = dsModel;
  const dsKey = deepseekApiKeyEl.value.trim();
  if (dsKey) deepseek.apiKey = dsKey;

  const openai = {};
  const oBase = openaiBaseUrlEl.value.trim();
  const oModel = openaiModelEl.value.trim();
  const oAsr = openaiAsrModelEl.value.trim();
  if (oBase) openai.baseUrl = oBase;
  if (oModel) openai.model = oModel;
  if (oAsr) openai.asrModel = oAsr;
  const oKey = openaiApiKeyEl.value.trim();
  if (oKey) openai.apiKey = oKey;

  return {
    ...engineConfig(),
    tencent,
    qiniu,
    aliyun,
    baidu,
    deepl,
    deepseek,
    openai,
  };
}

async function postProviderTest(layer, id, btn) {
  const row = btn.closest(".cap-row");
  const statusEl = row?.querySelector(".cap-status");
  btn.disabled = true;
  if (statusEl) {
    statusEl.dataset.pending = "1";
    statusEl.classList.remove("ok", "err");
    statusEl.textContent = "测试中…";
  }
  try {
    const r = await fetch("/api/cloud/test", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...cloudConfigPayload(), layer, providerId: id }),
    });
    let d;
    try {
      d = await r.json();
    } catch {
      if (statusEl) {
        statusEl.textContent = "测试失败：响应异常";
        statusEl.classList.add("err");
      }
      return;
    }
    if (d.ok) {
      if (statusEl) {
        delete statusEl.dataset.pending;
        statusEl.dataset.custom = "1";
        statusEl.textContent = d.message || "已通过";
        statusEl.classList.remove("err");
        statusEl.classList.add("ok");
      }
      applyEngineStatus(d);
      let el = row?.closest("details") ?? row?.closest(".fold-group");
      while (el) {
        el.open = true;
        el = el.parentElement?.closest("details") ?? null;
      }
    } else {
      const msg = d.message || (d.errors || ["测试失败"]).join(" · ");
      if (statusEl) {
        delete statusEl.dataset.pending;
        delete statusEl.dataset.custom;
        statusEl.textContent = msg;
        statusEl.classList.remove("ok");
        statusEl.classList.add("err");
      }
      cloudSettingsNoteEl.textContent = msg;
      cloudSettingsNoteEl.classList.add("warn");
      applyVerifiedStatus(d.verified || {});
    }
  } catch {
    if (statusEl) {
      delete statusEl.dataset.pending;
      statusEl.textContent = "测试失败";
      statusEl.classList.add("err");
    }
  } finally {
    btn.disabled = active;
  }
}

async function postCloudSettings() {
  const r = await fetch("/api/cloud/settings", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(cloudConfigPayload()),
  });
  let d;
  try {
    d = await r.json();
  } catch {
    cloudSettingsNoteEl.textContent = "保存失败：服务端响应异常";
    cloudSettingsNoteEl.classList.add("warn");
    return;
  }
  if (!d.ok) {
    cloudSettingsNoteEl.textContent = (d.errors || ["保存失败"]).join(" · ");
    cloudSettingsNoteEl.classList.add("warn");
    return;
  }
  applyEngineStatus(d);
  tencentSecretIdEl.value = "";
  tencentSecretKeyEl.value = "";
  qiniuApiKeyEl.value = "";
  aliyunApiKeyEl.value = "";
  baiduSecretKeyEl.value = "";
  deeplApiKeyEl.value = "";
  deepseekApiKeyEl.value = "";
  openaiApiKeyEl.value = "";
  cloudSettingsNoteEl.textContent += " · 已保存";
}

saveCloudBtn.addEventListener("click", () => {
  if (active) return;
  postCloudSettings().catch(() => {
    cloudSettingsNoteEl.textContent = "保存失败";
    cloudSettingsNoteEl.classList.add("warn");
  });
});

captureBtn.addEventListener("click", () => {
  if (stream) {
    stopCapture();
  } else {
    startCapture();
  }
});

bindHintTriggers();

for (const strip of document.querySelectorAll(".cap-strip")) {
  strip.addEventListener("click", (e) => e.stopPropagation());
}

for (const btn of testButtons()) {
  btn.addEventListener("click", (e) => {
    e.preventDefault();
    e.stopPropagation();
    if (active) return;
    const row = btn.closest(".cap-row");
    const layer = row?.dataset.layer;
    const id = row?.dataset.id;
    if (layer && id) {
      postProviderTest(layer, id, btn).catch(() => {
        const statusEl = row.querySelector(".cap-status");
        if (statusEl) {
          statusEl.textContent = "测试失败";
          statusEl.classList.add("err");
        }
      });
    }
  });
}
