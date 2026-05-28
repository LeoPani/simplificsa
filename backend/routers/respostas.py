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
