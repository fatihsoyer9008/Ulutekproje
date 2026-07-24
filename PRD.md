# PRD — Yapay Zeka Destekli Kişisel Finans Asistanı
**Doküman Sahibi:** Takım Kaptanı & Mimari Ekibi
**Versiyon:** 1.0
**Tarih:** 22 Temmuz 2026
**Durum:** Geliştirmeye Hazır (Dev-Ready)
**Süre:** 30 iş günü | **Ekip:** 10 kişi (Squad bazlı)

---

## 1. Overview

Bu doküman, kullanıcıların manuel harcama girişi yapma zorunluluğunu ortadan kaldıran, cihaz üzerinde (on-device) çalışan OCR ve hibrit LLM (Gemini API) destekli bir kişisel finans asistanı mobil uygulamasının MVP (Minimum Uygulanabilir Ürün) aşamasını tanımlar. Uygulama Flutter ile geliştirilecek, tamamen **Local-First** ve **Privacy-First** prensipleriyle inşa edilecek; kullanıcı verisi hiçbir backend sunucuya gönderilmeyecektir.

Bu doküman; vizyon, kapsam, kullanıcı hikayeleri, teknik mimari, NFR'ler, ekip dağılımı ve başarı metriklerini içerir. Amaç, hem yönetim kademesine sunulabilecek kadar stratejik hem de mühendislik ekibinin doğrudan sprint planlamasına dökebileceği kadar teknik bir referans oluşturmaktır.

----

## 2. Problem Tanımı

Türkiye ve benzer enflasyonist ekonomilerde bireysel bütçe yönetimi, hane halkının finansal sağlığı için kritik hale gelmiştir. Ancak mevcut bütçe uygulamalarının büyük çoğunluğu **manuel veri girişi** talep eder: kullanıcı her fişi eline alıp, tutarı, kategoriyi ve tarihi tek tek yazmak zorundadır.

Bu durum şu sonuçları doğurur:

- **"Süreksizlik Eksikliği":** Kullanıcılar ilk 3-7 gün düzenli veri girer, ardından uygulamayı terk eder (yüksek churn).
- **Veri kalitesi düşüklüğü:** Elle girilen kategoriler tutarsızdır (ör. "market" bir gün "gıda", bir gün "diğer" olarak işaretlenir).
- **Gizlilik endişesi:** Finansal verilerini bulut sunuculara yükleyen uygulamalara güvenmeyen, hassas kullanıcı segmenti mevcuttur.
- **Ekonomik kırılganlık dönemlerinde** anlık ve doğru harcama görünürlüğüne olan ihtiyaç artmıştır; kullanıcılar "ay sonunu nasıl getiririm" sorusuna gerçek zamanlı yanıt arar.

**Çözüm:** Kullanıcı fişi kameraya gösterir → cihaz içi OCR metni çıkarır → basit örüntüler regex ile, karmaşık/belirsiz fişler ise cihaz üzerinden çağrılan Gemini LLM ile ayrıştırılır → sonuç otomatik kategorize edilerek lokal veritabanına yazılır. Kullanıcının tek yapması gereken fotoğrafı çekmek ve sonucu onaylamaktır.

---

## 3. Ürün Vizyonu ve Hedefleri (Goals)

**Vizyon:** Kullanıcının bütçesini takip etmek için manuel veri girişini minimuma indirerek tamamen hibrit bir şekilde uygulamanın çalışmasını sağlar.

### Ürün Hedefleri (MVP)
| # | Hedef | Ölçüt |
|---|-------|-------|
| G1 | Manuel veri girişini minimuma indirmek | Fiş taramadan işlem kaydına kadar geçen süre < 10 sn |
| G2 | Gizliliği taviz vermeden korumak | Sıfır ağ isteği (Gemini API çağrısı hariç) — veri asla cihazdan kalıcı olarak dışarı çıkmaz |
| G3 | Offline deneyim sunmak | İnternet olmadan da (regex ile) temel fiş okuma çalışabilmeli |
| G4 | Kategori doğruluğunu artırmak | Hibrit (regex + LLM) yaklaşımla ≥ %85 doğru otomatik kategori ataması |
| G5 | 30 günde çalışan bir MVP çıkarmak | Tüm P0 kullanıcı hikayeleri kabul kriterleriyle tamamlanmış olmalı |

---

## 4. Kapsam (Scope)

### 4.1. Kapsam İçi (MVP — Kesinlikle Yapılacaklar)

**Çekirdek Özellikler:**
- Kamera ile fiş tarama (google_ml_kit ile on-device OCR)
- OCR çıktısının regex tabanlı hızlı ayrıştırması (tutar, tarih, mağaza adı)
- Regex'in çözemediği/güven skoru düşük fişler için Gemini API'ye (google_generative_ai) fallback ile gönderilip yapılandırılmış JSON (kategori, kalemler, toplam tutar) olarak geri alınması
- Otomatik kategorizasyon (ihtiyaç, eğlence, yatırım vb.)
- Kullanıcının OCR/LLM sonucunu onaylama veya manuel düzeltme ekranı (insan doğrulama katmanı — "human-in-the-loop")
- Manuel işlem ekleme (fişi olmayan harcamalar için — kamera olmadan da uygulama kullanılabilmeli)
- Lokal veritabanı (Isar/Hive) ile tüm işlemlerin cihazda saklanması
- Günlük/Aylık/Haftalık/Yıllık harcama özeti ve kategori bazlı grafik (basit dashboard)
- Bütçe limiti belirleme ve limit aşıldığında lokal bildirim
- İşlem listesi: filtreleme (kategori, tarih aralığı), arama, düzenleme, silme
- .env dosyası ile API key yönetimi (build-time secret injection)
- Tek kullanıcı, tek cihaz ve onboarding.

**Teknik Kapsam:**
- Multi-package Flutter mimarisi: `core_ui`, `finance_database`, `receipt_ai_scanner`, `app_main`
- iOS ve Android için native OCR entegrasyonu (ML Kit)
- Temel hata yönetimi (OCR başarısız olursa, API zaman aşımına uğrarsa manuel girişe yönlendirme)

### 4.2. Kapsam Dışı (Out of Scope — İleride Eklenecekler)

| Özellik | Neden MVP Dışı |
|---------|-----------------|
| Çoklu kullanıcı / hane halkı paylaşımlı bütçe | Local-first mimaride senkronizasyon gerektirir, backend ihtiyacı doğurur |
| Bulut yedekleme / cihazlar arası senkron | "Privacy-first" prensibiyle çelişir, ayrı bir mimari faz gerektirir |
| Banka hesabı / kredi kartı entegrasyonu (Open Banking) | Regülasyon (BDDK/PSD2 benzeri) süreçleri, MVP süresini aşar |
| Çoklu para birimi ve döviz kuru desteği | Ek karmaşıklık, ilk sürümde tek para birimi (TL) yeterli |
| Gelişmiş yapay zeka önerileri (tasarruf tavsiyeleri, tahminleme) | Ayrı bir veri bilimi/analitik fazı gerektirir |
| Sosyal özellikler (paylaşım, gamification, liderlik tablosu) | Ürün-market uyumu netleşmeden erken optimizasyon |
| Web / masaüstü versiyonu | Mobil-first strateji, MVP sadece iOS/Android |
| Karanlık mod dışında tema/özelleştirme | Kozmetik, MVP'de tek tema (light + basic dark) yeterli |
| Abonelik / ücretli plan (paywall) altyapısı | Önce ürün-market uyumu doğrulanmalı |
| Çoklu dil desteği (sadece Türkçe) | İlk hedef kitle yerel; lokalizasyon ayrı faz |

---

## 5. Kullanıcı Profili (Target Persona)

Bu uygulama, gelir ve giderlerini düzenli şekilde takip etmek isteyen, finansal farkındalığını artırmayı hedefleyen ve manuel veri girişine minimum zaman ayırmak isteyen bireyleri hedeflemektedir. Ürün, farklı yaş grupları ve mesleklerden kullanıcılar tarafından kullanılabilecek şekilde tasarlanmıştır. 
Günlük, haftalık veya aylık harcamalarını takip etmek isteyen bireyler.
Finansal verilerinin gizliliğine önem veren ve verilerinin cihaz üzerinde saklanmasını tercih eden kullanıcılar.
Hızlı, kolay ve düşük etkileşim gerektiren bir bütçe yönetimi deneyimi bekleyen kullanıcılar.

## 6. Kullanıcı Hikayeleri (User Stories) ve Kabul Kriterleri

### Epic A — Fiş Tarama ve Otomatik Kayıt

**US-01 (P0):** Bir kullanıcı olarak, fişimi kameraya gösterdiğimde uygulamanın tutarı, mağaza adını ve tarihi otomatik olarak okumasını istiyorum ki elle yazmak zorunda kalmayayım.
- **Kabul Kriterleri:**
  - Kamera açıldıktan sonra fiş kadraja girdiğinde OCR otomatik/manuel tetiklenir.
  - OCR sonucu 3 saniye içinde ekranda gösterilir (cihaz içi işlem, ağ gecikmesi yok).
  - Tutar, tarih ve mağaza adı alanları otomatik doldurulur; kullanıcı onaylamadan kayıt tamamlanmaz.
  - OCR hiçbir metin bulamazsa kullanıcıya "Fiş okunamadı, manuel giriş yapabilirsiniz" mesajı gösterilir.

**US-02 (P0):** Bir kullanıcı olarak, fişimdeki ürünler karmaşık/anlaşılmaz bir formatta olsa bile (örn. indirimli fiyat, çoklu ürün, kısaltmalar) doğru kategoriye ayrılmasını istiyorum.
- **Kabul Kriterleri:**
  - Regex tabanlı ayrıştırıcı güven skoru (confidence score) belirli bir eşiğin (örn. %70) altında kalırsa, ham OCR metni otomatik olarak Gemini API'ye gönderilir.
  - Gemini'den dönen yanıt yapılandırılmış JSON şemasına (kategori, toplam tutar, kalem listesi) uygun olmalı; şema doğrulaması başarısız olursa kullanıcıya manuel kategori seçimi sunulur.
  - LLM çağrısı 5 saniyeyi aşarsa zaman aşımı devreye girer ve kullanıcı manuel akışa yönlendirilir.
  - İnternet yoksa, sistem otomatik olarak sadece regex sonucunu kullanıcıya sunar ve "Detaylı analiz için internet gerekli" bilgilendirmesi yapılır.

**US-03 (P0):** Bir kullanıcı olarak, uygulamanın önerdiği kategoriyi ve tutarı kaydetmeden önce düzenleyebilmek istiyorum ki hatalı okumalar bütçemi yanıltmasın.
- **Kabul Kriterleri:**
  - Onay ekranında tüm alanlar (tutar, kategori, tarih, not) düzenlenebilir.
  - Kullanıcı "Kaydet" demeden hiçbir veri veritabanına yazılmaz.
  - Kullanıcı düzeltme yaptığında bu tercih sadece o işlem için geçerlidir (MVP'de öğrenen model/kişiselleştirme yok).

### Epic B — Manuel İşlem ve Bütçe Takibi

**US-04 (P0):** Bir kullanıcı olarak, fişi olmayan harcamalarımı (örn. nakit verilen bahşiş) da manuel olarak ekleyebilmek istiyorum.
- **Kabul Kriterleri:** Ana ekranda "+" butonu ile tutar, kategori, tarih, açıklama girilebilen basit bir form açılır; kayıt anında listeye yansır.

**US-05 (P0):** Bir kullanıcı olarak, aylık harcamalarımın kategori bazlı dağılımını grafikte görmek istiyorum ki nereye ne kadar harcadığımı anlayayım.
- **Kabul Kriterleri:** Ana ekranda seçili ay için pasta/çubuk grafik gösterilir; grafik üzerinden kategoriye tıklandığında o kategoriye ait işlemler listelenir.

**US-06 (P1):** Bir kullanıcı olarak, bir kategori için aylık bütçe limiti belirleyip, bu limite yaklaştığımda/aştığımda bildirim almak istiyorum.
- **Kabul Kriterleri:** Kullanıcı kategori bazlı limit tanımlar; harcama limitin %80'ine ulaştığında ve %100'ü aştığında lokal push bildirim gönderilir (backend yok, tamamen cihaz üzerinde zamanlanmış kontrol).

### Epic C — Veri Yönetimi ve Gizlilik

**US-07 (P0):** Bir kullanıcı olarak, tüm finansal verimin sadece kendi cihazımda saklandığından emin olmak istiyorum.
- **Kabul Kriterleri:** Uygulama içinde "Gizlilik" ekranı, verinin lokal veritabanında (Isar/Hive) tutulduğunu ve sadece OCR sonrası ayrıştırma için (yalnızca metin, görsel değil) Gemini API'ye istek gönderildiğini açıkça belirtir. Görsel (fiş fotoğrafı) hiçbir zaman cihaz dışına gönderilmez.

**US-08 (P1):** Bir kullanıcı olarak, istediğim bir işlemi düzenleyebilmek veya silebilmek istiyorum.
- **Kabul Kriterleri:** İşlem listesinde her kayıt için düzenle/sil aksiyonu bulunur; silme işlemi onay diyaloğu ile teyit edilir.

---

## 7. Fonksiyonel Gereksinimler

| ID | Gereksinim |
|----|------------|
| FR-01 | Sistem, cihaz kamerasından alınan görüntüyü google_ml_kit ile OCR'dan geçirmelidir. |
| FR-02 | Sistem, OCR çıktısını regex tabanlı bir ayrıştırıcıdan geçirerek tutar/tarih/mağaza tespiti yapmalıdır. |
| FR-03 | Regex güven skoru eşik altında kalırsa sistem, ham metni Gemini API'ye (google_generative_ai) yapılandırılmış prompt ile göndermelidir. |
| FR-04 | LLM yanıtı JSON şemasına göre doğrulanmalı (schema validation); hatalı yanıt manuel girişe düşmelidir. |
| FR-05 | Kullanıcı, önerilen veri onaylanmadan işlem kalıcı olarak kaydedilmemelidir. |
| FR-06 | Sistem, işlemleri lokal veritabanında (Isar) tarih, kategori, tutar, kaynak (OCR/LLM/Manuel) alanlarıyla saklamalıdır. |
| FR-07 | Sistem, kategori bazlı aylık/haftalık özet ve grafik üretmelidir. |
| FR-08 | Kullanıcı kategori bazlı bütçe limiti tanımlayabilmeli, limit aşımında lokal bildirim tetiklenmelidir. |
| FR-09 | Kullanıcı işlemleri listeleyebilmeli, filtreleyebilmeli, arayabilmeli, düzenleyebilmeli, silebilmelidir. |
| FR-10 | API anahtarı `.env` dosyasından okunmalı, kaynak kodda hardcode edilmemelidir. |

---

## 8. Fonksiyonel Olmayan Gereksinimler (NFR)

### 8.1. Performans
- **Sıfır gecikme prensibi:** OCR işlemi tamamen cihaz üzerinde (offline) çalışmalı; fiş görüntüsünden metne çevrim süresi **≤ 2 saniye** (orta segment cihaz baz alınarak).
- Regex ayrıştırma işlemi **≤ 200ms** içinde tamamlanmalı.
- LLM fallback çağrısı için maksimum bekleme süresi **5 saniye**; aşılırsa otomatik timeout ve manuel girişe yönlendirme.
- Uygulama soğuk başlatma (cold start) süresi ≤ 2.5 saniye.

### 8.2. Gizlilik ve Güvenlik (Privacy-First)
- Fiş görselleri **hiçbir zaman** cihaz dışına gönderilmez; sadece OCR sonrası çıkarılan **metin**, kullanıcı onayıyla (veya otomatik fallback senaryosunda) Gemini API'ye gönderilir.
- Tüm finansal veri Isar/Hive lokal veritabanında, cihaz üzerinde şifreli (Isar encryption / Hive AES) saklanır.
- API anahtarı derleme zamanında `.env` üzerinden `--dart-define` veya `flutter_dotenv` ile enjekte edilir; repoya commit edilmez (`.gitignore` içinde).
- Uygulama, kullanıcıya açık bir "Gizlilik Beyanı" sunar: hangi veri, ne zaman, nereye gider.
- Uygulama izinleri (kamera, bildirim) sadece ilgili özellik kullanılmadan hemen önce (just-in-time permission) istenir.

### 8.3. Güvenilirlik ve Hata Toleransı
- İnternet bağlantısı olmadığında uygulama tamamen çalışabilir olmalı (LLM fallback devre dışı kalır, regex + manuel giriş yeterli olmalı).
- OCR veya LLM başarısız olduğunda kullanıcı deneyimi kesintiye uğramamalı, her zaman manuel giriş "kaçış yolu" (escape hatch) olarak sunulmalı.

### 8.4. Sürdürülebilirlik / Mimari
- Paketler arası bağımlılık tek yönlü olmalı: `app_main` → `receipt_ai_scanner`, `finance_database`, `core_ui`; alt paketler birbirine veya `app_main`'e bağımlı olmamalı.
- Her paket kendi test setine sahip olmalı (unit test coverage hedefi ≥ %60, kritik iş mantığı için ≥ %80).

---

## 9. Sistem Mimarisi ve Veri Akışı

### 9.1. Paket Mimarisi (Multi-Package)

```
app_main/               → Uygulama giriş noktası, navigasyon, state yönetimi, ekranların birleştirilmesi
core_ui/                → Paylaşılan tema, tipografi, buton/kart/input widget'ları, tasarım sistemi
finance_database/       → Isar/Hive şema tanımları, repository katmanı, CRUD işlemleri, bütçe/limit mantığı
receipt_ai_scanner/     → Kamera entegrasyonu, google_ml_kit OCR, regex parser, Gemini API istemcisi, JSON şema doğrulama
```

**Bağımlılık kuralı:** `app_main` diğer üç pakete bağımlıdır. `receipt_ai_scanner` ve `finance_database` birbirinden habersizdir — aralarındaki veri akışı `app_main` katmanındaki bir "orchestrator/use-case" sınıfı üzerinden yürütülür (bu, paketlerin bağımsız test edilebilirliğini korur).

### 9.2. Uçtan Uca Veri Akışı (Fiş Tarama Senaryosu)

```
[1] Kullanıcı Kamerayı Açar
        ↓
[2] receipt_ai_scanner: Görüntü yakalanır (image_picker / camera)
        ↓
[3] receipt_ai_scanner: google_ml_kit → On-device OCR
        (Görsel HİÇBİR ZAMAN cihaz dışına çıkmaz)
        ↓
[4] receipt_ai_scanner: Ham OCR metni → Regex Parser
        ↓
   [Karar Noktası: Güven Skoru]
        ├── Güven Skoru YÜKSEK (regex yeterli)
        │        ↓
        │   [5a] Yapılandırılmış veri (tutar, tarih, mağaza) hazır
        │
        └── Güven Skoru DÜŞÜK / Karmaşık Fiş
                 ↓
            [5b] İnternet var mı? 
                    ├── Evet → Ham metin, google_generative_ai ile
                    │          Gemini API'ye gönderilir (yapılandırılmış prompt + JSON şema)
                    │          → Yanıt şema doğrulamasından geçer
                    │
                    └── Hayır → Kullanıcıya "sadece regex sonucu" gösterilir
                                + "Detaylı analiz için internet gerekli" bilgisi
        ↓
[6] app_main: Sonuç, Onay/Düzenleme Ekranında kullanıcıya gösterilir
        ↓
[7] Kullanıcı onaylar veya düzenler
        ↓
[8] finance_database: Onaylanan veri Isar'a yazılır
        (transaction tablosu: id, tutar, kategori, tarih, kaynak[OCR/LLM/Manuel], not)
        ↓
[9] app_main: Dashboard/İşlem listesi anlık olarak güncellenir (reaktif state yönetimi, örn. Riverpod/Bloc)
```

### 9.3. Kullanılan Temel Teknolojiler
- **Flutter** (state yönetimi için Riverpod veya Bloc önerilir — squad kararına bırakılabilir, tutarlılık şart)
- **google_ml_kit** — on-device text recognition
- **google_generative_ai** — Gemini API istemcisi (sadece metin gönderimi, görsel değil)
- **Isar** (önerilen) veya **Hive** — lokal, şifrelenebilir, hızlı NoSQL veritabanı
- **flutter_dotenv** veya `--dart-define` — API key yönetimi

---

## 10. Ekip Dağılımı ve Roller (10 Kişi — Domain Bazlı Squad)

| Squad | Kişi Sayısı | Sorumluluk | İlgili Paket |
|-------|-------------|------------|--------------|
| **Squad Lead / Scrum Master** | 1 | Sprint planlama, blocker yönetimi, paydaş iletişimi, 30 günlük takvimi izleme | Tümü (koordinasyon) |
| **UI/UX & Design System Squad** | 2 | Tasarım sistemi, ortak widget'lar, erişilebilirlik, ekran akışları | `core_ui`, `app_main` (view layer) |
| **Database & Domain Logic Squad** | 2 | Isar şema tasarımı, repository katmanı, bütçe/limit iş mantığı, migrasyon stratejisi | `finance_database` |
| **AI/OCR Squad** | 3 | ML Kit entegrasyonu, regex parser motoru, Gemini prompt mühendisliği, JSON şema doğrulama, güven skoru algoritması | `receipt_ai_scanner` |
| **App Integration & QA Squad** | 2 | `app_main` orkestrasyonu, state yönetimi, uçtan uca test, performans/gizlilik NFR doğrulaması, cihaz testleri | `app_main` (entegrasyon) |

> **Not:** AI/OCR squad'a 3 kişi ayrılmıştır çünkü hibrit regex+LLM mantığı projenin en riskli ve farklılaştırıcı bileşenidir; bu alanda gecikme, tüm MVP takvimini etkiler.

---

## 11. Başarı Metrikleri (Success Metrics / KPI)

### Teknik Metrikler
| Metrik | Hedef |
|--------|-------|
| OCR işlem süresi (cihaz içi) | ≤ 2 saniye |
| Regex ile başarılı ayrıştırma oranı | ≥ %60 (fişlerin çoğunluğu LLM'e gitmeden çözülmeli — maliyet/hız için) |
| Hibrit (regex+LLM) genel kategori doğruluğu | ≥ %85 |
| Kritik crash oranı | < %1 (test cihazlarında) |
| Unit test coverage (kritik paketler) | ≥ %70 |
| API key sızıntısı / güvenlik açığı | 0 (statik kod analizi ile doğrulanmalı) |

### Kullanıcı Bazlı Metrikler (MVP sonrası pilot için)
| Metrik | Hedef |
|--------|-------|
| Fiş taramadan kayda kadar geçen süre | < 10 saniye |
| İlk hafta kullanıcı elde tutma (retention) | ≥ %40 |
| Manuel düzeltme oranı (LLM/regex sonucuna müdahale) | < %25 (düşük olması yüksek doğruluk anlamına gelir) |
| Kullanıcı memnuniyeti (pilot anketi, 1-5) | ≥ 4.0 |

---

## 12. Regülasyon ve Uyumluluk Notları

- MVP'de banka/kart entegrasyonu olmadığı için BDDK, PSD2 benzeri finansal regülasyonlara tabi değildir.
- KVKK (Türkiye) açısından: uygulama kişisel veri işlemediği sürece (veri cihazda kalıyor, sunucuya kaydedilmiyor) düşük risk sınıfındadır; ancak Gemini API'ye gönderilen **metin** verisi için kullanıcıya açık rıza ve aydınlatma metni (Gizlilik Ekranı — bkz. US-07) sunulmalıdır.
- Google Gemini API kullanım koşulları ve veri işleme politikası incelenmeli; üçüncü taraf işlemcisi olarak gizlilik politikasında açıkça belirtilmelidir.
- Kamera izni, Android/iOS mağaza politikalarına uygun şekilde gerekçelendirilmelidir (Play Store/App Store inceleme riski).

---

## 13. Edge Case'ler (Uç Durumlar)

| Durum | Beklenen Davranış |
|-------|--------------------|
| Fiş fotoğrafı bulanık/okunamıyor | "Fiş okunamadı" mesajı + manuel giriş yönlendirmesi |
| Fişte birden fazla tutar var (ara toplam, KDV, genel toplam) | Regex öncelik sırası: "Genel Toplam/Toplam" anahtar kelimesi aranır; bulunamazsa LLM'e düşer |
| İnternet yokken karmaşık fiş taranırsa | Sadece regex sonucu gösterilir, LLM analizi kullanılamaz bilgisi verilir, sonradan tekrar denenebilir seçeneği sunulur |
| Gemini API kotası/limiti dolarsa | Hata yakalanır, kullanıcı regex sonucuyla devam eder, sessiz/loglu hata (crash yok) |
| Kullanıcı kamerayı reddederse (izin vermezse) | Manuel giriş akışı ana akış olarak sunulur, özellik kısıtlaması net şekilde açıklanır |
| Aynı fiş yanlışlıkla iki kez taranırsa | MVP'de otomatik duplicate tespiti yok (Out of Scope); kullanıcı manuel silebilir |
| Çok uzun/yoğun fiş (market alışverişi, 50+ kalem) | Sadece toplam tutar ve kategori özetlenir; kalem bazlı detay MVP'de opsiyonel/basitleştirilmiş |
| Cihaz düşük donanımlı (eski model) | OCR/parsing süresi uzayabilir; 5sn üzeri işlemler için loading state ve iptal seçeneği gösterilir |

---

## 14. Analitik (Yerel/Privacy-Safe)

Backend olmadığından üçüncü parti analitik SDK'ları (Firebase Analytics vb.) **kullanılmayacaktır** (privacy-first prensibiyle çelişir). Bunun yerine:

- Uygulama içi **lokal event log** (yalnızca cihazda, anonim, kimliksiz): OCR başarı/başarısızlık oranı, regex vs LLM kullanım oranı, ortalama işlem süresi.
- Bu loglar MVP aşamasında sadece geliştirici/QA cihazlarında debug modunda incelenir; üretimde kullanıcıya "Anonim Kullanım İstatistikleri" ekranında agregatif olarak gösterilebilir (opsiyonel, kullanıcı onayına bağlı).
- İleri fazda, kullanıcı onayı ile opt-in bir telemetri sistemi değerlendirilebilir (Out of Scope — MVP'de yok).

---

## 15. Açık Sorular (Open Questions)

1. Isar mı Hive mı kesin karar verilecek mi, yoksa squad değerlendirmesine mi bırakılacak? (Öneri: Isar — daha güçlü sorgulama ve şifreleme desteği.)
2. Gemini API çağrıları için günlük/aylık kullanıcı başına maliyet limiti/kota stratejisi ne olacak (kullanıcı kendi API key'ini mi girecek, yoksa uygulama sahibi merkezi mi sağlayacak)?
3. Kategori seti (Market, Ulaşım, Fatura vb.) sabit mi olacak, kullanıcı özel kategori ekleyebilecek mi? (MVP'de sabit öneriliyor.)
4. Karanlık mod MVP'ye dahil mi, yoksa post-MVP mi?
5. Uygulama mağazası (Play Store/App Store) inceleme sürecinde kamera izni gerekçelendirmesi için ek bir gizlilik politikası sayfası (web) gerekecek mi?
6. Test cihazı matrisi (hangi Android/iOS sürümleri, hangi donanım segmentleri) QA squad tarafından netleştirilmeli.

---

## 16. Risk Analizi ve Azaltma Stratejileri (Risk Assessment & Mitigation)

Proje geliştirme sürecinde karşılaşılabilecek başlıca riskler teknik, performans ve güvenlik başlıkları altında değerlendirilmiştir. Her risk için uygulanacak azaltma stratejileri aşağıda özetlenmiştir.

### 16.1 Teknik Riskler

| Risk | Azaltma Stratejisi |
|------|--------------------|
| OCR'ın düşük kaliteli fişleri okuyamaması | Kullanıcıya yeniden tarama önerilir ve manuel giriş seçeneği sunulur. |
| Regex ayrıştırıcısının karmaşık fişlerde yetersiz kalması | Güven skoru eşik değerin altına düştüğünde Gemini API devreye alınır. |
| Gemini API gecikmesi veya kota sınırı | Timeout uygulanır, kullanıcı regex sonucu ile devam ederek manuel düzenleme yapabilir. |

### 16.2 Performans Riskleri

| Risk | Azaltma Stratejisi |
|------|--------------------|
| Düşük donanımlı cihazlarda performans kaybı | Farklı cihaz segmentlerinde test yapılır, uzun işlemler için yüklenme göstergesi ve iptal seçeneği sunulur. |
| İnternet bağlantısının bulunmaması | OCR ve regex çevrimdışı çalışmaya devam eder, LLM analizi devre dışı bırakılır. |

### 16.3 Güvenlik Riskleri

| Risk | Azaltma Stratejisi |
|------|--------------------|
| API anahtarının istemci uygulamasında bulunması | MVP'de `.env` ve `--dart-define` kullanılacaktır. Üretim sürümünde proxy tabanlı anahtar yönetimine geçilmesi planlanmaktadır. |
| Yanlış kategori önerisi nedeniyle kullanıcı güveninin azalması | Son karar kullanıcıya bırakılır, hiçbir işlem onay olmadan kaydedilmez. |

### Risk Öncelikleri

Aşağıdaki riskler MVP geliştirme sürecinde öncelikli olarak takip edilecektir:

- OCR doğruluğunun farklı fiş formatlarında yeterli seviyeye ulaşması.
- Gemini API'nin gecikme ve kota sınırlamalarının kullanıcı deneyimine etkisi.
- Düşük donanımlı cihazlarda uygulama performansının korunması.

Bu riskler her sprint sonunda gözden geçirilecek ve gerekli durumlarda azaltma stratejileri güncellenecektir.

## 17. Release Planı (30 İş Günü)

| Faz | Gün Aralığı | Ana Çıktılar |
|-----|-------------|--------------|
| **Faz 0 — Kurulum & Mimari** | Gün 1-3 | Monorepo/multi-package iskeleti, CI/CD temel pipeline, `.env` yapılandırması, tasarım sistemi taslağı |
| **Faz 1 — Çekirdek Altyapı** | Gün 4-10 | `finance_database` şema + repository, `core_ui` temel bileşenler, kamera + ML Kit entegrasyonu (ham OCR çıktısı alınabiliyor) |
| **Faz 2 — Hibrit Ayrıştırma Motoru** | Gün 11-18 | Regex parser, güven skoru algoritması, Gemini API entegrasyonu + JSON şema doğrulama, fallback mantığı |
| **Faz 3 — Uçtan Uca Entegrasyon** | Gün 19-24 | Onay/düzenleme ekranı, manuel işlem ekleme, dashboard/grafik, bütçe limiti + bildirimler |
| **Faz 4 — Sertleştirme & QA** | Gün 25-28 | Uç durum testleri, performans optimizasyonu, güvenlik taraması (API key sızıntısı kontrolü), cihaz matrisi testleri |
| **Faz 5 — Release Hazırlığı** | Gün 29-30 | Mağaza metadata/gizlilik politikası, son regresyon testi, build imzalama, dağıtım (internal/beta) |

**Kritik Yol (Critical Path):** Faz 2 (Hibrit Ayrıştırma Motoru) projenin en yüksek riskli aşamasıdır; AI/OCR squad'ın bu fazda gecikmesi tüm takvimi etkiler. Bu nedenle Faz 1 ile paralel olarak Gemini prompt tasarımı Gün 4'ten itibaren başlatılmalıdır (spike/prototip çalışması).

---

## 18. (Opsiyonel) Veritabanı Şeması — Taslak

```
Collection: Transaction
- id: int (auto-increment / Isar Id)
- amount: double
- category: String (enum: market, ulasim, fatura, eglence, saglik, giyim, diger)
- date: DateTime
- merchantName: String?
- source: String (enum: ocr_regex, ocr_llm, manual)
- rawOcrText: String? (opsiyonel, debug/iyileştirme amaçlı, kullanıcı gizlilik ayarından kapatılabilir)
- note: String?
- createdAt: DateTime
- updatedAt: DateTime

Collection: BudgetLimit
- id: int
- category: String
- monthlyLimit: double
- month: String (YYYY-MM)
- notifiedAt80Percent: bool
- notifiedAt100Percent: bool
```

## 19. (Opsiyonel) Kullanıcı Kabul Kriterleri — Genel Definition of Done

MVP'nin "tamamlandı" sayılabilmesi için:
- [ ] Tüm P0 user story'ler kabul kriterleriyle birlikte test edilmiş ve geçmiş olmalı.
- [ ] İnternet olmadan uygulama (regex + manuel giriş ile) tam işlevsel çalışmalı.
- [ ] Fiş görselinin cihaz dışına çıkmadığı, kod incelemesi ve statik analizle doğrulanmalı.
- [ ] .env / API key hiçbir şekilde repo geçmişinde veya derlenmiş binary'de düz metin olarak bulunmamalı.
- [ ] En az 2 farklı cihaz segmentinde (düşük/orta donanım) performans NFR'leri karşılanmalı.
- [ ] Gizlilik Ekranı, kullanıcıya veri akışını net şekilde açıklıyor olmalı.

## 20. (Opsiyonel) Monitoring / Log Stratejisi

- Üretimde merkezi sunucu log toplama **yoktur** (backend yok).
- Hata ayıklama için lokal crash log (örn. Sentry'nin self-hosted olmayan SDK'sı **kullanılmamalı** — gizlilik ilkesiyle çelişir); bunun yerine cihaz üzerinde tutulan, kullanıcı isteğiyle dışa aktarılabilen bir "Destek Log Dosyası" (ör. son 50 hata kaydı) önerilir.
- QA/Dev build'lerinde `debugPrint` ve yerel log dosyası kullanılabilir; release build'de bu loglar devre dışı bırakılmalı.

---

*Bu doküman, 30 günlük MVP sprint planlamasının temel referansıdır. Kapsam değişiklikleri Squad Lead/Scrum Master onayı ile bu dokümana işlenmelidir.*
