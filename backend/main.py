import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import calendario, respostas
from core.config import settings

app = FastAPI(
    title="simplifICSA API",
    description="Backend de compliance regulatório e calendário para o simplifICSA.",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.origins_list(),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(calendario.router)
app.include_router(respostas.router)


@app.get("/health", tags=["Infra"])
def health() -> dict:
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
