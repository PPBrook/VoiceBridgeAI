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
const testAllCloudBtn = document.getElementById("test-all-cloud");
const cloudSettingsNoteEl = document.getElementById("cloud-settings-note");

const capRows = () => Array.from(document.querySelectorAll(".cap-row"));
const testButtons = () => Array.from(document.querySelectorAll(".btn-test"));

const LAYER_ORDER = ["asr", "partial", "final"];
const LAYER_NEXT = { asr: "partial", partial: "final" };

let lastCapRowFocusTimer = null;

function openAncestorDetails(el) {
  let node = el;
  while (node) {
    if (node.tagName === "DETAILS") node.open = true;
    node = node.parentElement;
  }
}

function highlightCapRow(row) {
  if (!row) return;
  openAncestorDetails(row);
  row.classList.add("cap-row-next");
  row.scrollIntoView({ behavior: "smooth", block: "nearest" });
  row.querySelector(".btn-test")?.focus({ preventScroll: true });
  if (lastCapRowFocusTimer) clearTimeout(lastCapRowFocusTimer);
  lastCapRowFocusTimer = setTimeout(() => {
    row.classList.remove("cap-row-next");
    lastCapRowFocusTimer = null;
  }, 2400);
}

function capRowPassed(row) {
  return row?.querySelector(".cap-status")?.classList.contains("ok");
}

function findCapRow(scope, layer, providerId) {
  if (!scope || !layer) return null;
  const selector = providerId
    ? `.cap-row[data-layer="${layer}"][data-id="${providerId}"]`
    : `.cap-row[data-layer="${layer}"]`;
  return scope.querySelector(selector);
}

/** After a layer passes, expand and focus the next cap row in the same provider block. */
function advanceToNextLayer(passedRow) {
  if (!passedRow) return;
  const layer = passedRow.dataset.layer;
  const nextLayer = LAYER_NEXT[layer];
  if (!nextLayer) return;

  const scope =
    passedRow.closest(".provider-fold") ??
    passedRow.closest(".cap-strip")?.closest("details") ??
    passedRow.closest(".fold-group-body");

  let nextRow = findCapRow(passedRow.closest(".cap-strip"), nextLayer);
  if (!nextRow && scope) {
    nextRow = findCapRow(scope, nextLayer);
  }
  if (!nextRow) return;

  if (capRowPassed(nextRow)) {
    advanceToNextLayer(nextRow);
    return;
  }

  highlightCapRow(nextRow);
}

function advanceProvidersAfterResults(results = []) {
  const folds = new Set();
  for (const item of results) {
    if (!item.ok) continue;
    const row = document.querySelector(
      `.cap-row[data-layer="${item.layer}"][data-id="${item.providerId}"]`
    );
    const fold = row?.closest(".provider-fold");
    if (fold) folds.add(fold);
  }

  let focusRow = null;
  for (const fold of folds) {
    let lastPassed = null;
    for (const layer of LAYER_ORDER) {
      const row = fold.querySelector(`.cap-row[data-layer="${layer}"]`);
      if (row && capRowPassed(row)) lastPassed = row;
    }
    if (!lastPassed) continue;
    const nextLayer = LAYER_NEXT[lastPassed.dataset.layer];
    if (!nextLayer) continue;
    const nextRow = findCapRow(fold, nextLayer);
    if (nextRow && !capRowPassed(nextRow)) {
      focusRow = nextRow;
    }
  }

  if (focusRow) highlightCapRow(focusRow);
}

let lastHealthData = null;
let startupPollTimer = null;
let startupResultsApplied = false;

const capTipEl = document.getElementById("cap-tip");
let capTipAnchor = null;

function capStatusDisplay(text, { err = false } = {}) {
  const msg = (text || "").replace(/\s+/g, " ").trim();
  if (!msg) return { short: "", tip: "" };
  if (msg === "测试中…") return { short: msg, tip: "" };

  if (err) {
    const code = msg.match(/HTTP (\d+)/)?.[1];
    return { short: code ? `失败 ${code}` : "失败", tip: msg };
  }

  if (
    msg.includes("测试通过") ||
    msg.includes("已通过") ||
    msg.includes("可用") ||
    msg.includes("有效") ||
    msg.includes("成功")
  ) {
    return { short: "已通过", tip: msg !== "已通过" ? msg : "" };
  }

  if (msg.length <= 8) return { short: msg, tip: "" };
  return { short: `${msg.slice(0, 7)}…`, tip: msg };
}

function hideCapTip() {
  if (!capTipEl) return;
  capTipEl.hidden = true;
  capTipEl.textContent = "";
  capTipAnchor = null;
}

function showCapTip(statusEl) {
  if (!capTipEl || !statusEl?.dataset.tip) return;
  capTipAnchor = statusEl;
  capTipEl.textContent = statusEl.dataset.tip;
  capTipEl.hidden = false;
  capTipEl.style.left = "0px";
  capTipEl.style.top = "0px";
  const rect = statusEl.getBoundingClientRect();
  const tipRect = capTipEl.getBoundingClientRect();
  let left = rect.left;
  let top = rect.bottom + 6;
  if (left + tipRect.width > window.innerWidth - 8) {
    left = Math.max(8, window.innerWidth - tipRect.width - 8);
  }
  if (top + tipRect.height > window.innerHeight - 8) {
    top = Math.max(8, rect.top - tipRect.height - 6);
  }
  capTipEl.style.left = `${left}px`;
  capTipEl.style.top = `${top}px`;
}

function updateCapStatusEl(statusEl, text, { err = false } = {}) {
  if (!statusEl) return;
  const { short, tip } = capStatusDisplay(text, { err });
  statusEl.textContent = short;
  if (tip) {
    statusEl.dataset.tip = tip;
    statusEl.classList.add("has-tip");
  } else {
    delete statusEl.dataset.tip;
    statusEl.classList.remove("has-tip");
    if (capTipAnchor === statusEl) hideCapTip();
  }
}

function bindCapStatusTips() {
  const root = document.querySelector(".config-page");
  if (!root || root.dataset.capTipsBound) return;
  root.dataset.capTipsBound = "1";

  root.addEventListener("mouseover", (e) => {
    const el = e.target.closest(".cap-status.has-tip");
    if (el) showCapTip(el);
  });
  root.addEventListener("mouseout", (e) => {
    const el = e.target.closest(".cap-status.has-tip");
    if (!el) return;
    const next = e.relatedTarget;
    if (next && (el.contains(next) || capTipEl?.contains(next))) return;
    hideCapTip();
  });
  window.addEventListener(
    "scroll",
    () => {
      if (capTipAnchor) showCapTip(capTipAnchor);
    },
    true
  );
  window.addEventListener("resize", hideCapTip);
}

bindCapStatusTips();

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
        updateCapStatusEl(statusEl, "已通过");
      }
    } else if (!statusEl.classList.contains("err") && !statusEl.dataset.custom) {
      statusEl.classList.remove("ok");
      updateCapStatusEl(statusEl, "");
    }
  }
}

function expandVerifiedFolds() {
  for (const row of capRows()) {
    const statusEl = row.querySelector(".cap-status");
    if (!statusEl?.classList.contains("ok")) continue;
    openAncestorDetails(row);
  }
}

function cloudConfigHasInput() {
  return Object.values(cloudConfigPayload()).some(
    (block) => block && Object.keys(block).length > 0
  );
}

function cloudSettingsSummary(d) {
  const ready = d?.verified || {};
  const parts = [
    ...(ready.asr || []).map((id) => `识别·${id}`),
    ...(ready.partial || []).map((id) => `句中·${id}`),
    ...(ready.final || []).map((id) => `句末·${id}`),
  ];
  return parts.length
    ? `已测试通过：${parts.join("、")}`
    : "离线默认可用；填写密钥后请保存并测试";
}

function applyCloudStatus(d) {
  const t = d.tencent || {};
  const q = d.qiniu || {};
  const a = d.aliyun || {};
  applyVerifiedStatus(d.verified || {});
  expandVerifiedFolds();

  if (t.appId != null) tencentAppIdEl.value = t.appId || "";
  if (t.engine != null) tencentEngineEl.value = t.engine || "";
  if (t.tmtRegion != null) tencentTmtRegionEl.value = t.tmtRegion || "";
  if (t.tmtProjectId != null) tencentTmtProjectIdEl.value = t.tmtProjectId || "";
  tencentSecretIdEl.placeholder = t.hasSecretId
    ? "已配置，留空不修改"
    : "粘贴 SecretId";
  tencentSecretKeyEl.placeholder = t.hasSecretKey
    ? "已配置，留空不修改"
    : "粘贴 SecretKey";
  if (q.baseUrl != null) qiniuBaseUrlEl.value = q.baseUrl || "";
  if (q.model != null) qiniuModelEl.value = q.model || "";
  qiniuApiKeyEl.placeholder = q.hasApiKey ? "已配置，留空不修改" : "粘贴 API Key";
  if (a.baseUrl != null) aliyunBaseUrlEl.value = a.baseUrl || "";
  if (a.model != null) aliyunModelEl.value = a.model || "";
  aliyunApiKeyEl.placeholder = a.hasApiKey ? "已配置，留空不修改" : "粘贴 API Key";
  if (d.baidu?.appId != null) baiduAppIdEl.value = d.baidu.appId || "";
  baiduSecretKeyEl.placeholder = d.baidu?.hasSecretKey
    ? "已配置，留空不修改"
    : "粘贴 Secret Key";
  deeplApiKeyEl.placeholder = d.deepl?.hasApiKey
    ? "已配置，留空不修改"
    : "粘贴 API Key";
  if (d.deepseek?.baseUrl != null) deepseekBaseUrlEl.value = d.deepseek.baseUrl || "";
  if (d.deepseek?.model != null) deepseekModelEl.value = d.deepseek.model || "";
  deepseekApiKeyEl.placeholder = d.deepseek?.hasApiKey
    ? "已配置，留空不修改"
    : "粘贴 API Key";
  if (d.openai?.baseUrl != null) openaiBaseUrlEl.value = d.openai.baseUrl || "";
  if (d.openai?.model != null) openaiModelEl.value = d.openai.model || "";
  if (d.openai?.asrModel != null) openaiAsrModelEl.value = d.openai.asrModel || "";
  openaiApiKeyEl.placeholder = d.openai?.hasApiKey
    ? "已配置，留空不修改"
    : "粘贴 API Key";

  cloudSettingsNoteEl.classList.remove("warn");
  cloudSettingsNoteEl.textContent = cloudSettingsSummary(d);
}

function applyTestAllResults(results = []) {
  for (const item of results) {
    const row = document.querySelector(
      `.cap-row[data-layer="${item.layer}"][data-id="${item.providerId}"]`
    );
    const statusEl = row?.querySelector(".cap-status");
    if (!statusEl) continue;
    delete statusEl.dataset.pending;
    statusEl.dataset.custom = "1";
    updateCapStatusEl(statusEl, item.message || (item.ok ? "已通过" : "失败"), {
      err: !item.ok,
    });
    statusEl.classList.toggle("ok", !!item.ok);
    statusEl.classList.toggle("err", !item.ok);
  }
  advanceProvidersAfterResults(results);
}

function handleStartupTest(d) {
  const st = d?.startupTest;
  if (!st) return;
  if (testAllCloudBtn) testAllCloudBtn.disabled = !!st.running;
  if (st.running) {
    cloudSettingsNoteEl.textContent = st.summary || "正在启动测试…";
    cloudSettingsNoteEl.classList.remove("warn");
    if (!startupPollTimer) {
      startupPollTimer = setTimeout(() => {
        startupPollTimer = null;
        refreshConfig().catch(() => {});
      }, 1500);
    }
    return;
  }
  if (startupPollTimer) {
    clearTimeout(startupPollTimer);
    startupPollTimer = null;
  }
  if (st.done && st.results?.length && !startupResultsApplied) {
    applyTestAllResults(st.results);
    startupResultsApplied = true;
    cloudSettingsNoteEl.textContent = st.summary;
    cloudSettingsNoteEl.classList.toggle(
      "warn",
      st.results.some((item) => !item.ok)
    );
    expandVerifiedFolds();
  }
}

function applyConfigStatus(d) {
  if (!d) return;
  if (!d.verified && lastHealthData?.verified) {
    d = { ...d, verified: lastHealthData.verified };
  }
  lastHealthData = d;
  applyCloudStatus(d);
}

async function refreshConfig() {
  try {
    const r = await fetch("/api/health");
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    const d = await r.json();
    applyConfigStatus(d);
    handleStartupTest(d);
    return d;
  } catch (err) {
    console.error("config refresh failed:", err);
    cloudSettingsNoteEl.textContent = "无法连接后端，请确认已运行 ./run.sh";
    cloudSettingsNoteEl.classList.add("warn");
    return null;
  }
}

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

  return { tencent, qiniu, aliyun, baidu, deepl, deepseek, openai };
}

function clearSecretFields() {
  tencentSecretIdEl.value = "";
  tencentSecretKeyEl.value = "";
  qiniuApiKeyEl.value = "";
  aliyunApiKeyEl.value = "";
  baiduSecretKeyEl.value = "";
  deeplApiKeyEl.value = "";
  deepseekApiKeyEl.value = "";
  openaiApiKeyEl.value = "";
}

async function postTestAll() {
  testAllCloudBtn.disabled = true;
  saveCloudBtn.disabled = true;
  cloudSettingsNoteEl.textContent = "正在测试全部已配置接口…";
  cloudSettingsNoteEl.classList.remove("warn");
  for (const btn of testButtons()) btn.disabled = true;
  try {
    const r = await fetch("/api/cloud/test-all", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(cloudConfigPayload()),
    });
    let d;
    try {
      d = await r.json();
    } catch {
      cloudSettingsNoteEl.textContent = "一键测试失败：响应异常";
      cloudSettingsNoteEl.classList.add("warn");
      return;
    }
    applyTestAllResults(d.results || []);
    cloudSettingsNoteEl.textContent = d.message || "测试完成";
    cloudSettingsNoteEl.classList.toggle("warn", (d.failed || 0) > 0);
    applyConfigStatus(d);
    expandVerifiedFolds();
  } catch {
    cloudSettingsNoteEl.textContent = "一键测试失败";
    cloudSettingsNoteEl.classList.add("warn");
  } finally {
    saveCloudBtn.disabled = false;
    testAllCloudBtn.disabled = false;
    for (const btn of testButtons()) btn.disabled = false;
  }
}

async function postProviderTest(layer, id, btn) {
  const row = btn.closest(".cap-row");
  const statusEl = row?.querySelector(".cap-status");
  btn.disabled = true;
  if (statusEl) {
    statusEl.dataset.pending = "1";
    statusEl.classList.remove("ok", "err");
    updateCapStatusEl(statusEl, "测试中…");
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
        statusEl.classList.add("err");
        updateCapStatusEl(statusEl, "测试失败：响应异常", { err: true });
      }
      return;
    }
    if (d.ok) {
      if (statusEl) {
        delete statusEl.dataset.pending;
        statusEl.dataset.custom = "1";
        updateCapStatusEl(statusEl, d.message || "已通过");
        statusEl.classList.remove("err");
        statusEl.classList.add("ok");
      }
      applyConfigStatus(d);
      advanceToNextLayer(row);
    } else {
      const msg = d.message || (d.errors || ["测试失败"]).join(" · ");
      if (statusEl) {
        delete statusEl.dataset.pending;
        delete statusEl.dataset.custom;
        updateCapStatusEl(statusEl, msg, { err: true });
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
      statusEl.classList.add("err");
      updateCapStatusEl(statusEl, "测试失败", { err: true });
    }
  } finally {
    btn.disabled = false;
  }
}

async function postCloudSettings() {
  if (!cloudConfigHasInput()) {
    cloudSettingsNoteEl.textContent =
      "没有可保存的内容（请填写至少一项；密钥留空表示不修改已有值）";
    cloudSettingsNoteEl.classList.add("warn");
    return;
  }

  saveCloudBtn.disabled = true;
  cloudSettingsNoteEl.classList.remove("warn");
  cloudSettingsNoteEl.textContent = "正在保存…";

  try {
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
    if (!r.ok || d.ok === false) {
      cloudSettingsNoteEl.textContent = (d.errors || [d.message || "保存失败"]).join(
        " · "
      );
      cloudSettingsNoteEl.classList.add("warn");
      if (d.tencent || d.verified) applyConfigStatus(d);
      return;
    }
    applyConfigStatus(d);
    clearSecretFields();
    const summary = cloudSettingsSummary(d);
    cloudSettingsNoteEl.classList.remove("warn");
    cloudSettingsNoteEl.textContent = `${summary} · 已保存到 .env`;
  } catch {
    cloudSettingsNoteEl.textContent = "保存失败：无法连接后端";
    cloudSettingsNoteEl.classList.add("warn");
  } finally {
    saveCloudBtn.disabled = false;
  }
}

saveCloudBtn.addEventListener("click", () => {
  postCloudSettings().catch(() => {
    cloudSettingsNoteEl.textContent = "保存失败";
    cloudSettingsNoteEl.classList.add("warn");
  });
});

testAllCloudBtn?.addEventListener("click", () => {
  postTestAll().catch(() => {
    cloudSettingsNoteEl.textContent = "一键测试失败";
    cloudSettingsNoteEl.classList.add("warn");
  });
});

for (const strip of document.querySelectorAll(".cap-strip")) {
  strip.addEventListener("click", (e) => e.stopPropagation());
}

for (const btn of testButtons()) {
  btn.addEventListener("click", (e) => {
    e.preventDefault();
    e.stopPropagation();
    const row = btn.closest(".cap-row");
    const layer = row?.dataset.layer;
    const id = row?.dataset.id;
    if (layer && id) {
      postProviderTest(layer, id, btn).catch(() => {
        const statusEl = row.querySelector(".cap-status");
        if (statusEl) {
          statusEl.classList.add("err");
          updateCapStatusEl(statusEl, "测试失败", { err: true });
        }
      });
    }
  });
}

refreshConfig();
