# FişKon Ürün Gereksinimleri Dokümanı (PRD)

**Sürüm:** 1.0
**Tarih:** 13 Ağustos 2026
**Durum:** Aktif geliştirme
**Platformlar:** Flutter (Android/iOS), FastAPI, PostgreSQL, Redis, Isar
**Canlı ortam:** Hetzner üzerinde Docker Compose

## 1. Ürün Özeti

FişKon; kullanıcıların fişlerini kamera veya galeriden taramasını, OCR ve yapay zekâ ile işlem bilgilerine dönüştürmesini, gelir-giderlerini çevrimdışı çalışabilen bir mobil uygulamada takip etmesini ve ortak harcamaları grup üyeleriyle bölüştürmesini sağlayan kişisel finans uygulamasıdır.

Ürün iki birbirini tamamlayan çalışma alanına sahiptir:

1. **Kişisel Finans:** Gelir-gider kaydı, fiş tarama, bütçe ve istatistik takibi.
2. **Gruplarım:** Ortak masraf oluşturma, fiş ürünlerini kişilere atama, hızlı bölüştürme, borç sadeleştirme ve ödeme kaydı.

Grup özellikleri Drawer içindeki **Gruplarım** alanında ayrı bir deneyim olarak sunulmalı; kişisel finans akışıyla veri veya navigasyon açısından karışmamalıdır.

## 2. Problem Tanımı

Kullanıcılar fiş verilerini elle girmekte, ortak harcamaları ayrı uygulamalarda hesaplamakta ve kimin kime ne kadar borçlu olduğunu takip etmekte zorlanmaktadır. FişKon aşağıdaki sorunları tek akışta çözmeyi hedefler:

- Fiş üzerindeki kurum, tarih, toplam ve ürünlerin otomatik okunması.
- OCR sonucunun kullanıcı tarafından doğrulanıp düzeltilebilmesi.
- Kişisel finans kayıtlarının internet olmadan da kullanılabilmesi.
- Fiş ürünlerinin grup üyelerine tek tek atanabilmesi.
- Ürün bilgisi olmayan harcamaların eşit, yüzdelik veya tutar bazlı bölünebilmesi.
- Karmaşık grup borçlarının az sayıda transfer önerisine indirgenmesi.
- Kayıtlı kullanıcı verilerinin cihazlar arasında güvenli şekilde senkronize edilmesi.

## 3. Ürün Hedefleri

- Bir fişi çekimden onaylanmış işleme mümkün olduğunca az kullanıcı müdahalesiyle dönüştürmek.
- Kişisel harcama kaydını ve grup paylaşımını birbirinden bağımsız, anlaşılır akışlar olarak sunmak.
- Tüm parasal hesapları kuruş cinsinden tamsayılarla güvenli ve deterministik yapmak.
- Misafir kullanımını korurken kayıtlı kullanıcılara bulut yedekleme ve çoklu cihaz desteği sunmak.
- Grup masraflarında yetkisiz erişimi önlemek ve her kullanıcıya yalnızca üyesi olduğu grupları göstermek.
- Backend servislerini sınırlı sunucu kaynağında güvenli ve gözlemlenebilir biçimde işletmek.

## 4. Kapsam Dışı

İlk production sürümünde aşağıdakiler zorunlu değildir:

- Banka hesabından otomatik işlem çekme.
- Gerçek para transferi veya ödeme kuruluşu entegrasyonu.
- Kredi/yatırım tavsiyesi üretme.
- Çoklu para birimi arasında otomatik kur dönüşümü.
- Web için tam özellikli finans yönetim paneli.
- Grup sohbeti veya sosyal medya özellikleri.

## 5. Hedef Kullanıcılar

### 5.1 Bireysel kullanıcı

Fişlerini hızlıca kaydetmek, harcamalarını kategori ve dönem bazında izlemek isteyen kullanıcı.

### 5.2 Ev arkadaşı veya çift

Market, kira, fatura ve abonelik masraflarını iki veya daha fazla kişi arasında paylaşan kullanıcılar.

### 5.3 Öğrenci veya arkadaş grubu

Gezi, yemek ve ortak alışveriş gibi masrafları ürün veya toplam tutar üzerinden bölüştüren kullanıcılar.

## 6. Başarı Ölçütleri

- Geçerli bir fişin taramadan onay ekranına başarıyla ulaşma oranı: **≥ %90**.
- OCR sonucu boş veya kullanılamaz olduğunda kırmızı Flutter hata ekranı görülme oranı: **%0**.
- Kişisel işlem kaydı başarı oranı: **≥ %99**.
- Grup masrafında pay toplamının ana tutara eşit olduğu kayıt oranı: **%100**.
- Aynı idempotency anahtarıyla çift kayıt oluşma oranı: **%0**.
- Yetkisiz grup verisi erişimi: **%0**.
- Kritik backend endpointleri için p95 yanıt süresi (AI işlemleri hariç): **< 500 ms**.
- Crash-free session oranı: **≥ %99,5**.

## 7. Mevcut Ürün Durumu

### 7.1 Tamamlanan veya büyük ölçüde tamamlanan özellikler

- E-posta/şifre ile kayıt ve giriş.
- E-posta doğrulama ve parola sıfırlama akışları.
- Google ile giriş; Apple Sign-In backend altyapısı ve revoke mekanizması.
- JWT access token, opaque refresh token, rotation ve reuse detection.
- Argon2id parola hashleme ve SHA-256 token saklama.
- Redis tabanlı auth, OCR ve AI asistan rate limitleri.
- Misafir kullanım ve güvenli token depolama.
- Kamera ve galeriden fiş seçimi.
- Yerel OCR, görsel doğrulama/optimizasyon ve güvenli sunucu analizi.
- OCR hata sınıflandırması, retry, iptal ve manuel devam seçenekleri.
- Fiş onay ekranı ve kişisel gelir-gider kaydı.
- Isar tabanlı yerel finans veritabanı ve offline görev altyapısı.
- JSON/CSV içe ve dışa aktarma.
- Dashboard, istatistik, arama, dark mode ve günlük hatırlatıcı.
- Finansal AI asistan arayüzü, kullanıcı onayı, özetlenmiş veri ve ayrı kota.
- PostgreSQL üzerinde grup, üyelik, grup masrafı, pay, ürün ataması ve settlement modelleri.
- Group CRUD, RBAC, Fast Split, Itemized Split ve Settlement backend endpointleri.
- Saf borç sadeleştirme algoritması ve borç özeti cache altyapısı.
- Flutter grup listesi, detay, Fast Split, Itemized Split ve borç özeti ekranları.
- Kişisel OCR’dan ayrı `/groups/:groupId/ocr` grup OCR ekranı.
- Alembic migration zinciri ve PostgreSQL CI regresyon testleri.

### 7.2 Tamamlanması gereken kritik entegrasyonlar

- Flutter grup provider’ları halen varsayılan olarak `FakeGroupRepository` kullanıyor.
- Grup ekranlarının gerçek `ApiGroupRepository` ve `ApiGroupExpenseRepository` ile production bağlantısı tamamlanmalı.
- Grup davet oluşturma/kabul endpointleri ve gerçek davet yaşam döngüsü tamamlanmalı.
- Grup OCR sonucu `GroupExpenseDraft` modeline dönüştürülmeli.
- Grup OCR sonrasında ürün durumuna göre Fast Split veya Itemized Split yönlendirmesi yapılmalı.
- Grup masrafı submit state’i ortak Riverpod controller üzerinden yönetilmeli.
- OCR → grup seçimi → split → API kaydı → yenilenmiş borç özeti uçtan uca doğrulanmalı.
- Kayıtlı kullanıcının Isar verileri ile PostgreSQL arasındaki claim/push/pull akışı gerçek cihazda tamamlanmalı.
- Production domain, HTTPS reverse proxy, yedekleme, izleme ve alarm altyapısı tamamlanmalı.

## 8. Temel Kullanıcı Akışları

### 8.1 Kişisel fiş kaydı

1. Kullanıcı **Gider Gir** ekranını açar.
2. Kamera, galeri veya manuel giriş seçer.
3. Görsel yerel OCR’dan geçirilir; gerekirse güvenli sunucu analizi kullanılır.
4. Kullanıcı kurum, tarih, tutar, kategori ve ürünleri kontrol eder.
5. İşlem Isar’a atomik olarak kaydedilir.
6. Kayıtlı kullanıcı için işlem senkronizasyon kuyruğuna alınır.
7. Dashboard ve istatistikler anında yenilenir.

### 8.2 Grup fişi paylaşımı

1. Kullanıcı `Drawer → Gruplarım → Grup Detayı` yolunu izler.
2. **Yeni Masraf Ekle → Fiş Tara** seçeneğini açar.
3. Ayrı grup OCR ekranında fişi tarar.
4. Kurum, tarih, toplam ve ürün sayısını doğrular.
5. **Grupla Paylaş** butonuna basar.
6. Anlamlı ürün varsa Itemized Split, yoksa Fast Split açılır.
7. Kullanıcı ödeyeni, katılımcıları ve payları belirler.
8. Masraf idempotency anahtarıyla backend’e kaydedilir.
9. Grup masraf listesi ve borç özeti yenilenir.

### 8.3 Hızlı bölüştürme

- **Eşit:** Kuruş farkları deterministik üye sırasıyla dağıtılır.
- **Yüzdelik:** Toplam `10000` basis point olmalıdır.
- **Tutar bazlı:** Payların toplamı masraf toplamına eşit olmalıdır.
- Bütün para değerleri `amount_in_minor: int` olarak işlenir.

### 8.4 Kalem bazlı bölüştürme

1. OCR’dan gelen anlamlı ürünler listelenir.
2. Her ürün bir veya daha fazla aktif üyeye atanır.
3. Miktar ve kuruş artıkları deterministik dağıtılır.
4. Atanmayan ürün varsa gönderim engellenir.
5. Vergi, bahşiş ve servis bedeli ayrı ek tutarlar olarak paylaştırılır.
6. Nihai pay toplamı fiş toplamıyla eşleşmeden kayıt yapılamaz.

### 8.5 Borç kapatma

1. Kullanıcı grup detayından **Borç Özeti** alanını açar.
2. Sistem sadeleştirilmiş transfer önerilerini gösterir.
3. Borçlu kullanıcı **Ödeme Yapıldı** aksiyonunu seçer.
4. Onay sonrası immutable settlement kaydı oluşturulur.
5. Aynı istek idempotency ile tekrar kaydedilemez.
6. Borç cache’i temizlenir ve güncel özet gösterilir.

## 9. Fonksiyonel Gereksinimler

### 9.1 Kimlik doğrulama

- Misafir kullanıcı kişisel yerel özellikleri kullanabilmelidir.
- Grup özellikleri yalnızca doğrulanmış ve giriş yapmış kullanıcıya açılmalıdır.
- Access token yalnızca RAM’de, refresh token secure storage içinde tutulmalıdır.
- Hesap silme; bulut verilerini, oturumları ve gerekli OAuth bağlantılarını kaldırmalıdır.
- Aynı e-posta için hesap varlığını açığa çıkaran zamanlama veya hata oracle’ı oluşmamalıdır.

### 9.2 OCR ve fiş işleme

- JPG, JPEG ve PNG desteklenmelidir.
- Dosya boyutu, piksel sayısı ve gerçek byte formatı doğrulanmalıdır.
- OCR metni uzunluk ve prompt-injection filtresinden geçmelidir.
- Teknik exception metinleri kullanıcıya doğrudan gösterilmemelidir.
- Kamera ile üretilen geçici görseller ve metadata güvenli şekilde temizlenmelidir.
- Kullanıcının elle düzelttiği alanlar ikinci analiz sonucuyla izinsiz ezilmemelidir.

### 9.3 Kişisel finans

- Gelir ve giderler owner scope ile izole edilmelidir.
- Dashboard, işlemler ve istatistik ekranları aynı repository kaynağını kullanmalıdır.
- Dinamik kategoriler korunmalı ve Türkçe karakter normalizasyonuyla aranabilmelidir.
- Tüm finansal hesaplamalar minor-unit tamsayılarla yapılmalıdır.

### 9.4 Grup ve üyelik

- Kullanıcı yalnızca aktif üyesi olduğu grupları görebilmelidir.
- Roller `owner`, `admin`, `member` olarak uygulanmalıdır.
- Son owner’ın gruptan ayrılması engellenmeli veya atomik owner devri yapılmalıdır.
- Production üyelik ekleme akışı e-posta/token tabanlı davet sistemi kullanmalıdır.
- Ayrılmış üyeler gerektiğinde mevcut kayıt üzerinden yeniden etkinleştirilmelidir.
- Grup silme işlemi varsayılan olarak soft archive olmalıdır.

### 9.5 Grup masrafları

- Split türleri `equal`, `percentage`, `fixed_amount`, `itemized` olmalıdır.
- Payların toplamı masraf toplamına eşit olmalıdır.
- Aynı masraf ve kullanıcı için yinelenen pay engellenmelidir.
- Harcama geçmişi kullanıcı hesabı silinse de finansal denetim amacıyla korunmalıdır.
- Create endpointleri idempotent ve eşzamanlı isteklere dayanıklı olmalıdır.

### 9.6 Borç özeti ve settlement

- Net bakiyeler gerçek grup masrafları ve settlement kayıtlarından üretilmelidir.
- Algoritma aynı input için deterministik çıktı vermelidir.
- Settlement kayıtları değiştirilemez olmalıdır.
- Kullanıcı kendisine ödeme kaydedememelidir.
- Yalnızca aktif grup üyeleri ödeme kaydedebilmelidir.
- Başarılı masraf veya settlement sonrasında Redis borç cache’i temizlenmelidir.

### 9.7 Offline ve senkronizasyon

- Her yerel kaydın cihazlar arası benzersiz `clientRecordId` değeri olmalıdır.
- Sahiplik `guest:<installation-id>` veya `user:<user-id>` şeklinde ayrılmalıdır.
- Claim, push ve pull işlemleri idempotent olmalıdır.
- Aynı kullanıcının iki cihazdaki verileri birbirini eski veriyle ezmemelidir.
- Failed/conflict görevleri kullanıcı tarafından tekrar denenebilmelidir.
- Misafir verisi açık kullanıcı onayı olmadan buluta gönderilmemelidir.

## 10. Teknik Mimari

```text
Flutter / Riverpod
  ├─ Auth ve güvenli token yönetimi
  ├─ Kişisel finans UI + Isar
  ├─ OCR / kamera / galeri
  ├─ Gruplarım UI
  └─ Offline sync coordinator
             │ HTTPS / JSON / Multipart
FastAPI
  ├─ Auth ve OAuth
  ├─ Receipt/OCR
  ├─ Sync
  ├─ Groups / Expenses / Settlements
  └─ AI Assistant
       ├─ PostgreSQL: kalıcı bulut verisi
       ├─ Redis: rate limit ve cache
       └─ Gemini: OCR ayrıştırma ve AI asistan
```

### 10.1 Veri kuralları

- Kimlikler UUID olmalıdır.
- Zamanlar UTC ve timezone-aware saklanmalıdır.
- Para değerleri kuruş cinsinden `int` olmalıdır.
- Yüzdeler basis point, miktarlar milli-unit cinsinden `int` olmalıdır.
- PostgreSQL cloud verisinin, Isar ise yerel/offline verinin kaynağıdır.
- Migration’lar yalnızca Alembic üzerinden uygulanmalıdır.

## 11. Güvenlik ve Gizlilik Gereksinimleri

- Production yalnızca HTTPS üzerinden erişilebilir olmalıdır.
- CORS yalnızca izin verilen production origin’leriyle sınırlandırılmalıdır.
- Proxy IP header’ları yalnızca güvenilen reverse proxy’den kabul edilmelidir.
- Auth, OCR ve AI endpointleri Redis tabanlı ayrı kotalara sahip olmalıdır.
- Redis kullanılamadığında maliyetli production endpointleri korumasız devam etmemelidir.
- Parola ve tokenlar loglanmamalıdır.
- E-posta adresleri normal log ve traceback çıktılarında maskelenmelidir.
- Her backend isteğinde request ID ve işlem süresi bulunmalıdır.
- Fiş görselleri kalıcı saklanmamalı; gerekli geçici dosyalar `finally` ile temizlenmelidir.
- EXIF/GPS metadata sunucuya veya kalıcı depoya taşınmamalıdır.
- Grup endpointlerinde membership/RBAC kontrolü zorunlu olmalıdır.
- Repository’ye gerçek `.env`, API anahtarı, SMTP şifresi veya private key commit edilmemelidir.

## 12. Performans ve Dayanıklılık

- API, PostgreSQL ve Redis healthcheck’leri bulunmalıdır.
- AI isteklerinde açık timeout, iptal ve retry politikası kullanılmalıdır.
- Retry yalnızca güvenli/idempotent isteklerde yapılmalıdır.
- Uzun listelerde sayfalama veya cursor kullanılmalıdır.
- Borç özeti `(group_id, updated_at)` veya eşdeğer sürümle cache’lenmelidir.
- Migration işlemi deploy sırasında tek instance tarafından çalıştırılmalıdır.
- PostgreSQL günlük otomatik yedeklenmeli ve geri yükleme tatbikatı yapılmalıdır.

## 13. Gözlemlenebilirlik

- Structured loglarda request ID, endpoint, status, duration ve model bilgisi yer almalıdır.
- Token, parola, OCR ham metni ve kişisel e-posta loglanmamalıdır.
- Aşağıdaki olaylar alarm üretmelidir:
  - API healthcheck başarısızlığı
  - PostgreSQL/Redis bağlantı hatası
  - Artan HTTP 5xx oranı
  - OCR/AI provider hata oranı
  - Rate limit ve reuse-detection güvenlik olayları
  - Migration veya backup başarısızlığı

## 14. Öncelikli Yol Haritası

### P0 — Grup özelliğini gerçek uçtan uca çalıştırma

- [ ] Flutter grup provider’larını build/environment seçimine göre gerçek API repository’sine bağla.
- [ ] Production grup daveti oluşturma, kabul ve iptal endpointlerini tamamla.
- [ ] Davet UI’sini gerçek API’ye bağla.
- [ ] Grup OCR sonucundan immutable `GroupExpenseDraft` üret.
- [ ] Anlamlı ürün varsa Itemized, yoksa Fast Split yönlendirmesi yap.
- [ ] `GroupExpenseState` ve Riverpod submit controller oluştur.
- [ ] 401/403/409/422/429 hata kodlarını kullanıcı dostu biçimde göster.
- [ ] OCR → split → kaydet → masraf listesi → borç özeti zincirini gerçek API ile test et.
- [ ] Settlement UI’yi gerçek API’ye bağla ve yenilemeyi doğrula.

### P0 — Production sertleştirme

- [ ] Domain ve TLS sertifikalı reverse proxy kur.
- [ ] Production CORS ve trusted proxy ayarlarını kesinleştir.
- [ ] Hetzner firewall’da yalnızca gerekli portları aç.
- [ ] PostgreSQL/Redis portlarını internete kapat.
- [ ] Otomatik backup, restore testi ve log rotation kur.
- [ ] Uptime ve hata alarmı ekle.
- [ ] Secret rotation prosedürü oluştur.

### P1 — Offline/cloud bütünlüğü

- [ ] Guest claim akışını gerçek cihazda ve kısmi hata senaryosunda doğrula.
- [ ] Çoklu cihaz conflict politikasını netleştir ve test et.
- [ ] Failed/conflict queue retry akışını tamamla.
- [ ] Kullanıcı değişiminde farklı owner scope verilerinin görünmediğini doğrula.
- [ ] Grup verileri için offline okuma/yazma kapsamına karar ver.

### P1 — Ürün kalitesi

- [ ] Gerçek düşük/yüksek kaliteli fişlerden anonimleştirilmiş test veri seti oluştur.
- [ ] OCR alan doğruluğunu merchant/date/total/items bazında ölç.
- [ ] Accessibility ve küçük ekran testlerini genişlet.
- [ ] iOS gerçek cihaz, Apple Sign-In ve hesap silme akışını doğrula.
- [ ] Kullanıcıya privacy policy, terms ve veri silme URL’si sun.

### P2 — Sonraki ürün geliştirmeleri

- [ ] Push notification ve grup daveti bildirimi.
- [ ] Grup masrafı düzenleme/iptal politikası.
- [ ] Çoklu para birimi desteği.
- [ ] Gelişmiş bütçe hedefleri ve anonim ürün fiyat trendleri.
- [ ] Yönetim/operasyon paneli.
- [ ] n8n üzerinden kontrollü bildirim ve operasyon otomasyonları.

## 15. Release Kabul Kriterleri

Production sürümü aşağıdaki koşullar sağlanmadan tamamlanmış sayılmaz:

- [ ] `flutter analyze` hatasız.
- [ ] Tüm Flutter ve paket testleri başarılı.
- [ ] `ruff check` hatasız.
- [ ] Tüm backend testleri başarılı.
- [ ] Zorunlu PostgreSQL migration CI testi başarılı.
- [ ] Temiz PostgreSQL üzerinde `alembic upgrade head` başarılı.
- [ ] Mevcut production snapshot’ı üzerinde migration ve veri koruma testi başarılı.
- [ ] Docker Compose healthcheck’leri başarılı.
- [ ] Kişisel OCR → kayıt akışı gerçek Android cihazda başarılı.
- [ ] Grup OCR → Fast Split akışı gerçek API ile başarılı.
- [ ] Grup OCR → Itemized Split akışı gerçek API ile başarılı.
- [ ] Settlement sonrası borç özeti doğru yenileniyor.
- [ ] Yetkisiz grup erişimi 403/404 ile engelleniyor.
- [ ] Aynı idempotency anahtarı çift kayıt oluşturmuyor.
- [ ] HTTPS, firewall, backup ve geri yükleme doğrulanmış.
- [ ] Repository ve container loglarında secret bulunmuyor.

## 16. Açık Kararlar

- Grup masraflarının offline oluşturulup oluşturulmayacağı.
- Grup masrafı düzenleme yerine append-only düzeltme kaydı kullanılıp kullanılmayacağı.
- Davetlerin e-posta, uygulama linki veya ikisini birlikte kullanma politikası.
- Çoklu para biriminin ilk production sürümüne dahil edilip edilmeyeceği.
- Fiş görsellerinin hiçbir zaman saklanmaması veya açık izinle kısa süreli saklanması.
- n8n’in yalnızca bildirim/operasyon için mi, yoksa ürün akışında da mı kullanılacağı.

## 17. İlgili Dokümanlar

- [Takım Ortam ve Build Rehberi](docs/TEAM_ENV_AND_BUILD_GUIDE.md)
- [Grup API Sözleşmesi](docs/group_api_contract.md)
- [Kimlik Doğrulama ve Senkronizasyon Planı](implementation_plan.md)
- [Proje README](README.md)
