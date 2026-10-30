"""
pregunta.py
-----------
Conserva el texto, fecha, filtros e intención detectada de cada interacción.
Actúa como el núcleo de trazabilidad del agente, conectando la pregunta del usuario
con la intención, la consulta analítica, el resultado obtenido y la respuesta producida.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, Optional, TYPE_CHECKING
from .base import EntidadPersistente

if TYPE_CHECKING:
    from .intencion import Intencion
    from .consulta_analitica import ConsultaAnalitica
    from .resultado_consulta import ResultadoConsulta
    from .respuesta_agente import RespuestaAgente


class Pregunta(EntidadPersistente):
    """
    Representa una solicitud formulada por un usuario y conserva el ciclo de vida
    completo de su procesamiento para fines de auditoría y trazabilidad.
    """

    def __init__(
        self,
        texto_pregunta: str,
        filtros_detectados: Optional[Dict[str, Any]] = None,
        intencion: Optional[Intencion] = None,
        consulta: Optional[ConsultaAnalitica] = None,
        resultado: Optional[ResultadoConsulta] = None,
        respuesta: Optional[RespuestaAgente] = None,
        estado: str = "RECIBIDA",
        es_ambigua: bool = False,
        es_fuera_de_alcance: bool = False,
        motivo_error: Optional[str] = None,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(oid, fecha_creacion, fecha_modificacion, version)
        self._texto_pregunta: str = texto_pregunta
        self._filtros_detectados: Dict[str, Any] = dict(filtros_detectados) if filtros_detectados else {}
        self._intencion: Optional[Intencion] = intencion
        self._consulta: Optional[ConsultaAnalitica] = consulta
        self._resultado: Optional[ResultadoConsulta] = resultado
        self._respuesta: Optional[RespuestaAgente] = respuesta
        self._estado: str = estado
        self._es_ambigua: bool = es_ambigua
        self._es_fuera_de_alcance: bool = es_fuera_de_alcance
        self._motivo_error: Optional[str] = motivo_error

    @property
    def texto_pregunta(self) -> str:
        return self._texto_pregunta

    @property
    def filtros_detectados(self) -> Dict[str, Any]:
        return dict(self._filtros_detectados)

    @property
    def intencion(self) -> Optional[Intencion]:
        return self._intencion

    @property
    def consulta(self) -> Optional[ConsultaAnalitica]:
        return self._consulta

    @property
    def resultado(self) -> Optional[ResultadoConsulta]:
        return self._resultado

    @property
    def respuesta(self) -> Optional[RespuestaAgente]:
        return self._respuesta

    @property
    def estado(self) -> str:
        return self._estado

    @property
    def es_ambigua(self) -> bool:
        return self._es_ambigua

    @property
    def es_fuera_de_alcance(self) -> bool:
        return self._es_fuera_de_alcance

    @property
    def motivo_error(self) -> Optional[str]:
        return self._motivo_error

    # Métodos de transición de estado (Encapsulamiento del ciclo de vida)
    def asociar_intencion(self, intencion: Intencion, filtros: Dict[str, Any]) -> None:
        self._intencion = intencion
        self._filtros_detectados.update(filtros)
        self._estado = "INTERPRETADA"
        self.registrar_modificacion()

    def asociar_consulta(self, consulta: ConsultaAnalitica) -> None:
        self._consulta = consulta
        self._estado = "CONSULTA_PREPARADA"
        self.registrar_modificacion()

    def registrar_resultado(self, resultado: ResultadoConsulta) -> None:
        self._resultado = resultado
        self._estado = "EJECUTADA" if resultado.exitoso else "ERROR_EJECUCION"
        self.registrar_modificacion()

    def asignar_respuesta(self, respuesta: RespuestaAgente) -> None:
        self._respuesta = respuesta
        if self._estado not in ("ERROR", "FUERA_DE_ALCANCE"):
            self._estado = "RESPONDIDA"
        self.registrar_modificacion()

    def marcar_ambigua(self, motivo: str) -> None:
        self._es_ambigua = True
        self._motivo_error = motivo
        self._estado = "AMBIGUA"
        self.registrar_modificacion()

    def marcar_fuera_de_alcance(self, motivo: str) -> None:
        self._es_fuera_de_alcance = True
        self._motivo_error = motivo
        self._estado = "FUERA_DE_ALCANCE"
        self.registrar_modificacion()

    def marcar_error(self, motivo: str) -> None:
        self._motivo_error = motivo
        self._estado = "ERROR"
        self.registrar_modificacion()

    def obtener_trazabilidad_completa(self) -> Dict[str, Any]:
        """
        Retorna la evidencia integral de la interacción:
        pregunta, intención, consulta, resultado y respuesta (sección 8.4).
        """
        return {
            "oid_pregunta": self._oid,
            "fecha": self._fecha_creacion,
            "texto_usuario": self._texto_pregunta,
            "estado": self._estado,
            "es_ambigua": self._es_ambigua,
            "es_fuera_de_alcance": self._es_fuera_de_alcance,
            "filtros": self._filtros_detectados,
            "intencion": self._intencion.a_diccionario() if self._intencion else None,
            "consulta": self._consulta.a_diccionario() if self._consulta else None,
            "resultado": self._resultado.a_diccionario() if self._resultado else None,
            "respuesta": self._respuesta.a_diccionario() if self._respuesta else None,
            "motivo_error": self._motivo_error,
        }

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "texto_pregunta": self._texto_pregunta,
            "filtros_detectados": self._filtros_detectados,
            "intencion_oid": self._intencion.oid if self._intencion else None,
            "consulta_oid": self._consulta.oid if self._consulta else None,
            "resultado_oid": self._resultado.oid if self._resultado else None,
            "respuesta_oid": self._respuesta.oid if self._respuesta else None,
            "estado": self._estado,
            "es_ambigua": self._es_ambigua,
            "es_fuera_de_alcance": self._es_fuera_de_alcance,
            "motivo_error": self._motivo_error,
        })
        return base
