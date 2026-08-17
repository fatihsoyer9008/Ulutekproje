# FişKon Takım Ortam ve Build Rehberi

Bu belge, yeni bir ekip üyesinin backend'i Docker ile çalıştırmasını ve Flutter
uygulamasını emülatör ya da fiziksel Android cihazda güvenli biçimde açmasını
anlatır.

## 1. Önemli ayrım: backend `.env` ve Flutter build ayarları

- `backend/.env` yalnızca FastAPI, PostgreSQL, Redis, SMTP, OAuth ve Gemini
  yapılandırması içindir.
- Flutter uygulaması `backend/.env` dosyasını okumaz.
- Flutter API adresini ve gerektiğinde Google Web Client ID'yi derleme anında
  `--dart-define` ile alır.
- `backend/.env` ve bütün gerçek parola/API anahtarları Git'e gönderilmez.
- `backend/.env.example` güvenli şablondur ve repoda kalır.

## 2. Mevcut `.env` inceleme sonucu

Yerel `backend/.env`, şablonun eski bir sürümünden kalmıştır:

- `SMTP_USERNAME` yerine güncel standart `SMTP_USER` kullanılmalıdır.
- `SMTP_START_TLS` yerine güncel standart `SMTP_TLS` kullanılmalıdır.
- Kod eski iki adı geçici olarak desteklemektedir; yeni ekip kurulumlarında eski
  adlar kullanılmamalıdır.
- Güncel `.env.example` içindeki Redis, rate limit, OAuth, Gemini, e-posta linki
  ve fiş görseli ayarları eski `.env` içinde eksik olabilir.

Mevcut çalışan `.env` dosyasının üstüne körlemesine yazmayın. Önce yedek alın,
güncel şablondan yeni dosya üretin ve yalnızca gerçek secret değerlerini taşıyın:

```powershell
cd C:\Ulutekproje\backend
Copy-Item .env .env.local-backup -Force
Copy-Item .env.example .env -Force
```

Ardından `.env.local-backup` içindeki gerçek değerleri yeni `.env` dosyasındaki
karşılıklarına elle aktarın. Yedek dosyayı da commit etmeyin.

## 3. Ekip üyelerinin değiştirmesi gereken backend değerleri

### Her yerel kurulumda kontrol edilecekler

| Değişken | Ne yapılmalı? |
|---|---|
| `APP_ENV` | Yerelde `development`, sunucuda `production` olmalı. |
| `DATABASE_URL` | Docker dışından backend açılıyorsa `127.0.0.1`; API de Docker içindeyse Compose bunu `postgres` hostuna çevirir. |
| `REDIS_URL` | Docker dışından backend açılıyorsa `127.0.0.1`; Compose API için bunu `redis` hostuna çevirir. |
| `JWT_SECRET` | En az 32 bayt, rastgele ve ekip ortamına özel olmalı. Production değeri paylaşılmamalı. |
| `SECURITY_HMAC_SECRET` | JWT secret'tan farklı, rastgele bir değer olmalı. |
| `RATE_LIMIT_ENABLED` | Normal geliştirme ve production için `true` bırakılmalı. |
| `TRUST_PROXY_HEADERS` | Yerelde `false`; Hetzner reverse proxy ayarları tamamlandığında production'da `true`. |

Güvenli secret üretme örneği:

```powershell
[Convert]::ToHexString([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

### Gerçek e-posta doğrulaması için

```dotenv
EMAIL_DELIVERY_MODE=smtp
EMAIL_FROM=ekip-hesabi@example.com
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=ekip-hesabi@example.com
SMTP_PASSWORD=uygulama-sifresi
SMTP_TLS=true
SMTP_TIMEOUT_SECONDS=15
EMAIL_ACTION_BASE_URL=https://erisilebilir-backend-adresi/api/v1/auth
```

- Gmail'de normal hesap şifresi değil, iki aşamalı doğrulama sonrası üretilen
  uygulama şifresi kullanılmalıdır.
- `EMAIL_ACTION_BASE_URL`, telefondan ve e-posta uygulamasından açılabilen HTTPS
  adres olmalıdır. `127.0.0.1` başka bir cihazdan çalışmaz.
- Cloudflare Quick Tunnel her yeniden açıldığında adres değişir. Bu değer
  güncellenip API container'ı yeniden build/restart edilmelidir.

### Google giriş için

```dotenv
GOOGLE_OAUTH_CLIENT_IDS=WEB_CLIENT_ID.apps.googleusercontent.com
```

- Buraya Android Client ID değil, Google Web OAuth Client ID yazılır.
- Değer Flutter'daki `GOOGLE_SERVER_CLIENT_ID` ile aynı olmalıdır.
- `android/app/google-services.json` içindeki Web client da aynı Firebase/Google
  Cloud projesine ait olmalıdır.
- Takım üyelerinin debug SHA-1 ve SHA-256 parmak izleri Firebase Android app
  ayarlarına eklenmelidir. Sonrasında güncel `google-services.json` indirilir.
- OAuth client secret Flutter'a veya repoya konulmaz.

### Gerçek Gemini ayrıştırması için

```dotenv
GEMINI_API_KEY=gercek-anahtar
GEMINI_MODEL=gemini-3.5-flash-lite
USE_DUMMY_PARSER=false
```

Dummy yanıtla UI geliştirmek için anahtar gerekmez:

```dotenv
GEMINI_API_KEY=
USE_DUMMY_PARSER=true
```

Fiş taramasında sürekli `Örnek Süpermarket` dönüyorsa ilk kontrol edilmesi gereken
değer `USE_DUMMY_PARSER` değeridir.

### Şimdilik değiştirilmemesi gerekenler

- `APPLE_*`: Apple Developer hesabı ve gerçek iOS kimlikleri hazırlanana kadar
  örnek/boş kalabilir.
- Receipt limit ve görsel boyutu değerleri, görev gerektirmedikçe ekip üyeleri
  tarafından rastgele değiştirilmemelidir.
- Yerelde `TRUST_PROXY_HEADERS=false` kalmalıdır.

## 4. Gereksinimler

- Git
- Docker Desktop
- Flutter stable `3.44.x` ve Dart `3.12.2` ile uyumlu SDK
- Android Studio/Android SDK
- Java 17 uyumlu JDK (Android Gradle hedefi Java 17'dir)
- Backend'i Docker dışında çalıştıracaklar için Python 3.12

Kontrol:

```powershell
git --version
flutter --version
flutter doctor -v
java -version
docker --version
docker compose version
```

Not: Backend Docker image'ı Python 3.12 kullanır. Bilgisayardaki farklı Python
sürümü Docker ile çalıştırmayı etkilemez.

## 5. İlk kurulum

```powershell
git clone https://github.com/fatihsoyer9008/Ulutekproje.git
cd C:\Ulutekproje
git checkout main
git pull --ff-only origin main

cd backend
Copy-Item .env.example .env
```

`backend/.env` dosyasını yukarıdaki kurallara göre doldurun. Daha sonra:

```powershell
cd C:\Ulutekproje
docker compose up -d --build
docker compose ps
```

Kontrol adresleri:

- `http://127.0.0.1:8000/health`
- `http://127.0.0.1:8000/docs`

Log kontrolü:

```powershell
docker compose logs --tail 100 api
```

Migration kontrolü:

```powershell
docker compose exec api alembic current
docker compose exec api alembic upgrade head
```

## 6. Flutter bağımlılıkları ve cihaz kontrolü

```powershell
cd C:\Ulutekproje\fis_uygulamasi
flutter clean
flutter pub get
flutter devices
```

`flutter clean` her çalıştırmada gerekli değildir. Yalnızca Gradle/plugin/cache
sorunlarında kullanın. Normal günlük akışta `flutter pub get` yeterlidir.

## 7. Çalıştırma seçenekleri

### Android emülatör + yerel Docker backend

Android emülatörü host bilgisayara `10.0.2.2` üzerinden ulaşır. Uygulamanın
varsayılan adresi zaten budur:

```powershell
flutter run
```

### Fiziksel telefon + aynı Wi-Fi

Bilgisayarın IPv4 adresini bulun:

```powershell
ipconfig
```

Uvicorn Docker üzerinden `8000` portunda yayınlanıyorsa:

```powershell
flutter run `
  --dart-define=API_BASE_URL=http://192.168.1.50:8000 `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=WEB_CLIENT_ID.apps.googleusercontent.com
```

`192.168.1.50` örnektir; kendi bilgisayarınızın IPv4 adresini kullanın. Windows
Firewall 8000 portuna izin vermeli ve iki cihaz aynı ağda olmalıdır.

### Fiziksel telefon + HTTPS tünel

Backend çalışırken ayrı terminalde:

```powershell
cloudflared tunnel --url http://127.0.0.1:8000
```

Üretilen HTTPS adresini kullanın:

```powershell
flutter run `
  --dart-define=API_BASE_URL=https://ornek.trycloudflare.com `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=WEB_CLIENT_ID.apps.googleusercontent.com
```

`GOOGLE_SERVER_CLIENT_ID` alanına API URL'si yazılmaz. Bu alan yalnızca
`...apps.googleusercontent.com` biçimindeki Web Client ID'dir.

### Production/Hetzner backend

```powershell
flutter run `
  --dart-define=API_BASE_URL=https://api.fiskon.example `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=WEB_CLIENT_ID.apps.googleusercontent.com
```

## 8. Test ve kalite kontrolü

Flutter:

```powershell
cd C:\Ulutekproje\fis_uygulamasi
flutter analyze
flutter test
```

Finance database:

```powershell
cd C:\Ulutekproje\finance_database
flutter test
```

Backend:

```powershell
cd C:\Ulutekproje\backend
py -3.12 -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt -r requirements-dev.txt
pytest -q -p no:cacheprovider
ruff check .
```

Production API image'ı test bağımlılıklarını ve `tests/` klasörünü içermez; bu
nedenle `pytest` ve Ruff kontrolleri varsayılan API container'ında değil, yerel
Python 3.12 sanal ortamında veya CI üzerinde çalıştırılır.

## 9. APK build

Test amaçlı release APK:

```powershell
cd C:\Ulutekproje\fis_uygulamasi
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api.fiskon.example `
  --dart-define=GOOGLE_SERVER_CLIENT_ID=WEB_CLIENT_ID.apps.googleusercontent.com
```

Çıktı:

```text
fis_uygulamasi/build/app/outputs/flutter-apk/app-release.apk
```

Mevcut Android yapılandırması release build'i debug anahtarıyla imzalamaktadır.
Bu APK yalnızca ekip testi içindir. Google Play yayını öncesinde:

- `applicationId` değeri `com.example...` yerine gerçek paket adına çevrilmeli,
- production keystore oluşturulmalı,
- release signing yapılandırılmalı,
- version/build number artırılmalı,
- production HTTPS API adresi kullanılmalıdır.

## 10. Günlük ekip çalışma akışı

```powershell
cd C:\Ulutekproje
git checkout main
git pull --ff-only origin main
git checkout -b feature/gorev-adi

cd fis_uygulamasi
flutter pub get
flutter run --dart-define=API_BASE_URL=<ekibin-aktif-api-adresi>
```

Kişisel `.env`, SMTP şifresi, Gemini anahtarı, production secret, keystore ve
yerel build klasörleri hiçbir PR'a eklenmemelidir.

## 11. Hızlı hata tablosu

| Hata | İlk kontrol |
|---|---|
| `Fiş servisine bağlanılamadı` | API URL, `/health`, Docker API durumu ve tünel açık mı? |
| `Örnek Süpermarket` dönüyor | `USE_DUMMY_PARSER=true` kalmış olabilir. |
| Google giriş `canceled` | Web Client ID eşleşmesi, SHA-1/SHA-256 ve güncel `google-services.json`. |
| Doğrulama e-postası gelmiyor | SMTP değerleri, uygulama şifresi ve API logları. |
| E-posta linki açılmıyor | `EMAIL_ACTION_BASE_URL` localhost veya eski tünel olabilir. |
| `429 Too Many Requests` | Redis/rate-limit kotası ve `Retry-After`; sürekli tekrar denemeyin. |
| `502 Bad Gateway` | Tünel açık fakat API kapalı veya yanlış porta bağlı olabilir. |
| Port 8000 kullanımda | Yeni API açmadan önce `docker compose ps` ve `netstat -ano | findstr :8000`. |
