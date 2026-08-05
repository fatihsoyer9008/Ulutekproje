# Fiş Ürünleri İnceleme Arayüzü V2

## Amaç

Ana `İşlemi Kontrol Et` ekranını sade tutarken OCR tarafından bulunan ürünlerin
ayrı bir ekranda güvenli biçimde incelenmesini ve düzenlenmesini sağlamak.

## Onay Taslağı

```text
İşlemi Kontrol Et
┌──────────────────────────────────────┐
│ Fiş Ürünleri                         │
│ 4 ürün kalemi bulundu.  [Görüntüle] │
└──────────────────────────────────────┘

Fiş Ürünleri
┌──────────────────────────────────────┐
│ Ürün toplamı fişle eşleşmiyor        │
│ [Fiş tutarını güncelle]              │
└──────────────────────────────────────┘
┌──────────────────────────────────────┐
│ Süt                         ✎  🗑    │
│ Miktar: 2                            │
│ Birim fiyat: 12,50 TL                │
│ Satır toplamı: 25,00 TL              │
└──────────────────────────────────────┘

[Vazgeç]                 [Uygula]
                            [+ Ürün ekle]
```

## Tasarım Kararları

- Ürün CRUD işlemleri ana formun dışında ayrı bir sayfada yapılır.
- Sayfa açılırken ürün listesi kopyalanır; `TransactionDraft` doğrudan
  değiştirilmez.
- `Vazgeç` yerel kopyayı atar, `Uygula` güncellenen listeyi üst ekrana döndürür.
- Eksik OCR alanları `Belirtilmedi` olarak gösterilir.
- Para değerleri daima kuruş cinsinden `int` tutulur.
- Fiş tutarı ürün toplamına otomatik eşitlenmez; kullanıcı açıkça onaylar.
- Uzun listeler `ListView.builder` ile oluşturulur.
- Material 3 renk şeması açık/koyu temada sistem renklerini kullanır.
- Kontroller TalkBack ve VoiceOver için açıklayıcı semantic etiketler taşır.

## Kabul Edilen Modüler Yapı

- `receipt_items_summary_card.dart`: Ana ekrandaki sade özet.
- `receipt_items_review_page.dart`: Liste, empty-state ve toplam doğrulaması.
- `receipt_item_form_dialog.dart`: Ürün ekleme ve düzenleme formu.
