import os
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="SimplifiCSA API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
GROQ_URL = "https://api.groq.com/openai/v1/chat/completions"
GROQ_MODEL = "llama3-8b-8192"


class ChatRequest(BaseModel):
    setor: str = ""
    porte: str = ""
    contexto: str = ""
    pergunta: str


@app.get("/")
def health():
    return {"status": "online", "message": "Backend SimplifiCSA rodando."}


@app.post("/chat")
async def chat(payload: ChatRequest):
    if not GROQ_API_KEY:
        raise HTTPException(status_code=503, detail="GROQ_API_KEY não configurada no servidor.")

    system_prompt = (
        "Você é o assistente do simplifICSA, especialista em direito ambiental "
        "e regulatório para indústrias em Mariana/MG."
    )
    if payload.setor:
        system_prompt += f"\n\nCONTEXTO DA EMPRESA:\n- Setor: {payload.setor}\n- Porte: {payload.porte}"
    if payload.contexto:
        system_prompt += f"\n- Informações adicionais: {payload.contexto}"

    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            GROQ_URL,
            headers={"Authorization": f"Bearer {GROQ_API_KEY}", "Content-Type": "application/json"},
            json={
                "model": GROQ_MODEL,
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": payload.pergunta},
                ],
                "temperature": 0.5,
                "max_tokens": 1024,
            },
        )

    if resp.status_code != 200:
        raise HTTPException(status_code=resp.status_code, detail=resp.text)

    return {"resposta": resp.json()["choices"][0]["message"]["content"].strip()}
