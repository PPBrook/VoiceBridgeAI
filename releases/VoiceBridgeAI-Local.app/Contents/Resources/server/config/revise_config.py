"""Revise / VAD presets for different viewing scenarios."""

from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any

from core.vad import VadParams

REVISE_SCENE_NOTE = (
    "按观看内容选择策略：影响断句节奏、句中更新、回溯深度，以及句末 LLM 润色风格。"
    "本地 Whisper / OpenAI 按静音切句；腾讯云 ASR 由云端切句。"
    "修改后保存；字幕运行中切换会即时生效。"
)

REVISE_MODES = (
    {
        "id": "speech",
        "label": "演讲 · 跟节奏",
        "description": "停顿约 1 秒再切句，单段不宜过长，跟演讲呼吸与排比节奏。",
        "polishNote": "润色偏口语化、有节奏感，适合 keynote 听感。",
        "examples": "TED、产品发布、毕业演讲",
        "polishHint": (
            "观看场景：公开演讲。译文宜口语流畅、有节奏，可适度修辞但勿浮夸或增删信息；"
            "适合一口气读完的字幕句长。"
        ),
    },
    {
        "id": "tech",
        "label": "技术分享 · 术语稳定",
        "description": "概念块尽量完整，术语与解释不拆开；句中更新较快，回溯更深。",
        "polishNote": "润色保留 API/框架等术语，全文译名一致。",
        "examples": "Meetup、架构讲解、DevRel、代码 walkthrough",
        "polishHint": (
            "观看场景：技术分享。保持概念块完整；Kubernetes、React、gRPC 等常见术语"
            "优先保留英文或业界通用译名，同一术语全文一致；解释型长句可略长但须易读。"
        ),
    },
    {
        "id": "conference",
        "label": "会议 · 低延迟",
        "description": "短停顿即切句，句中更新快，少回溯；适合多人轮替与快问快答。",
        "polishNote": "润色偏直译清晰，短句优先，减少赘述。",
        "examples": "峰会 Q&A、圆桌、同传、多边讨论",
        "polishHint": (
            "观看场景：会议 / Q&A。优先清晰直译与短句，快览式表达；"
            "不必过度润色，避免拉长字幕停留时间。"
        ),
    },
    {
        "id": "course",
        "label": "网课 · 知识点整段",
        "description": "长停顿才切句，过滤「嗯、好、下一页」；整段知识点一起显示。",
        "polishNote": "润色成完整知识点表述，适合暂停记笔记。",
        "examples": "MOOC、培训录播、在线课程",
        "polishHint": (
            "观看场景：课程讲解。整段知识点连贯表达，句子可稍长但结构清楚；"
            "去掉口语赘语，保留定义、步骤与因果，便于观众理解并记笔记。"
        ),
    },
)

_VALID = frozenset(m["id"] for m in REVISE_MODES)

# Older speed/balanced/accuracy values still load from .env and saved settings.
LEGACY_ALIASES: dict[str, str] = {
    "speed": "conference",
    "balanced": "speech",
    "accuracy": "course",
}


@dataclass(frozen=True)
class ReviseParams:
    debounce_s: float
    lookback: int
    refine_interval_s: float
    silence_ms: int
    min_utterance_ms: int
    max_utterance_s: float
    silence_rms: float = 0.012
    min_chars: int = 3

    def vad_params(self) -> VadParams:
        return VadParams(
            silence_rms=self.silence_rms,
            silence_ms=self.silence_ms,
            min_utterance_ms=self.min_utterance_ms,
            max_utterance_s=self.max_utterance_s,
            refine_interval_s=self.refine_interval_s,
        )


PRESETS: dict[str, ReviseParams] = {
    "speech": ReviseParams(
        debounce_s=0.28,
        lookback=2,
        refine_interval_s=0.9,
        silence_ms=1050,
        min_utterance_ms=500,
        max_utterance_s=14.0,
    ),
    "tech": ReviseParams(
        debounce_s=0.22,
        lookback=3,
        refine_interval_s=0.7,
        silence_ms=900,
        min_utterance_ms=600,
        max_utterance_s=18.0,
    ),
    "conference": ReviseParams(
        debounce_s=0.18,
        lookback=1,
        refine_interval_s=0.5,
        silence_ms=600,
        min_utterance_ms=400,
        max_utterance_s=10.0,
    ),
    "course": ReviseParams(
        debounce_s=0.32,
        lookback=3,
        refine_interval_s=1.1,
        silence_ms=1500,
        min_utterance_ms=800,
        max_utterance_s=22.0,
    ),
}


def _mode_catalog_entry(mode_id: str) -> dict[str, Any]:
    meta = next(m for m in REVISE_MODES if m["id"] == mode_id)
    params = PRESETS[mode_id]
    return {
        **meta,
        "silenceMs": params.silence_ms,
        "minUtteranceMs": params.min_utterance_ms,
        "maxUtteranceS": params.max_utterance_s,
        "refineIntervalS": params.refine_interval_s,
        "lookback": params.lookback,
    }


def default_mode() -> str:
    env = os.getenv("REVISE_MODE", "").strip()
    if env:
        return normalize_mode(env)
    return "speech"


def normalize_mode(mode: str | None) -> str:
    if not mode:
        return default_mode()
    if mode in _VALID:
        return mode
    if mode in LEGACY_ALIASES:
        return LEGACY_ALIASES[mode]
    return "speech"


def get_params(mode: str | None = None) -> ReviseParams:
    return PRESETS[normalize_mode(mode)]


def polish_hint_for_mode(mode: str | None = None) -> str:
    mode_id = normalize_mode(mode)
    for item in REVISE_MODES:
        if item["id"] == mode_id:
            return str(item.get("polishHint") or "")
    return ""


def get_status(mode: str | None = None) -> dict[str, Any]:
    current = normalize_mode(mode)
    params = get_params(current)
    return {
        "reviseMode": current,
        "reviseSceneNote": REVISE_SCENE_NOTE,
        "reviseModes": [_mode_catalog_entry(m["id"]) for m in REVISE_MODES],
        "reviseLookback": params.lookback,
        "reviseDebounce": params.debounce_s,
        "reviseRefineInterval": params.refine_interval_s,
        "reviseSilenceMs": params.silence_ms,
        "reviseMinUtteranceMs": params.min_utterance_ms,
        "reviseMaxUtteranceS": params.max_utterance_s,
    }
