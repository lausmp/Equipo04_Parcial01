"""
resultado_consulta.py
---------------------
Conserva los datos devueltos por el Data Mart y los metadatos de ejecución técnica.
Encapsula filas, columnas, métricas de rendimiento y estado de la consulta.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional
from .base import EntidadPersistente


class ResultadoConsulta(EntidadPersistente):
    """
    Conserva los resultados de una ejecución SQL sobre el Data Mart y su trazabilidad técnica.
    """

    def __init__(
        self,
        consulta_codigo: str,
        columnas: List[str],
        filas: List[List[Any]],
        tiempo_ejecucion_ms: float,
        total_registros: int,
        parametros_aplicados: Dict[str, Any],
        exitoso: bool = True,
        mensaje_error: Optional[str] = None,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(oid, fecha_creacion, fecha_modificacion, version)
        self._consulta_codigo: str = consulta_codigo
        self._columnas: List[str] = list(columnas)
        self._filas: List[List[Any]] = [list(f) for f in filas]
        self._tiempo_ejecucion_ms: float = round(tiempo_ejecucion_ms, 2)
        self._total_registros: int = total_registros
        self._parametros_aplicados: Dict[str, Any] = dict(parametros_aplicados)
        self._exitoso: bool = exitoso
        self._mensaje_error: Optional[str] = mensaje_error

    @property
    def consulta_codigo(self) -> str:
        return self._consulta_codigo

    @property
    def columnas(self) -> List[str]:
        return list(self._columnas)

    @property
    def filas(self) -> List[List[Any]]:
        return [list(f) for f in self._filas]

    @property
    def tiempo_ejecucion_ms(self) -> float:
        return self._tiempo_ejecucion_ms

    @property
    def total_registros(self) -> int:
        return self._total_registros

    @property
    def parametros_aplicados(self) -> Dict[str, Any]:
        return dict(self._parametros_aplicados)

    @property
    def exitoso(self) -> bool:
        return self._exitoso

    @property
    def mensaje_error(self) -> Optional[str]:
        return self._mensaje_error

    def es_vacio(self) -> bool:
        """Indica si el resultado no contiene filas de datos."""
        return self._total_registros == 0 or len(self._filas) == 0

    def a_lista_diccionarios(self) -> List[Dict[str, Any]]:
        """Convierte las filas en una lista de diccionarios {columna: valor}."""
        resultado = []
        for fila in self._filas:
            resultado.append(dict(zip(self._columnas, fila)))
        return resultado

    def obtener_columna(self, nombre_columna: str) -> List[Any]:
        """Obtiene todos los valores de una columna específica."""
        if nombre_columna not in self._columnas:
            raise KeyError(f"Columna '{nombre_columna}' no existe en el resultado. Disponibles: {self._columnas}")
        idx = self._columnas.index(nombre_columna)
        return [fila[idx] for fila in self._filas]

    def obtener_primera_fila(self) -> Optional[Dict[str, Any]]:
        """Retorna la primera fila como diccionario o None si no hay registros."""
        if self.es_vacio():
            return None
        return dict(zip(self._columnas, self._filas[0]))

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "consulta_codigo": self._consulta_codigo,
            "columnas": self._columnas,
            "filas": self._filas,
            "tiempo_ejecucion_ms": self._tiempo_ejecucion_ms,
            "total_registros": self._total_registros,
            "parametros_aplicados": self._parametros_aplicados,
            "exitoso": self._exitoso,
            "mensaje_error": self._mensaje_error,
        })
        return base

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> ResultadoConsulta:
        return cls(
            consulta_codigo=datos["consulta_codigo"],
            columnas=datos["columnas"],
            filas=datos["filas"],
            tiempo_ejecucion_ms=datos.get("tiempo_ejecucion_ms", 0.0),
            total_registros=datos.get("total_registros", len(datos.get("filas", []))),
            parametros_aplicados=datos.get("parametros_aplicados", {}),
            exitoso=datos.get("exitoso", True),
            mensaje_error=datos.get("mensaje_error"),
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )
