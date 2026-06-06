const serverStatusEl = document.getElementById("server-status");
const btnStart = document.getElementById("btn-start");
const btnStop = document.getElementById("btn-stop");
const hintEl = document.getElementById("hint");
const errorEl = document.getElementById("error");
const asrModeEl = document.getElementById("asr-mode");
const partialProviderEl = document.getElementById("partial-provider");
const finalProviderEl = document.getElementById("final-provider");
const reviseModeEl = document.getElementById("revise-mode");
const openConsoleEl = document.getElementById("open-console");

const engineEls = [asrModeEl, partialProviderEl, finalProviderEl, reviseModeEl];

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
  const config = {
    asrMode: asrModeEl.value,
    asrProvider: asrModeEl.value,
    partialProvider: partialProviderEl.value,
    finalProvider: finalProviderEl.value,
    reviseMode: reviseModeEl.value,
  };
  await chrome.storage.sync.set(config);
  return config;
}

async function loadSettings() {
  const stored = await chrome.storage.sync.get([
    "serverUrl",
    "asrMode",
    "asrProvider",
    "partialProvider",
    "finalProvider",
    "reviseMode",
  ]);
  if (stored.reviseMode) reviseModeEl.value = stored.reviseMode;
  const base = stored.serverUrl || "http://127.0.0.1:8765";
  openConsoleEl.href = base;
  return stored;
}

let lastHealthData = null;

function applyEngineOptions(d, stored = {}) {
  const pair = reconcileEnginePair({
    ...d,
    partialProvider: stored.partialProvider || d.partialProvider,
    finalProvider: stored.finalProvider || d.finalProvider,
  });
  syncSelect(asrModeEl, d.asrModes, stored.asrProvider || stored.asrMode || d.asrProvider);
  syncSelect(partialProviderEl, pair.partialList, pair.partialId);
  syncSelect(finalProviderEl, pair.finalList, pair.finalId);
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
  const base = stored.serverUrl || "http://127.0.0.1:8765";
  const health = await fetchEngineOptions(base, stored);

  serverStatusEl.textContent = status.serverOk ? "服务已连接" : "服务未连接";
  serverStatusEl.className = `status-pill ${status.serverOk ? "ok" : "bad"}`;
  btnStart.disabled = !status.serverOk;
  setCapturing(status.capturing);

  if (status.capturing) {
    hintEl.textContent = "正在当前标签页显示悬浮字幕…";
  } else if (status.serverOk && health) {
    hintEl.textContent = "句中快译 + 句末润色；机器翻译勿重复选同一家。";
  } else if (status.serverOk) {
    hintEl.textContent = "打开控制台配置 API Key 后，可选接口会出现在此处。";
  } else {
    hintEl.textContent = "请先在项目目录运行 ./run.sh";
  }

  if (status.config && health) {
    lastHealthData = health;
    applyEngineOptions(health, status.config);
    if (status.config.reviseMode) reviseModeEl.value = status.config.reviseMode;
  }
}

btnStart.addEventListener("click", async () => {
  showError("");
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
  syncSelect(finalProviderEl, pair.finalList, pair.finalId);
  saveSettings();
});

finalProviderEl?.addEventListener("change", () => {
  if (!lastHealthData) return saveSettings();
  const pair = reconcileEnginePair({
    ...lastHealthData,
    partialProvider: partialProviderEl.value,
    finalProvider: finalProviderEl.value,
  });
  syncSelect(partialProviderEl, pair.partialList, pair.partialId);
  saveSettings();
});

for (const el of [asrModeEl, reviseModeEl]) {
  el.addEventListener("change", () => saveSettings());
}

refreshStatus();
