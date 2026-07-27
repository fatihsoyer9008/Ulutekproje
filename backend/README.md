# Receipt Parser API

Flutter uygulaması ile ilerideki fiş ayrıştırma servisi arasındaki FastAPI iskeleti.

## Yerelde çalıştırma

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Sunucu çalıştığında `http://127.0.0.1:8000/health` adresi `status: ok` döndürür.

