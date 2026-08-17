# n8n Webhook Sözleşmesi

## Amaç ve kapsam

Bu sözleşme, FişKon ile n8n arasındaki otomasyon olaylarının güvenli ve
sürümlenebilir biçimde iletilmesini tanımlar.

Webhook yalnızca bildirim ve operasyon otomasyonları için kullanılır. Ham OCR
metni, fiş görseli, parola, access/refresh token, e-posta adresi veya başka
kişisel veri payload ya da loglara eklenmez.

## Event isimleri

Event isimleri namespaced biçimde yazılır:

- `receipt.parsed`
- `group_expense.created`
- `settlement.completed`
- `group.invitation.created`
- `system.healthcheck.failed`
- `backup.failed`

Yeni event türleri `domain.action` biçimini korumalıdır.

## HTTP isteği

```http
POST /api/v1/integrations/n8n/events
Content-Type: application/json
Idempotency-Key: <8-128 karakter benzersiz anahtar>
X-Webhook-Timestamp: <Unix timestamp, saniye>
X-Webhook-Signature: sha256=<hex digest>
```

Tüm istekler HTTPS üzerinden gönderilmelidir.

## Payload zarfı

Her event aşağıdaki sürümlü zarfı kullanır:

```json
{
  "event_type": "group_expense.created",
  "event_id": "4a6d8f18-668c-4aea-895c-0681a818890a",
  "occurred_at": "2026-08-17T12:30:00Z",
  "schema_version": 1,
  "data": {}
}
```

Kurallar:

- `event_id` UUID olmalıdır.
- `occurred_at` UTC ve ISO-8601 biçiminde olmalıdır.
- `schema_version` pozitif integer olmalıdır.
- Para alanları her zaman kuruş cinsinden integer ile taşınır.
- `double`, `float` veya `"125.50"` gibi decimal string kullanılmaz.
- Şema değişiklikleri eski workflow'ları bozmamak için yeni
  `schema_version` ile yayınlanır.

## Örnek event

```json
{
  "event_type": "group_expense.created",
  "event_id": "4a6d8f18-668c-4aea-895c-0681a818890a",
  "occurred_at": "2026-08-17T12:30:00Z",
  "schema_version": 1,
  "data": {
    "group_id": "c9bc37aa-4c16-4573-9ef4-3ee0045d917b",
    "expense_id": "80cb3d39-2fcb-4de2-90b1-363a2b53a17f",
    "total_amount_in_minor": 12550,
    "currency": "TRY",
    "split_type": "equal"
  }
}
```

## HMAC imzası

Webhook secret, mevcut `SECURITY_HMAC_SECRET` ile paylaşılmaz. Ayrı environment
değişkeni kullanılır:

```dotenv
N8N_WEBHOOK_HMAC_SECRET=<ayrı-ve-rastgele-secret>
```

Gönderici imzayı aşağıdaki UTF-8 değer üzerinden üretir:

```text
timestamp + "." + raw_body
```

Algoritma `HMAC-SHA256` olmalıdır. Sonuç:

```http
X-Webhook-Signature: sha256=<hex digest>
```

Alıcı:

1. `X-Webhook-Timestamp` değerini doğrular.
2. Zaman damgası mevcut zamandan ±5 dakikadan fazla uzaksa isteği reddeder.
3. Aynı `timestamp + "." + raw_body` değeriyle HMAC-SHA256 üretir.
4. İmzaları `hmac.compare_digest` ile karşılaştırır.
5. Geçersiz imza için `401`, süresi geçmiş istek için `400` döner.

## Idempotency

`Idempotency-Key` 8-128 karakter arasında olmalıdır.

- Aynı anahtar ve aynı payload tekrar gelirse ilk isteğin sonucu döndürülür.
- Aynı anahtar farklı payload ile gelirse `409` ve
  `idempotency_conflict` hata kodu döner.
- Idempotency kayıtları event türü ve gönderen kapsamı ile birlikte tutulur.

## Hata ve retry davranışı

| Yanıt | Anlamı | n8n davranışı |
| --- | --- | --- |
| 2xx | Event kabul edildi | Retry etme |
| 400 / 401 / 409 / 422 | Kalıcı sözleşme, imza veya payload hatası | Retry etme; workflow hataya/alarm akışına geçsin |
| 429 | Geçici kota sınırı | `Retry-After` varsa ona uy; yoksa backoff uygula |
| 5xx / bağlantı hatası | Geçici sunucu veya ağ hatası | Exponential backoff ile retry et |

n8n workflow'u sınırlı deneme sayısı kullanmalı; son denemeden sonra olay
dead-letter/alarm akışına yönlendirilmelidir.

## Güvenlik ve gözlemlenebilirlik

- Production'da `N8N_WEBHOOK_HMAC_SECRET` boş veya zayıf olamaz.
- Secret yalnızca yerel `.env` veya deployment secret yönetiminde saklanır;
  Git'e commit edilmez.
- Loglar mevcut kişisel veri maskeleme mekanizmasından geçirilir.
- Loglarda yalnızca `event_type`, `event_id`, `request_id`, HTTP durum kodu ve
  süre gibi güvenli metadata tutulur.
- Ham webhook payload'ı veya HMAC secret loglanmaz.

## Backend uygulama notları

Backend ekibi endpointi eklemeden önce bu sözleşmeyi onaylamalıdır. Uygulama:

1. `N8N_WEBHOOK_HMAC_SECRET` ayarını `SecretStr` olarak ekler.
2. Production ayar kontrolünde boş/zayıf secret ile başlamayı engeller.
3. HMAC ve timestamp doğrulamasını endpointten önce uygular.
4. Payload doğrulama, idempotency ve hata yanıtlarını bu sözleşmeye göre
   uygular.
5. Unit/integration testlerinde geçerli imza, geçersiz imza, eski timestamp,
   replay, aynı idempotency anahtarı ve 5xx retry senaryolarını kapsar.