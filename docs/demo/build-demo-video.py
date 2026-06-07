#!/usr/bin/env python3
"""Generate VoiceBridgeAI demo MP4: TTS narration + slide images."""

from __future__ import annotations

import math
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "VoiceBridgeAI-demo.mp4"
WORK = Path(tempfile.mkdtemp(prefix="vb-demo-"))
WIDTH, HEIGHT = 1280, 720
VOICE = "Ting-Ting"
BG = (20, 20, 40)
TITLE_COLOR = (255, 255, 255)
BODY_COLOR = (184, 197, 214)

SLIDES = [
    ("VoiceBridgeAI", "macOS 实时英文字幕翻译", "系统音频 → 中文悬浮字幕"),
    ("数据流", "ScreenCaptureKit 采集系统声音", "Swift App → Python 引擎 → 悬浮 Overlay"),
    ("三层引擎", "① ASR（Whisper 本地 / 云端）", "② 句中翻译  ③ 句末 LLM 润色"),
    ("观看场景", "演讲 / 技术 / 会议 / 网课", "影响 VAD 断句与润色风格"),
    ("悬浮字幕", "背景与文字透明度可调", "静音约 2.5 秒自动清屏"),
    ("字幕记录", "定稿句写入文件", "多种中英排版模板"),
    ("Local 与 Cloud", "Local：离线 Whisper + Argos（约 1.2 GB）", "Cloud：仅云端 ASR/翻译（约 77 MB）"),
    ("设置与引擎", "云端 Provider 测试与保存", "引擎下拉、本地模型管理"),
    ("试用方式", "releases/ 下载 .app，右键打开", "授予屏幕录制 → 开始悬浮字幕"),
]

FONT_CANDIDATES = [
    "/System/Library/Fonts/Hiragino Sans GB.ttc",
    "/System/Library/Fonts/STHeiti Light.ttc",
    "/Library/Fonts/Arial Unicode.ttf",
]


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for path in FONT_CANDIDATES:
        if Path(path).exists():
            try:
                return ImageFont.truetype(path, size)
            except OSError:
                continue
    return ImageFont.load_default()


def render_slide(title: str, line1: str, line2: str, path: Path) -> None:
    img = Image.new("RGB", (WIDTH, HEIGHT), BG)
    draw = ImageDraw.Draw(img)
    title_font = load_font(52)
    body_font = load_font(34)

    def center_y(text: str, font, y_ratio: float, color) -> None:
        bbox = draw.textbbox((0, 0), text, font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        draw.text(((WIDTH - tw) / 2, HEIGHT * y_ratio - th / 2), text, font=font, fill=color)

    center_y(title, title_font, 0.28, TITLE_COLOR)
    center_y(line1, body_font, 0.48, BODY_COLOR)
    center_y(line2, body_font, 0.58, BODY_COLOR)
    img.save(path)


def run(cmd: list[str]) -> None:
    subprocess.run(cmd, check=True)


def audio_duration(path: Path) -> float:
    out = subprocess.check_output(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)],
        text=True,
    )
    return float(out.strip())


def main() -> None:
    segments: list[Path] = []
    load_font(52)

    for i, (title, line1, line2) in enumerate(SLIDES, start=1):
        png = WORK / f"slide{i}.png"
        audio = WORK / f"slide{i}.m4a"
        video = WORK / f"slide{i}.mp4"
        narration = f"{title}。{line1}。{line2}。"

        render_slide(title, line1, line2, png)
        run(["say", "-v", VOICE, "-o", str(audio), "--file-format=m4af", narration])
        dur = max(4.0, math.ceil(audio_duration(audio) + 0.5))

        run(
            [
                "ffmpeg",
                "-y",
                "-loop",
                "1",
                "-i",
                str(png),
                "-i",
                str(audio),
                "-c:v",
                "libx264",
                "-t",
                str(dur),
                "-pix_fmt",
                "yuv420p",
                "-c:a",
                "aac",
                "-shortest",
                str(video),
                "-loglevel",
                "error",
            ]
        )
        segments.append(video)

    concat_list = WORK / "concat.txt"
    concat_list.write_text("\n".join(f"file '{p}'" for p in segments) + "\n", encoding="utf-8")
    run(["ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", str(concat_list), "-c", "copy", str(OUT), "-loglevel", "error"])

    size_mb = OUT.stat().st_size / (1024 * 1024)
    print(f"已生成: {OUT} ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
