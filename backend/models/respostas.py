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
