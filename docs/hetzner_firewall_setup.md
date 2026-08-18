# Hetzner Firewall ve Docker Port Güvenliği

Bu doküman Task 7.1 kapsamında canlı ortamın (Hetzner, `116.202.14.23`) port
maruziyetini azaltmak için yapılan/yapılması gereken adımları kayıt altına
alır. `docker-compose.yml` bu ortamda doğrudan production için kullanılıyor
(bkz. `PRD.md` §"Canlı ortam").

## Mevcut durum (bu dokümandan önce)

| Port | Servis | Durum |
| --- | --- | --- |
| 5432 | PostgreSQL | `0.0.0.0:5432` — internete açık |
| 6379 | Redis | `0.0.0.0:6379` — internete açık |
| 8000 | API (uvicorn) | `0.0.0.0:8000` — internete açık, TLS yok, `/docs` (Swagger) herkese açık |
| 22 | SSH | açık |

## Yapılan değişiklik: `docker-compose.yml`

`postgres` ve `redis` servislerinin port mapping'leri `127.0.0.1:<port>:<port>`
olarak değiştirildi. Bu, container'ların birbirine Docker'ın internal
network'ü üzerinden (`postgres:5432`, `redis:6379` hostname'leriyle) erişmeye
devam etmesini sağlarken, host'un public arayüzünden bu portlara erişimi
tamamen keser — uygulama davranışında hiçbir değişiklik olmaz, sadece dışa
kapanır.

`api` servisinin `docker-compose.yml`'deki `8000:8000` mapping'i **bilinçli
olarak değiştirilmedi** — yerel geliştirme ortamında fiziksel cihaz/aynı-ağ
testi için (`docs/TEAM_ENV_AND_BUILD_GUIDE.md` §7) API'nin `0.0.0.0`'da
yayınlanması gerekiyor.

**Production için artık ayrı, versiyonlanmış bir dosya var:
`docker-compose.prod.yml`.** Daha önce bu fark sunucudaki çalışma kopyasına
elle (commit'lenmeden) yamanıyordu — bu, bir `git pull`/fresh deploy'da
sessizce kaybolup 8000'i tekrar açabilecek kırılgan bir kurulumdu (code
review'da bulundu). Artık böyle değil: `docker-compose.prod.yml`
postgres/redis/api için `127.0.0.1` binding'lerini ve sunucudaki eski
`docker-compose` (1.29.2) sürümüyle uyumlu `env_file` syntax'ını içeriyor,
Git'e commit'li. Sunucuda `docker-compose.yml` yerine **sadece**
`docker-compose.prod.yml` kullanılmalı (aşağıdaki "Deploy adımları"na
bakın) — iki dosyayı `-f` ile birleştirmeyin: bu sunucudaki eski
`docker-compose`'da `ports` listesini replace değil **append** ediyor,
`0.0.0.0:8000` ve `127.0.0.1:8000` ikisi birden kalıp çakışmaya yol açıyor
(bunu `docker-compose config` ile test ederek doğruladım).

`backend/tests/test_deployment_config.py` artık `docker-compose.prod.yml`'i
de `--no-proxy-headers` kontrolüne dahil ediyor ve port binding'lerinin
`127.0.0.1` olduğunu ayrı bir testle doğruluyor — bu dosya gelecekte
yanlışlıkla `0.0.0.0`'a dönerse CI kırılır.

## API portu 8000 — KAPATILDI (2026-08-17)

Reverse proxy kuruldu: sunucuya Caddy kuruldu (`/etc/caddy/Caddyfile`),
`https://116-202-14-23.sslip.io` adresi `127.0.0.1:8000`'e proxy ediyor ve
gerçek, geçerli bir Let's Encrypt sertifikası kullanıyor (`sslip.io`
ücretsiz IP-tabanlı DNS servisi — gerçek domain almaya gerek kalmadan
Let's Encrypt için geçerli bir hostname sağlıyor).

uvicorn'a `--proxy-headers` **eklenmedi** — `backend/tests/test_deployment_config.py::
test_uvicorn_runtime_commands_disable_proxy_header_processing` bunu bilerek
zorunlu kılıyor. Proje, proxy güvenini uvicorn seviyesinde değil, uygulama
seviyesinde (`TRUST_PROXY_HEADERS` / `TRUSTED_CLIENT_IP_HEADER` /
`TRUSTED_PROXY_CIDRS`, bkz. `app/api/dependencies.py:request_ip`) CIDR
tabanlı olarak yapıyor.

**Tamamlanan adımlar (2026-08-17):**
1. ✅ Sunucuda `git pull` + API image rebuild (main'deki CORS/N8N secret
   desteğini içeren kod deploy edildi).
2. ✅ `.env`'de kullanılmayan Apple OAuth placeholder'ları (`APPLE_CLIENT_ID`,
   `APPLE_TEAM_ID`, `APPLE_KEY_ID`) boşaltıldı — yarım dolu bırakılsaydı
   `_validate_production_settings` "Apple OAuth requires..." hatasıyla
   uygulamayı başlatmazdı.
3. ✅ `.env`'e `TRUST_PROXY_HEADERS=true`, `TRUSTED_CLIENT_IP_HEADER=X-Forwarded-For`,
   `TRUSTED_PROXY_CIDRS=172.18.0.1/32` eklendi (`172.18.0.1`, `docker network
   inspect ulutekproje_default` ile doğrulanan bridge gateway IP'si — hem
   Caddy hem doğrudan `:8000`'e gelen bağlantılar container'a bu IP'den
   ulaşıyordu, bu yüzden 8000 kapanana kadar bu ayar açılmamıştı).
4. ✅ API portu `docker-compose.prod.yml` içinde deklaratif olarak
   `127.0.0.1:8000:8000` — sunucuda bu dosyayla yeniden deploy edildi.
5. ✅ `ufw delete allow 8000/tcp` (ve v6) çalıştırıldı. UFW'de artık sadece
   22/80/443 var.
6. ✅ Dışarıdan doğrulandı: 8000 kapalı/timeout, 22 ve 443 açık, HTTPS
   sağlıklı (`/health` 200).
7. ✅ `N8N_WEBHOOK_HMAC_SECRET` `openssl rand -hex 32` ile üretilip `.env`'e
   eklendi — backend ekibinin n8n entegrasyonunu bitirmesini beklemeye
   gerek yoktu, secret'ın kendisi entegrasyon kodundan bağımsız üretilebilir
   (code review'da bulundu).
8. ✅ `APP_ENV=production` yapıldı, container yeniden oluşturuldu, loglar
   izlendi — çökme yok, `Application startup complete`. `/health` artık
   `"environment":"production"` dönüyor.
9. ✅ Production'a geçmenin asıl faydası doğrulandı: `POST /api/v1/groups/{id}/members`
   (local/mock member-add route, `app/api/routers/groups.py:466`) artık
   `404 group_not_found` ile gizli — daha önce development modunda açıktı
   (code review'da bulundu).

`/docs` ve `/redoc` endpoint'lerinin production'da kapatılması ayrı bir
güvenlik iyileştirmesi olarak değerlendirilebilir (bu dokümanın kapsamı
dışında, ayrı görev önerilir).

## Sunucudaki güncel UFW durumu (referans)

Aşağıdaki kurallar sunucuda **zaten uygulanmış durumda** — bu bölüm bir
"yapılacaklar" listesi değil, mevcut durumun kaydı. Sunucu sıfırdan
kurulursa aynı sırayla uygulanmalı (SSH kuralı `ufw enable`'dan **önce**
eklenmeli, yoksa bağlantı kopar ve sunucuya erişim kaybedilir). **8000 için
bir `ufw allow` kuralı YOK ve eklenmemeli** — API artık yalnızca Caddy
üzerinden (443) erişilebilir.

```bash
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'

# Postgres/Redis/API icin herhangi bir "allow" kurali EKLEMEYIN.
# Ucu docker-compose.prod.yml'de 127.0.0.1'e bind edildigi icin zaten
# disaridan ulasilamazlar; ufw'nin varsayilan deny-incoming kurali bunu
# ayrica garanti eder.

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status verbose
```

## Deploy adımları (production)

```bash
cd /path/to/Ulutekproje
git pull
docker-compose -f docker-compose.prod.yml up -d --build
docker-compose -f docker-compose.prod.yml ps
```

**`docker-compose.yml` ile `docker-compose.prod.yml`'i `-f` ile birlikte
vermeyin** — yukarıda açıklandığı gibi eski `docker-compose` sürümü
`ports` listesini birleştirir, çakışmaya yol açar. Sadece
`docker-compose.prod.yml` kullanın.

`docker-compose ps` çıktısında `postgres`, `redis` ve `api` satırlarının
üçünde de port kolonunun `127.0.0.1:...->...` şeklinde göründüğünü
doğrulayın (`0.0.0.0:...` değil).

## Dış ağdan erişim testi

Deploy sonrası **sunucu dışındaki** bir makineden (kendi bilgisayarınızdan)
çalıştırın:

```bash
# Kapali olmasi gerekenler (baglanti reddedilmeli / timeout olmali)
nc -vz -w 3 116.202.14.23 5432
nc -vz -w 3 116.202.14.23 6379
nc -vz -w 3 116.202.14.23 8000

# Acik kalmasi beklenenler (baglanti basarili olmali)
nc -vz -w 3 116.202.14.23 22
nc -vz -w 3 116.202.14.23 443
```

PowerShell'den (Windows):

```powershell
Test-NetConnection -ComputerName 116.202.14.23 -Port 5432   # TcpTestSucceeded: False bekleniyor
Test-NetConnection -ComputerName 116.202.14.23 -Port 6379   # TcpTestSucceeded: False bekleniyor
Test-NetConnection -ComputerName 116.202.14.23 -Port 8000   # TcpTestSucceeded: False bekleniyor (2026-08-17'de kapatildi)
Test-NetConnection -ComputerName 116.202.14.23 -Port 443    # TcpTestSucceeded: True bekleniyor
```

Bu testler 2026-08-17'de doğrulandı: 5432/6379/8000 kapalı, 22/443 açık,
`https://116-202-14-23.sslip.io/health` 200 dönüyor.

## Task 7.3 — Production environment, CORS ve secret kontrolü (durum, 2026-08-17 güncel)

Sunucudaki `.env` içeriği (değerler gösterilmeden) kontrol edildi:

| Kontrol | Durum |
| --- | --- |
| JWT_SECRET / SECURITY_HMAC_SECRET güçlü, default değil | ✅ |
| SMTP/Gemini/Google OAuth secret'ları `.env`'de, Git'te değil | ✅ (Gemini ve Assistant Gemini key'leri doğru şekilde farklı) |
| `EMAIL_ACTION_BASE_URL` HTTPS | ✅ → `https://116-202-14-23.sslip.io/api/v1/auth` |
| CORS middleware/allowlist | ✅ kod deploy edildi (`CORS_ALLOWED_ORIGINS`, `app/main.py` + `app/core/config.py`), wildcard (`*`) yapısal olarak reddediliyor. `.env`'de henüz değer yok (boş = CORS middleware hiç eklenmiyor — mobil app için sorun değil, tarayıcı client'ı olursa doldurulmalı) |
| `TRUST_PROXY_HEADERS=true` | ✅ **8000 kapandıktan sonra açıldı.** `TRUSTED_CLIENT_IP_HEADER=X-Forwarded-For`, `TRUSTED_PROXY_CIDRS=172.18.0.1/32` (Docker bridge gateway IP, `docker network inspect ulutekproje_default` ile doğrulandı) |
| Apple OAuth placeholder'ları | ✅ temizlendi — `APPLE_CLIENT_ID`/`APPLE_TEAM_ID`/`APPLE_KEY_ID` boşaltıldı (gerçek Apple Sign-In kullanılmıyor); yarım dolu bırakılsaydı production doğrulaması hata verirdi |
| `N8N_WEBHOOK_HMAC_SECRET` | ✅ `openssl rand -hex 32` ile üretilip eklendi. Backend ekibinin n8n entegrasyonunu bitirmesi beklenmedi — secret üretimi entegrasyon kodundan bağımsız |
| `APP_ENV=production` | ✅ **aktif.** `_validate_production_settings` (`app/main.py:35-133`) tüm kontrollerden hatasız geçti, container sağlıklı, `/health` → `"environment":"production"` |

Epic 7 (Task 7.1/7.2/7.3) tamamlandı. Kalan tek bağımlılık: ekibin geri
kalanının yeni HTTPS URL'ine geçmesi (bkz. Task 7.2 checklist'i, ayrı
takip ediliyor) — bu, port kapatma/production geçişini etkilemiyor, zaten
tamamlandı.
