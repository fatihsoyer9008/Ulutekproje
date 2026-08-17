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

`api` servisinin `8000:8000` mapping'i **bilinçli olarak değiştirilmedi** —
aşağıdaki "API portu 8000 — karar" bölümüne bakın.

## API portu 8000 — karar (GÜNCELLENDİ)

**Reverse proxy artık kuruldu.** Sunucuya Caddy kuruldu
(`/etc/caddy/Caddyfile`), `https://116-202-14-23.sslip.io` adresi
`127.0.0.1:8000`'e proxy ediyor ve gerçek, geçerli bir Let's Encrypt
sertifikası kullanıyor (`sslip.io` ücretsiz IP-tabanlı DNS servisi — gerçek
domain almaya gerek kalmadan Let's Encrypt için geçerli bir hostname
sağlıyor). uvicorn komutuna `--proxy-headers --forwarded-allow-ips=127.0.0.1`
eklendi, böylece Caddy arkasında doğru client IP/scheme algılanıyor.

**8000 hâlâ UFW'de açık ve `docker-compose.yml`'de `0.0.0.0:8000` olarak
mapping'li — bilerek.** Sebep: proje kapalı bir grup için (staj sunumu,
~10 kişi) kullanılıyor ve mevcut kurulu Flutter build'leri hâlâ
`http://116.202.14.23:8000`'e hardcode. 8000'i şimdi kapatırsak o build'ler
anında çöker.

**Kapatma sırası (tamamlanınca bu bölüm tekrar güncellenmeli):**
1. Flutter tarafında `--dart-define=API_BASE_URL=https://116-202-14-23.sslip.io`
   ile yeni build al.
2. Grubun 10 kişisi yeni build'e geçsin, eski build kullanan kalmadığı
   doğrulansın.
3. `docker-compose.yml`'de `api` servisinin portu `127.0.0.1:8000:8000`
   yap (hem yerel repo hem sunucu).
4. Sunucuda `ufw delete allow 8000/tcp` (ve v6 karşılığı) çalıştır.
5. Bu dokümandaki "açık portlar" tablosunu ve UFW komut listesini güncelle
   (8000 satırını kaldır).

Bu adımlar henüz uygulanmadı — 1. adım (yeni build) tamamlanana kadar 8000
kasıtlı olarak açık bırakılıyor.

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

# Acik kalmasi beklenenler (baglanti basarili olmali)
nc -vz -w 3 116.202.14.23 22
nc -vz -w 3 116.202.14.23 8000
```

PowerShell'den (Windows):

```powershell
Test-NetConnection -ComputerName 116.202.14.23 -Port 5432   # TcpTestSucceeded: False bekleniyor
Test-NetConnection -ComputerName 116.202.14.23 -Port 6379   # TcpTestSucceeded: False bekleniyor
Test-NetConnection -ComputerName 116.202.14.23 -Port 8000   # TcpTestSucceeded: True (henuz kapatilmadi)
```

Bu testleri ben (Claude) çalıştırmadım — gerçek production IP'sine dışarıdan
bağlantı denemesi olduğu için, firewall değişikliklerini siz sunucuda
uyguladıktan sonra sonucu doğrulamanız gerekiyor.
