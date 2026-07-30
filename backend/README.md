# Receipt Parser API

Flutter uygulaması ile ilerideki fiş ayrıştırma servisi arasındaki FastAPI iskeleti.

## Yerelde çalıştırma

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Sunucu çalıştığında `http://127.0.0.1:8000/health` adresi `status: ok` döndürür.

## Fiş ayrıştırma

`POST /api/v1/parse-receipt` uç noktası cihaz içi OCR metnini alır:

```json
{
  "ocr_text": "MİGROS TOPLAM 220,50 TL"
}
```

Yerel frontend geliştirmesinde `.env` içindeki `USE_DUMMY_PARSER=true` bırakılabilir.
Gerçek Gemini ayrıştırmasını kullanmak için:

```dotenv
GEMINI_API_KEY=your-api-key
GEMINI_MODEL=gemini-3.5-flash-lite
USE_DUMMY_PARSER=false
```

API anahtarını içeren `.env` dosyası Git tarafından yok sayılır; bu dosyayı commit etmeyin.

## Prompt ve dayanıklılık testleri

Gemini sistem talimatı tek kaynaktan yönetilir:

```text
app/constants/ai_prompts.py
```

Prompt; eksik alanların `null` bırakılmasını, okunamayan veya fiş olmayan
girdilerde veri uydurulmamasını ve para tutarlarının kuruş cinsinden `int`
olarak dönmesini zorunlu tutar.

Başarılı, eksik, okunamayan OCR ve geçersiz sağlayıcı cevabı senaryoları gerçek
Gemini kotası tüketmeden mock istemciyle test edilir:

```powershell
.\.venv\Scripts\python.exe -m pytest tests -q -p no:cacheprovider
```

Telefonun aynı Wi-Fi ağından sunucuya erişmesi gerekiyorsa Uvicorn'u
`--host 0.0.0.0` ile başlatın ve Flutter tarafında bilgisayarın yerel IP adresini kullanın.

## DigitalOcean App Platform ile yayınlama ve Swagger testi

Proje kökündeki `.do/app.yaml`, DigitalOcean App Platform ayarlarını içerir.
DigitalOcean panelinde GitHub reposunu bağlayın ve App Spec olarak bu dosyayı
kullanın. `GEMINI_API_KEY` değerini yalnızca DigitalOcean panelindeki ortam
değişkenlerine **Encrypt** seçeneğiyle girin; GitHub'a eklemeyin.

İlk Flutter/Postman testi için `USE_DUMMY_PARSER=true` bırakılabilir. Gerçek
Gemini ayrıştırması için DigitalOcean ortam değişkenlerinde
`USE_DUMMY_PARSER=false` yapın ve geçerli bir `GEMINI_API_KEY` tanımlayın.

Deploy tamamlandıktan sonra aşağıdaki adresleri kullanın:

```text
https://<digitalocean-servis-adresi>/health
https://<digitalocean-servis-adresi>/docs
```

Swagger'da `POST /api/v1/parse-receipt` endpoint'ini açıp şu gövdeyle
**Try it out** ve **Execute** seçeneklerini kullanın:

```json
{
  "ocr_text": "MİGROS\nTOPLAM 220,50 TL"
}
```

## Testler

```powershell
pip install -r requirements-dev.txt
pytest
```

## Auth altyapısını yerelde çalıştırma

Kimlik doğrulama altyapısı PostgreSQL ve Redis kullanır. Proje kökünde:

```powershell
docker compose up -d postgres redis
cd backend
Copy-Item .env.example .env
.\.venv\Scripts\Activate.ps1
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Makinede `5432` veya `6379` zaten kullanılıyorsa Compose servislerini farklı
host portlarında başlatabilirsiniz:

```powershell
$env:POSTGRES_PORT = "55432"
$env:REDIS_PORT = "56379"
docker compose up -d postgres redis
```

Bu durumda `DATABASE_URL` ve `REDIS_URL` içindeki host portlarını da aynı
değerlere göre güncelleyin. Container içindeki servis portları değişmez.

Gerçek e-posta teslimatı için `backend/.env` dosyasında SMTP sağlayıcınızın
bilgilerini tanımlayın. Gmail kullanırken normal hesap şifresi yerine iki
aşamalı doğrulama sonrasında üretilen uygulama şifresini kullanın:

```dotenv
EMAIL_DELIVERY_MODE=smtp
EMAIL_FROM=adresiniz@gmail.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=adresiniz@gmail.com
SMTP_PASSWORD=gmail-uygulama-sifresi
SMTP_TLS=true
EMAIL_ACTION_BASE_URL=https://api.example.com/api/v1/auth
```

SendGrid için `SMTP_HOST=smtp.sendgrid.net`, `SMTP_USER=apikey` ve
`SMTP_PASSWORD=<SendGrid API key>` kullanılır. Auth uç noktaları Swagger'da
`/api/v1/auth` etiketi altında listelenir. `EMAIL_ACTION_BASE_URL`, telefondan
ve e-posta istemcisinden erişilebilen gerçek HTTPS backend adresi olmalıdır.
Cloudflare quick tunnel kullanılıyorsa tünel her yeniden açıldığında bu değer
yeni adresle güncellenmeli ve API container'ı yeniden başlatılmalıdır.

Geliştirme ortamındaki örnek JWT ve HMAC secret değerleri production için
geçerli değildir. `APP_ENV=production` kullanıldığında uygulama zayıf secret
ve kapalı e-posta teslimatıyla başlamayı reddeder.

Migration durumunu kontrol etmek için:

```powershell
alembic current
alembic upgrade head
```

## Google ve Apple OAuth

Mobil istemci düz kullanıcı kimliği göndermez. Google endpoint'i imzalı ID
token ile nonce, Apple endpoint'i ise identity token, tek kullanımlık
authorization code ve nonce kabul eder:

```text
POST /api/v1/auth/google
POST /api/v1/auth/apple
```

Google için `GOOGLE_OAUTH_CLIENT_IDS`; Apple için `APPLE_CLIENT_ID`,
`APPLE_TEAM_ID`, `APPLE_KEY_ID`, `APPLE_PRIVATE_KEY` ve
`APPLE_TOKEN_ENCRYPTION_KEY` tanımlanmalıdır. Apple refresh token'ları yalnızca
backend'de, Fernet ile şifrelenmiş olarak saklanır ve hesap silme sırasında
Apple revoke endpoint'inde iptal edilir.

Aynı e-postaya sahip mevcut bir hesap provider e-postasına güvenilerek sessizce
birleştirilmez. Böyle bir durumda kullanıcı önce mevcut hesabıyla giriş yapmalı
ve ilerideki açık account-linking akışını kullanmalıdır.
