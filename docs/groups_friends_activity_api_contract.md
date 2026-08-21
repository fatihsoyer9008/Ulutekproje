# Groups / Friends / Activity API Sözleşmesi

## Amaç ve kapsam

Bu sözleşme, Flutter tarafında tasarlanan 4 ekranı (Groups, Grup Detayı,
Friends, Activity) besleyecek backend endpoint'lerini tanımlar. Mevcut
FastAPI + PostgreSQL yapısına (`GroupExpense`, `ExpenseShare`, `Settlement`,
`CloudReceipt`) eklenen/genişletilen kısımları kapsar.

Backend'i yazacak arkadaşlar bu dosyaya **birebir** uymalı — alan adları,
tipleri ve birimleri burada sabitlenmiştir. Değişiklik gerekiyorsa önce bu
dosya güncellenir, sonra kod yazılır.

## Genel kurallar (projenin geri kalanıyla tutarlılık için)

Bu kurallar mevcut `group_schemas.py` / `settlement_schemas.py`'den
çıkarılmıştır, yeni endpoint'ler de aynen uyar:

- **Para her zaman `_in_minor` integer'dır** (kuruş). Asla `float`/`Decimal`
  JSON'a çıkmaz. `275.22 TL` → `27522`.
- **ID'ler `uuid.UUID`'dir** (`"550e8400-e29b-41d4-a716-446655440000"`),
  kısa/insan-okunur ID (`"grp_001"`) kullanılmaz.
- **Zaman damgaları UTC, `Z` suffix'li ISO-8601** string olarak serialize
  edilir: `"2026-08-17T12:30:00Z"` (bkz. `field_serializer` kalıbı,
  `settlement_schemas.py`).
- **Para birimi** 3 harfli, büyük harf ISO kodu (`"TRY"`).
- **Response'lar zarflanır**: tekil kaynak `{"group": {...}}`,
  `{"settlement": {...}}` gibi; liste `{"groups": [...]}` gibi düz dizi.
- **Avatar**: `avatar_url` yoktur. Kullanıcı avatarı `avatar_id: string | null`
  ile temsil edilir — Flutter'daki sabit 16'lı katalogdan (`woman`, `man`,
  `bearded_man`, vb.) bir id, resim URL'i değil. Bkz.
  `backend/app/auth_schemas.py::ALLOWED_AVATAR_IDS`.
- **Hata formatı** mevcut kalıple aynı: `{"detail": {"code": "...",
  "message": "..."}}`.

## Alınan tasarım kararları (önceki tartışmadan netleşenler)

1. **"Friends" bir grup türüdür, ayrı bir tablo değildir.** İki kullanıcı
   arasındaki ilk 1:1 masrafta arka planda görünmez bir 2 kişilik `Group`
   oluşturulur (`is_direct = true`). Mevcut `GroupExpense` / `ExpenseShare` /
   `Settlement` / OCR-itemized-split altyapısı **hiç değişmeden** bu
   grup üzerinde çalışır.
2. **Direct (arkadaşlık) grupları normal `GET /groups` listesinde
   görünmez** — sadece `GET /friends`'te görünür. "Non-group expenses" gibi
   üçüncü bir kova **eklenmez**; her masraf ya normal bir gruba ya da bir
   direct gruba aittir. (Bu, önceki taslakta netliği olmayan bir noktaydı —
   karar budur.)
3. **Activity kaydı `type`'a göre şekil değiştirir.** Ortak zarf sabit,
   detay alanı `type`'a göre doludur (aşağıda tablo halinde).
4. **Cursor opak bir string'dir.** `next_cursor` client için anlamsız bir
   token'dır; backend içeride `(created_at, id)` çiftini kodlar (UUID'ler
   zaman sıralı olmadığı için salt `id` cursor olarak kullanılamaz).

## Veritabanı değişiklikleri

### 1. `groups` tablosuna yeni kolon

```
ALTER TABLE groups ADD COLUMN is_direct BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX ix_groups_is_direct ON groups (is_direct);
```

- `is_direct = true` olan bir grubun tam olarak 2 aktif üyesi olur (uygulama
  seviyesinde `GroupService.get_or_create_direct_group` tarafından garanti
  edilir; DB seviyesinde ek bir constraint gerekmez çünkü `GroupMember`
  zaten `left_at` ile ayrılmayı destekliyor).
- Migration zinciri: mevcut head `20260819_0001_users_avatar_id` üzerine
  eklenir (`down_revision = "20260819_0001"`).

### 2. Yeni tablo: `activity_log`

```
CREATE TABLE activity_log (
    id UUID PRIMARY KEY,
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    actor_user_id UUID NOT NULL,               -- users.id FK yok (silinen kullanıcının geçmişi kalır)
    type VARCHAR(32) NOT NULL,                  -- bkz. "Activity type enum'u"
    payload_json JSONB NOT NULL,                -- type'a göre şekli değişen detay
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_activity_log_group_created ON activity_log (group_id, created_at DESC, id);
CREATE INDEX ix_activity_log_actor ON activity_log (actor_user_id);
```

- Append-only'dir, hiçbir zaman UPDATE/DELETE edilmez.
- Her ilgili servis (expense create/update/delete, settlement create,
  member join/leave, invitation accept) kendi transaction'ı içinde bu
  tabloya bir satır ekler. Ayrı bir "sync" mekanizması gerekmez.
- `group_id` her zaman doludur — direct (friend) gruplarında da aynı
  mekanizma çalışır, çünkü onlar da birer `Group` satırıdır.

## Endpoint 1 — Genel Bakiye

```
GET /api/v1/me/balance-summary
```

Kullanıcının **direct olmayan** gruplarındaki net bakiyelerini para birimine
göre toplar. (Friends'teki 1:1 bakiyeler ayrıca `GET /friends`'te görünür;
"overall" başlığı bu ikisini karıştırmaz — Groups sekmesindeki "Overall"
sadece normal gruplar, Friends sekmesindeki "Overall" sadece direct gruplar
üzerinden hesaplanır. Aşağıdaki örnek Groups sekmesi içindir.)

```json
{
  "overall_balances": [
    {
      "currency": "TRY",
      "net_amount_in_minor": -27522,
      "status": "you_owe"
    }
  ]
}
```

`status` değerleri: `"you_owe"` (negatif), `"you_are_owed"` (pozitif),
`"settled_up"` (sıfır). Kullanıcının hiç masrafı yoksa dizi boş döner
(`"overall_balances": []`), sıfır tutarlı bir TRY girişi değil.

## Endpoint 2 — Gruplar Listesi (genişletilmiş)

```
GET /api/v1/groups
```

Mevcut endpoint; `GroupSummaryResponse`'a 2 alan eklenir. `is_direct = true`
olan gruplar bu listeden **filtrelenir** (backend tarafında, query'de).

```json
{
  "groups": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Bursa",
      "description": null,
      "currency": "TRY",
      "member_count": 2,
      "current_user_role": "owner",
      "current_user_net_amount_in_minor": -27522,
      "status": "you_owe",
      "created_by": "6f1c2e10-6b1b-4b1b-9f1a-1a2b3c4d5e6f",
      "created_at": "2026-08-09T10:00:00Z",
      "updated_at": "2026-08-19T09:00:00Z",
      "archived_at": null
    },
    {
      "id": "6e2d5f21-7c2c-4c2c-8f2b-2b3c4d5e6f70",
      "name": "Proje",
      "description": null,
      "currency": "TRY",
      "member_count": 5,
      "current_user_role": "member",
      "current_user_net_amount_in_minor": 0,
      "status": "settled_up",
      "created_by": "6f1c2e10-6b1b-4b1b-9f1a-1a2b3c4d5e6f",
      "created_at": "2026-08-05T08:00:00Z",
      "updated_at": "2026-08-05T08:00:00Z",
      "archived_at": null
    }
  ]
}
```

`status`: `"you_owe"` / `"you_are_owed"` / `"settled_up"` / `"no_expenses"`
(grup kurulmuş ama hiç masraf/settlement yok — `settled_up`'tan farklıdır,
çünkü "hareketsiz" ile "kapanmış" UI'da farklı gösterilir).

**Performans notu:** `current_user_net_amount_in_minor` her grup için ayrı
`debt-summary` sorgusuyla değil, `GroupService.list_for_user` içinde tek
geçişte (kullanıcının tüm expense/share/settlement satırları bir kerede
çekilip group_id'ye göre gruplanarak) hesaplanmalı. N+1 sorgudan kaçının.

## Endpoint 3 — Arkadaşlar

```
GET /api/v1/friends
```

Kullanıcının `is_direct = true` gruplarını, karşı taraf bilgisiyle listeler.
İki kullanıcı arasında **hem** normal bir grupta **hem de** direct grupta
ortak masraf varsa, `net_amount_in_minor` bu ikisinin toplamıdır (Splitwise
mantığı — "bu arkadaşınla toplam durumun" sorusuna cevap verir).

```json
{
  "friends": [
    {
      "user_id": "7a3e6f32-8d3d-4d3d-9f3c-3c4d5e6f7081",
      "display_name": "Ege Başaran",
      "avatar_id": "man",
      "email": "ege@example.com",
      "direct_group_id": "8b4f7043-9e4e-4e4e-af4d-4d5e6f708192",
      "net_amount_in_minor": -27522,
      "currency": "TRY",
      "status": "you_owe",
      "shared_group_ids": ["550e8400-e29b-41d4-a716-446655440000"]
    }
  ]
}
```

`shared_group_ids`: bu kişiyle ortak olunan **normal** grupların id listesi
(boş olabilir — sadece direct'te ortak masrafları varsa). UI'da "ayrıca X
grubunda da ortaksınız" gibi bir ipucu göstermek isterse kullanılır,
zorunlu değil.

```
POST /api/v1/friends/{friend_user_id}/expenses
```

**Yeni kod yazılmaz** — bu endpoint sadece bir yönlendirme katmanıdır: aynı
payload şemasını (`ItemizedExpenseCreateRequest` / `receipt_draft` /
`receipt_id`, mevcut `POST /groups/{group_id}/expenses` ile birebir aynı
gövde) kabul eder, `GroupService.get_or_create_direct_group(current_user,
friend_user_id)` ile `group_id`'yi çözer, sonra mevcut
`create_itemized_expense` mantığını o `group_id` ile çağırır. OCR
(`receipt_draft`) akışı dahil, hiçbir OCR-özel kod eklenmez.

## Endpoint 3.1 — Arkadaşlık Daveti

Arkadaşlık, `POST /friends/{friend_user_id}/expenses` ile bir masraf
bölüştürüldüğünde **örtük** olarak da kurulabilir (bkz. Endpoint 3), ama bir
masraf olmadan da "arkadaş ekle" isteği gönderilebilmesi için ayrı bir
davet + kabul akışı vardır. Deseni `group_invitations` ile birebir aynıdır
(bkz. `app/services/group_invitation_service.py`): e-posta ile davet
gönderilir, davet edilen kişi 24 saat içinde token'ı kabul etmezse davet
geçersiz olur.

```
POST /api/v1/friends/invitations
```

```json
{ "email": "arkadas@example.com" }
```

Kimlik doğrulama gerektirir (`current_user` davet edici olur). Yanıt her
zaman aynıdır (hesap var/yok bilgisi sızdırılmaz):

```json
{ "status": "request_received" }
```

`202 Accepted`. Rate limit: kullanıcı başına saatte
`friend_invitation_user_hourly_limit` (varsayılan 20), davet edilen e-posta
başına günde `friend_invitation_email_daily_limit` (varsayılan 5) — limit
aşılırsa `429` + `{"code": "invitation_rate_limited"}`.

```
POST /api/v1/friend-invitations/{token}/accept
```

Kimlik doğrulama gerektirir. Davet edilen e-posta ile giriş yapan kullanıcı
(ve e-postası doğrulanmış olmalı) token'ı kabul eder;
`GroupService.get_or_create_direct_group` çağrılarak taraflar arasında
gizli direct grup kurulur (zaten varsa, o grup — ve o güne kadarki bakiyesi
— aynen kullanılır). Başarılı yanıt, davet edenin `GET /friends`'teki
karşılığıyla birebir aynı şekle sahiptir:

```json
{
  "friend": {
    "user_id": "6f1c2e10-6b1b-4b1b-9f1a-1a2b3c4d5e6f",
    "display_name": "Ege Başaran",
    "avatar_id": "man",
    "email": "ege@example.com",
    "direct_group_id": "8b4f7043-9e4e-4e4e-af4d-4d5e6f708192",
    "net_amount_in_minor": 0,
    "currency": "TRY",
    "status": "settled_up",
    "shared_group_ids": []
  }
}
```

`201 Created`. Hata kodları: `invitation_email_mismatch` (`403` — giriş
yapan kullanıcının doğrulanmış e-postası davetle eşleşmiyor),
`invitation_expired_or_used` (`410` — token bulunamadı, süresi dolmuş,
zaten kullanılmış ya da daveti gönderen kullanıcı artık yok),
`cannot_friend_self` (`422` — kendi e-postana davet gönderip kabul etmeye
çalışırsan).

## Endpoint 4 — Aktivite Geçmişi

```
GET /api/v1/activity?limit=20&before=<cursor>
```

`before` opsiyoneldir (ilk sayfada gönderilmez). `limit` varsayılan 20,
maksimum 50.

```json
{
  "items": [
    {
      "id": "9c5f8154-af5f-4f5f-b05e-5e6f70819203",
      "type": "expense_created",
      "actor": {
        "user_id": "6f1c2e10-6b1b-4b1b-9f1a-1a2b3c4d5e6f",
        "display_name": "Sen"
      },
      "group": {
        "id": "550e8400-e29b-41d4-a716-446655440000",
        "name": "Bursa",
        "is_direct": false
      },
      "expense_details": {
        "expense_id": "ad6e9265-b06f-4f6f-b16f-6f708192a3b4",
        "title": "Elektrik",
        "total_amount_in_minor": 30700,
        "currency": "TRY"
      },
      "impact": {
        "status": "you_are_owed",
        "amount_in_minor": 15350
      },
      "created_at": "2026-08-18T15:22:00Z"
    },
    {
      "id": "ae7fa376-c17f-4f7f-c27f-7f8192a3b4c5",
      "type": "settlement_created",
      "actor": {
        "user_id": "7a3e6f32-8d3d-4d3d-9f3c-3c4d5e6f7081",
        "display_name": "Ege B."
      },
      "group": {
        "id": "8b4f7043-9e4e-4e4e-af4d-4d5e6f708192",
        "name": "Ege Başaran",
        "is_direct": true
      },
      "settlement_details": {
        "settlement_id": "bf80b487-d280-4080-d380-8092a3b4c5d6",
        "from_user_id": "7a3e6f32-8d3d-4d3d-9f3c-3c4d5e6f7081",
        "to_user_id": "6f1c2e10-6b1b-4b1b-9f1a-1a2b3c4d5e6f",
        "amount_in_minor": 27522,
        "currency": "TRY"
      },
      "impact": {
        "status": "you_get_back",
        "amount_in_minor": 27522
      },
      "created_at": "2026-08-15T13:55:00Z"
    }
  ],
  "next_cursor": "eyJjcmVhdGVkX2F0IjoiMjAyNi0wOC0xNVQxMzo1NTowMFoiLCJpZCI6ImFlN2ZhMzc2LWMxN2YtNGY3Zi1jMjdmLTdmODE5MmEzYjRjNSJ9"
}
```

Son sayfadaysa `next_cursor: null` döner.

### Activity `type` → detay alanı eşlemesi

| `type` | Dolu detay alanı | `impact` var mı? |
|---|---|---|
| `expense_created` / `expense_updated` | `expense_details` | evet |
| `expense_deleted` | `expense_details` (silinen masrafın son hali) | hayır |
| `settlement_created` | `settlement_details` | evet |
| `member_joined` / `member_left` | `member_details: {user_id, display_name}` | hayır |
| `invitation_accepted` | `member_details` | hayır |

`impact` sadece parasal etkisi olan aktivitelerde bulunur
(`you_get_back` / `you_owe` / `you_are_owed`, `amount_in_minor` her zaman
pozitif, yön `status`'ten okunur). Diğer tiplerde `impact` alanı hiç
gönderilmez (null değil, key yok).

## Mock veri seti (frontend geliştirme için)

Yukarıdaki 4 örnek response, frontend'in model/parser yazması için
doğrudan kullanılabilir birer mock'tur — gerçek backend hazır olmadan bu
JSON'ları sabit dosyadan okuyarak (örn. `assets/mocks/`) UI geliştirmeye
başlanabilir. Alan adları/tipleri değişmeyecek şekilde sabitlenmiştir.
