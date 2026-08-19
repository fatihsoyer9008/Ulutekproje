# n8n Self-Hosting (Hetzner)

n8n, `docker-compose.prod.yml`'e eklenen bir servis olarak aynı Hetzner
sunucusunda (`116.202.14.23`) çalışır — ayrı bir sunucu/n8n Cloud
kullanılmıyor.

## Kalıcılık ve şifreleme anahtarı

- Workflow'lar, credential'lar ve çalıştırma geçmişi container içindeki
  `/home/node/.n8n`'de tutulur; bu, adlandırılmış bir Docker volume'una
  (`n8n_data`) bağlıdır — container silinip yeniden oluşsa bile (rebuild,
  `docker-compose up -d --build`) veri kaybolmaz.
- **`N8N_ENCRYPTION_KEY` ayrı bir risktir.** Bu anahtar kaybolursa, volume
  sapasağlam dursa bile n8n'in içine kaydedilmiş tüm credential'lar
  (API key'ler, OAuth token'ları vb.) **kalıcı olarak** okunamaz hale
  gelir — n8n bunları bu anahtarla şifreler. Bu yüzden:
  - Anahtar sunucuda yalnızca `/root/Ulutekproje/.env` içinde tutulur
    (repo kökünde, docker-compose'un `${VAR}` interpolasyonu için okuduğu
    dosya). Bu dosya `.gitignore`'da (`/.env`) — Git'e commit edilmez.
  - **Aynı anahtar ayrıca bir password manager'a da kaydedilmeli** —
    sunucu kaybolursa/diskin bozulması durumunda tek kopya kalmasın diye.
  - `docker-compose.prod.yml`'de bu değişken `${N8N_ENCRYPTION_KEY:?...}`
    ile **zorunlu** yapıldı — `.env`'de yoksa `docker-compose up`
    hata verip durur, sessizce boş/varsayılan bir anahtarla başlamaz.

## Ağ ve erişim

- n8n container'ı `127.0.0.1:5678:5678`'e bağlı — postgres/redis/api ile
  aynı prensip, dışarıya asla doğrudan açık değil
  (`backend/tests/test_deployment_config.py::test_production_compose_binds_ports_to_loopback_only`
  bunu regression olarak kilitliyor).
- Dışarıdan erişim **ayrı bir subdomain** üzerinden, path değil:
  `https://n8n.116-202-14-23.sslip.io/` → `127.0.0.1:5678`. `sslip.io`
  herhangi bir alt alan adını (`<herhangi-bir-şey>.<ip-tire-ile>.sslip.io`)
  aynı IP'ye çözdüğü için ayrıca DNS ayarı gerekmedi.

  **Neden path değil (`/n8n/`) subdomain kullanıldı:** İlk denemede
  `N8N_PATH=/n8n/` ile path-bazlı hosting kuruldu, ama n8n'in editor UI'ı
  kendi JS/CSS asset'lerini (`/n8n/assets/...`) doğru servis etmiyor —
  bu path'e giden istekler `text/html` dönüyor (SPA fallback'e düşüyor),
  tarayıcı "MIME type mismatch" hatasıyla script'leri yüklemeyi reddediyor,
  editor boş sayfa açıyor. Bu, Caddy'yi bypass edip n8n'e doğrudan
  `127.0.0.1:5678`'den istek atılarak da doğrulandı — reverse proxy'nin
  suçu değil, n8n'in kendi `N8N_PATH` desteğindeki bir kısıt/hata. Ayrı
  subdomain'de n8n kökte (`/`) çalıştığı için bu sorun hiç oluşmuyor.

  Caddy config (`/etc/caddy/Caddyfile`, sunucuda, Git'e tabi değil — bkz.
  `docs/hetzner_firewall_setup.md`):

  ```caddyfile
  116-202-14-23.sslip.io {
  	reverse_proxy 127.0.0.1:8000
  }

  n8n.116-202-14-23.sslip.io {
  	reverse_proxy 127.0.0.1:5678
  }
  ```

## İlk kurulum

n8n ilk açıldığında bir "owner" hesabı oluşturma ekranı gösterir
(`N8N_USER_MANAGEMENT`, n8n'in kendi yerleşik oturum sistemi — ayrı bir
basic-auth şifresi kullanılmadı). Bu adım tarayıcıdan, sunucuya erişimi
olan kişi tarafından tamamlanmalı: `https://n8n.116-202-14-23.sslip.io/`

## n8n → EconBuddy webhook otomasyonu

n8n workflow'unun EconBuddy'ye event göndermesi gereken sözleşme
`docs/n8n_webhook_contract.md`'de. Özellikle `receipt.parsed` event'i
için `docs/n8n_webhook_contract.md`'deki "Event-özel veri şemaları"
bölümüne bakın — kullanıcı e-posta adresiyle eşleştirilir, yeni bir
`CloudReceipt` oluşturulur.
