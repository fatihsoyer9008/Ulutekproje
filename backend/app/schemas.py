from pydantic import BaseModel
from typing import List

class ReceiptItem(BaseModel):
    name: str
    price_minor: int  # Örn: 15.50 TL yerine 1550 olarak tutulacak

class ReceiptParserResponse(BaseModel):
    store_name: str
    total_amount_minor: int
    items: List[ReceiptItem]