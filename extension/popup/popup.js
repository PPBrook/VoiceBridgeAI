const serverStatusEl = document.getElementById("server-status");
const btnStart = document.getElementById("btn-start");
const btnStop = document.getElementById("btn-stop");
const hintEl = document.getElementById("hint");
const errorEl = document.getElementById("error");
const serverUrlEl = document.getElementById("server-url");
const inputModeEl = document.getElementById("input-mode");
const inputHintEl = document.getElementById("input-hint");
const asrLabelEl = document.getElementById("asr-label");
const asrModeEl = document.getElementById("asr-mode");
const partialProviderEl = document.getElementById("partial-provider");
const finalProviderEl = document.getElementById("final-provider");
const reviseModeEl = document.getElementById("revise-mode");
const openConsoleEl = document.getElementById("open-console");
const openConfigEl = document.getElementById("open-config");

function isCaptionMode() {
  return inputModeEl?.value === "caption";
}

function syncInputModeUi() {
  const caption = isCaptionMode();
  if (asrLabelEl) asrLabelEl.hidden = caption;
  if (inputHintEl) {
    inputHintEl.textContent = caption
      ? "在 YouTube 视频页开启 CC 英文字幕；跳过语音识别，只翻译字幕。"
      : "";
  }
}

const engineEls = [partialProviderEl, finalProviderEl, reviseModeEl];
if (asrModeEl) engineEls.unshift(asrModeEl);

const DEFAULT_SERVER_URL = "http://127.0.0.1:8765";

function normalizeServerUrl(raw) {
  let text = String(raw || "").trim();
  if (!text) return DEFAULT_SERVER_URL;
  if (!/^https?:\/\//i.test(text)) text = `http://${text}`;
  return new URL(text).origin;
}

function serverOriginPattern(origin) {
  return `${origin.replace(/\/$/, "")}/*`;
}

async function ensureServerPermission(origin) {
  if (/^https?:\/\/(127\.0\.0\.1|localhost)(:\d+)?$/i.test(origin)) {
    return true;
  }
  const pattern = serverOriginPattern(origin);
  if (await chrome.permissions.contains({ origins: [pattern] })) {
    return true;
  }
  return chrome.permissions.request({ origins: [pattern] });
}

function updateServerLinks(base) {
  openConsoleEl.href = base;
  if (openConfigEl) openConfigEl.href = `${base}/config`;
}

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
  return { partialList, finalList, partialId, finalId };
}

function showError(text) {
  if (!text) {
    errorEl.hidden = true;
    errorEl.textContent = "";
    return;
  }
  errorEl.hidden = false;
  errorEl.textContent = text;
}

function syncSelect(selectEl, providers, value) {
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
  if (pick) selectEl.value = pick;
}

async function saveSettings() {
  const base = normalizeServerUrl(serverUrlEl?.value);
  if (serverUrlEl) serverUrlEl.value = base;
  updateServerLinks(base);
  await chrome.storage.sync.set({ serverUrl: base });

  const config = {
    inputMode: inputModeEl?.value || "audio",
    asrMode: asrModeEl.value,
    asrProvider: asrModeEl.value,
    partialProvider: partialProviderEl.value,
    finalProvider: finalProviderEl.value,
    reviseMode: reviseModeEl.value,
  };
  await chrome.storage.sync.set(config);
  try {
    const body =
      config.inputMode === "caption"
        ? {
            inputMode: "caption",
            partialProvider: config.partialProvider,
            finalProvider: config.finalProvider,
            reviseMode: config.reviseMode,
          }
        : config;
    await fetch(`${base}/api/engine/settings`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });
  } catch {
    /* server offline — local extension prefs still saved */
  }
  return config;
}

async function loadSettings() {
  const stored = await chrome.storage.sync.get([
    "serverUrl",
    "inputMode",
    "asrMode",
    "asrProvider",
    "partialProvider",
    "finalProvider",
    "reviseMode",
  ]);
  const base = normalizeServerUrl(stored.serverUrl);
  if (serverUrlEl) serverUrlEl.value = base;
  updateServerLinks(base);
  if (stored.inputMode && inputModeEl) inputModeEl.value = stored.inputMode;
  syncInputModeUi();
  if (stored.reviseMode) reviseModeEl.value = stored.reviseMode;
  return { ...stored, serverUrl: base };
}

let lastHealthData = null;

function applyEngineOptions(d, stored = {}) {
  const pair = reconcileEnginePair({
    ...d,
    partialProvider: stored.partialProvider || d.partialProvider,
    finalProvider: stored.finalProvider || d.finalProvider,
  });
  syncSelect(asrModeEl, d.asrModes, stored.asrProvider || stored.asrMode || d.asrProvider);
  syncProviderSelect(partialProviderEl, pair.partialList, pair.partialId, "partial");
  syncProviderSelect(finalProviderEl, pair.finalList, pair.finalId, "final");
  return pair;
}

async function fetchEngineOptions(base, stored = {}) {
  try {
    const r = await fetch(`${base}/api/health`);
    if (!r.ok) return null;
    const d = await r.json();
    lastHealthData = d;
    applyEngineOptions(d, stored);
    return d;
  } catch {
    return null;
  }
}

function setCapturing(active) {
  btnStart.hidden = active;
  btnStop.hidden = !active;
  for (const el of engineEls) el.disabled = active;
}

async function refreshStatus() {
  const status = await chrome.runtime.sendMessage({ type: "GET_STATUS" });
  const stored = await loadSettings();
  const base = stored.serverUrl || DEFAULT_SERVER_URL;
  const health = await fetchEngineOptions(base, stored);

  serverStatusEl.textContent = status.serverOk ? "服务已连接" : "服务未连接";
  serverStatusEl.className = `status-pill ${status.serverOk ? "ok" : "bad"}`;
  btnStart.disabled = !status.serverOk;
  setCapturing(status.capturing);

  if (status.capturing) {
    hintEl.textContent = status.config?.inputMode === "caption"
      ? "正在读取 YouTube 字幕并显示中文悬浮字幕…"
      : "正在当前标签页显示悬浮字幕…";
  } else if (status.serverOk && health) {
    hintEl.textContent = isCaptionMode()
      ? "YouTube 字幕模式：请打开视频页并开启英文字幕 CC，再点开始。"
      : "离线默认可用；云端接口请先在控制台「接口配置」测试通过。";
  } else if (status.serverOk) {
    hintEl.textContent = "控制台引擎选项加载失败，请刷新扩展或打开控制台。";
  } else {
    hintEl.textContent = "请先启动 VoiceBridgeAI 服务端，并确认上方地址可访问。";
  }

  if (status.config && health) {
    lastHealthData = health;
    applyEngineOptions(health, status.config);
    if (status.config.reviseMode) reviseModeEl.value = status.config.reviseMode;
  }
}

btnStart.addEventListener("click", async () => {
  showError("");
  if (inputModeEl) {
    await chrome.storage.sync.set({ inputMode: inputModeEl.value || "audio" });
  }
  await saveSettings();
  btnStart.disabled = true;
  const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
  const res = await chrome.runtime.sendMessage({
    type: "START_CAPTURE",
    tabId: tab?.id,
  });
  btnStart.disabled = false;
  if (!res?.ok) {
    showError(res?.error || "启动失败");
    return;
  }
  window.close();
});

btnStop.addEventListener("click", async () => {
  await chrome.runtime.sendMessage({ type: "STOP_CAPTURE" });
  await refreshStatus();
});

partialProviderEl?.addEventListener("change", () => {
  if (!lastHealthData) return saveSettings();
  const pair = reconcileEnginePair({
    ...lastHealthData,
    partialProvider: partialProviderEl.value,
    finalProvider: finalProviderEl.value,
  });
  syncProviderSelect(finalProviderEl, pair.finalList, pair.finalId, "final");
  saveSettings();
});

finalProviderEl?.addEventListener("change", () => {
  if (!lastHealthData) return saveSettings();
  const pair = reconcileEnginePair({
    ...lastHealthData,
    partialProvider: partialProviderEl.value,
    finalProvider: finalProviderEl.value,
  });
  syncProviderSelect(partialProviderEl, pair.partialList, pair.partialId, "partial");
  saveSettings();
});

for (const el of [asrModeEl, reviseModeEl]) {
  el?.addEventListener("change", () => saveSettings());
}

inputModeEl?.addEventListener("change", () => {
  syncInputModeUi();
  saveSettings();
});

serverUrlEl?.addEventListener("change", async () => {
  showError("");
  try {
    const base = normalizeServerUrl(serverUrlEl.value);
    serverUrlEl.value = base;
    const ok = await ensureServerPermission(base);
    if (!ok) {
      showError("未授予访问该服务端的权限");
      return;
    }
    await saveSettings();
    await refreshStatus();
  } catch {
    showError("服务端地址无效，请使用 http://主机:端口 格式");
  }
});

refreshStatus();
syncInputModeUi();
