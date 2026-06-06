/** Grouped engine provider dropdowns (MT vs LLM recommendations). */
const MT_PROVIDER_IDS = new Set(["tmt", "baidu", "google", "deepl", "argos"]);

const PARTIAL_OPTION_GROUPS = [
  { label: "机器翻译 MT · 推荐句中", ids: ["tmt", "baidu", "deepl", "google", "argos"] },
  { label: "LLM 快译", ids: ["qiniu", "aliyun", "deepseek", "openai"] },
];

const FINAL_OPTION_GROUPS = [
  { label: "LLM 润色 · 推荐句末", ids: ["qiniu", "aliyun", "deepseek", "openai"] },
  { label: "机器翻译 MT", ids: ["tmt", "baidu", "deepl", "google", "argos"] },
  { label: "其它", ids: ["none"] },
];

function isMtProvider(id) {
  return MT_PROVIDER_IDS.has(id);
}

function buildGroupedSelectChildren(providers, groups) {
  const byId = new Map(providers.map((p) => [p.id, p]));
  const placed = new Set();
  const nodes = [];

  for (const { label, ids } of groups) {
    const items = ids.map((id) => byId.get(id)).filter(Boolean);
    if (!items.length) continue;
    items.forEach((p) => placed.add(p.id));
    const og = document.createElement("optgroup");
    og.label = label;
    for (const p of items) {
      const opt = document.createElement("option");
      opt.value = p.id;
      opt.textContent = p.label;
      og.append(opt);
    }
    nodes.push(og);
  }

  for (const p of providers) {
    if (placed.has(p.id)) continue;
    const opt = document.createElement("option");
    opt.value = p.id;
    opt.textContent = p.label;
    nodes.push(opt);
  }

  return nodes;
}

function syncProviderSelect(selectEl, providers, value, layer, onSyncing) {
  if (!selectEl || !providers?.length) return;
  const ids = providers.map((p) => p.id).join("|");
  const groups = layer === "partial" ? PARTIAL_OPTION_GROUPS : FINAL_OPTION_GROUPS;
  const cacheKey = `${layer}:${ids}`;
  if (selectEl.dataset.providerIds !== cacheKey) {
    selectEl.dataset.providerIds = cacheKey;
    selectEl.replaceChildren(...buildGroupedSelectChildren(providers, groups));
  }
  const pick =
    value && selectEl.querySelector(`option[value="${value}"]`)
      ? value
      : selectEl.options[0]?.value;
  if (pick && selectEl.value !== pick) {
    if (onSyncing) onSyncing(true);
    selectEl.value = pick;
    if (onSyncing) onSyncing(false);
  }
}

function isRecommendedMtLlmPair(partialId, finalId, llmIds) {
  if (!partialId || !finalId || finalId === "none") return false;
  return isMtProvider(partialId) && llmIds.has(finalId) && partialId !== finalId;
}
