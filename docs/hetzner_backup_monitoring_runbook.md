# Hetzner Backup, Monitoring ve Production Smoke Test

Bu doküman Task 7.6 kapsamında Hetzner production ortamı (`116.202.14.23`,
hostname `ocr-backend`) için yapılan yedekleme, healthcheck, log inceleme ve
smoke test çalışmalarını kayıt altına alır. `docs/hetzner_firewall_setup.md`
(Task 7.1-7.3) ile aynı sunucuyu ve `docker-compose.prod.yml`'i kapsar.

## PostgreSQL günlük yedekleme

Script: [`scripts/backup_postgres.sh`](../scripts/backup_postgres.sh). Host
Postgres client'ı gerektirmez — dump'ı `docker exec` ile çalışan `postgres`
container'ının içinde alır, `gzip` ile sıkıştırır.

- Yedekler: `/root/fiskon-backups/<db>_<UTC timestamp>.sql.gz`, dizin `700`,
  dosyalar `600` (yalnızca root okuyabilir).
- Saklama süresi: 14 gün (`RETENTION_DAYS`), her çalıştırmada daha eski
  dosyalar otomatik silinir.
- Cron: her gün UTC 03:15'te `root` kullanıcısı olarak çalışır (düşük
  trafik saati, backend ekibinin çalışma saatleri dışında):

```cron
15 3 * * * POSTGRES_CONTAINER=ulutekproje_postgres_1 /root/fiskon-ops/backup_postgres.sh >> /root/fiskon-backups/backup.log 2>&1
```

Script hem repoda (`scripts/backup_postgres.sh`, review/versiyon geçmişi
için) hem de sunucuda sabit bir ops dizininde (`/root/fiskon-ops/`, git
checkout'undan bağımsız) tutulur — böylece cron'un çalışacağı script,
uygulama deploy'larından (branch değişimi, `git pull`) etkilenmez. Script
değiştiğinde repodaki kopya güncellenip sunucudaki ops kopyasına elle
senkronize edilmelidir.

### İlk çalıştırma doğrulaması

`bash /root/fiskon-ops/backup_postgres.sh` elle çalıştırıldı; sonuç ve dosya
boyutu bu dokümanın "Doğrulamalar" bölümünde kayıtlı.

## Restore

1. Sunucuya bağlan, hedef dosyayı belirle:
   ```bash
   ls -la /root/fiskon-backups/
   ```
2. **Var olan veriyi geri yüklemeden önce mutlaka yeni bir yedek al**
   (yanlışlıkla eski veriye dönmek yerine mevcut durumu da kaybetmemek için):
   ```bash
   bash /root/fiskon-ops/backup_postgres.sh
   ```
3. API'yi durdur (restore sırasında yazma olmasın diye; postgres/redis açık
   kalabilir):
   ```bash
   cd /root/Ulutekproje
   docker-compose -f docker-compose.prod.yml stop api
   ```
4. Hedef veritabanını geri yükle (mevcut şemanın üzerine `pg_dump --format=plain`
   çıktısını uygular; `--clean` KULLANILMADI çünkü dump `--clean` olmadan
   alındı — tablo çakışması olursa önce `dropdb`/`createdb` gerekir, aşağıya
   bakın):
   ```bash
   gunzip -c /root/fiskon-backups/receipt_app_<timestamp>.sql.gz | \
     docker exec -i ulutekproje_postgres_1 psql --username receipt_app --dbname receipt_app
   ```
   Sıfırdan/temiz bir restore gerekiyorsa (ör. bozuk bir migration sonrası):
   ```bash
   docker exec ulutekproje_postgres_1 dropdb --username receipt_app receipt_app
   docker exec ulutekproje_postgres_1 createdb --username receipt_app --owner receipt_app receipt_app
   gunzip -c /root/fiskon-backups/receipt_app_<timestamp>.sql.gz | \
     docker exec -i ulutekproje_postgres_1 psql --username receipt_app --dbname receipt_app
   ```
5. API'yi tekrar başlat ve doğrula:
   ```bash
   docker-compose -f docker-compose.prod.yml start api
   docker-compose -f docker-compose.prod.yml ps
   curl -s https://116-202-14-23.sslip.io/health
   ```

## Healthcheck: API, PostgreSQL, Redis

`postgres` ve `redis` servislerinde zaten `healthcheck` vardı
(`pg_isready`, `redis-cli ping`). Bu PR `api` servisine de bir healthcheck
ekledi (`docker-compose.yml` ve `docker-compose.prod.yml`, ikisinde de aynı
blok):

```yaml
healthcheck:
  test:
    - CMD
    - python
    - -c
    - import urllib.request as u; u.urlopen("http://127.0.0.1:8000/health", timeout=3)
  interval: 10s
  timeout: 5s
  retries: 5
  start_period: 30s
```

`curl`/`wget` image'da yok (`python:3.12-slim`); ekstra paket kurmamak için
zaten mevcut olan `python`'la `urllib.request` kullanıldı — `/health`
200 dönmezse veya timeout olursa komut exception fırlatıp non-zero exit
verir, Docker bunu `unhealthy` olarak işaretler.

`backend/tests/test_deployment_config.py::test_api_service_declares_a_healthcheck`
bu bloğun her iki compose dosyasında da bulunmasını regression olarak
kilitliyor.

Durum kontrolü:

```bash
docker-compose -f docker-compose.prod.yml ps
# Name kolonunda "(healthy)" görünmeli (start_period 30s sonrası)
```

## Docker log kontrol rehberi

```bash
# Son N satır, canlı takip
docker-compose -f docker-compose.prod.yml logs --tail 100 api
docker-compose -f docker-compose.prod.yml logs -f api

# Sadece hata/exception içeren satırlar
docker-compose -f docker-compose.prod.yml logs api 2>&1 | grep -iE "error|exception|traceback"

# postgres / redis
docker-compose -f docker-compose.prod.yml logs --tail 50 postgres
docker-compose -f docker-compose.prod.yml logs --tail 50 redis

# Container yeniden başlama sayısı / son durumu (crash-loop tespiti)
docker inspect --format '{{.Name}}: restarts={{.RestartCount}} status={{.State.Status}} health={{.State.Health.Status}}' \
  ulutekproje_api_1 ulutekproje_postgres_1 ulutekproje_redis_1
```

`app/core/observability.py`'deki `PersonalDataRedactionFilter` tüm
`app`/`uvicorn` logger'larına otomatik uygulanıyor (bkz. `CLAUDE.md`), yani
bu loglarda e-posta gibi kişisel veriler zaten `<redacted-email>` ile
maskeleniyor olmalı — loglarda maskesiz bir e-posta/token görülmesi başlı
başına bir bug'dır, `app/core/observability.py`'e bakılmalı.

## Sunucu yeniden başlatma testi

Aşağıdaki adımlar `docker-compose.prod.yml` servislerinin (rebuild
olmadan, sadece process restart) sağlıklı şekilde geri geldiğini doğrular:

```bash
cd /root/Ulutekproje
docker-compose -f docker-compose.prod.yml restart
sleep 35   # start_period + birkaç healthcheck döngüsü
docker-compose -f docker-compose.prod.yml ps
curl -s https://116-202-14-23.sslip.io/health
```

## Smoke test senaryoları

Script: [`scripts/prod_smoke_test.sh`](../scripts/prod_smoke_test.sh).
Sunucuda `/root/fiskon-ops/prod_smoke_test.sh` olarak da tutulur (backup
script'iyle aynı gerekçeyle: deploy/branch durumundan bağımsız çalışsın).

Kapsam: health, auth (register → login → delete-account ile temizlik),
sync (`GET /pull`, salt okunur), n8n webhook (imzalı istek, sadece
main'e merge olduktan sonra çalıştırılabilir — bkz. aşağıdaki not). OCR
gerçek Gemini key'i çağırdığı için ayrı ve tek bir minimal istekle
sınırlı tutuldu (bkz. Doğrulamalar).

## Doğrulamalar

Bu bölümdeki her adım gerçekten prod sunucusunda (`root@116.202.14.23`)
çalıştırıldı, 2026-08-18.

### Ön koşul: sunucu 10 commit geride bulundu

Task 7.6'ya başlamadan önce sunucunun `main@b4a5e66`'da takılı kaldığı ve
`docker-compose.prod.yml`'in hâlâ **untracked** olarak elle bırakılmış bir
kopya olduğu bulundu (`docs/hetzner_firewall_setup.md`'nin "artık böyle
değil" dediği kırılgan durum, aslında sunucuda devam ediyordu). Untracked
kopya `git show origin/main:docker-compose.prod.yml` ile byte-byte aynı
olduğu doğrulandıktan sonra silindi, `git pull origin main` fast-forward ile
`5037bf4`'e getirdi (#133 port kapatma, #134 group sync, #135 offline sync
dahil). Rebuild sırasında sunucudaki eski `docker-compose` (1.29.2) sürümünün
bilinen bir `KeyError: 'ContainerConfig'` hatası çıktı (yeni Docker
29.1.3'ün ürettiği image formatıyla `docker-compose` 1.29.2'nin recreate
mantığı arasındaki bilinen uyumsuzluk) — `api` container'ının volume'u
olmadığı için etkilenen orphan container elle silinip `up -d` tekrar
çalıştırılarak çözüldü. Toplam kesinti birkaç dakikayı geçmedi.
`/health` hem `127.0.0.1:8000` hem `https://116-202-14-23.sslip.io`
üzerinden 200 döndü.

### Backup

```
$ bash /root/fiskon-ops/backup_postgres.sh
[backup_postgres] starting dump of receipt_app at 20260818T080248Z
[backup_postgres] wrote /root/fiskon-backups/receipt_app_20260818T080248Z.sql.gz (20K)
[backup_postgres] pruned 0 backup(s) older than 14 days
[backup_postgres] done
```

`gunzip -t` ile bütünlük doğrulandı, dosya `postgres_dump` başlığıyla
başlıyor. Dizin `700`, dosya `600`. Cron kuruldu (`crontab -l` ile
doğrulandı):

```
15 3 * * * POSTGRES_CONTAINER=ulutekproje_postgres_1 /root/fiskon-ops/backup_postgres.sh >> /root/fiskon-backups/backup.log 2>&1
```

### Restart testi

`docker-compose -f docker-compose.prod.yml restart` sonrası üç servis de
`Up`/`healthy`, `/health` 200. (`ulutekproje_api_1` bu PR merge olmadan
Docker-seviyeli healthcheck'e sahip olmayacağı için `docker inspect`'te
`State.Health` alanı henüz yok — beklenen; healthcheck kodu bu PR'da yazıldı
ve `docker-compose config` ile doğrulandı, sunucuya bu PR merge olup
`git pull` yapıldıktan sonra etkin olacak.)

### Smoke test

`scripts/prod_smoke_test.sh` prod'a karşı çalıştırıldı, tamamı geçti:

```
[ok]   GET /health (200)
[ok]   POST /api/v1/auth/register (202)
[ok]   POST /api/v1/auth/login (bad creds) (401)
[ok]   GET /api/v1/auth/me (no token) (401)
[ok]   GET /api/v1/sync/pull (no token) (401)
[ok]   POST /api/v1/parse-receipt (200) — gerçek Gemini çağrısı, fişi doğru ayrıştırdı
== n8n: skipped (N8N_WEBHOOK_HMAC_SECRET not set, or endpoint not deployed yet) ==
All smoke checks passed.
```

Not: script ilk çalıştırmada `example.invalid`/`.invalid` alan adını
kullanıyordu; `pydantic`'in `email-validator` bağımlılığı RFC 2606'daki
reserved TLD'leri (`.invalid`, `.test`, `.example` vb.) 422 ile reddediyor.
Script bunun yerine gerçek ama var olmayan bir alan adı
(`nonexistent-fiskon-smoketest-domain.net`) kullanacak şekilde düzeltildi.

Register çağrıları `is_email_verified=false` iki gerçek `users` satırı
oluşturdu (doğrulama linkine tıklanmadığı için hiçbir zaman login
edilemezlerdi); bu test satırları doğrulama sonrası
`DELETE FROM users WHERE email LIKE '%nonexistent-fiskon-smoketest-domain.net%'`
ile temizlendi (`DELETE 2`, sonrasında `count=0` ile doğrulandı).

### n8n webhook — bloke

`receipt.parsed`/imza doğrulama kodu (Task 7.5, PR #136) henüz `main`'e
merge edilmedi, dolayısıyla sunucuda deploy edilmiş değil. n8n smoke
senaryosu `scripts/prod_smoke_test.sh`'e `N8N_WEBHOOK_HMAC_SECRET` env'i
verilerek eklendi ve kod hazır; **#136 merge olup sunucuda `git pull` +
rebuild yapıldıktan sonra** şu şekilde çalıştırılmalı:

```bash
ssh root@116.202.14.23
cd /root/Ulutekproje && grep N8N_WEBHOOK_HMAC_SECRET backend/.env
N8N_WEBHOOK_HMAC_SECRET=<yukarıdaki değer> bash /root/fiskon-ops/prod_smoke_test.sh
```
