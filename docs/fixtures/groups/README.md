# Grup UI Mock Fixture'ları

Bu klasördeki raw JSON fixture'larının normatif kaynağı
[`docs/group_api_contract.md`](../../group_api_contract.md) dosyasıdır.
Flutter tarafındaki karşılıkları
`fis_uygulamasi/test/fixtures/group_fixtures.dart` içinde bulunur.

| Dosya | Sözleşme modeli |
|---|---|
| `group.json` | `Group` |
| `group_member.json` | `GroupMember` |
| `group_expense.json` | `GroupExpense` |
| `expense_share.json` | `ExpenseShare` |

Borç fixture'ları kardeş `group_debts` klasöründedir. Bütün parasal alanlar
kuruş cinsinden `int`, kimlikler UUID `String` ve tarihler UTC RFC 3339
biçimindedir. Flutter testleri bu dosyaları Dart fixture'larıyla karşılaştırarak
iki temsilin aynı kalmasını güvence altına alır.
