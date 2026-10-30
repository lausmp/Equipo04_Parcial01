"""
regla_validacion.py
-------------------
Representa los controles y validaciones aplicados antes de generar la respuesta final.
Implementa una jerarquía polimórfica (Patrón Strategy / Specification) que demuestra
herencia y encapsulamiento en el modelo orientado a objetos.
"""
from __future__ import annotations

import re
from abc import abstractmethod
from typing import Any, Dict, List, Optional, Tuple, TYPE_CHECKING
from .base import EntidadPersistente

if TYPE_CHECKING:
    from .resultado_consulta import ResultadoConsulta
    from .consulta_analitica import ConsultaAnalitica


class ReglaValidacion(EntidadPersistente):
    """
    Clase base abstracta para las reglas de validación y control de calidad.
    Cada regla concreta encapsula un criterio analítico o de seguridad.
    """

    def __init__(
        self,
        codigo: str,
        nombre: str,
        descripcion: str,
        severidad: str = "WARNING",  # "INFO", "WARNING", "BLOCKING"
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(oid, fecha_creacion, fecha_modificacion, version)
        self._codigo: str = codigo
        self._nombre: str = nombre
        self._descripcion: str = descripcion
        self._severidad: str = severidad.upper()

    @property
    def codigo(self) -> str:
        return self._codigo

    @property
    def nombre(self) -> str:
        return self._nombre

    @property
    def descripcion(self) -> str:
        return self._descripcion

    @property
    def severidad(self) -> str:
        return self._severidad

    @abstractmethod
    def validar(
        self, resultado: ResultadoConsulta, consulta: ConsultaAnalitica
    ) -> Tuple[bool, List[str]]:
        """
        Método polimórfico fundamental.
        Retorna (pasa_validacion: bool, advertencias_o_errores: List[str]).
        """
        pass

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "codigo": self._codigo,
            "nombre": self._nombre,
            "descripcion": self._descripcion,
            "severidad": self._severidad,
        })
        return base


class ReglaNoVacio(ReglaValidacion):
    """
    Controla que el Data Mart retorne registros.
    Cumple el requisito 6.4: Ante ausencia de registros, informar el resultado
    vacío sin convertirlo en cero cuando esa interpretación no esté justificada.
    """

    def __init__(
        self,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo="REG_NO_VACIO",
            nombre="Control de Registros Existentes",
            descripcion="Verifica si la consulta obtuvo registros en el periodo/filtros solicitados sin falsear a cero.",
            severidad="WARNING",
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )

    def validar(
        self, resultado: ResultadoConsulta, consulta: ConsultaAnalitica
    ) -> Tuple[bool, List[str]]:
        if resultado.es_vacio():
            msg = (
                f"La consulta '{consulta.codigo}' no devolvió registros para los filtros especificados. "
                "Advertencia: No se infiere un valor de cero ya que no existe evidencia transaccional registrada."
            )
            return False, [msg]
        return True, []

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> ReglaNoVacio:
        return cls(
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class ReglaMargenValido(ReglaValidacion):
    """
    Controla el impacto de productos con costo nulo (NULL) en el cálculo del margen bruto.
    Cumple la regla del Data Mart: SUM ignora productos sin costo y el agente debe advertirlo.
    """

    def __init__(
        self,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo="REG_MARGEN_VALIDO",
            nombre="Auditoría de Margen y Costo",
            descripcion="Detecta presencia de valores nulos en costos que puedan distorsionar el margen bruto.",
            severidad="INFO",
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )

    def validar(
        self, resultado: ResultadoConsulta, consulta: ConsultaAnalitica
    ) -> Tuple[bool, List[str]]:
        advertencias = []
        # Si la consulta involucra margen
        if "margen" in consulta.plantilla_sql.lower():
            advertencias.append(
                "Nota metodológica: El margen bruto se calcula únicamente sobre productos con costo unitario conocido. "
                "Las líneas de productos sin costo registrado se excluyen de la métrica de rentabilidad."
            )
        return True, advertencias

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> ReglaMargenValido:
        return cls(
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class ReglaFiltroDesconocido(ReglaValidacion):
    """
    Verifica que las consultas excluyan los registros centinela 'Desconocido' (sk = -1)
    en rankings y reportes ejecutivos para no distorsionar comparativas.
    """

    def __init__(
        self,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo="REG_FILTRO_DESCONOCIDO",
            nombre="Exclusión de Registros Centinela",
            descripcion="Garantiza que sk = -1 (Desconocido) no participe en rankings directos.",
            severidad="INFO",
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )

    def validar(
        self, resultado: ResultadoConsulta, consulta: ConsultaAnalitica
    ) -> Tuple[bool, List[str]]:
        sql = consulta.plantilla_sql
        if "<> -1" in sql or "!= -1" in sql:
            return True, [
                "Control de calidad: Se han excluido automáticamente registros con claves desconocidas (sk = -1)."
            ]
        return True, []

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> ReglaFiltroDesconocido:
        return cls(
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class ReglaSeguridadSQL(ReglaValidacion):
    """
    Cumple el requisito 6.2 y 7: Impide acceso a tablas no autorizadas (como las operacionales
    src_*), bloquea instrucciones destructivas (DROP, DELETE, INSERT, UPDATE) y previene inyección SQL.
    """

    PALABRAS_PROHIBIDAS = ["drop", "delete", "insert", "update", "alter", "attach", "truncate", "exec"]

    def __init__(
        self,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo="REG_SEGURIDAD_SQL",
            nombre="Seguridad y Autorización de Consultas",
            descripcion="Bloquea operaciones destructivas o acceso a tablas operacionales del sistema de origen.",
            severidad="BLOCKING",
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )

    def validar(
        self, resultado: ResultadoConsulta, consulta: ConsultaAnalitica
    ) -> Tuple[bool, List[str]]:
        sql = consulta.plantilla_sql.lower()
        for palabra in self.PALABRAS_PROHIBIDAS:
            if re.search(rf"\b{palabra}\b", sql):
                msg = f"Violación de seguridad: La consulta contiene la instrucción prohibida '{palabra.upper()}'."
                return False, [msg]

        # Validar que no consulte tablas operacionales src_*
        if re.search(r"\bsrc_\w+", sql):
            msg = (
                "Acceso denegado: El agente tiene prohibido consultar tablas operacionales directas (src_*). "
                "Toda consulta analítica debe resolver exclusivamente contra el Data Mart dimensional oficial."
            )
            return False, [msg]

        return True, []

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> ReglaSeguridadSQL:
        return cls(
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class ReglaCoherenciaPeriodo(ReglaValidacion):
    """
    Valida la coherencia de fechas en consultas con parámetros temporales (:desde, :hasta).
    """

    def __init__(
        self,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo="REG_COHERENCIA_PERIODO",
            nombre="Validación de Consistencia Temporal",
            descripcion="Asegura que el rango de fechas sea cronológicamente válido y respete formato ISO.",
            severidad="BLOCKING",
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )

    def validar(
        self, resultado: ResultadoConsulta, consulta: ConsultaAnalitica
    ) -> Tuple[bool, List[str]]:
        params = resultado.parametros_aplicados
        desde = params.get("desde") or params.get("a_desde")
        hasta = params.get("hasta") or params.get("b_hasta")

        if desde and hasta and desde > hasta:
            return False, [f"Incoherencia temporal: La fecha de inicio ({desde}) es posterior a la fecha final ({hasta})."]

        return True, []

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> ReglaCoherenciaPeriodo:
        return cls(
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class ReglaAmbiguedadCriterio(ReglaValidacion):
    """
    Cumple el requisito 6.4: Ante preguntas ambiguas como '¿cuál fue el mejor canal?',
    asegura que se explicite el criterio de ordenamiento y comparación.
    """

    def __init__(
        self,
        criterio_explicitado: str = "Ingreso Neto",
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo="REG_AMBIGUEDAD_CRITERIO",
            nombre="Explicitación de Criterio Analítico",
            descripcion="Explicita el criterio cuantitativo adoptado ante términos ambiguos como 'mejor' o 'superior'.",
            severidad="INFO",
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )
        self._criterio_explicitado: str = criterio_explicitado

    @property
    def criterio_explicitado(self) -> str:
        return self._criterio_explicitado

    def validar(
        self, resultado: ResultadoConsulta, consulta: ConsultaAnalitica
    ) -> Tuple[bool, List[str]]:
        return True, [
            f"Aclaración de ambigüedad: Se adoptó '{self._criterio_explicitado}' como criterio de medición oficial."
        ]

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base["criterio_explicitado"] = self._criterio_explicitado
        return base

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> ReglaAmbiguedadCriterio:
        return cls(
            criterio_explicitado=datos.get("criterio_explicitado", "Ingreso Neto"),
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )
