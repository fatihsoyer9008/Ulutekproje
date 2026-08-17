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

`api` servisinin repodaki `8000:8000` mapping'i **bilinçli olarak
değiştirilmedi** — yerel geliştirme ortamında fiziksel cihaz/aynı-ağ testi
için (`docs/TEAM_ENV_AND_BUILD_GUIDE.md` §7) API'nin `0.0.0.0`'da
yayınlanması gerekiyor. Sunucuda ise bu satır **elle** (sadece sunucudaki
çalışma kopyasında, commit'lenmeden) `127.0.0.1:8000:8000` olarak
yamalanıyor — tıpkı `env_file` syntax farkı gibi, üçüncü "sadece sunucuya
özel" patch. Sunucuda yeni bir `git pull` sonrası bu satırı tekrar
`127.0.0.1:8000:8000` yapmayı unutmayın.

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

**Ekip yeni HTTPS URL'ine geçtikten sonra tamamlanan adımlar:**
1. ✅ Sunucuda `git pull` + `docker-compose build api` (main'deki CORS/N8N
   secret desteğini içeren kod deploy edildi).
2. ✅ `.env`'de kullanılmayan Apple OAuth placeholder'ları (`APPLE_CLIENT_ID`,
   `APPLE_TEAM_ID`, `APPLE_KEY_ID`) boşaltıldı — yarım dolu bırakılsaydı
   `_validate_production_settings` "Apple OAuth requires..." hatasıyla
   uygulamayı başlatmazdı.
3. ✅ `.env`'e `TRUST_PROXY_HEADERS=true`, `TRUSTED_CLIENT_IP_HEADER=X-Forwarded-For`,
   `TRUSTED_PROXY_CIDRS=172.18.0.1/32` eklendi (`172.18.0.1`, `docker network
   inspect ulutekproje_default` ile doğrulanan bridge gateway IP'si — hem
   Caddy hem doğrudan `:8000`'e gelen bağlantılar container'a bu IP'den
   ulaşıyordu, bu yüzden 8000 kapanana kadar bu ayar açılmamıştı).
4. ✅ `docker-compose.yml`'de sunucuya özel `api` portu `127.0.0.1:8000:8000`
   yapıldı, container yeniden oluşturuldu.
5. ✅ `ufw delete allow 8000/tcp` (ve v6) çalıştırıldı. UFW'de artık sadece
   22/80/443 var.
6. ✅ Dışarıdan doğrulandı: 8000 kapalı/timeout, 22 ve 443 açık, HTTPS
   sağlıklı (`/health` 200).

**Henüz yapılmadı — ayrı görev:** `N8N_WEBHOOK_HMAC_SECRET` backend ekibinin
n8n entegrasyonu bitmediği için `.env`'e eklenmedi. Bu yüzden `APP_ENV`
hâlâ `development`'ta bırakıldı — `_validate_production_settings` bu
secret olmadan `production` modunda uygulamayı başlatmaz
(`app/main.py:92-101`). Backend ekibi secret'ı üretip Fatih'e/sunucuya
ilettiğinde: `.env`'e `N8N_WEBHOOK_HMAC_SECRET` eklenip `APP_ENV=production`
yapılmalı, container yeniden oluşturulup loglar (`docker logs
ulutekproje_api_1`) çökme olup olmadığı için izlenmeli.

`/docs` ve `/redoc` endpoint'lerinin production'da kapatılması ayrı bir
güvenlik iyileştirmesi olarak değerlendirilebilir (bu dokümanın kapsamı
dışında, ayrı görev önerilir).

## Sunucuda çalıştırılacak UFW komutları

Bunları Hetzner sunucusuna SSH ile bağlanıp **siz** çalıştırmalısınız —
buradan uzaktan uygulanmadı. SSH kuralını eklemeden `ufw enable`
çalıştırmayın, yoksa bağlantınız kopar ve sunucuya erişiminizi
kaybedebilirsiniz.

```bash
# Mevcut kuralları görüntüle (değişiklik öncesi referans için)
sudo ufw status verbose

# Gerekli portları aç (sıralama önemli: SSH önce)
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow 8000/tcp comment 'API - gecici, reverse proxy kurulunca kaldirilacak'

# Postgres/Redis icin herhangi bir "allow" kurali EKLEMEYIN.
# Zaten docker-compose 127.0.0.1'e bind ettigi icin disaridan ulasilamazlar;
# ufw'nin varsayilan deny-incoming kurali bunu ayrica garanti eder.

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status verbose
```

## Deploy adımları

```bash
cd /path/to/Ulutekproje
git pull
docker compose up -d --build
docker compose ps
```

`docker compose ps` çıktısında `postgres` ve `redis` satırlarında port
kolonunun `127.0.0.1:5432->5432/tcp` ve `127.0.0.1:6379->6379/tcp` şeklinde
göründüğünü doğrulayın (önceden `0.0.0.0:...` idi).

## Dış ağdan erişim testi

Deploy sonrası **sunucu dışındaki** bir makineden (kendi bilgisayarınızdan)
çalıştırın:

```bash
# Kapali olmasi gerekenler (baglanti reddedilmeli / timeout olmali)
nc -vz -w 3 116.202.14.23 5432
nc -vz -w 3 116.202.14.23 6379

# Kapali olmasi gerekenler (2026-08-17 itibariyle 8000 de bu listede)
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
| `N8N_WEBHOOK_HMAC_SECRET` | ❌ **eklenmedi** — backend ekibi n8n entegrasyonunu henüz bitirmedi, secret manuel eklenecek |
| `APP_ENV=production` | ❌ **kasıtlı olarak development bırakıldı**, yalnızca `N8N_WEBHOOK_HMAC_SECRET` eksik olduğu için — `app/main.py:92-101` bu secret olmadan `RuntimeError` fırlatıp uygulamayı başlatmaz. Diğer tüm production ön koşulları (proxy trust, Apple, email, secret gücü) sağlanmış durumda. |

**Son kalan adım:** Backend ekibi `N8N_WEBHOOK_HMAC_SECRET` üretip iletince
`.env`'e eklenip `APP_ENV=production` yapılacak, container yeniden
oluşturulup loglar izlenerek doğrulanacak.
