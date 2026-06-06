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

function showError(text) {
  if (!text) {
    errorEl.hidden = true;
    errorEl.textContent = "";
    return;
  }
  errorEl.hidden = false;
  errorEl.textContent = text;
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
  if (stored.asrMode || stored.asrProvider) {
    asrModeEl.value = stored.asrProvider || stored.asrMode;
  }
  if (stored.partialProvider) partialProviderEl.value = stored.partialProvider;
  if (stored.finalProvider) finalProviderEl.value = stored.finalProvider;
  if (stored.reviseMode) reviseModeEl.value = stored.reviseMode;
  const base = stored.serverUrl || "http://127.0.0.1:8765";
  openConsoleEl.href = base;
}

function setCapturing(active) {
  btnStart.hidden = active;
  btnStop.hidden = !active;
  for (const el of engineEls) el.disabled = active;
}

async function refreshStatus() {
  const status = await chrome.runtime.sendMessage({ type: "GET_STATUS" });
  serverStatusEl.textContent = status.serverOk ? "服务已连接" : "服务未连接";
  serverStatusEl.className = `status-pill ${status.serverOk ? "ok" : "bad"}`;
  btnStart.disabled = !status.serverOk;
  setCapturing(status.capturing);
  if (status.capturing) {
    hintEl.textContent = "正在当前标签页显示悬浮字幕…";
  } else if (status.serverOk) {
    hintEl.textContent = "打开英文视频页，点击「开始悬浮字幕」。";
  } else {
    hintEl.textContent = "请先在项目目录运行 ./run.sh";
  }
  if (status.config) {
    asrModeEl.value = status.config.asrProvider || status.config.asrMode;
    partialProviderEl.value = status.config.partialProvider || "tmt";
    finalProviderEl.value = status.config.finalProvider || "qiniu";
    reviseModeEl.value = status.config.reviseMode;
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

for (const el of engineEls) {
  el.addEventListener("change", () => saveSettings());
}

loadSettings().then(refreshStatus);
