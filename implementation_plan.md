# Kimlik Doğrulama ve Bulut Senkronizasyonu Uygulama Planı

> Durum: Yalnızca mimari plan. Bu belge onaylanmadan auth veya senkronizasyon kodu uygulanmayacaktır.
>
> Hazırlanma tarihi: 29 Temmuz 2026

## 1. Mevcut Kod Tabanı Özeti

### Flutter

- Uygulama `MaterialApp(home: ...)` ile doğrudan `FinanceHome` ekranında açılıyor; merkezi router ve auth state bulunmuyor.
- Fiş servisi `ReceiptParserClient` içinde doğrudan `http.Client` ile çağrılıyor.
- API adresi `RECEIPT_API_BASE_URL` dart-define değeriyle alınıyor.
- Access/refresh token yönetimi, güvenli depolama ve yetkili HTTP istemcisi bulunmuyor.
- Finans kayıtları `finance_database` paketindeki Isar veritabanında saklanıyor.
- Uygulama yerel-first çalışıyor; mevcut fiş tarama, manuel kayıt ve Dashboard stream akışları korunmalı.

### FastAPI

- `/health` ve `/api/v1/parse-receipt` endpoint'leri mevcut.
- ORM, PostgreSQL bağlantısı, Alembic, Redis veya auth modülü bulunmuyor.
- Uygulama şu anda tek bir `app/main.py` içinde kuruluyor; router ve dependency katmanlarına ayrılması gerekiyor.
- Gemini anahtarı `.env` üzerinden okunuyor ve fiş ayrıştırma testleri mevcut.

### Isar

- Tek koleksiyon `TransactionEntity`; kayıtların sahibi veya senkronizasyon durumu bulunmuyor.
- Sayısal Isar `id` cihazlar arasında benzersiz olmadığı için cloud claim işleminde doğrudan kullanılamaz.
- Mevcut kayıtlar anonim/misafir veri kabul edilerek kayıpsız bir şema geçişi yapılmalı.

## 2. Hedef Mimari

```text
Flutter
  ├─ Auth UI + AuthController
  ├─ Access token (yalnızca RAM)
  ├─ Refresh token (flutter_secure_storage)
  ├─ Yetkili API istemcisi / tekil refresh kuyruğu
  ├─ Isar (misafir veya kullanıcı kapsamlı yerel veri)
  └─ Claim/Sync Coordinator
           │ HTTPS
FastAPI
  ├─ Auth Router
  ├─ Receipt Router
  ├─ Sync Router
  ├─ PostgreSQL / SQLAlchemy / Alembic
  ├─ Redis rate limit ve geçici güvenlik state'i
  ├─ E-posta sağlayıcısı
  └─ Google ve Apple OIDC doğrulama servisleri
```

### Temel kararlar

1. **Misafir kullanımı korunacak.** Kullanıcı giriş yapmadan mevcut Isar tabanlı özellikleri kullanabilir.
2. **Misafir finans verisi backend'e gönderilmeyecek.** İlk başarılı ve doğrulanmış girişten sonra açık kullanıcı onayıyla claim edilir.
3. **PostgreSQL bulut verisinin kaynağıdır; Isar çevrimdışı cache ve yerel çalışma deposudur.**
4. **Access token kısa ömürlü JWT, refresh token ise rastgele opaque token olacaktır.** Refresh token JWT olmayacaktır.
5. **OAuth sağlayıcı token'ları Flutter'da kalıcı tutulmayacaktır.** Google/Apple kanıtı backend'e iletilir ve uygulamanın kendi oturumu oluşturulur.
6. **Mevcut receipt parser bağımlılık enjeksiyonuyla yeni yetkili istemciye taşınacak; OCR davranışı değişmeyecek.**

## 3. Önerilen Backend Dosya Yapısı

```text
backend/app/
  main.py
  api/
    dependencies.py
    routers/
      auth.py
      receipts.py
      sync.py
  core/
    config.py
    database.py
    redis.py
    security.py
    rate_limit.py
  models/
    user.py
    oauth_account.py
    refresh_session.py
    one_time_token.py
    cloud_transaction.py
  schemas/
    auth.py
    user.py
    sync.py
    receipt.py
  repositories/
    users.py
    sessions.py
    transactions.py
  services/
    auth_service.py
    email_service.py
    google_oauth.py
    apple_oauth.py
    session_service.py
    account_deletion.py
    sync_service.py
    receipt_parser.py
  templates/email/
alembic/
docker-compose.yml
```

## 4. PostgreSQL Veri Modeli

Tüm kimlikler UUID olmalı ve bütün zamanlar UTC saklanmalıdır.

### User

- `id: UUID` primary key
- `email: CITEXT` unique, normalize edilmiş
- `password_hash: str | null` — yalnızca e-posta/şifre hesabında Argon2id
- `display_name: str | null`
- `is_email_verified: bool`
- `status: active | suspended | deletion_pending`
- `auth_version: int` — tüm access token'ları gerektiğinde geçersizleştirmek için
- `last_login_at`, `created_at`, `updated_at`

### OAuthAccount

- `id: UUID`
- `user_id: UUID` ve `ON DELETE CASCADE`
- `provider: google | apple`
- `provider_subject: str`
- `provider_email: str | null`
- `provider_refresh_token_encrypted: bytes | null` — Apple revoke için uygulama seviyesinde şifreli
- `created_at`, `updated_at`
- Unique constraint: `(provider, provider_subject)`

Provider e-postasına bakarak otomatik ve sessiz hesap birleştirme yapılmamalıdır. Mevcut hesapla ilişkilendirme, doğrulanmış kullanıcı oturumu veya açık bir hesap bağlama akışı gerektirir.

### RefreshSession

- `id: UUID`
- `user_id: UUID`
- `family_id: UUID`
- `parent_session_id: UUID | null`
- `replaced_by_session_id: UUID | null`
- `token_hash: str` unique — yalnızca SHA-256 özeti
- `issued_at`, `expires_at`, `last_used_at`
- `revoked_at`, `reuse_detected_at`
- `device_id_hash`, `device_name`, `ip_hash`, `user_agent`

Rotation sırasında eski session revoke edilir ve yenisi aynı `family_id` ile oluşturulur. Daha önce kullanılmış bir token tekrar sunulursa aynı family içindeki bütün session'lar tek transaction içinde iptal edilir ve `auth_version` artırılır.

### OneTimeToken

E-posta doğrulama ve parola sıfırlama token'ları için ortak tablo:

- `id`, `user_id`, `purpose`
- `token_hash` — SHA-256
- `expires_at`, `consumed_at`, `created_at`
- Aynı amaçtaki önceki aktif token'lar yenisi üretildiğinde iptal edilir.

### CloudTransaction

Claim ve senkronizasyon için mevcut `TransactionEntity` alanlarının server karşılığı:

- `id: UUID`
- `user_id: UUID`, index ve foreign key
- `client_record_id: UUID`
- `installation_id_hash: str`
- `transaction_type`, `amount_in_minor`, `category`, `transaction_date`
- `merchant_name`, `source`, `raw_ocr_text`, `note`
- `client_created_at`, `client_updated_at`, `created_at`, `updated_at`
- `deleted_at: datetime | null` — senkronize silmeler için tombstone
- Unique constraint: `(user_id, client_record_id)`

## 5. Auth API Sözleşmesi

Tüm auth endpoint'leri `/api/v1/auth` altında yayınlanmalıdır. Hassas cevaplarda `Cache-Control: no-store` kullanılmalıdır.

### Zorunlu endpoint'ler

- `POST /auth/register`
  - E-posta ve şifreyi doğrular, Argon2id hash oluşturur, doğrulama e-postası gönderir.
  - Var/yok bilgisini açığa çıkarmayan genel cevap kullanır.
- `POST /auth/login`
  - Sabit/görece eşit maliyetli başarısızlık yolu, Redis tabanlı deneme sayacı ve generic hata.
  - Doğrulanmamış e-posta politikasına göre sınırlı session veya doğrulama gerektiren cevap.
- `POST /auth/google`
  - Flutter'dan gelen Google ID token'ı backend'de imza, `iss`, `aud`, `exp` ve nonce ile doğrular.
- `POST /auth/apple`
  - Identity token ve tek kullanımlık authorization code'u doğrular; Apple token endpoint'iyle code exchange yapar.
  - Apple refresh token'ı yalnızca backend'de şifreli saklar.
- `POST /auth/refresh`
  - Opaque refresh token rotation ve reuse detection uygular.
- `POST /auth/logout`
  - Mevcut refresh session'ı revoke eder; `all_devices=true` seçeneği ayrı ve açık olmalıdır.
- `GET /auth/me`
  - Aktif kullanıcı profilini döndürür.
- `DELETE /auth/me`
  - Yakın zamanda yeniden kimlik doğrulama ister.
  - Kullanıcıya ait cloud verisini, session'ları ve OAuth bağlantılarını siler.
  - Apple hesabında Apple token revoke işlemini gerçekleştirir.
- `POST /auth/verify-email`
  - Tek kullanımlık, hash saklanan ve süreli token'ı tüketir.
- `POST /auth/resend-verification`
  - E-posta varlığını açıklamayan `202` cevabı ve sıkı rate limit.
- `POST /auth/forgot-password`
  - Her durumda aynı genel `202` cevabı ve benzer cevap süresi.
- `POST /auth/reset-password`
  - Token'ı tek kullanımlık tüketir, yeni Argon2id hash kaydeder, `auth_version` artırır ve bütün refresh session'ları iptal eder.

### Claim/senkronizasyon endpoint'leri

İstenen anonim veri aktarımı auth endpoint'leriyle tek başına yapılamaz; aşağıdaki korumalı API gereklidir:

- `POST /api/v1/sync/claim`
  - `Idempotency-Key` ve sınırlı batch kabul eder.
  - Her kayıt için `client_record_id` üzerinden `accepted`, `duplicate` veya `rejected` sonucu döndürür.
- `POST /api/v1/sync/push`
  - Sonraki çevrimdışı değişiklikleri idempotent gönderir.
- `GET /api/v1/sync/pull?cursor=...`
  - Kullanıcının başka cihazdaki değişikliklerini cursor ile döndürür.

## 6. Token ve Oturum Güvenliği

- Parola hash: Argon2id; parametreler başlangıçta ölçülerek sunucuda yaklaşık 100–250 ms hedeflenir ve hash içinde versionlanır.
- Access token: imzalı JWT, 10–15 dakika; `iss`, `aud`, `sub`, `exp`, `iat`, `jti`, `sid`, `auth_version` claim'leri zorunlu.
- Refresh token: CSPRNG ile en az 256 bit; mobil istemciye yalnızca bir kez plaintext verilir.
- Veritabanında refresh ve one-time token'ların sadece SHA-256 özeti bulunur.
- Refresh rotation işlemi SQL transaction ve satır kilidiyle atomik yapılır.
- Reuse tespitinde bütün token family iptal edilir; güvenlik olayı loglanır ancak token veya e-posta loglanmaz.
- OAuth ID token'ları yalnızca backend'de resmi doğrulama kurallarıyla kabul edilir; istemciden gelen provider user ID'sine güvenilmez.
- Apple client secret sunucuda kısa ömürlü üretilir; private key secret manager/env üzerinden sağlanır.
- Apple revoke geçici olarak başarısız olursa hesap hemen erişilemez yapılır ve şifreli token güvenli deletion outbox ile tekrar denenir.

## 7. Redis Rate Limiting ve Brute-Force Koruması

- Redis sayaçları atomik Lua script veya güvenilir rate-limit kütüphanesiyle uygulanmalı.
- Limit anahtarlarında düz e-posta/IP yerine HMAC özeti kullanılmalı.
- Endpoint bazlı IP, e-posta ve birleşik limitler ayarlardan yönetilmeli.
- Login başarısızlıklarında artan gecikme; kalıcı hesap kilidi yerine kısa süreli Redis kilidi kullanılmalı.
- Register, resend, forgot-password ve OAuth endpoint'leri daha sıkı limitlenmeli.
- `X-Forwarded-For` yalnızca güvenilen proxy/DigitalOcean yapılandırmasında kabul edilmeli.
- Redis erişilemezse auth yazma endpoint'lerinde seçilen güvenli davranış dokümante edilmeli; üretimde korumasız devam edilmemeli.
- Receipt parser misafir kullanımına açık kalacağı için IP + installation kimliği bazlı ayrı kota uygulanmalı.

## 8. Flutter Mimarisi

### Önerilen bağımlılıklar

- `go_router`: deklaratif routing ve auth/guest yönlendirmesi
- `flutter_riverpod`: session ve uygulama başlangıç state'i
- `dio`: interceptor ve istek tekrar kontrolü
- `flutter_secure_storage`: refresh token
- `google_sign_in`: Google giriş
- `sign_in_with_apple`: Apple giriş
- `uuid`: installation ve client record kimlikleri

Sürümler uygulama aşamasında mevcut Flutter 3.44.7/3.44.8 uyumluluğuna göre kilitlenmelidir.

### Ekranlar ve route'lar

```text
/startup
/welcome
/login
/register
/forgot-password
/verify-email
/home
/profile
/settings
/account/delete
```

- İlk açılışta `StartupGate`, secure storage'daki refresh token ile sessiz yenileme yapar.
- Refresh yoksa kullanıcı Welcome ekranından misafir devam edebilir.
- Auth ekranları uygulamanın geri kalanını zorunlu olarak kilitlemez.
- iOS'ta Google giriş gösteriliyorsa eşdeğer Apple giriş butonu da gösterilir.
- Profil ekranında e-posta doğrulama durumu, çıkış ve hesap silme bulunur.

### Token saklama

- Access token yalnızca `AuthSessionController` belleğinde tutulur.
- Refresh token yalnızca `flutter_secure_storage` içinde tutulur.
- `KeyStoreException`, bozuk/erişilemeyen secure storage ve platform hataları yakalanır.
- Secure storage hatasında token başka bir düz depoya yazılmaz; güvenli biçimde temizlenir ve uygulama misafir moda döner.
- Log, analytics ve crash raporlarına token yazılmaz.

### HTTP interceptor

- Bütün korumalı isteklere `Authorization: Bearer <access>` eklenir.
- 401 sonrası yalnızca bir refresh isteği çalışır; diğer istekler aynı Future üzerinde bekler.
- Refresh endpoint'i interceptor refresh mantığından hariç tutulur.
- Her normal istek en fazla bir kez yeniden denenir.
- Refresh başarısızsa secure storage temizlenir, bekleyen istekler kontrollü hata alır ve kullanıcı misafir/login state'ine döner.
- `ReceiptParserClient`, enjekte edilen ortak API istemcisini kullanacak şekilde uyarlanır; mevcut response mapping ve testleri korunur.

## 9. Isar Sahiplik ve Anonim Claim Geçişi

`TransactionEntity` alanlarına aşağıdakiler eklenmelidir:

- `clientRecordId: String` — UUID, index/unique
- `ownerKey: String` — `guest:<installation-id>` veya `user:<user-id>`
- `syncState: localOnly | pending | synced | failed | pendingDelete`
- `serverId: String?`
- `lastSyncedAt: DateTime?`

### Mevcut kayıt migration'ı

1. Uygulama güncellemesinden sonra `clientRecordId` olmayan her mevcut kayda UUID atanır.
2. Kayıtlar aktif installation ID'ye ait guest kayıt olarak işaretlenir.
3. Bu işlem tekrar çalıştırılabilir/idempotent olmalıdır.
4. Repository sorguları aktif `ownerKey` ile filtrelenir; farklı kullanıcıların yerel verileri birbirine gösterilmez.

### İlk girişte claim

1. Giriş tamamlandıktan sonra uygulama yerel guest kayıt sayısını kullanıcıya gösterir ve aktarım için açık onay ister.
2. Kayıtlar küçük batch'ler halinde, `Idempotency-Key` ve `clientRecordId` ile gönderilir.
3. Backend unique constraint sayesinde aynı batch tekrar gönderilse de duplicate oluşmaz.
4. Yalnızca backend ACK verdikten sonra yerel kayıt `synced` olur ve owner kullanıcıya geçirilir.
5. Kısmi hata durumunda başarılı kayıtlar korunur, kalanlar tekrar kuyruğunda kalır.
6. Logout yerel kullanıcı verisini otomatik olarak silmez; ancak guest veya başka kullanıcı scope'unda göstermez.
7. Hesap silme ekranı hem cloud hesabının hem cihazdaki kullanıcı kapsamlı verinin ne olacağını açıkça sorar.

## 10. E-posta Akışları

- E-posta sağlayıcısı bir interface arkasına alınmalı; testte fake provider kullanılmalı.
- Verification ve reset linkleri universal/app link ile uygulamayı açmalı; ayrıca web fallback sayfası bulunmalı.
- Token'lar URL'de kısa ömürlü, tek kullanımlık ve DB'de hash olarak saklanmalı.
- E-posta gönderim hatası register transaction'ını belirsiz bırakmamalı; outbox/retry yaklaşımı kullanılmalı.
- Uygulama mağazası production yayınından önce gönderici domain için SPF, DKIM ve DMARC kurulmalı.

## 11. Hesap Silme ve Mağaza Politikaları

- Uygulama içinde Profil/Ayarlar → Hesabı Sil yolu bulunmalı.
- Hassas silme öncesinde yeniden parola veya provider re-auth istenmeli.
- Kullanıcının cloud transaction verileri, OAuth bağlantıları, session'ları ve kişisel verileri silinmeli.
- Apple kullanıcısında Apple refresh/access token, Apple revoke endpoint'i üzerinden iptal edilmelidir.
- Google Play için uygulama dışından da erişilebilen işlevsel hesap silme talep URL'si hazırlanmalıdır.
- App Store privacy manifest/labels ve Google Play Data Safety formu gerçek veri akışına göre güncellenmelidir.

Resmi referanslar:

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Apple account deletion ve token revoke rehberi](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)
- [Google Play hesap silme gereksinimleri](https://support.google.com/googleplay/android-developer/answer/13327111)
- [Google ID token backend doğrulaması](https://developers.google.com/identity/sign-in/android/backend-auth)

## 12. Docker, Migration ve Dağıtım

### Docker Compose servisleri

- `api`: FastAPI
- `postgres`: kalıcı volume, healthcheck ve ayrı uygulama kullanıcısı
- `redis`: authentication, kalıcı olmayan güvenlik cache'i ve healthcheck
- E-posta teslimatı geliştirme ve production ortamlarında gerçek SMTP sağlayıcısı
  üzerinden yapılır; yerel Mailpit servisi kullanılmaz.

### Alembic sırası

1. User, OAuthAccount, RefreshSession ve OneTimeToken tabloları
2. CloudTransaction ve unique/index constraint'leri
3. Gerekli PostgreSQL extension/CITEXT oluşturma

Deploy sırasında migration tek bir release/pre-deploy job olarak çalıştırılmalı; birden fazla API instance aynı anda migration çalıştırmamalıdır.

DigitalOcean yapılandırmasına `DATABASE_URL`, `REDIS_URL`, JWT key/issuer/audience, OAuth client değerleri, Apple key bilgileri, token encryption key ve e-posta provider secret'ları encrypted env olarak eklenmelidir.

## 13. Uygulama Fazları

### Faz 0 — Karar ve secret hazırlığı

- E-posta sağlayıcısı, production domain ve deep-link domain'i seçilir.
- Google Cloud OAuth client'ları ve Apple App ID/Service ID/Key hazırlanır.
- JWT imzalama ve OAuth token encryption key yönetimi belirlenir.

### Faz 1 — Backend temel altyapı

- SQLAlchemy async, PostgreSQL, Redis ve Alembic kurulur.
- App factory/router/dependency yapısı oluşturulur.
- Modeller ve ilk migration eklenir.
- Docker Compose hazırlanır.

### Faz 2 — E-posta/şifre ve session güvenliği

- Register/login/me/refresh/logout geliştirilir.
- Argon2id, opaque refresh token, rotation ve reuse detection tamamlanır.
- Rate limit ve brute-force korumaları eklenir.
- Verify/resend ve forgot/reset akışları tamamlanır.

### Faz 3 — Google ve Apple OAuth

- Backend provider doğrulaması ve güvenli account linking geliştirilir.
- Flutter native yapılandırmaları ve butonları eklenir.
- Apple token saklama/revoke ve provider credential revocation senaryoları uygulanır.

### Faz 4 — Flutter auth shell

- Router, startup gate, auth state ve ekranlar eklenir.
- Secure storage ve sessiz refresh uygulanır.
- Tekil refresh yapan API interceptor eklenir.
- Receipt parser ortak istemciye taşınarak regression test edilir.

### Faz 5 — Guest claim ve senkronizasyon

- Isar şeması sahiplik/sync alanlarıyla migrate edilir.
- Backend cloud transaction ve claim endpoint'leri eklenir.
- İzinli, batch ve idempotent claim akışı tamamlanır.
- Logout/login ve çoklu kullanıcı izolasyonu test edilir.

### Faz 6 — Hesap silme ve policy yüzeyleri

- Uygulama içi silme, re-auth ve Apple revoke tamamlanır.
- Web deletion request sayfası ve mağaza beyanları hazırlanır.

### Faz 7 — Sertleştirme ve yayın

- Entegrasyon, güvenlik, yük ve release testleri çalıştırılır.
- Secret rotation, backup/restore, monitoring ve alarm runbook'ları hazırlanır.
- Aşamalı rollout ve geri dönüş planı uygulanır.

## 14. Test Planı ve Teslim Kriterleri

### Backend testleri

- Model/repository ve Alembic upgrade/downgrade testleri
- Register/login doğrulama ve enumeration eşdeğer cevap testleri
- Argon2id hash/rehash testleri
- Refresh rotation, eş zamanlı refresh ve reuse family revoke testleri
- Redis IP/e-posta limit testleri
- Verification/reset token expiry ve tek kullanım testleri
- Google/Apple imza, audience, issuer, nonce ve expired token testleri
- Apple revoke başarı, timeout ve retry/outbox testleri
- Claim duplicate, kısmi hata, tekrar gönderim ve kullanıcı izolasyonu testleri
- Account deletion cascade ve veri kalmama testleri

### Flutter testleri

- Startup guest, valid refresh, expired refresh ve secure storage failure testleri
- Interceptor tekil refresh, bir kez retry ve sonsuz döngü engelleme testleri
- Register/login/verify/reset ekran testleri
- Google/Apple iptal, hata ve başarı testleri
- Guest verinin kullanıcı onayı olmadan upload edilmediği test
- Claim retry ve duplicate engelleme testleri
- Logout sonrası başka kullanıcının verisinin görünmediği test
- Mevcut OCR → onay → Isar akışının regression testleri

### Zorunlu teslim kontrolleri

- `flutter analyze` hatasız
- Bütün Flutter testleri başarılı
- `pytest` testleri başarılı
- Alembic temiz PostgreSQL üzerinde sıfırdan upgrade başarılı
- Docker Compose ile API/PostgreSQL/Redis healthcheck başarılı
- Refresh token plaintext olarak DB/log içinde bulunmuyor
- Access token kalıcı Flutter depolamasında bulunmuyor
- Auth olmadan misafir OCR ve yerel kayıt akışı çalışıyor
- Auth sonrası claim duplicate oluşturmuyor
- iOS Google + Apple giriş ve uygulama içi hesap silme akışı gerçek cihazda doğrulanmış

## 15. Uygulama Öncesi Onay Gerektiren Kararlar

Önerilen varsayılanlarla ilerlemek için aşağıdaki kararlar onaylanmalıdır:

1. PostgreSQL bulut verisi, Isar çevrimdışı cache olacak.
2. Guest kayıtları kullanıcı onayıyla ilk girişte cloud'a claim edilecek.
3. Flutter ağ katmanı `http` yerine Dio tabanlı ortak istemciye geçirilecek.
4. Routing/state için `go_router + Riverpod` kullanılacak.
5. Access JWT 15 dakika, refresh session 30 gün olacak.
6. E-posta doğrulanmadan cloud sync açılmayacak; misafir özellikler çalışmaya devam edecek.
7. E-posta sağlayıcısı ve production/deep-link domain'i uygulama başlamadan ekip tarafından sağlanacak.
