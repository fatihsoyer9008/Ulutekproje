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
- Dışarıdan erişim yalnızca Caddy üzerinden, path-bazlı:
  `https://116-202-14-23.sslip.io/n8n/` → `127.0.0.1:5678`. Caddy config
  (`/etc/caddy/Caddyfile`, sunucuda, Git'e tabi değil — bkz.
  `docs/hetzner_firewall_setup.md`):

  ```caddyfile
  116-202-14-23.sslip.io {
  	handle /n8n/* {
  		reverse_proxy 127.0.0.1:5678
  	}
  	handle {
  		reverse_proxy 127.0.0.1:8000
  	}
  }
  ```
- n8n'e `N8N_PATH=/n8n/` verildi ki ürettiği tüm URL'ler (webhook'lar,
  static asset'ler, editor) bu path altında doğru üretilsin.

## İlk kurulum

n8n ilk açıldığında bir "owner" hesabı oluşturma ekranı gösterir
(`N8N_USER_MANAGEMENT`, n8n'in kendi yerleşik oturum sistemi — ayrı bir
basic-auth şifresi kullanılmadı). Bu adım tarayıcıdan, sunucuya erişimi
olan kişi tarafından tamamlanmalı: `https://116-202-14-23.sslip.io/n8n/`

## n8n → FişKon webhook otomasyonu

n8n workflow'unun FişKon'a event göndermesi gereken sözleşme
`docs/n8n_webhook_contract.md`'de. Özellikle `receipt.parsed` event'i
için `docs/n8n_webhook_contract.md`'deki "Event-özel veri şemaları"
bölümüne bakın — kullanıcı e-posta adresiyle eşleştirilir, yeni bir
`CloudReceipt` oluşturulur.
