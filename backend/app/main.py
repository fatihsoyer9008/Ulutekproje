from fastapi import FastAPI

from app.api.v1.receipts import router as receipts_router
from app.core.config import settings

app = FastAPI(title=settings.app_name, version="0.1.0")
app.include_router(receipts_router)


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    return {"status": "ok", "environment": settings.app_env}

