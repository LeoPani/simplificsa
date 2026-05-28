FROM python:3.11-slim
WORKDIR /code
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY ./app ./app
# O Render injeta a variável $PORT dinamicamente. O padrão fallback é 10000.
CMD uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-10000}
