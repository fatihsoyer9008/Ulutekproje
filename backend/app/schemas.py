from pydantic import BaseModel
from typing import List

# 1. YENİ EKLENEN: Frontend'den gelecek olan İstek (Request) Modeli
class ReceiptParserRequest(BaseModel):
    ocr_text: str  # Fişten okunan ham metin buraya gönderilecek

# 2. GÜNCELLENEN: Fişteki ürün modeli (category eklendi)
class ReceiptItem(BaseModel):
    name: str
    price_minor: int  
    category: str  # YENİ EKLENDİ (Örn: "Gıda", "Temizlik")

# 3. Frontend'e döneceğimiz Yanıt (Response) Modeli
class ReceiptParserResponse(BaseModel):
    store_name: str
    total_amount_minor: int
    items: List[ReceiptItem]