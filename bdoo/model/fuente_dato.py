"""
fuente_dato.py
--------------
Identifica el Data Mart, tablas y campos utilizados en las consultas analíticas.
Garantiza el Principio Rector: el Data Mart contiene la verdad analítica del negocio
y la BDOO almacena los metadatos y evidencias de las fuentes consultadas.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional
from .base import EntidadPersistente


class FuenteDato(EntidadPersistente):
    """
    Representa una fuente de datos analítica autorizada.
    Encapsula el esquema de tablas de hechos, dimensiones y campos consultables.
    """

    def __init__(
        self,
        id_fuente: str,
        nombre_data_mart: str,
        tabla_hechos: str,
        tablas_dimensiones: List[str],
        campos_utilizados: List[str],
        descripcion_grano: str,
        tipo_almacen: str = "SQLITE_DIMENSIONAL",
        es_fuente_oficial: bool = True,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(oid, fecha_creacion, fecha_modificacion, version)
        self._id_fuente: str = id_fuente
        self._nombre_data_mart: str = nombre_data_mart
        self._tabla_hechos: str = tabla_hechos
        self._tablas_dimensiones: List[str] = list(tablas_dimensiones)
        self._campos_utilizados: List[str] = list(campos_utilizados)
        self._descripcion_grano: str = descripcion_grano
        self._tipo_almacen: str = tipo_almacen
        self._es_fuente_oficial: bool = es_fuente_oficial

    @property
    def id_fuente(self) -> str:
        return self._id_fuente

    @property
    def nombre_data_mart(self) -> str:
        return self._nombre_data_mart

    @property
    def tabla_hechos(self) -> str:
        return self._tabla_hechos

    @property
    def tablas_dimensiones(self) -> List[str]:
        return list(self._tablas_dimensiones)

    @property
    def campos_utilizados(self) -> List[str]:
        return list(self._campos_utilizados)

    @property
    def descripcion_grano(self) -> str:
        return self._descripcion_grano

    @property
    def tipo_almacen(self) -> str:
        return self._tipo_almacen

    @property
    def es_fuente_oficial(self) -> bool:
        return self._es_fuente_oficial

    def verificar_campo_permitido(self, campo: str) -> bool:
        """Comprueba si un campo forma parte de las columnas auditadas de la fuente."""
        return campo in self._campos_utilizados

    def obtener_resumen_fuente(self) -> str:
        dims = ", ".join(self._tablas_dimensiones)
        return f"{self._nombre_data_mart} [Hechos: {self._tabla_hechos} | Dimensiones: {dims}]"

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "id_fuente": self._id_fuente,
            "nombre_data_mart": self._nombre_data_mart,
            "tabla_hechos": self._tabla_hechos,
            "tablas_dimensiones": self._tablas_dimensiones,
            "campos_utilizados": self._campos_utilizados,
            "descripcion_grano": self._descripcion_grano,
            "tipo_almacen": self._tipo_almacen,
            "es_fuente_oficial": self._es_fuente_oficial,
        })
        return base

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> FuenteDato:
        return cls(
            id_fuente=datos["id_fuente"],
            nombre_data_mart=datos["nombre_data_mart"],
            tabla_hechos=datos["tabla_hechos"],
            tablas_dimensiones=datos["tablas_dimensiones"],
            campos_utilizados=datos["campos_utilizados"],
            descripcion_grano=datos["descripcion_grano"],
            tipo_almacen=datos.get("tipo_almacen", "SQLITE_DIMENSIONAL"),
            es_fuente_oficial=datos.get("es_fuente_oficial", True),
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )
