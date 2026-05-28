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
