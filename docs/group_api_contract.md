# Grup API Sözleşmesi

## Durum ve Amaç

- Sözleşme sürümü: `v1-draft-2`
- API taban yolu: `/api/v1`
- Kapsam: Grup, üyelik, grup masrafı, bölüştürme, ödeme ve borç özeti
- Ortak kullanıcılar: Backend, Flutter UI, borç sadeleştirme ve offline-sync ekipleri

Bu dosyadaki alan adları, enum değerleri, para birimi kuralları ve örnek JSON
şekilleri ekipler arasındaki ortak sözleşmedir. UI ekibi fake repository ve mock
JSON'ları bu sözleşmeye göre hazırlarken backend ekibi aynı şekilleri gerçek
PostgreSQL modelleri ve FastAPI endpointleriyle üretir.

Sözleşmede değişiklik gerekiyorsa doğrudan bir ekibin kodunda değiştirilmez.
Önce bu dosyaya PR açılır ve backend ile UI ekiplerinin onayı alınır.

## Değişiklik Kuralları

- Request alanının kaldırılması veya yeniden adlandırılması kırıcı değişikliktir.
- Enum değerinin kaldırılması veya yeniden adlandırılması kırıcı değişikliktir.
- Response'a opsiyonel alan eklenmesi geriye uyumlu değişikliktir.
- İstemciler response içindeki bilmedikleri yeni alanları yok saymalıdır.
- Backend, request içindeki sözleşme dışı alanları reddetmelidir.
- Bu sözleşmedeki kanonik mock kimlikleri test ve tasarım içindir; production
  verisi değildir.

## Genel Kurallar

### Kimlik Doğrulama

Bütün grup endpointleri aşağıdaki header'ı ister:

```http
Authorization: Bearer <access_token>
```

Token yoksa veya geçersizse `401`, grup yetkisi yetersizse `403` döner.

### Veri Biçimleri

| Veri | Kural | Örnek |
| --- | --- | --- |
| JSON alanları | `snake_case` | `member_count` |
| Kimlikler | UUID string | `10000000-0000-4000-8000-000000000001` |
| Tarih-saat | UTC RFC 3339 | `2026-08-10T10:00:00Z` |
| Sadece tarih | ISO 8601 | `2026-08-10` |
| Para | Kuruş cinsinden pozitif `int` | `12550` = 125,50 TL |
| Para birimi | ISO 4217, büyük harf | `TRY` |
| Yüzde | Basis point cinsinden `int` | `5000` = %50,00 |
| Ürün miktarı | Binde birim cinsinden `int` | `1500` = 1,500 adet |

API'de parasal değerler için `double` veya metin kullanılmaz. Yüzdelik
bölüştürmede kayan nokta hatasını önlemek için toplam `10000` basis point
olmalıdır.

Bu sözleşmede “para alanları `amount_in_minor: int` olacak” kuralı, bütün para
alanlarının kuruş cinsinden `int` olması ve adının `_in_minor` ile bitmesi
anlamına gelir. Model bağlamına göre sabit alan adları `amount_in_minor`,
`total_amount_in_minor` ve `net_amount_in_minor` olabilir. Bunların hiçbiri
`double`, ondalıklı metin veya TL cinsinden sayı olamaz.

Ürün miktarı da kayan noktalı sayı değildir. `quantity_share_milli` binde adet
cinsinden `int` kullanır: `1000` bir adet, `1500` bir buçuk adettir. Parasal
hesaplamada her zaman `amount_in_minor` esas alınır; miktar alanı ürün payını
kesin ve tekrarlanabilir biçimde ifade eder.

### Ortak Enum Değerleri

```text
group_role: owner | admin | member
split_type: equal | percentage | fixed_amount | itemized
share_status_v1: open
share_status_reserved_v2: partially_settled | settled
```

## Sabit Model Sözlüğü

Bu bölüm normatiftir. Backend DTO'ları, Flutter domain modelleri, fixture'lar
ve borç algoritması aynı alan adlarını kullanmalıdır.

### Group

| Alan | Tip | Zorunlu | Açıklama |
| --- | --- | --- | --- |
| `id` | UUID `String` | Evet | Grup kimliği |
| `name` | `String` | Evet | Grup adı |
| `description` | `String?` | Evet | Açıklama veya `null` |
| `currency` | `String` | Evet | İlk sürümde `TRY` |
| `member_count` | `int` | Evet | Aktif üye sayısı |
| `current_user_role` | `group_role` | Evet | Aktif kullanıcının rolü |
| `created_by` | UUID `String?` | Evet | Hesap silinmişse `null` |
| `created_at` | UTC `String` | Evet | Oluşturulma zamanı |
| `updated_at` | UTC `String` | Evet | Son güncelleme zamanı |
| `archived_at` | UTC `String?` | Evet | Aktif grupta `null` |

### GroupMember

| Alan | Tip | Zorunlu | Açıklama |
| --- | --- | --- | --- |
| `group_id` | UUID `String` | Evet | Üyeliğin bağlı olduğu grup |
| `user_id` | UUID `String` | Evet | Kullanıcı kimliği |
| `display_name` | `String` | Evet | UI gösterim adı |
| `role` | `group_role` | Evet | Üyelik rolü |
| `joined_at` | UTC `String` | Evet | Son katılma zamanı |
| `left_at` | UTC `String?` | Evet | Aktif üyede `null` |

### GroupExpense

| Alan | Tip | Zorunlu | Açıklama |
| --- | --- | --- | --- |
| `id` | UUID `String` | Evet | Masraf kimliği |
| `group_id` | UUID `String` | Evet | Grup kimliği |
| `receipt_id` | UUID `String?` | Evet | Fiş yoksa `null` |
| `payer_user_id` | UUID `String` | Evet | Ödeyen grup üyesi |
| `created_by` | UUID `String` | Evet | Kaydı oluşturan kullanıcı |
| `title` | `String` | Evet | Masraf başlığı |
| `note` | `String?` | Evet | Not veya `null` |
| `expense_date` | UTC `String` | Evet | Masraf zamanı |
| `total_amount_in_minor` | `int` | Evet | Toplam tutar |
| `currency` | `String` | Evet | Grup para birimi |
| `split_type` | `split_type` | Evet | Kullanılan bölüştürme |
| `is_financially_locked` | `bool` | Evet | Settlement sonrası finansal düzenleme kilidi |
| `shares` | `List<ExpenseShare>` | Evet | Nihai kişi payları |
| `line_item_assignments` | `List<ReceiptLineItemAssignment>` | Evet | Kalem atamaları |
| `created_at` | UTC `String` | Evet | Oluşturulma zamanı |
| `updated_at` | UTC `String` | Evet | Son güncelleme zamanı |
| `deleted_at` | UTC `String?` | Evet | Aktif kayıtta `null` |

### ExpenseShare

| Alan | Tip | Zorunlu | Açıklama |
| --- | --- | --- | --- |
| `expense_id` | UUID `String` | Evet | Payın bağlı olduğu masraf |
| `user_id` | UUID `String` | Evet | Pay sahibi |
| `display_name` | `String` | Evet | UI gösterim adı |
| `amount_in_minor` | `int` | Evet | Nihai pay tutarı |
| `status` | `share_status_v1` | Evet | v1'de daima `open` |
| `settled_at` | UTC `String?` | Evet | v1'de daima `null` |

### ReceiptLineItemAssignment

API ve Flutter tarafındaki sabit model adı `ReceiptLineItemAssignment` olur.
Backend veritabanı sınıfı farklı adlandırılsa bile JSON alanları değişmez.

| Alan | Tip | Zorunlu | Açıklama |
| --- | --- | --- | --- |
| `expense_id` | UUID `String` | Evet | Atamanın bağlı olduğu masraf |
| `receipt_line_item_id` | UUID `String` | Evet | Fiş ürün satırı |
| `user_id` | UUID `String` | Evet | Atanan grup üyesi |
| `amount_in_minor` | `int` | Evet | Üyeye düşen ürün tutarı |
| `quantity_share_milli` | `int?` | Evet | 1,500 adet için `1500`; bilinmiyorsa `null` |

### DebtTransfer

`DebtTransfer` istemci tarafından oluşturulan ayrı bir kayıt değildir. Saf borç
hesabının ve `DebtSummary` response'unun önerdiği transfer nesnesidir; algoritma
request'i Borç Algoritması bölümündeki `expense_balances` ve `settlements`
listeleridir.

| Alan | Tip | Zorunlu | Açıklama |
| --- | --- | --- | --- |
| `from_user_id` | UUID `String` | Evet | Ödeyecek kullanıcı |
| `to_user_id` | UUID `String` | Evet | Ödemeyi alacak kullanıcı |
| `amount_in_minor` | `int` | Evet | Transfer tutarı |

### Settlement

| Alan | Tip | Zorunlu | Açıklama |
| --- | --- | --- | --- |
| `id` | UUID `String` | Evet | Ödeme kaydı kimliği |
| `group_id` | UUID `String` | Evet | Grup kimliği |
| `from_user_id` | UUID `String` | Evet | Gönderen kullanıcı |
| `to_user_id` | UUID `String` | Evet | Alan kullanıcı |
| `amount_in_minor` | `int` | Evet | Ödeme tutarı |
| `currency` | `String` | Evet | Grup para birimi |
| `settled_at` | UTC `String` | Evet | Ödeme zamanı |
| `note` | `String?` | Evet | Not veya `null` |
| `created_at` | UTC `String` | Evet | Kayıt zamanı |

### DebtSummary

| Alan | Tip | Zorunlu | Açıklama |
| --- | --- | --- | --- |
| `group_id` | UUID `String` | Evet | Grup kimliği |
| `currency` | `String` | Evet | Grup para birimi |
| `balances` | `List<DebtBalance>` | Evet | Kullanıcı net bakiyeleri |
| `suggested_transfers` | `List<DebtTransfer>` | Evet | Sadeleştirilmiş transferler |
| `generated_at` | UTC `String` | Evet | Hesaplama zamanı |

`DebtBalance` alanları `user_id`, `display_name` ve `net_amount_in_minor` olur.
Pozitif net tutar alacağı, negatif net tutar borcu gösterir.

## Ortak Response Nesneleri

### GroupSummary

`GET /groups` listesindeki her grup şu şekildedir:

```json
{
  "id": "10000000-0000-4000-8000-000000000001",
  "name": "Ev Arkadaşları",
  "description": "Ortak ev masrafları",
  "currency": "TRY",
  "member_count": 4,
  "current_user_role": "owner",
  "created_by": "00000000-0000-4000-8000-000000000001",
  "created_at": "2026-08-10T10:00:00Z",
  "updated_at": "2026-08-10T10:00:00Z",
  "archived_at": null
}
```

### GroupMember

```json
{
  "group_id": "10000000-0000-4000-8000-000000000001",
  "user_id": "00000000-0000-4000-8000-000000000001",
  "display_name": "Zafer Tuna",
  "role": "owner",
  "joined_at": "2026-08-10T10:00:00Z",
  "left_at": null
}
```

Aktif üyelerde `left_at` daima `null` olur. Kullanıcının e-posta adresi grup
response'larında dönülmez.

### GroupDetail

```json
{
  "id": "10000000-0000-4000-8000-000000000001",
  "name": "Ev Arkadaşları",
  "description": "Ortak ev masrafları",
  "currency": "TRY",
  "member_count": 2,
  "current_user_role": "owner",
  "created_by": "00000000-0000-4000-8000-000000000001",
  "created_at": "2026-08-10T10:00:00Z",
  "updated_at": "2026-08-10T10:00:00Z",
  "archived_at": null,
  "members": [
    {
      "group_id": "10000000-0000-4000-8000-000000000001",
      "user_id": "00000000-0000-4000-8000-000000000001",
      "display_name": "Zafer Tuna",
      "role": "owner",
      "joined_at": "2026-08-10T10:00:00Z",
      "left_at": null
    },
    {
      "group_id": "10000000-0000-4000-8000-000000000001",
      "user_id": "00000000-0000-4000-8000-000000000002",
      "display_name": "Abdullah Seydi",
      "role": "member",
      "joined_at": "2026-08-10T10:05:00Z",
      "left_at": null
    }
  ]
}
```

### ExpenseShare

Backend bütün split türlerini kesin tutarlara dönüştürür. Response'ta UI'nın
göstereceği nihai paylar bulunur:

```json
{
  "expense_id": "40000000-0000-4000-8000-000000000001",
  "user_id": "00000000-0000-4000-8000-000000000002",
  "display_name": "Abdullah Seydi",
  "amount_in_minor": 6250,
  "status": "open",
  "settled_at": null
}
```

### GroupExpense

```json
{
  "id": "40000000-0000-4000-8000-000000000001",
  "group_id": "10000000-0000-4000-8000-000000000001",
  "receipt_id": null,
  "payer_user_id": "00000000-0000-4000-8000-000000000001",
  "created_by": "00000000-0000-4000-8000-000000000001",
  "title": "Aylık market alışverişi",
  "note": null,
  "expense_date": "2026-08-10T12:00:00Z",
  "total_amount_in_minor": 12500,
  "currency": "TRY",
  "split_type": "equal",
  "is_financially_locked": false,
  "shares": [
    {
      "expense_id": "40000000-0000-4000-8000-000000000001",
      "user_id": "00000000-0000-4000-8000-000000000001",
      "display_name": "Zafer Tuna",
      "amount_in_minor": 6250,
      "status": "open",
      "settled_at": null
    },
    {
      "expense_id": "40000000-0000-4000-8000-000000000001",
      "user_id": "00000000-0000-4000-8000-000000000002",
      "display_name": "Abdullah Seydi",
      "amount_in_minor": 6250,
      "status": "open",
      "settled_at": null
    }
  ],
  "line_item_assignments": [],
  "created_at": "2026-08-10T12:01:00Z",
  "updated_at": "2026-08-10T12:01:00Z",
  "deleted_at": null
}
```

### ReceiptLineItemAssignment

Response nesnesi aşağıdaki sabit alan isimlerini kullanır. Masraf oluşturma
request'inde masraf henüz oluşmadığı için `expense_id` gönderilmez; backend
oluşturduğu masrafın kimliğini response'a ekler:

```json
{
  "expense_id": "40000000-0000-4000-8000-000000000002",
  "receipt_line_item_id": "30000000-0000-4000-8000-000000000001",
  "user_id": "00000000-0000-4000-8000-000000000001",
  "amount_in_minor": 3000,
  "quantity_share_milli": 1000
}
```

### DebtTransfer

```json
{
  "from_user_id": "00000000-0000-4000-8000-000000000002",
  "to_user_id": "00000000-0000-4000-8000-000000000001",
  "amount_in_minor": 6250
}
```

### Settlement

```json
{
  "id": "50000000-0000-4000-8000-000000000001",
  "group_id": "10000000-0000-4000-8000-000000000001",
  "from_user_id": "00000000-0000-4000-8000-000000000002",
  "to_user_id": "00000000-0000-4000-8000-000000000001",
  "amount_in_minor": 2500,
  "currency": "TRY",
  "settled_at": "2026-08-11T09:00:00Z",
  "note": "Havale ile ödendi",
  "created_at": "2026-08-11T09:01:00Z"
}
```

## Endpoint Özeti

| Method | Yol | Yetki | Başarılı durum |
| --- | --- | --- | --- |
| `POST` | `/api/v1/groups` | Giriş yapmış kullanıcı | `201` |
| `GET` | `/api/v1/groups` | Giriş yapmış kullanıcı | `200` |
| `GET` | `/api/v1/groups/{group_id}` | Üye | `200` |
| `PATCH` | `/api/v1/groups/{group_id}` | Owner | `200` |
| `DELETE` | `/api/v1/groups/{group_id}` | Owner | `204` |
| `POST` | `/api/v1/groups/{group_id}/invitations` | Owner/Admin | `202` |
| `POST` | `/api/v1/group-invitations/{token}/accept` | Giriş yapmış kullanıcı | `201` |
| `POST` | `/api/v1/groups/{group_id}/members` | Yalnız development/mock | `201` |
| `PATCH` | `/api/v1/groups/{group_id}/members/{user_id}` | Owner | `200` |
| `DELETE` | `/api/v1/groups/{group_id}/members/{user_id}` | Owner/Admin | `204` |
| `DELETE` | `/api/v1/groups/{group_id}/members/me` | Üye | `204` |
| `POST` | `/api/v1/groups/{group_id}/expenses` | Üye | `201` |
| `GET` | `/api/v1/groups/{group_id}/expenses` | Üye | `200` |
| `GET` | `/api/v1/groups/{group_id}/expenses/{expense_id}` | Üye | `200` |
| `PATCH` | `/api/v1/groups/{group_id}/expenses/{expense_id}` | Oluşturan/Owner/Admin | `200` |
| `DELETE` | `/api/v1/groups/{group_id}/expenses/{expense_id}` | Oluşturan/Owner/Admin | `204` |
| `POST` | `/api/v1/groups/{group_id}/settlements` | Üye | `201` |
| `GET` | `/api/v1/groups/{group_id}/settlements` | Üye | `200` |
| `GET` | `/api/v1/groups/{group_id}/debts` | Üye | `200` |

## Task 1.1 Veritabanı Uyum Kararları

Bu kararlar API davranışının PostgreSQL modeliyle çelişmemesi için Task 1.1
uygulanmadan önce backend ekibi tarafından onaylanmalıdır:

- `Group.id` UUID primary key olur.
- `GroupMember` için `(group_id, user_id)` unique constraint kullanılır.
- Grup fiziksel olarak silinirse üyelikler `ON DELETE CASCADE` ile silinir.
- Normal API silme işlemi fiziksel silme değil, `archived_at` ile arşivlemedir.
- Kullanıcı hesabı fiziksel silindiğinde grubun kendisi silinmez.
- `GroupMember.user_id`, kullanıcı silinmesinde `ON DELETE CASCADE` uygular.
- `Group.created_by`, kullanıcı silinmesinde `ON DELETE SET NULL` uygular ve
  nullable olabilir. Bu nedenle response istemcileri `created_by: null`
  değerini kabul etmelidir.
- Hesabı silinen kişi grubun tek owner'ıysa servis aynı transaction içinde
  önce en eski aktif admini, admin yoksa en eski aktif üyeyi owner yapar.
  Başka aktif üye yoksa grup arşivlenir.
- Daha önce ayrılmış bir kullanıcı yeniden eklenirse yeni üyelik satırı
  oluşturulmaz; mevcut satır `joined_at` güncellenip `left_at = null` yapılarak
  tekrar aktifleştirilir.

## Grup Endpointleri

### Grup Oluşturma

```http
POST /api/v1/groups
```

Request:

```json
{
  "name": "Ev Arkadaşları",
  "description": "Ortak ev masrafları",
  "currency": "TRY"
}
```

Kurallar:

- `name`: Zorunlu, kırpıldıktan sonra 1-120 karakter.
- `description`: Opsiyonel, en fazla 1000 karakter.
- `currency`: Zorunlu, ilk sürümde yalnızca `TRY`.
- Grubu oluşturan kullanıcı otomatik olarak `owner` üyeliği kazanır.

Response `201`:

```json
{
  "group": {
    "id": "10000000-0000-4000-8000-000000000001",
    "name": "Ev Arkadaşları",
    "description": "Ortak ev masrafları",
    "currency": "TRY",
    "member_count": 1,
    "current_user_role": "owner",
    "created_by": "00000000-0000-4000-8000-000000000001",
    "created_at": "2026-08-10T10:00:00Z",
    "updated_at": "2026-08-10T10:00:00Z",
    "archived_at": null,
    "members": [
      {
        "group_id": "10000000-0000-4000-8000-000000000001",
        "user_id": "00000000-0000-4000-8000-000000000001",
        "display_name": "Zafer Tuna",
        "role": "owner",
        "joined_at": "2026-08-10T10:00:00Z",
        "left_at": null
      }
    ]
  }
}
```

### Grupları Listeleme

```http
GET /api/v1/groups?include_archived=false
```

Yalnızca aktif kullanıcının üye olduğu grupları döndürür.

Response `200`:

```json
{
  "groups": [
    {
      "id": "10000000-0000-4000-8000-000000000001",
      "name": "Ev Arkadaşları",
      "description": "Ortak ev masrafları",
      "currency": "TRY",
      "member_count": 4,
      "current_user_role": "owner",
      "created_by": "00000000-0000-4000-8000-000000000001",
      "created_at": "2026-08-10T10:00:00Z",
      "updated_at": "2026-08-10T10:00:00Z",
      "archived_at": null
    }
  ]
}
```

### Grup Detayı

```http
GET /api/v1/groups/{group_id}
```

Response `200`:

```json
{
  "group": "<GroupDetail>"
}
```

Buradaki `group`, yukarıdaki `GroupDetail` nesnesidir. Grup üyesi olmayan
kullanıcıya `403`, bulunmayan gruba `404` döner.

### Grup Güncelleme

```http
PATCH /api/v1/groups/{group_id}
```

Request alanlarının tamamı opsiyoneldir; en az biri gönderilmelidir:

```json
{
  "name": "Yeni Ev Grubu",
  "description": "Güncellenmiş açıklama"
}
```

Response `200`:

```json
{
  "group": "<GroupDetail>"
}
```

### Grup Arşivleme

```http
DELETE /api/v1/groups/{group_id}
```

Fiziksel silme yapmaz; `archived_at` alanını doldurur. Response `204` ve boş
body döner.

## Üyelik Endpointleri

### Production Üye Daveti

Mobil kullanıcıdan başka bir kullanıcının UUID değeri istenmez. Production
ortamında üyelik, doğrulanmış e-posta adresine gönderilen tek kullanımlık davet
bağlantısıyla başlatılır:

```http
POST /api/v1/groups/{group_id}/invitations
```

Request:

```json
{
  "email": "abdullah@example.com",
  "role": "member"
}
```

Response her durumda `202` ve aynı genel gövde olur:

```json
{
  "status": "request_received"
}
```

Güvenlik ve gizlilik kuralları:

- Response; e-posta kayıtlı, kayıtsız veya henüz doğrulanmamış olsa da değişmez.
- Response içinde `user_id`, kullanıcı varlığı, davet kimliği veya token dönmez.
- E-posta küçük harfe dönüştürülüp normalize edilir; loglarda açık e-posta
  yerine maskelenmiş veya hash'lenmiş değer kullanılır.
- Endpoint kullanıcı ve grup bazında rate-limit uygular.
- Owner `admin` veya `member`, admin yalnızca `member` davet edebilir.
- Davet token'ı tahmin edilemez, veritabanında hash'li, tek kullanımlık ve
  24 saat geçerli olur.
- Hesabı bulunmayan kişiye aynı bağlantı üzerinden kayıt ve e-posta doğrulama
  akışı sunulabilir; üyelik yalnızca doğrulama tamamlandıktan sonra oluşur.

Davet bağlantısını açan kullanıcı giriş yaptıktan sonra kabul eder:

```http
POST /api/v1/group-invitations/{token}/accept
```

Request body yoktur. Token'ın davet edildiği doğrulanmış e-posta ile giriş
yapan kullanıcının doğrulanmış e-postası aynı olmalıdır.

Response `201`:

```json
{
  "member": "<GroupMember>"
}
```

Aynı token ikinci kez kullanılırsa veya süresi dolmuşsa `410`, farklı
doğrulanmış e-posta ile kullanılmaya çalışılırsa `403` döner.

### Development/Mock Doğrudan Üye Ekleme

Bu akış yalnızca fake repository, fixture ve yerel entegrasyon testleri içindir.
Production ortamında kapalı olmalı ve route bulunmuyormuş gibi `404` dönmelidir.

```http
POST /api/v1/groups/{group_id}/members
```

Request:

```json
{
  "user_id": "00000000-0000-4000-8000-000000000002",
  "role": "member"
}
```

Response `201`:

```json
{
  "member": {
    "group_id": "10000000-0000-4000-8000-000000000001",
    "user_id": "00000000-0000-4000-8000-000000000002",
    "display_name": "Abdullah Seydi",
    "role": "member",
    "joined_at": "2026-08-10T10:05:00Z",
    "left_at": null
  }
}
```

Kurallar:

- Aynı kullanıcı aynı gruba iki kez eklenemez.
- Admin yalnızca `member` rolünde üye ekleyebilir.
- `admin` rolü verme ve owner devri yalnızca owner tarafından yapılabilir.
- Bu endpoint production UI veya Dio repository tarafından çağrılamaz.

### Üye Rolü Güncelleme ve Owner Devri

```http
PATCH /api/v1/groups/{group_id}/members/{user_id}
```

Request:

```json
{
  "role": "admin"
}
```

Response `200`:

```json
{
  "member": "<GroupMember>"
}
```

Mevcut tek owner başka üyeyi `owner` yaptığında owner'lık devredilir ve eski
owner `admin` olur. Bir grupta hiçbir zaman sıfır owner bulunamaz.

### Üye Çıkarma

```http
DELETE /api/v1/groups/{group_id}/members/{user_id}
```

Response `204` ve boş body döner.

- Admin, owner'ı veya başka bir admini çıkaramaz.
- Kullanıcı kendi çıkışı için `/members/me` yolunu kullanır.
- Son owner gruptan çıkamaz; önce owner devri gerekir.
- Çıkarılan üyeliğin `left_at` alanı doldurulur. Geçmiş masraf kayıtları
  korunur, fakat kullanıcı artık yeni grup işlemi yapamaz.

## Grup Masrafı ve Split Endpointleri

### Ortak Masraf Alanları

Bütün split türleri aynı endpoint üzerinden oluşturulur:

```http
POST /api/v1/groups/{group_id}/expenses
Idempotency-Key: <8-128 karakter benzersiz değer>
```

Ortak request alanları:

```json
{
  "receipt_id": null,
  "payer_user_id": "00000000-0000-4000-8000-000000000001",
  "title": "Aylık market alışverişi",
  "note": null,
  "expense_date": "2026-08-10T12:00:00Z",
  "total_amount_in_minor": 12500,
  "currency": "TRY",
  "split": {}
}
```

Kurallar:

- `payer_user_id` aktif bir grup üyesi olmalıdır.
- Masrafı oluşturan kullanıcı aktif bir grup üyesi olmalıdır.
- `total_amount_in_minor` sıfırdan büyük olmalıdır.
- Masraf para birimi grup para birimiyle aynı olmalıdır.
- `receipt_id` verilirse fiş aktif kullanıcıya ait olmalıdır.
- Aynı `Idempotency-Key` ve aynı body tekrar gönderilirse ilk response döner.
- Aynı `Idempotency-Key` farklı body ile kullanılırsa `409` döner.

Response `201`:

```json
{
  "expense": "<GroupExpense>"
}
```

### Eşit Bölüşüm

```json
{
  "split": {
    "type": "equal",
    "member_ids": [
      "00000000-0000-4000-8000-000000000001",
      "00000000-0000-4000-8000-000000000002"
    ]
  }
}
```

Kuruş kalanı request içindeki `member_ids` sırasına göre dağıtılır. Örneğin
100 kuruş üç kişi arasında `34, 33, 33` olarak paylaşılır.

### Yüzdelik Bölüşüm

```json
{
  "split": {
    "type": "percentage",
    "shares": [
      {
        "user_id": "00000000-0000-4000-8000-000000000001",
        "percentage_basis_points": 6000
      },
      {
        "user_id": "00000000-0000-4000-8000-000000000002",
        "percentage_basis_points": 4000
      }
    ]
  }
}
```

`percentage_basis_points` toplamı tam olarak `10000` olmalıdır. Kuruş kalanı
request sırasına göre dağıtılır.

### Sabit Tutar Bölüşümü

```json
{
  "split": {
    "type": "fixed_amount",
    "shares": [
      {
        "user_id": "00000000-0000-4000-8000-000000000001",
        "amount_in_minor": 7500
      },
      {
        "user_id": "00000000-0000-4000-8000-000000000002",
        "amount_in_minor": 5000
      }
    ]
  }
}
```

Payların toplamı `total_amount_in_minor` değerine eşit olmalıdır.

### Kalem Bazlı Bölüşüm

```json
{
  "receipt_id": "20000000-0000-4000-8000-000000000001",
  "payer_user_id": "00000000-0000-4000-8000-000000000001",
  "title": "Market fişi",
  "note": null,
  "expense_date": "2026-08-10T12:00:00Z",
  "total_amount_in_minor": 12500,
  "currency": "TRY",
  "split": {
    "type": "itemized",
    "line_items": [
      {
        "receipt_line_item_id": "30000000-0000-4000-8000-000000000001",
        "shares": [
          {
            "user_id": "00000000-0000-4000-8000-000000000001",
            "amount_in_minor": 3000,
            "quantity_share_milli": 1000
          },
          {
            "user_id": "00000000-0000-4000-8000-000000000002",
            "amount_in_minor": 3000,
            "quantity_share_milli": 1000
          }
        ]
      },
      {
        "receipt_line_item_id": "30000000-0000-4000-8000-000000000002",
        "shares": [
          {
            "user_id": "00000000-0000-4000-8000-000000000002",
            "amount_in_minor": 6000,
            "quantity_share_milli": 1000
          }
        ]
      }
    ],
    "extra_amount_shares": [
      {
        "user_id": "00000000-0000-4000-8000-000000000001",
        "amount_in_minor": 250
      },
      {
        "user_id": "00000000-0000-4000-8000-000000000002",
        "amount_in_minor": 250
      }
    ]
  }
}
```

Kurallar:

- Her `receipt_line_item_id`, `receipt_id` altındaki gerçek bir ürünü gösterir.
- Bir ürün birden fazla üyeye atanabilir.
- Ürün paylarının toplamı ürünün `price_in_minor` değerine eşit olmalıdır.
- `extra_amount_shares`; KDV, bahşiş, servis veya fiş-ürün toplam farkı için
  kullanılır.
- Ürün ve ekstra tutar paylarının toplamı masraf toplamına eşit olmalıdır.
- Atanmayan ürün varsa masraf oluşturulmaz ve `422` response içindeki
  `unassigned_receipt_line_item_ids` alanında bildirilir.
- Ürünü olmayan fişte `itemized` reddedilir; UI `equal`, `percentage` veya
  `fixed_amount` önermelidir.

Başarılı `GroupExpense` response'unda ayrıca aşağıdaki alan bulunur:

```json
{
  "line_item_assignments": [
    {
      "expense_id": "40000000-0000-4000-8000-000000000002",
      "receipt_line_item_id": "30000000-0000-4000-8000-000000000001",
      "user_id": "00000000-0000-4000-8000-000000000001",
      "amount_in_minor": 3000,
      "quantity_share_milli": 1000
    }
  ]
}
```

### Masraf Güncelleme

```http
PATCH /api/v1/groups/{group_id}/expenses/{expense_id}
```

Request'te en az bir alan gönderilmelidir. `title`, `note` ve `expense_date`
metadata alanlarıdır. Tutar, ödeyen veya split değişecekse
`financial_details` eksiksiz gönderilir:

```json
{
  "title": "Düzeltilmiş market alışverişi",
  "note": "Fiş yeniden kontrol edildi",
  "financial_details": {
    "receipt_id": null,
    "payer_user_id": "00000000-0000-4000-8000-000000000001",
    "total_amount_in_minor": 13000,
    "currency": "TRY",
    "split": {
      "type": "equal",
      "member_user_ids": [
        "00000000-0000-4000-8000-000000000001",
        "00000000-0000-4000-8000-000000000002"
      ]
    }
  }
}
```

Response `200`:

```json
{
  "expense": "<GroupExpense>"
}
```

Yetki ve kilit kuralları:

- Masrafı oluşturan kullanıcı kendi masrafını güncelleyebilir.
- Owner/Admin gruptaki bütün masrafları güncelleyebilir.
- `financial_details`, oluşturma endpointindeki bütün tutar ve split
  doğrulamalarından yeniden geçer.
- Masrafın `created_at` değerinden sonra aynı grupta en az bir settlement
  kaydedilmişse `is_financially_locked: true` olur. Bu durumda tutar, ödeyen,
  para birimi, fiş ve split değiştirilemez; deneme
  `409 expense_locked_by_settlement` döndürür.
- Kilitli masrafın yalnızca `title`, `note` ve `expense_date` metadata alanları
  güncellenebilir.
- V1'de settlement belirli bir `ExpenseShare` kaydına tahsis edilmediği için
  “tek masraf tamamen kapandı” durumu tutulmaz. Finansal kilit yukarıdaki
  settlement sınırına göre belirlenir.

### Masraf Silme

```http
DELETE /api/v1/groups/{group_id}/expenses/{expense_id}
```

- Masrafı oluşturan kullanıcı veya Owner/Admin silebilir.
- Silme `deleted_at` alanını dolduran soft delete işlemidir.
- `is_financially_locked: true` olan masraf silinemez ve
  `409 expense_locked_by_settlement` döner. V1'de düzeltme, yeni bir ters
  kayıtla yapılır; settlement geçmişi değiştirilmez.
- Başarılı response `204` ve boş body'dir.

### Masrafları Listeleme

```http
GET /api/v1/groups/{group_id}/expenses?cursor=<cursor>&limit=50
```

Response `200`:

```json
{
  "expenses": ["<GroupExpense>"],
  "next_cursor": null,
  "has_more": false
}
```

`limit` en az `1`, en fazla `100` olabilir. Varsayılan `50` olur.

## Settlement Endpointleri

### Ödeme Kaydetme

```http
POST /api/v1/groups/{group_id}/settlements
Idempotency-Key: <8-128 karakter benzersiz değer>
```

Request:

```json
{
  "from_user_id": "00000000-0000-4000-8000-000000000002",
  "to_user_id": "00000000-0000-4000-8000-000000000001",
  "amount_in_minor": 2500,
  "currency": "TRY",
  "settled_at": "2026-08-11T09:00:00Z",
  "note": "Havale ile ödendi"
}
```

Kurallar:

- `from_user_id` access token sahibinin kullanıcı kimliği olmalıdır.
- Gönderen ve alan aktif grup üyesi olmalıdır.
- Kullanıcı kendine ödeme yapamaz.
- Tutar sıfırdan büyük ve grup para biriminde olmalıdır.
- Idempotency davranışı grup masrafıyla aynıdır.

Response `201`:

```json
{
  "settlement": {
    "id": "50000000-0000-4000-8000-000000000001",
    "group_id": "10000000-0000-4000-8000-000000000001",
    "from_user_id": "00000000-0000-4000-8000-000000000002",
    "to_user_id": "00000000-0000-4000-8000-000000000001",
    "amount_in_minor": 2500,
    "currency": "TRY",
    "settled_at": "2026-08-11T09:00:00Z",
    "note": "Havale ile ödendi",
    "created_at": "2026-08-11T09:01:00Z"
  }
}
```

### Settlement'ın Net Borca ve Share Durumuna Etkisi

- Settlement kayıtları grup net borç hesabına dahil edilir ve silinmez.
- `from_user_id` bakiyesi `amount_in_minor` kadar artırılır; borcu azalır.
- `to_user_id` bakiyesi aynı tutarda azaltılır; alacağı azalır.
- Örnekte settlement öncesi Zafer `6250` alacaklı, Abdullah `-6250`
  borçludur. Abdullah'ın Zafer'e `2500` ödemesinden sonra net bakiyeler
  sırasıyla `3750` ve `-3750` olur.
- V1 settlement'ları belirli bir masraf veya `ExpenseShare` kaydına tahsis
  edilmez. Bu nedenle `ExpenseShare.status` v1'de daima `open`,
  `ExpenseShare.settled_at` daima `null` kalır.
- `partially_settled` ve `settled` değerleri masraf-pay tahsisi tasarlandığında
  kullanılmak üzere v2 için ayrılmıştır. UI v1'de ödeme durumunu
  `DebtSummary` ve settlement geçmişinden gösterir.

## Borç Algoritması ve Özet Sözleşmesi

Borç algoritmasında pozitif `net_amount_in_minor` kullanıcının alacaklı,
negatif değer borçlu olduğunu gösterir. Bütün net tutarların toplamı sıfırdır.

Saf algoritmanın ortak mock girdisi:

```json
{
  "currency": "TRY",
  "expense_balances": [
    {
      "user_id": "00000000-0000-4000-8000-000000000001",
      "net_amount_in_minor": 6250
    },
    {
      "user_id": "00000000-0000-4000-8000-000000000002",
      "net_amount_in_minor": -6250
    }
  ],
  "settlements": [
    {
      "from_user_id": "00000000-0000-4000-8000-000000000002",
      "to_user_id": "00000000-0000-4000-8000-000000000001",
      "amount_in_minor": 2500
    }
  ]
}
```

Saf algoritmanın çıktısı ve `GET /groups/{group_id}/debts` response'u:

```json
{
  "group_id": "10000000-0000-4000-8000-000000000001",
  "currency": "TRY",
  "balances": [
    {
      "user_id": "00000000-0000-4000-8000-000000000001",
      "display_name": "Zafer Tuna",
      "net_amount_in_minor": 3750
    },
    {
      "user_id": "00000000-0000-4000-8000-000000000002",
      "display_name": "Abdullah Seydi",
      "net_amount_in_minor": -3750
    }
  ],
  "suggested_transfers": [
    {
      "from_user_id": "00000000-0000-4000-8000-000000000002",
      "to_user_id": "00000000-0000-4000-8000-000000000001",
      "amount_in_minor": 3750
    }
  ],
  "generated_at": "2026-08-11T09:05:00Z"
}
```

Sadeleştirme algoritması deterministik olmalıdır. Eşit adaylarda UUID'nin
alfabetik sırası kullanılır. Sıfır tutarlı transfer response'a eklenmez.

## Hata Sözleşmesi

Yeni grup endpointleri aynı hata zarfını kullanır:

```json
{
  "detail": {
    "code": "invalid_split_total",
    "message": "Payların toplamı masraf toplamına eşit olmalıdır.",
    "field_errors": [
      {
        "field": "split.shares",
        "message": "Beklenen 12500, gelen 12000."
      }
    ],
    "unassigned_receipt_line_item_ids": []
  }
}
```

`field_errors` ve `unassigned_receipt_line_item_ids` opsiyoneldir.

| HTTP | code | Kullanım |
| --- | --- | --- |
| `400` | `invalid_request` | İş kuralına uymayan genel request |
| `401` | `unauthorized` | Geçersiz veya eksik token |
| `403` | `group_forbidden` | Grup veya rol yetkisi yok |
| `403` | `invitation_email_mismatch` | Davet ile giriş hesabının e-postası farklı |
| `404` | `group_not_found` | Grup bulunamadı |
| `404` | `member_not_found` | Üye bulunamadı |
| `404` | `expense_not_found` | Masraf bulunamadı |
| `409` | `member_already_exists` | Aynı aktif üyelik zaten var |
| `409` | `last_owner_required` | Son owner ayrılamaz/çıkarılamaz |
| `409` | `idempotency_conflict` | Anahtar farklı request ile kullanıldı |
| `409` | `expense_locked_by_settlement` | Settlement sonrası finansal değişiklik yasak |
| `410` | `invitation_expired_or_used` | Davet süresi dolmuş veya daha önce kullanılmış |
| `422` | `invalid_split_total` | Pay toplamı masrafla eşleşmiyor |
| `422` | `invalid_percentage_total` | Yüzde toplamı `10000` değil |
| `422` | `unassigned_line_items` | Atanmayan ürünler bulunuyor |
| `422` | `currency_mismatch` | Masraf para birimi grupla farklı |
| `429` | `invitation_rate_limited` | Çok fazla davet isteği gönderildi |
| `503` | `service_unavailable` | Grup servisine geçici olarak ulaşılamıyor |

## Kanonik UI Mock Verisi

UI ve widget testleri rastgele alan isimleri üretmek yerine aşağıdaki response
şeklini başlangıç fixture'ı olarak kullanır:

```json
{
  "groups": [
    {
      "id": "10000000-0000-4000-8000-000000000001",
      "name": "Ev Arkadaşları",
      "description": "Ortak ev masrafları",
      "currency": "TRY",
      "member_count": 4,
      "current_user_role": "owner",
      "created_by": "00000000-0000-4000-8000-000000000001",
      "created_at": "2026-08-10T10:00:00Z",
      "updated_at": "2026-08-10T10:00:00Z",
      "archived_at": null
    },
    {
      "id": "10000000-0000-4000-8000-000000000002",
      "name": "Ulutek Ekibi",
      "description": "Ekip içi ortak harcamalar",
      "currency": "TRY",
      "member_count": 9,
      "current_user_role": "member",
      "created_by": "00000000-0000-4000-8000-000000000003",
      "created_at": "2026-08-10T11:00:00Z",
      "updated_at": "2026-08-10T11:00:00Z",
      "archived_at": null
    }
  ]
}
```

Fake repository en az şu davranışları taklit etmelidir:

- Listeleme yalnızca kullanıcının üye olduğu grupları döndürür.
- Grup oluşturulduğunda aktif kullanıcı owner olur.
- Aynı üye tekrar eklendiğinde `member_already_exists` hatası üretir.
- Yetkisiz güncellemede `group_forbidden` hatası üretir.
- Split hesaplarından sonra response'ta nihai `amount_in_minor` değerlerini
  döndürür.
- Idempotency testinde aynı anahtar aynı nesneyi, farklı body ise conflict
  hatasını döndürür.

## UI Mock Senaryo Matrisi

UI ekibi aşağıdaki fixture adlarını ve sözleşme nesnelerini ortak olarak
kullanır. Fixture'lar yeni alan üretemez; yalnızca bu dosyada tanımlanan model
ve enum değerlerini kullanabilir.

| Fixture adı | Tür/durum | Zorunlu içerik |
|---|---|---|
| `emptyGroupsResponse` | Grup listesi response'u | `groups` boş liste |
| `twoMemberGroup` | `GroupDetail` | Zafer owner, Abdullah member; `member_count: 2` |
| `fourMemberGroup` | `GroupDetail` | Bir owner, bir admin, iki member; `member_count: 4` |
| `currentUserDebtorDebtSummary` | `DebtSummary` | Aktif kullanıcının `net_amount_in_minor` değeri negatif |
| `currentUserCreditorDebtSummary` | `DebtSummary` | Aktif kullanıcının `net_amount_in_minor` değeri pozitif |
| `itemizedMarketExpense` | `GroupExpense` | `split_type: itemized`, fiş kimliği ve ürün atamaları dolu |
| `fastSplitTransferExpense` | `GroupExpense` | `split_type: equal`, `receipt_id: null`, ürün ataması yok |
| `groupsLoading` | Repository durumu | Riverpod `AsyncLoading`; API response modeli değildir |
| `groupsApiError` | Repository durumu | Aşağıdaki standart hata nesnesiyle `AsyncError` |

Boş grup ve API hata fixture'larının sabit JSON değerleri:

```json
{
  "groups": []
}
```

```json
{
  "detail": {
    "code": "service_unavailable",
    "message": "Grup bilgileri şu anda alınamıyor.",
    "field_errors": []
  }
}
```

Borç senaryolarında aktif kullanıcı kimliği
`00000000-0000-4000-8000-000000000001` olarak sabittir:

- `currentUserDebtorDebtSummary`: aktif kullanıcı için
  `net_amount_in_minor: -6250`; karşı üye için `6250`.
- `currentUserCreditorDebtSummary`: aktif kullanıcı için
  `net_amount_in_minor: 6250`; karşı üye için `-6250`.

`itemizedMarketExpense`, Kalem Bazlı Bölüşüm bölümündeki request'in
`GroupExpense` response'una dönüştürülmüş halidir. Her ürün ataması
`ReceiptLineItemAssignment` modelini kullanır. `fastSplitTransferExpense`,
Ortak Response Nesneleri bölümündeki `GroupExpense` örneğini kullanır.

### Repository Değiştirme Noktası

- UI widget'ları doğrudan `FakeGroupRepository` veya `DioGroupRepository`
  sınıfına değil, ortak bir `GroupRepository` arayüzüne bağımlı olur.
- `groupRepositoryProvider`, `GroupRepository` türünü sağlar ve testlerde
  Riverpod `ProviderScope.overrides` ile değiştirilebilir olur.
- Loading ve API hata senaryoları domain modeline sahte alan eklenerek değil,
  provider'ın async durumu üzerinden temsil edilir.
- Gerçek endpointler hazır olduğunda yalnızca provider'ın ürettiği repository
  `FakeGroupRepository` yerine `DioGroupRepository` olur; widget kodu ve domain
  modelleri değişmez.

Bu matrisin hedef dosyaları:

- `fis_uygulamasi/lib/features/groups/domain/group_models.dart`
- `fis_uygulamasi/test/fixtures/group_fixtures.dart`
- `fis_uygulamasi/lib/features/groups/data/fake_group_repository.dart`

## Backend ve UI Sınırı

Backend sorumlulukları:

- Yetki, constraint ve split toplamlarını doğrulamak.
- Para ve yüzde hesaplarını deterministik yapmak.
- Request'i nihai `ExpenseShare` tutarlarına dönüştürmek.
- Idempotency ve soft-delete davranışını uygulamak.
- Response'ları bu sözleşmeyle birebir üretmek.

UI sorumlulukları:

- Bu sözleşmeye karşı DTO ve repository arayüzlerini yazmak.
- İlk aşamada aynı JSON şekillerini `FakeGroupRepository` üzerinden sağlamak.
- Kullanıcı girişini göndermeden önce temel form doğrulaması yapmak.
- Backend hata `code` değerlerini kullanıcı dostu Türkçe mesajlara çevirmek.
- Gerçek API hazır olduğunda yalnızca repository implementasyonunu
  `DioGroupRepository` ile değiştirmek; ekranları yeniden yazmamak.

## İlk Gün Ortak Onay Listesi

- [ ] Backend ve UI ekipleri alan adlarını onayladı.
- [ ] UUID, UTC, minor-unit ve yüzde basis-point kararları onaylandı.
- [ ] Grup ve üye response şekilleri onaylandı.
- [ ] Fast Split request şekilleri onaylandı.
- [ ] Itemized Split request şekli onaylandı.
- [ ] Settlement request/response şekli onaylandı.
- [ ] Borç algoritması input/output şekli onaylandı.
- [ ] Hata kodları onaylandı.
- [ ] Production e-posta daveti ve kullanıcı gizliliği kuralları onaylandı.
- [ ] `quantity_share_milli` tamsayı miktar gösterimi onaylandı.
- [ ] Masraf güncelleme/silme yetkisi ve settlement kilidi onaylandı.
- [ ] Settlement'ın net borca etkisi ve v1 share-status davranışı onaylandı.
- [ ] UI fake repository kanonik mock JSON ile başlatıldı.
- [ ] Sözleşme PR'ı merge edilmeden model veya UI alan adları sabitlenmedi.
