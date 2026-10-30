"""
Módulo de Modelo de Dominio de la Base de Datos Orientada a Objetos (BDOO).
Define los 10 objetos mínimos exigidos en la especificación y sus jerarquías de herencia.
"""

from .base import EntidadPersistente
from .usuario import Usuario, UsuarioGerencial, UsuarioOperativo
from .sesion import Sesion
from .intencion import (
    Intencion,
    IntencionRanking,
    IntencionTendencia,
    IntencionComparativa,
    IntencionLiderazgo,
    IntencionAgregacion,
)
from .fuente_dato import FuenteDato
from .regla_validacion import (
    ReglaValidacion,
    ReglaNoVacio,
    ReglaMargenValido,
    ReglaFiltroDesconocido,
    ReglaSeguridadSQL,
    ReglaCoherenciaPeriodo,
    ReglaAmbiguedadCriterio,
)
from .resultado_consulta import ResultadoConsulta
from .consulta_analitica import ConsultaAnalitica
from .respuesta_agente import RespuestaAgente
from .pregunta import Pregunta
from .agente import AgenteAnalitico

__all__ = [
    "EntidadPersistente",
    "Usuario",
    "UsuarioGerencial",
    "UsuarioOperativo",
    "Sesion",
    "Intencion",
    "IntencionRanking",
    "IntencionTendencia",
    "IntencionComparativa",
    "IntencionLiderazgo",
    "IntencionAgregacion",
    "FuenteDato",
    "ReglaValidacion",
    "ReglaNoVacio",
    "ReglaMargenValido",
    "ReglaFiltroDesconocido",
    "ReglaSeguridadSQL",
    "ReglaCoherenciaPeriodo",
    "ReglaAmbiguedadCriterio",
    "ResultadoConsulta",
    "ConsultaAnalitica",
    "RespuestaAgente",
    "Pregunta",
    "AgenteAnalitico",
]
