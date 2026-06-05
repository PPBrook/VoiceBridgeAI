"""English → Chinese machine translation."""

from deep_translator import GoogleTranslator

_translator = GoogleTranslator(source="en", target="zh-CN")


def translate(text: str) -> str:
    text = text.strip()
    if not text:
        return ""
    return _translator.translate(text)
