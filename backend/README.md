# Receipt Parser API

Flutter istemcisi ile yapay zeka/fiş işleme katmanı arasındaki yerel FastAPI köprüsüdür.

## Çalıştırma

Python 3.11 veya üzerini kurduktan sonra, bu klasörde aşağıdaki komutları çalıştırın:

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

Sunucu `http://127.0.0.1:8000` üzerinde açılır. İnteraktif sözleşme dokümanı: `http://127.0.0.1:8000/docs`.

## Test endpoint'i

`POST /api/v1/parse-receipt` şu aşamada yapay zeka yerine sabit, sözleşmeye uygun veri döndürür. İstek gövdesi opsiyoneldir:

```json
{
  "image_base64": "...",
  "file_name": "market-fisi.jpg"
}
```

Tutarlar daima `*_minor` alanlarında kuruş cinsinden `int` olarak taşınır. Örneğin `32760`, `₺327,60` anlamına gelir.

