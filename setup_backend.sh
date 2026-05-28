#!/usr/bin/env bash
# setup_backend.sh — Cria a fundação do backend FastAPI do simplifICSA
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND="$ROOT/backend"

echo "▶ Criando estrutura de pastas..."
mkdir -p "$BACKEND/routers"
mkdir -p "$BACKEND/models"
mkdir -p "$BACKEND/core"

# ─────────────────────────────────────────────────────────────────────────────
# requirements.txt
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/requirements.txt" << 'EOF'
fastapi==0.111.0
uvicorn[standard]==0.29.0
pydantic==2.7.1
pydantic-settings==2.3.1
python-dotenv==1.0.1
httpx==0.27.0
EOF

# ─────────────────────────────────────────────────────────────────────────────
# .env (template — nunca commitar com valores reais)
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/.env.example" << 'EOF'
GROQ_API_KEY=your_groq_api_key_here
ALLOWED_ORIGINS=http://localhost:3000,https://simplificsa.onrender.com
EOF

# ─────────────────────────────────────────────────────────────────────────────
# core/config.py — settings centralizadas via pydantic-settings
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/core/config.py" << 'EOF'
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    groq_api_key: str = ""
    allowed_origins: str = "http://localhost:3000"

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    def origins_list(self) -> list[str]:
        return [o.strip() for o in self.allowed_origins.split(",")]


settings = Settings()
EOF

# ─────────────────────────────────────────────────────────────────────────────
# models/calendario.py
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/models/calendario.py" << 'EOF'
from datetime import date
from pydantic import BaseModel


class Etapa(BaseModel):
    titulo: str
    dias_estimados: int


class AgendamentoRequest(BaseModel):
    setor: str
    porte: str          # "A" | "B"
    data_inicio: date
    etapas: list[Etapa]


class EtapaComData(BaseModel):
    titulo: str
    dias_estimados: int
    data_conclusao: date


class AgendamentoResponse(BaseModel):
    setor: str
    porte: str
    data_inicio: date
    cronograma: list[EtapaComData]
EOF

# ─────────────────────────────────────────────────────────────────────────────
# models/respostas.py
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/models/respostas.py" << 'EOF'
from pydantic import BaseModel


class Mensagem(BaseModel):
    role: str   # "user" | "assistant"
    content: str


class ChatRequest(BaseModel):
    setor: str
    porte: str
    contexto_extra: str = ""
    historico: list[Mensagem] = []
    pergunta: str


class ChatResponse(BaseModel):
    resposta: str
EOF

# ─────────────────────────────────────────────────────────────────────────────
# routers/calendario.py
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/routers/calendario.py" << 'EOF'
from datetime import timedelta
from fastapi import APIRouter
from models.calendario import AgendamentoRequest, AgendamentoResponse, EtapaComData

router = APIRouter(prefix="/calendario", tags=["Calendário"])


@router.post("/calcular", response_model=AgendamentoResponse)
def calcular_cronograma(payload: AgendamentoRequest) -> AgendamentoResponse:
    """
    Recebe uma lista de etapas com dias_estimados e uma data_inicio.
    Retorna o cronograma com a data_conclusao calculada sequencialmente.

    TODO: persistir agendamentos em banco de dados.
    """
    cronograma: list[EtapaComData] = []
    data_corrente = payload.data_inicio

    for etapa in payload.etapas:
        data_corrente = data_corrente + timedelta(days=etapa.dias_estimados)
        cronograma.append(
            EtapaComData(
                titulo=etapa.titulo,
                dias_estimados=etapa.dias_estimados,
                data_conclusao=data_corrente,
            )
        )

    return AgendamentoResponse(
        setor=payload.setor,
        porte=payload.porte,
        data_inicio=payload.data_inicio,
        cronograma=cronograma,
    )
EOF

# ─────────────────────────────────────────────────────────────────────────────
# routers/respostas.py
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/routers/respostas.py" << 'EOF'
import httpx
from fastapi import APIRouter, HTTPException
from models.respostas import ChatRequest, ChatResponse
from core.config import settings

router = APIRouter(prefix="/respostas", tags=["Respostas IA"])

GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "llama3-8b-8192"


def _build_system_prompt(setor: str, porte: str, contexto_extra: str) -> str:
    base = (
        "Você é o assistente do simplifICSA, especialista em direito ambiental "
        "e regulatório para indústrias em Mariana/MG.\n\n"
        f"CONTEXTO DA EMPRESA:\n"
        f"- Setor: {setor}\n"
        f"- Porte: {porte}\n"
    )
    if contexto_extra:
        base += f"- Informações adicionais: {contexto_extra}\n"
    base += "\nResponda de forma objetiva e sempre cite a legislação pertinente."
    return base


@router.post("/chat", response_model=ChatResponse)
async def chat(payload: ChatRequest) -> ChatResponse:
    """
    Proxy seguro para a API Groq. A chave nunca é exposta ao frontend.

    TODO: adicionar rate limiting e cache de respostas.
    """
    if not settings.groq_api_key:
        raise HTTPException(status_code=503, detail="GROQ_API_KEY não configurada no servidor.")

    system_prompt = _build_system_prompt(payload.setor, payload.porte, payload.contexto_extra)

    messages = [{"role": "system", "content": system_prompt}]
    for msg in payload.historico:
        messages.append({"role": msg.role, "content": msg.content})
    messages.append({"role": "user", "content": payload.pergunta})

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            GROQ_URL,
            headers={
                "Authorization": f"Bearer {settings.groq_api_key}",
                "Content-Type": "application/json",
            },
            json={"model": GROQ_MODEL, "messages": messages, "temperature": 0.5, "max_tokens": 1024},
        )

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    data = resp.json()
    resposta = data["choices"][0]["message"]["content"].strip()
    return ChatResponse(resposta=resposta)
EOF

# ─────────────────────────────────────────────────────────────────────────────
# main.py — entrypoint da aplicação
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/main.py" << 'EOF'
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
EOF

# ─────────────────────────────────────────────────────────────────────────────
# Dockerfile — multi-stage build
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/Dockerfile" << 'EOF'
# ── Stage 1: dependências ───────────────────────────────────────────────────
FROM python:3.12-slim AS builder

WORKDIR /app

# Instala dependências em camada separada para cache eficiente
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: imagem final enxuta ────────────────────────────────────────────
FROM python:3.12-slim AS runner

WORKDIR /app

# Copia apenas as libs instaladas (sem pip, setuptools, etc.)
COPY --from=builder /install /usr/local

# Copia o código da aplicação
COPY . .

# Render injeta $PORT em runtime; uvicorn lê via shell exec
CMD ["sh", "-c", "uvicorn main:app --host 0.0.0.0 --port ${PORT:-8000}"]
EOF

# ─────────────────────────────────────────────────────────────────────────────
# .dockerignore do backend
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/.dockerignore" << 'EOF'
__pycache__
*.pyc
*.pyo
.env
.env.*
!.env.example
.git
*.md
README*
.venv
venv
EOF

# ─────────────────────────────────────────────────────────────────────────────
# .gitignore do backend
# ─────────────────────────────────────────────────────────────────────────────
cat > "$BACKEND/.gitignore" << 'EOF'
__pycache__/
*.pyc
.env
.venv/
venv/
EOF

echo ""
echo "✅  Backend criado em: $BACKEND"
echo ""
echo "Estrutura gerada:"
find "$BACKEND" -not -path '*/__pycache__/*' | sort | sed "s|$BACKEND||" | sed 's|^/||' | awk '{print "  " $0}'
echo ""
echo "Próximos passos:"
echo "  1. cd backend"
echo "  2. python -m venv .venv && source .venv/bin/activate"
echo "  3. pip install -r requirements.txt"
echo "  4. cp .env.example .env  →  preencha GROQ_API_KEY"
echo "  5. uvicorn main:app --reload"
echo "  6. Acesse http://localhost:8000/docs  (Swagger gerado automaticamente)"
