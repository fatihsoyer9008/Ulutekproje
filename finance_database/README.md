# Finance Database

Uygulamanın Isar koleksiyonları, generated schema dosyaları ve repository
katmanı bu pakette yaşar. `fis_uygulamasi`, açılan tek Isar instance'ını
Riverpod provider'ları üzerinden kullanır.

Model veya index alanı değiştirildikten sonra paket dizininde code generation
çalıştırılmalıdır:

```powershell
cd finance_database
flutter pub run build_runner build --delete-conflicting-outputs
```
