const serverStatusEl = document.getElementById("server-status");
const btnStart = document.getElementById("btn-start");
const btnStop = document.getElementById("btn-stop");
const hintEl = document.getElementById("hint");
const errorEl = document.getElementById("error");
const asrModeEl = document.getElementById("asr-mode");
const translateModeEl = document.getElementById("translate-mode");
const reviseModeEl = document.getElementById("revise-mode");
const openConsoleEl = document.getElementById("open-console");

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
    translateMode: translateModeEl.value,
    reviseMode: reviseModeEl.value,
  };
  await chrome.storage.sync.set(config);
  return config;
}

async function loadSettings() {
  const stored = await chrome.storage.sync.get([
    "serverUrl",
    "asrMode",
    "translateMode",
    "reviseMode",
  ]);
  if (stored.asrMode) asrModeEl.value = stored.asrMode;
  if (stored.translateMode) translateModeEl.value = stored.translateMode;
  if (stored.reviseMode) reviseModeEl.value = stored.reviseMode;
  const base = stored.serverUrl || "http://127.0.0.1:8765";
  openConsoleEl.href = base;
}

function setCapturing(active) {
  btnStart.hidden = active;
  btnStop.hidden = !active;
  asrModeEl.disabled = active;
  translateModeEl.disabled = active;
  reviseModeEl.disabled = active;
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
    asrModeEl.value = status.config.asrMode;
    translateModeEl.value = status.config.translateMode;
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

for (const el of [asrModeEl, translateModeEl, reviseModeEl]) {
  el.addEventListener("change", () => saveSettings());
}

loadSettings().then(refreshStatus);
