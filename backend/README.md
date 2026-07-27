# Receipt Parser API

Flutter uygulaması ile ilerideki fiş ayrıştırma servisi arasındaki FastAPI iskeleti.

## Yerelde çalıştırma

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
Copy-Item .env.example .env
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Sunucu çalıştığında `http://127.0.0.1:8000/health` adresi `status: ok` döndürür.

## Fiş ayrıştırma

`POST /api/v1/parse-receipt` uç noktası cihaz içi OCR metnini alır:

```json
{
  "ocr_text": "MİGROS TOPLAM 220,50 TL"
}
```

Yerel frontend geliştirmesinde `.env` içindeki `USE_DUMMY_PARSER=true` bırakılabilir.
Gerçek Gemini ayrıştırmasını kullanmak için:

```dotenv
GEMINI_API_KEY=your-api-key
GEMINI_MODEL=gemini-3.5-flash-lite
USE_DUMMY_PARSER=false
```

API anahtarını içeren `.env` dosyası Git tarafından yok sayılır; bu dosyayı commit etmeyin.

Telefonun aynı Wi-Fi ağından sunucuya erişmesi gerekiyorsa Uvicorn'u
`--host 0.0.0.0` ile başlatın ve Flutter tarafında bilgisayarın yerel IP adresini kullanın.

## Testler

```powershell
pip install -r requirements-dev.txt
pytest
```

