"""
consulta_analitica.py
---------------------
Encapsula la plantilla SQL parametrizada, los parámetros requeridos,
las reglas de validación asociadas y la referencia a la fuente de datos oficial.
Demuestra composición de objetos (contiene ReglaValidacion y FuenteDato).
"""
from __future__ import annotations

import time
import sqlite3
from typing import Any, Dict, List, Optional, Tuple, TYPE_CHECKING
from .base import EntidadPersistente
from .resultado_consulta import ResultadoConsulta

if TYPE_CHECKING:
    from .fuente_dato import FuenteDato
    from .regla_validacion import ReglaValidacion


class ConsultaAnalitica(EntidadPersistente):
    """
    Representa una consulta analítica parametrizada del catálogo oficial del agente.
    """

    def __init__(
        self,
        codigo: str,
        nombre: str,
        descripcion: str,
        plantilla_sql: str,
        parametros_esperados: List[str],
        fuente_dato: FuenteDato,
        regla_calculo: str,
        reglas_validacion: Optional[List[ReglaValidacion]] = None,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(oid, fecha_creacion, fecha_modificacion, version)
        self._codigo: str = codigo
        self._nombre: str = nombre
        self._descripcion: str = descripcion
        self._plantilla_sql: str = plantilla_sql.strip()
        self._parametros_esperados: List[str] = list(parametros_esperados)
        self._fuente_dato: FuenteDato = fuente_dato
        self._regla_calculo: str = regla_calculo
        self._reglas_validacion: List[ReglaValidacion] = list(reglas_validacion) if reglas_validacion else []

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
    def plantilla_sql(self) -> str:
        return self._plantilla_sql

    @property
    def parametros_esperados(self) -> List[str]:
        return list(self._parametros_esperados)

    @property
    def fuente_dato(self) -> FuenteDato:
        return self._fuente_dato

    @property
    def regla_calculo(self) -> str:
        return self._regla_calculo

    @property
    def reglas_validacion(self) -> List[ReglaValidacion]:
        return list(self._reglas_validacion)

    def agregar_regla(self, regla: ReglaValidacion) -> None:
        """Composición dinámica: agrega una regla de validación a la consulta."""
        self._reglas_validacion.append(regla)
        self.registrar_modificacion()

    def ejecutar(
        self, conexion: sqlite3.Connection, parametros: Dict[str, Any]
    ) -> ResultadoConsulta:
        """
        Ejecuta la consulta parametrizada de manera segura sobre la conexión SQLite del Data Mart.
        Retorna una instancia encapsulada de ResultadoConsulta con tiempos y metadatos.
        """
        inicio = time.perf_counter()
        cursor = conexion.cursor()

        # Filtrar solo los parámetros esperados por la plantilla
        params_limpios = {k: v for k, v in parametros.items() if f":{k}" in self._plantilla_sql}

        try:
            cursor.execute(self._plantilla_sql, params_limpios)
            columnas = [desc[0] for desc in cursor.description] if cursor.description else []
            filas = cursor.fetchall()
            fin = time.perf_counter()
            tiempo_ms = (fin - inicio) * 1000.0

            return ResultadoConsulta(
                consulta_codigo=self._codigo,
                columnas=columnas,
                filas=filas,
                tiempo_ejecucion_ms=tiempo_ms,
                total_registros=len(filas),
                parametros_aplicados=params_limpios,
                exitoso=True,
                mensaje_error=None,
            )
        except Exception as e:
            fin = time.perf_counter()
            tiempo_ms = (fin - inicio) * 1000.0
            return ResultadoConsulta(
                consulta_codigo=self._codigo,
                columnas=[],
                filas=[],
                tiempo_ejecucion_ms=tiempo_ms,
                total_registros=0,
                parametros_aplicados=params_limpios,
                exitoso=False,
                mensaje_error=str(e),
            )

    def aplicar_reglas(
        self, resultado: ResultadoConsulta
    ) -> Tuple[bool, List[str]]:
        """
        Aplica polimórficamente todas las reglas de validación asociadas.
        Retorna (todas_validas: bool, lista_advertencias: List[str]).
        """
        todas_validas = True
        advertencias_totales: List[str] = []

        for regla in self._reglas_validacion:
            valida, msgs = regla.validar(resultado, self)
            if not valida and regla.severidad == "BLOCKING":
                todas_validas = False
            advertencias_totales.extend(msgs)

        return todas_validas, advertencias_totales

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "codigo": self._codigo,
            "nombre": self._nombre,
            "descripcion": self._descripcion,
            "plantilla_sql": self._plantilla_sql,
            "parametros_esperados": self._parametros_esperados,
            "fuente_dato_oid": self._fuente_dato.oid,
            "regla_calculo": self._regla_calculo,
            "reglas_validacion_oids": [r.oid for r in self._reglas_validacion],
        })
        return base
