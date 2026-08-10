# Grup Borç Mock Fixture'ları

Bu klasördeki dosyaların normatif kaynağı
[`docs/group_api_contract.md`](../../group_api_contract.md) dosyasındaki
`DebtTransfer`, `DebtSummary`, `Settlement` ve **Borç Algoritması ve Özet
Sözleşmesi** bölümleridir. Buradaki fixture'lar yeni alan tanımlamaz.

## Modeller

### DebtBalance

| Alan | Tip | Anlam |
|---|---|---|
| `user_id` | UUID `String` | Kullanıcı kimliği |
| `display_name` | `String` | UI gösterim adı |
| `net_amount_in_minor` | `int` | Pozitifse alacak, negatifse borç |

### DebtTransfer

| Alan | Tip | Anlam |
|---|---|---|
| `from_user_id` | UUID `String` | Ödeyecek kullanıcı |
| `to_user_id` | UUID `String` | Ödemeyi alacak kullanıcı |
| `amount_in_minor` | `int` | Kuruş cinsinden transfer tutarı |

### DebtSummary

| Alan | Tip | Anlam |
|---|---|---|
| `group_id` | UUID `String` | Grup kimliği |
| `currency` | `String` | ISO 4217 para birimi |
| `balances` | `List<DebtBalance>` | Üyelerin net bakiyeleri |
| `suggested_transfers` | `List<DebtTransfer>` | Sadeleştirilmiş transferler |
| `generated_at` | UTC `String` | Hesaplama zamanı |

## Saf Algoritma Sözleşmesi

Algoritma girdisi `currency`, `expense_balances` ve `settlements` alanlarından
oluşur. Settlement, gönderenin bakiyesini `amount_in_minor` kadar artırır ve
alanın bakiyesini aynı tutarda azaltır. Çıktı bir `DebtSummary` nesnesidir.

Kurallar:

- Bütün para alanları kuruş cinsinden `int` değeridir.
- Net bakiyelerin toplamı daima sıfırdır.
- Sıfır tutarlı transfer oluşturulmaz.
- Negatif bakiyeli kullanıcı öder, pozitif bakiyeli kullanıcı alır.
- Eşit adaylarda UUID alfabetik sırası kullanılır.
- Kimlikler UUID string, `generated_at` UTC RFC 3339 biçimindedir.

## Fixture Matrisi

| Dosya | Senaryo |
|---|---|
| `debt_algorithm_input_2_members.json` | Settlement içeren iki üyeli algoritma girdisi |
| `debt_summary_2_members.json` | Aktif kullanıcının borçlu olduğu iki üyeli çıktı |
| `debt_summary_2_members_current_user_creditor.json` | Aktif kullanıcının alacaklı olduğu UI çıktısı |
| `debt_algorithm_input_3_members.json` | Settlement içeren üç üyeli algoritma girdisi |
| `debt_summary_3_members.json` | Bir borçlu ve iki alacaklı sadeleştirilmiş çıktı |
| `debt_algorithm_input_5_members.json` | İki settlement ve eşit alacaklı içeren beş üyeli girdi |
| `debt_summary_5_members.json` | İki borçlu ve üç alacaklı sadeleştirilmiş çıktı |

UI fixture eşlemesi:

- `currentUserDebtorDebtSummary` → `debt_summary_2_members.json`
- `currentUserCreditorDebtSummary` →
  `debt_summary_2_members_current_user_creditor.json`

Gerçek API hazır olduğunda bu JSON şekilleri değişmeden Dio repository response'u
olarak deserialize edilmelidir.
