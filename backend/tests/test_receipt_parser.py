from app.schemas import ReceiptParserResponse
from app.services.receipt_parser import (
    SYSTEM_INSTRUCTION,
    GeminiReceiptParserService,
)


def test_gemini_rules_are_sent_as_system_instruction() -> None:
    config = GeminiReceiptParserService._generation_config()

    assert config.system_instruction == SYSTEM_INSTRUCTION
    assert config.response_schema is ReceiptParserResponse
    assert "kuruş" in SYSTEM_INSTRUCTION

