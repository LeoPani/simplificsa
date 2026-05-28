#!/bin/bash
echo "🚀 Criando a infraestrutura do SimplifiCSA (FastAPI)..."

# Cria a pasta da API
mkdir -p app

# Cria o arquivo principal de rotas (main.py)
cat << 'PY' > app/main.py
from fastapi import FastAPI

app = FastAPI(title="SimplifiCSA API")

@app.get("/")
def read_root():
    return {"status": "online", "message": "Backend do calendário rodando perfeito!"}
PY

# Cria as dependências
echo -e "fastapi\nuvicorn\npydantic" > requirements.txt

# Cria o Dockerfile otimizado para o Render
cat << 'DKR' > Dockerfile
FROM python:3.11-slim
WORKDIR /code
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY ./app ./app
# O Render injeta a variável $PORT dinamicamente. O padrão fallback é 10000.
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000}
DKR

# Cria o .dockerignore para o build ficar rápido
echo -e "__pycache__/\n*.pyc\n.git\n.env\nsetup_backend.sh" > .dockerignore

echo "✅ Estrutura criada com sucesso! Dockerfile pronto."
