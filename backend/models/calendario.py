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
