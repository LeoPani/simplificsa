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
