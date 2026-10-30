"""
respuesta_agente.py
-------------------
Almacena la respuesta ejecutiva final generada por el agente para la gerencia.
Encapsula la evidencia cuantitativa, métrica, regla de cálculo, periodo, filtros,
fuente oficial consultada y advertencias (numeral 6.3 de la especificación).
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional
from .base import EntidadPersistente


class RespuestaAgente(EntidadPersistente):
    """
    Representa la respuesta sustentada en datos producida por el agente.
    """

    def __init__(
        self,
        texto_interpretacion: str,
        resultado_cuantitativo: Any,
        metrica_utilizada: str,
        regla_calculo: str,
        periodo_aplicado: str,
        filtros_aplicados: Dict[str, Any],
        dimension_analizada: str,
        fuentes_consultadas: List[str],
        consulta_utilizada: str,
        advertencias: Optional[List[str]] = None,
        valida: bool = True,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(oid, fecha_creacion, fecha_modificacion, version)
        self._texto_interpretacion: str = texto_interpretacion
        self._resultado_cuantitativo: Any = resultado_cuantitativo
        self._metrica_utilizada: str = metrica_utilizada
        self._regla_calculo: str = regla_calculo
        self._periodo_aplicado: str = periodo_aplicado
        self._filtros_aplicados: Dict[str, Any] = dict(filtros_aplicados)
        self._dimension_analizada: str = dimension_analizada
        self._fuentes_consultadas: List[str] = list(fuentes_consultadas)
        self._consulta_utilizada: str = consulta_utilizada
        self._advertencias: List[str] = list(advertencias) if advertencias else []
        self._valida: bool = valida

    @property
    def texto_interpretacion(self) -> str:
        return self._texto_interpretacion

    @property
    def resultado_cuantitativo(self) -> Any:
        return self._resultado_cuantitativo

    @property
    def metrica_utilizada(self) -> str:
        return self._metrica_utilizada

    @property
    def regla_calculo(self) -> str:
        return self._regla_calculo

    @property
    def periodo_aplicado(self) -> str:
        return self._periodo_aplicado

    @property
    def filtros_aplicados(self) -> Dict[str, Any]:
        return dict(self._filtros_aplicados)

    @property
    def dimension_analizada(self) -> str:
        return self._dimension_analizada

    @property
    def fuentes_consultadas(self) -> List[str]:
        return list(self._fuentes_consultadas)

    @property
    def consulta_utilizada(self) -> str:
        return self._consulta_utilizada

    @property
    def advertencias(self) -> List[str]:
        return list(self._advertencias)

    @property
    def valida(self) -> bool:
        return self._valida

    def agregar_advertencia(self, mensaje: str) -> None:
        """Agrega una advertencia o nota metodológica a la respuesta."""
        self._advertencias.append(mensaje)
        self.registrar_modificacion()

    def formatear_informe_ejecutivo(self) -> str:
        """
        Construye una salida ejecutiva formateada con toda la evidencia exigida
        en la sección 6.3 del documento.
        """
        lineas = [
            "=" * 70,
            "INFORME EJECUTIVO ANALÍTICO - AGENTE IA",
            "=" * 70,
            f"Interpretación Gerencial:\n  {self._texto_interpretacion}",
            "-" * 70,
            f"Resultado Cuantitativo/Categórico:\n  {self._formatear_datos(self._resultado_cuantitativo)}",
            "-" * 70,
            "Evidencia Metodológica y Trazabilidad:",
            f"  • Métrica utilizada: {self._metrica_utilizada}",
            f"  • Regla de cálculo:  {self._regla_calculo}",
            f"  • Dimensión:         {self._dimension_analizada}",
            f"  • Periodo analizado: {self._periodo_aplicado}",
            f"  • Filtros:           {self._filtros_aplicados}",
            f"  • Fuentes Data Mart: {', '.join(self._fuentes_consultadas)}",
            f"  • Consulta ejecutada:{self._consulta_utilizada}",
        ]
        if self._advertencias:
            lineas.append("-" * 70)
            lineas.append("Advertencias y Controles de Calidad:")
            for adv in self._advertencias:
                lineas.append(f"  [!] {adv}")
        lineas.append("=" * 70)
        return "\n".join(lineas)

    def _formatear_datos(self, datos: Any) -> str:
        if isinstance(datos, list):
            if not datos:
                return "(Sin registros encontrados para los filtros indicados)"
            if len(datos) <= 5:
                return "\n  ".join(str(d) for d in datos)
            return "\n  ".join(str(d) for d in datos[:5]) + f"\n  ... ({len(datos)} registros totales)"
        return str(datos)

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "texto_interpretacion": self._texto_interpretacion,
            "resultado_cuantitativo": self._resultado_cuantitativo,
            "metrica_utilizada": self._metrica_utilizada,
            "regla_calculo": self._regla_calculo,
            "periodo_aplicado": self._periodo_aplicado,
            "filtros_aplicados": self._filtros_aplicados,
            "dimension_analizada": self._dimension_analizada,
            "fuentes_consultadas": self._fuentes_consultadas,
            "consulta_utilizada": self._consulta_utilizada,
            "advertencias": self._advertencias,
            "valida": self._valida,
        })
        return base

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> RespuestaAgente:
        return cls(
            texto_interpretacion=datos["texto_interpretacion"],
            resultado_cuantitativo=datos.get("resultado_cuantitativo"),
            metrica_utilizada=datos["metrica_utilizada"],
            regla_calculo=datos["regla_calculo"],
            periodo_aplicado=datos["periodo_aplicado"],
            filtros_aplicados=datos.get("filtros_aplicados", {}),
            dimension_analizada=datos["dimension_analizada"],
            fuentes_consultadas=datos.get("fuentes_consultadas", []),
            consulta_utilizada=datos.get("consulta_utilizada", ""),
            advertencias=datos.get("advertencias", []),
            valida=datos.get("valida", True),
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )
