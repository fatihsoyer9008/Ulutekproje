# FişKon Flutter uygulaması

## OCR ve backend yapılandırması

Android emülatöründe backend varsayılan olarak
`http://10.0.2.2:8000` adresinden çağrılır. Fiziksel cihazda veya yayınlanmış
backend ile çalışırken API adresini `dart-define` ile verin:

```powershell
flutter run --dart-define=RECEIPT_API_BASE_URL=https://api-adresiniz
```

Akış: kamera ile fiş tarama → cihaz içi OCR → FastAPI ayrıştırma → kullanıcı
onay ekranı. HTTP erişimi yalnız debug Android manifestinde yerel geliştirme
için açıktır; yayın ortamında HTTPS kullanılmalıdır.

## Kontroller

```powershell
flutter analyze
flutter test
```
