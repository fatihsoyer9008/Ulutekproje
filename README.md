# EconBuddy

Flutter, FastAPI, ML Kit OCR ve Gemini AI destekli kişisel finans ve akıllı
fiş yönetimi uygulaması.

## Neler yapabiliyor?

- **Kişisel finans takibi** — gelir/gider kayıtları, kategoriler, aylık/yıllık
  istatistikler ve grafikler.
- **Akıllı fiş tarama** — kamerayla çekilen fişler Google ML Kit (cihaz üzeri
  metin tanıma) ve Gemini AI ile otomatik olarak ayrıştırılıp harcamaya
  dönüştürülür; n8n tabanlı bir onay/otomasyon akışıyla desteklenir.
- **Kumbara (birikim hedefleri)** — hedef belirleme, ilerleme takibi ve
  otomatik biriktirme kuralları.
- **Gruplar** — ortak harcama grupları oluşturma, eşit/yüzdesel/sabit
  tutarla veya fiş kalemi bazında (itemized) bölüştürme, borç özetleri ve
  ödeme (settlement) kayıtları.
- **Arkadaşlar** — grup oluşturmadan iki kişi arasında harcama bölüştürme;
  e-posta ile arkadaşlık daveti gönderip kabul etme.
- **Aktivite akışı** — gruplardaki harcama, ödeme ve üyelik hareketlerinin
  kronolojik geçmişi.

## Mimari

- `fis_uygulamasi/` — Flutter uygulaması (Riverpod, go_router, Isar).
- `backend/` — FastAPI + PostgreSQL + Redis API sunucusu (Alembic migration,
  JWT tabanlı kimlik doğrulama, Google/Apple OAuth).
- `core_ui/`, `finance_database/`, `receipt_ai_scanner/` — paylaşılan Dart
  paketleri.
- n8n — fiş onay/otomasyon iş akışları (bkz. `docs/n8n_webhook_contract.md`).

## Hızlı başlangıç (canlı backend ile)

Backend `https://116-202-14-23.sslip.io` adresinde canlıda çalışıyor. Kendi
backend'inizi ayağa kaldırmadan, doğrudan bu adrese bağlanarak uygulamayı
deneyebilirsiniz:

```bash
cd fis_uygulamasi
flutter pub get
flutter run --dart-define=API_BASE_URL=https://116-202-14-23.sslip.io
```

Backend'i kendi bilgisayarınızda (Docker ile) çalıştırmak, `.env`
değişkenlerini yapılandırmak, Android cihaz/emülatör kurulumu, test ve APK
build adımları için
[Takım Ortam ve Build Rehberi](docs/TEAM_ENV_AND_BUILD_GUIDE.md)'ni kullanın.

## Lisans

[MIT](LICENSE)
