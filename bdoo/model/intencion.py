"""
intencion.py
------------
Representa la necesidad analítica identificada a partir de la pregunta del usuario.
Estructura la intención, métrica, dimensión, periodo, filtros y operación analítica
(numeral 6.1 de la especificación). Demuestra herencia y polimorfismo.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple
from .base import EntidadPersistente


class Intencion(EntidadPersistente):
    """
    Clase base para representar la intención analítica identificada por el agente.
    """

    def __init__(
        self,
        codigo: str,
        nombre: str,
        descripcion: str,
        operacion_analitica: str,
        metricas_esperadas: List[str],
        dimensiones_esperadas: List[str],
        consulta_sugerida: str,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(oid, fecha_creacion, fecha_modificacion, version)
        self._codigo: str = codigo
        self._nombre: str = nombre
        self._descripcion: str = descripcion
        self._operacion_analitica: str = operacion_analitica
        self._metricas_esperadas: List[str] = list(metricas_esperadas)
        self._dimensiones_esperadas: List[str] = list(dimensiones_esperadas)
        self._consulta_sugerida: str = consulta_sugerida

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
    def operacion_analitica(self) -> str:
        return self._operacion_analitica

    @property
    def metricas_esperadas(self) -> List[str]:
        return list(self._metricas_esperadas)

    @property
    def dimensiones_esperadas(self) -> List[str]:
        return list(self._dimensiones_esperadas)

    @property
    def consulta_sugerida(self) -> str:
        return self._consulta_sugerida

    def validar_parametros(self, params: Dict[str, Any]) -> Tuple[bool, List[str]]:
        """
        Método polimórfico de validación de parámetros de la intención.
        Por defecto verifica que no sea nulo.
        """
        return True, []

    def describir_interpretacion(self, filtros: Dict[str, Any]) -> str:
        """Genera el resumen de interpretación conforme al numeral 6.1."""
        metricas = ", ".join(self._metricas_esperadas) or "N/A"
        dims = ", ".join(self._dimensiones_esperadas) or "N/A"
        periodo = f"{filtros.get('desde', '')} a {filtros.get('hasta', '')}".strip() or "No especificado"
        limite = filtros.get("n", 1)
        return (
            f"Intención: {self._nombre} | Métrica: {metricas} | "
            f"Dimensión: {dims} | Periodo: {periodo} | "
            f"Operación: {self._operacion_analitica} | Límite: {limite}"
        )

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "codigo": self._codigo,
            "nombre": self._nombre,
            "descripcion": self._descripcion,
            "operacion_analitica": self._operacion_analitica,
            "metricas_esperadas": self._metricas_esperadas,
            "dimensiones_esperadas": self._dimensiones_esperadas,
            "consulta_sugerida": self._consulta_sugerida,
        })
        return base


class IntencionRanking(Intencion):
    """
    Especialización para intenciones de clasificación Top N / Bottom N
    (ej. categorías con mayor margen, canal con mayor venta).
    """

    def __init__(
        self,
        codigo: str,
        nombre: str,
        descripcion: str,
        metricas_esperadas: List[str],
        dimensiones_esperadas: List[str],
        consulta_sugerida: str,
        limite_defecto: int = 5,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo=codigo,
            nombre=nombre,
            descripcion=descripcion,
            operacion_analitica="RANKING_DESC",
            metricas_esperadas=metricas_esperadas,
            dimensiones_esperadas=dimensiones_esperadas,
            consulta_sugerida=consulta_sugerida,
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )
        self._limite_defecto: int = limite_defecto

    @property
    def limite_defecto(self) -> int:
        return self._limite_defecto

    def validar_parametros(self, params: Dict[str, Any]) -> Tuple[bool, List[str]]:
        errores = []
        n = params.get("n", self._limite_defecto)
        if not isinstance(n, int) or n <= 0:
            errores.append(f"El parámetro de ranking 'n' debe ser un entero positivo. Recibido: {n}")
        return len(errores) == 0, errores

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base["limite_defecto"] = self._limite_defecto
        return base

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> IntencionRanking:
        return cls(
            codigo=datos["codigo"],
            nombre=datos["nombre"],
            descripcion=datos["descripcion"],
            metricas_esperadas=datos["metricas_esperadas"],
            dimensiones_esperadas=datos["dimensiones_esperadas"],
            consulta_sugerida=datos["consulta_sugerida"],
            limite_defecto=datos.get("limite_defecto", 5),
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class IntencionTendencia(Intencion):
    """
    Especialización para análisis de evolución o series temporales (ej. ingreso neto por mes).
    """

    def __init__(
        self,
        codigo: str,
        nombre: str,
        descripcion: str,
        metricas_esperadas: List[str],
        consulta_sugerida: str,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo=codigo,
            nombre=nombre,
            descripcion=descripcion,
            operacion_analitica="EVOLUCION_TEMPORAL",
            metricas_esperadas=metricas_esperadas,
            dimensiones_esperadas=["DimTiempo"],
            consulta_sugerida=consulta_sugerida,
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )

    def validar_parametros(self, params: Dict[str, Any]) -> Tuple[bool, List[str]]:
        errores = []
        if "desde" not in params or "hasta" not in params:
            errores.append("La intención de tendencia temporal requiere los parámetros de fecha ':desde' y ':hasta'.")
        return len(errores) == 0, errores

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> IntencionTendencia:
        return cls(
            codigo=datos["codigo"],
            nombre=datos["nombre"],
            descripcion=datos["descripcion"],
            metricas_esperadas=datos["metricas_esperadas"],
            consulta_sugerida=datos["consulta_sugerida"],
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class IntencionComparativa(Intencion):
    """
    Especialización para comparar entidades o periodos (ej. margen de 2 canales, reducción por segmento).
    """

    def __init__(
        self,
        codigo: str,
        nombre: str,
        descripcion: str,
        tipo_comparacion: str,  # "CANALES", "PERIODOS", "SEGMENTOS"
        metricas_esperadas: List[str],
        dimensiones_esperadas: List[str],
        consulta_sugerida: str,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo=codigo,
            nombre=nombre,
            descripcion=descripcion,
            operacion_analitica="COMPARACION_DIRECTA",
            metricas_esperadas=metricas_esperadas,
            dimensiones_esperadas=dimensiones_esperadas,
            consulta_sugerida=consulta_sugerida,
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )
        self._tipo_comparacion: str = tipo_comparacion

    @property
    def tipo_comparacion(self) -> str:
        return self._tipo_comparacion

    def validar_parametros(self, params: Dict[str, Any]) -> Tuple[bool, List[str]]:
        errores = []
        if self._tipo_comparacion == "CANALES":
            if "canal1" not in params or "canal2" not in params:
                errores.append("La comparación de canales exige ':canal1' y ':canal2'.")
        elif self._tipo_comparacion == "PERIODOS":
            requeridos = ["a_desde", "a_hasta", "b_desde", "b_hasta"]
            faltantes = [p for p in requeridos if p not in params]
            if faltantes:
                errores.append(f"La comparación entre periodos exige: {faltantes}")
        return len(errores) == 0, errores

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base["tipo_comparacion"] = self._tipo_comparacion
        return base

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> IntencionComparativa:
        return cls(
            codigo=datos["codigo"],
            nombre=datos["nombre"],
            descripcion=datos["descripcion"],
            tipo_comparacion=datos.get("tipo_comparacion", "CANALES"),
            metricas_esperadas=datos["metricas_esperadas"],
            dimensiones_esperadas=datos["dimensiones_esperadas"],
            consulta_sugerida=datos["consulta_sugerida"],
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class IntencionLiderazgo(Intencion):
    """
    Especialización para determinar el producto o entidad líder en una categoría y periodo.
    """

    def __init__(
        self,
        codigo: str,
        nombre: str,
        descripcion: str,
        metricas_esperadas: List[str],
        consulta_sugerida: str,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo=codigo,
            nombre=nombre,
            descripcion=descripcion,
            operacion_analitica="MAX_LIDERAZGO",
            metricas_esperadas=metricas_esperadas,
            dimensiones_esperadas=["DimProducto", "DimTiempo"],
            consulta_sugerida=consulta_sugerida,
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )

    def validar_parametros(self, params: Dict[str, Any]) -> Tuple[bool, List[str]]:
        errores = []
        if "categoria" not in params:
            errores.append("La determinación de liderazgo exige el parámetro ':categoria'.")
        return len(errores) == 0, errores

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> IntencionLiderazgo:
        return cls(
            codigo=datos["codigo"],
            nombre=datos["nombre"],
            descripcion=datos["descripcion"],
            metricas_esperadas=datos["metricas_esperadas"],
            consulta_sugerida=datos["consulta_sugerida"],
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class IntencionAgregacion(Intencion):
    """
    Especialización para consultas analíticas de agregación global o ratios porcentuales.
    """

    def __init__(
        self,
        codigo: str,
        nombre: str,
        descripcion: str,
        metricas_esperadas: List[str],
        dimensiones_esperadas: List[str],
        consulta_sugerida: str,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            codigo=codigo,
            nombre=nombre,
            descripcion=descripcion,
            operacion_analitica="AGREGACION_METRICAS",
            metricas_esperadas=metricas_esperadas,
            dimensiones_esperadas=dimensiones_esperadas,
            consulta_sugerida=consulta_sugerida,
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> IntencionAgregacion:
        return cls(
            codigo=datos["codigo"],
            nombre=datos["nombre"],
            descripcion=datos["descripcion"],
            metricas_esperadas=datos["metricas_esperadas"],
            dimensiones_esperadas=datos["dimensiones_esperadas"],
            consulta_sugerida=datos["consulta_sugerida"],
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )
