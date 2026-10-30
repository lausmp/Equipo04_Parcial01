"""
formateador.py
--------------
Generador de respuestas ejecutivas sustentadas en datos (numeral 6.3).
Produce salidas formateadas para terminal (ANSI), texto plano, Markdown y HTML
con tablas de resultados, evidencia metodológica y alertas de calidad.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional
from bdoo.model.respuesta_agente import RespuestaAgente


class FormateadorRespuesta:
    """
    Formatea las respuestas del Agente Analítico garantizando la inclusión de
    todos los elementos de evidencia exigidos en el numeral 6.3.
    """

    @staticmethod
    def a_texto_consola(respuesta: RespuestaAgente, usar_colores: bool = True) -> str:
        """Formatea la respuesta con recuadros y estilos para la terminal."""
        c_reset = "\033[0m" if usar_colores else ""
        c_azul = "\033[1;34m" if usar_colores else ""
        c_verde = "\033[1;32m" if usar_colores else ""
        c_amarillo = "\033[1;33m" if usar_colores else ""
        c_rojo = "\033[1;31m" if usar_colores else ""
        c_cyan = "\033[1;36m" if usar_colores else ""
        c_gris = "\033[0;90m" if usar_colores else ""

        ancho = 80
        sep = "=" * ancho
        sep_fina = "-" * ancho

        lineas = [
            f"{c_azul}{sep}{c_reset}",
            f"{c_azul} AGENTE ANALÍTICO DE VENTAS | INFORME GERENCIAL CON EVIDENCIA{c_reset}",
            f"{c_azul}{sep}{c_reset}",
            f"{c_verde}>> SÍNTESIS EJECUTIVA:{c_reset}",
            f"   {respuesta.texto_interpretacion}",
            f"{c_gris}{sep_fina}{c_reset}",
            f"{c_cyan}>> RESULTADOS CUANTITATIVOS / CATEGÓRICOS:{c_reset}",
        ]

        # Formatear tabla de datos
        datos = respuesta.resultado_cuantitativo
        if isinstance(datos, list) and datos and isinstance(datos[0], dict):
            lineas.extend(FormateadorRespuesta._construir_tabla_ascii(datos, c_gris, c_reset))
        elif isinstance(datos, list) and not datos:
            lineas.append(f"   {c_amarillo}(Sin registros en el Data Mart para los filtros especificados){c_reset}")
        else:
            lineas.append(f"   {datos}")

        lineas.extend([
            f"{c_gris}{sep_fina}{c_reset}",
            f"{c_azul}>> EVIDENCIA METODOLÓGICA Y FUENTES (NUMERAL 6.3):{c_reset}",
            f"   • Métrica utilizada:   {respuesta.metrica_utilizada}",
            f"   • Regla de cálculo:    {respuesta.regla_calculo}",
            f"   • Dimensión evaluada:  {respuesta.dimension_analizada}",
            f"   • Periodo aplicado:    {respuesta.periodo_aplicado}",
            f"   • Filtros aplicados:   {respuesta.filtros_aplicados}",
            f"   • Fuente consultada:   {', '.join(respuesta.fuentes_consultadas)}",
            f"   • Consulta oficial:    {respuesta.consulta_utilizada}",
        ])

        if respuesta.advertencias:
            lineas.append(f"{c_gris}{sep_fina}{c_reset}")
            lineas.append(f"{c_amarillo}>> CONTROLES DE CALIDAD Y ADVERTENCIAS METODOLÓGICAS:{c_reset}")
            for adv in respuesta.advertencias:
                lineas.append(f"   {c_amarillo}[!]{c_reset} {adv}")

        lineas.append(f"{c_azul}{sep}{c_reset}")
        return "\n".join(lineas)

    @staticmethod
    def _construir_tabla_ascii(filas_dict: List[Dict[str, Any]], c_borde: str, c_reset: str) -> List[str]:
        """Construye una tabla ASCII limpia alineando texto y números."""
        if not filas_dict:
            return ["   (tabla vacía)"]

        cols = list(filas_dict[0].keys())
        anchos = {c: len(str(c)) for c in cols}

        for fila in filas_dict:
            for c in cols:
                val_str = FormateadorRespuesta._formatear_valor(fila.get(c))
                anchos[c] = max(anchos[c], len(val_str))

        # Encabezado
        borde_horiz = "+-" + "-+-".join("-" * anchos[c] for c in cols) + "-+"
        encabezado = "| " + " | ".join(c.upper().ljust(anchos[c]) for c in cols) + " |"

        lineas_tabla = [
            f"   {c_borde}{borde_horiz}{c_reset}",
            f"   {c_borde}|{c_reset} " + " | ".join(c.upper().ljust(anchos[c]) for c in cols) + f" {c_borde}|{c_reset}",
            f"   {c_borde}{borde_horiz}{c_reset}",
        ]

        for fila in filas_dict:
            celdas = []
            for c in cols:
                v = fila.get(c)
                val_str = FormateadorRespuesta._formatear_valor(v)
                if isinstance(v, (int, float)):
                    celdas.append(val_str.rjust(anchos[c]))
                else:
                    celdas.append(val_str.ljust(anchos[c]))
            lineas_tabla.append(f"   {c_borde}|{c_reset} " + " | ".join(celdas) + f" {c_borde}|{c_reset}")

        lineas_tabla.append(f"   {c_borde}{borde_horiz}{c_reset}")
        return lineas_tabla

    @staticmethod
    def _formatear_valor(v: Any) -> str:
        if v is None:
            return "NULL"
        if isinstance(v, float):
            return f"{v:,.2f}"
        if isinstance(v, int):
            return f"{v:,}"
        return str(v)
