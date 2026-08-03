import re
import unicodedata

OCR_TEXT_MAX_LENGTH = 30_000

_PROMPT_INJECTION_PATTERNS = (
    re.compile(
        r"\b(?:ignore|disregard|forget)\b.{0,80}"
        r"\b(?:previous|prior|above|system|developer)\b.{0,40}"
        r"\b(?:instruction|prompt|message)s?\b",
    ),
    re.compile(
        r"\b(?:reveal|show|print|repeat|return)\b.{0,80}"
        r"\b(?:system|developer)\b.{0,40}"
        r"\b(?:instruction|prompt|message)s?\b",
    ),
    re.compile(
        r"\b(?:önceki|yukarıdaki|sistem|geliştirici)\b.{0,80}"
        r"\b(?:talimat|komut|istem|mesaj)(?:ı|i|u|ü|ları|leri)?\b.{0,40}"
        r"\b(?:yok say|unut|göster|açıkla|tekrarla)\b",
    ),
    re.compile(
        r"\b(?:yok say|unut|göster|açıkla|tekrarla)\b.{0,80}"
        r"\b(?:önceki|yukarıdaki|sistem|geliştirici)\b.{0,40}"
        r"\b(?:talimat|komut|istem|mesaj)(?:ı|i|u|ü|ları|leri)?\b",
    ),
    re.compile(r"\b(?:system|developer)\s*(?:prompt|message)\s*:"),
)


def normalize_ocr_text(value: str) -> str:
    """Normalize OCR text for validation while preserving receipt line breaks."""
    return unicodedata.normalize("NFKC", value).strip()


def contains_prompt_injection(value: str) -> bool:
    comparable = " ".join(value.casefold().split())
    return any(pattern.search(comparable) for pattern in _PROMPT_INJECTION_PATTERNS)


def validate_ocr_text(value: str) -> str:
    normalized = normalize_ocr_text(value)
    if not normalized:
        raise ValueError("OCR metni boş olamaz")
    if len(normalized) > OCR_TEXT_MAX_LENGTH:
        raise ValueError(f"OCR metni en fazla {OCR_TEXT_MAX_LENGTH} karakter olabilir")
    if contains_prompt_injection(normalized):
        raise ValueError("OCR metni güvenlik filtresini geçemedi")
    return normalized
