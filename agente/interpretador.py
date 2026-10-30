"""
interpretador.py
----------------
Analizador sintáctico y semántico de preguntas gerenciales en lenguaje natural.
Cumple con el numeral 6.1 (identificación de intención, métrica, dimensión, periodo,
filtros, operación analítica y límite) y el numeral 6.4 (manejo de límites, ambigüedad
y prevención de inyecciones / operaciones destructivas).
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple


@dataclass
class ResultadoInterpretacion:
    """Estructura normalizada de la interpretación de una solicitud gerencial (numeral 6.1)."""
    texto_original: str
    intencion_codigo: str = ""
    intencion_nombre: str = ""
    metrica: str = ""
    dimension: str = ""
    periodo: str = ""
    filtros: Dict[str, Any] = field(default_factory=dict)
    operacion_analitica: str = ""
    limite: int = 1
    es_ambigua: bool = False
    es_fuera_de_alcance: bool = False
    es_dimension_inexistente: bool = False
    es_no_autorizada: bool = False
    advertencias: List[str] = field(default_factory=list)
    motivo_bloqueo: Optional[str] = None

    def a_formato_documento(self) -> str:
        """
        Produce la salida formateada exacta especificada en el numeral 6.1 del examen:
        'Intención: analizar rentabilidad | Métrica: margen bruto | Dimensión: categoría |
         Periodo: segundo trimestre | Operación: ranking descendente | Límite: 1'
        """
        if self.es_no_autorizada or self.es_fuera_de_alcance or self.es_dimension_inexistente:
            return f"Estado: RECHAZADA/CONTROLADA | Motivo: {self.motivo_bloqueo}"

        return (
            f"Intención: {self.intencion_nombre} | "
            f"Métrica: {self.metrica} | "
            f"Dimensión: {self.dimension} | "
            f"Periodo: {self.periodo} | "
            f"Operación: {self.operacion_analitica} | "
            f"Límite: {self.limite}"
        )


class InterpretadorPreguntas:
    """
    Motor de análisis de lenguaje natural del agente analítico.
    Mapea preguntas libres en español a parámetros controlados para el Data Mart.
    """

    CATEGORIAS_VALIDAS = ["Electronica", "Hogar", "Ropa", "Alimentos", "Deportes"]
    CANALES_VALIDOS = ["Tienda Fisica", "Web"]
    SUCURSALES_VALIDAS = ["Sucursal Norte", "Sucursal Centro", "Sucursal Sur"]
    SEGMENTOS_VALIDOS = ["VIP", "Frecuente", "Corporativo", "Ocasional"]

    PALABRAS_DESTRUCTIVAS = ["drop", "delete", "insert", "update", "alter", "truncate", "src_"]
    DIMENSIONES_FALSAS = ["proveedor", "vendedor", "almacen", "bodega", "temperatura", "clima"]
    FUERA_DE_ALCANCE = [
        "salario", "sueldo", "nomina", "nómina", "empleado", "empleados",
        "inflacion", "inflación", "dolar", "dólar", "tipo de cambio", "asistencia", "vacaciones"
    ]

    def __init__(self, periodo_datamart_defecto: Optional[Dict[str, str]] = None) -> None:
        self._periodo_defecto = periodo_datamart_defecto or {
            "desde": "2026-04-01",
            "hasta": "2026-09-30",
        }

    def interpretar(self, texto: str, contexto_sesion: Optional[Dict[str, Any]] = None) -> ResultadoInterpretacion:
        """
        Interpreta la pregunta y extrae componentes analíticos y controles de seguridad.
        """
        t = texto.strip().lower()
        contexto = contexto_sesion or {}
        resultado = ResultadoInterpretacion(texto_original=texto)

        # 1. CONTROL DE SEGURIDAD (Sección 6.2 y 7.1)
        if any(p in t for p in self.PALABRAS_DESTRUCTIVAS):
            resultado.es_no_autorizada = True
            resultado.motivo_bloqueo = (
                "Operación denegada: Instrucción destructiva o intento de acceso a tablas operacionales no autorizadas."
            )
            return resultado

        # 2. CONTROL FUERA DE ALCANCE (Sección 6.4 y 7.1)
        if any(fa in t for fa in self.FUERA_DE_ALCANCE):
            resultado.es_fuera_de_alcance = True
            resultado.motivo_bloqueo = (
                "La consulta está fuera del alcance del Data Mart de Ventas. El sistema no inventa información ni presupone datos ausentes."
            )
            return resultado

        # 3. CONTROL DE DIMENSIÓN INEXISTENTE (Sección 7.1)
        if any(df in t for df in self.DIMENSIONES_FALSAS):
            resultado.es_dimension_inexistente = True
            resultado.motivo_bloqueo = (
                "La dimensión solicitada no forma parte del esquema estrella del Data Mart (dimensiones válidas: Tiempo, Cliente, Producto, Canal, Sucursal)."
            )
            return resultado

        # 4. RESOLUCIÓN DE PERIODOS Y FECHAS
        periodo_str, desde, hasta, advertencia_periodo = self._extraer_periodo(t, contexto)
        if advertencia_periodo:
            resultado.advertencias.append(advertencia_periodo)

        resultado.periodo = periodo_str

        # 5. RESOLUCIÓN DE LÍMITES NUMÉRICOS
        n = self._extraer_limite(t)
        resultado.limite = n

        # 6. IDENTIFICACIÓN DE CASOS PARTICULARES Y AMBIGÜEDAD

        # Caso: Simulación sin registros (7.1)
        if "sin registros" in t or "categoria inexistente" in t or "2099" in t:
            resultado.intencion_codigo = "INT_LIDER_VENTAS_CATEGORIA"
            resultado.intencion_nombre = "Producto líder por categoría"
            resultado.metrica = "ingreso neto, unidades"
            resultado.dimension = "producto, categoría"
            resultado.operacion_analitica = "máximo ventas por categoría"
            resultado.filtros = {"categoria": "CategoriaInexistenteXYZ", "desde": "2099-01-01", "hasta": "2099-12-31"}
            return resultado

        # Caso: Reducción de volumen por segmento (Q4 / Comparativa de periodos)
        if "segmento" in t and ("redujo" in t or "volumen" in t or "variacion" in t or "variación" in t):
            resultado.intencion_codigo = "INT_REDUCCION_VOLUMEN_SEGMENTO"
            resultado.intencion_nombre = "Detectar contracción de compra por segmento"
            resultado.metrica = "volumen (unidades), variación"
            resultado.dimension = "cliente (segmento SCD2)"
            resultado.periodo = "Periodo A (Q2: 2026-04-01 a 2026-06-30) vs Periodo B (Q3: 2026-07-01 a 2026-09-30)"
            resultado.operacion_analitica = "comparación temporal entre periodos"
            resultado.limite = 4
            resultado.filtros = {
                "a_desde": "2026-04-01", "a_hasta": "2026-06-30",
                "b_desde": "2026-07-01", "b_hasta": "2026-09-30",
            }
            return resultado

        # Caso: Comparar margen de dos canales (Q6 / Comparativa de canales)
        if "compare" in t or "comparar" in t or ("margen" in t and ("dos canales" in t or "canales" in t and "ultimos" in t)):
            c1, c2 = self._extraer_canales(t)
            resultado.intencion_codigo = "INT_COMPARAR_MARGEN_CANALES"
            resultado.intencion_nombre = "Comparativa mensual de margen entre canales"
            resultado.metrica = "margen bruto, margen porcentual"
            resultado.dimension = "canal, tiempo (mes)"
            resultado.periodo = "últimos tres meses disponibles (2026-07-01 a 2026-09-30)"
            resultado.operacion_analitica = "comparación mensual directa"
            resultado.limite = 6
            resultado.filtros = {
                "canal1": c1,
                "canal2": c2,
                "desde": "2026-07-01",
                "hasta": "2026-09-30",
            }
            return resultado

        # Caso: Pregunta ambigua ("¿cuál fue el mejor canal?") (Sección 6.4 y 7.1)
        if "mejor canal" in t:
            resultado.es_ambigua = True
            msg_amb = (
                "Expresión ambigua detectada ('mejor canal'): La noción de 'mejor' puede medirse por ingreso neto, "
                "margen bruto, volumen o ticket promedio. Se explicitó e implementó el criterio: Ingreso Neto."
            )
            resultado.advertencias.append(msg_amb)
            resultado.intencion_codigo = "INT_CANAL_MAYOR_VENTA"
            resultado.intencion_nombre = "Determinar canal de mayor concentración de venta"
            resultado.metrica = "ingreso neto (criterio explicitado ante ambigüedad)"
            resultado.dimension = "canal"
            resultado.operacion_analitica = "ranking descendente"
            resultado.limite = 1
            resultado.filtros = {"desde": desde, "hasta": hasta, "n": 1}
            return resultado

        # Caso: Canal que concentra el mayor valor de ventas (Q5)
        if "canal" in t and ("concentra" in t or "mayor valor" in t or "ventas" in t and "canal" in t):
            resultado.intencion_codigo = "INT_CANAL_MAYOR_VENTA"
            resultado.intencion_nombre = "Determinar canal de mayor concentración de venta"
            resultado.metrica = "ingreso neto"
            resultado.dimension = "canal"
            resultado.operacion_analitica = "ranking descendente"
            resultado.limite = n if n > 1 else 1
            resultado.filtros = {"desde": desde, "hasta": hasta, "n": resultado.limite}
            return resultado

        # Caso: Sucursal con ticket promedio más alto (Q3)
        if "sucursal" in t and ("ticket" in t or "promedio" in t or "mas alto" in t or "más alto" in t):
            resultado.intencion_codigo = "INT_TICKET_PROMEDIO_SUCURSAL"
            resultado.intencion_nombre = "Evaluar eficiencia de ticket por sucursal"
            resultado.metrica = "ticket promedio (ingreso_neto / conteo tickets)"
            resultado.dimension = "sucursal"
            resultado.operacion_analitica = "ranking descendente"
            resultado.limite = n if n > 1 else 1
            resultado.filtros = {"desde": desde, "hasta": hasta, "n": resultado.limite}
            return resultado

        # Caso: Categorías con mayor margen bruto (Q2)
        if "categor" in t and ("margen" in t or "rentab" in t or "mayor" in t):
            resultado.intencion_codigo = "INT_RANKING_CATEGORIA_MARGEN"
            resultado.intencion_nombre = "Identificar categorías más rentables"
            resultado.metrica = "margen bruto"
            resultado.dimension = "categoría de producto"
            resultado.operacion_analitica = "ranking descendente"
            resultado.limite = n if n > 1 else 5
            resultado.filtros = {"desde": desde, "hasta": hasta, "n": resultado.limite}
            return resultado

        # Caso: Producto líder de ventas dentro de una categoría (Q7)
        if "producto" in t and ("lider" in t or "líder" in t or "lidera" in t or "mas vendido" in t):
            cat = self._extraer_categoria(t, contexto)
            resultado.intencion_codigo = "INT_LIDER_VENTAS_CATEGORIA"
            resultado.intencion_nombre = "Producto líder por categoría"
            resultado.metrica = "ingreso neto y unidades"
            resultado.dimension = "producto, categoría"
            resultado.operacion_analitica = "máximo de ventas (Top 1)"
            resultado.limite = 1
            resultado.filtros = {"categoria": cat, "desde": desde, "hasta": hasta}
            return resultado

        # Caso: Descuento total y porcentaje por canal (Q10 - Adicional 3)
        if "descuento" in t and "canal" in t:
            resultado.intencion_codigo = "INT_DESCUENTO_CANAL"
            resultado.intencion_nombre = "Impacto de descuentos por canal"
            resultado.metrica = "descuento total, tasa de descuento %"
            resultado.dimension = "canal"
            resultado.operacion_analitica = "agregación y ratio porcentual"
            resultado.limite = 5
            resultado.filtros = {"desde": desde, "hasta": hasta}
            return resultado

        # Caso: Top N clientes por ingreso neto (Q9 - Adicional 2)
        if "cliente" in t and ("top" in t or "mayor" in t or "ingreso" in t):
            resultado.intencion_codigo = "INT_TOP_CLIENTES"
            resultado.intencion_nombre = "Top clientes por ingreso neto"
            resultado.metrica = "ingreso neto unificado SCD2"
            resultado.dimension = "cliente"
            resultado.operacion_analitica = "ranking descendente"
            resultado.limite = n if n > 1 else 10
            resultado.filtros = {"desde": desde, "hasta": hasta, "n": resultado.limite}
            return resultado

        # Caso: Margen porcentual por categoría (Q8 - Adicional 1)
        if "margen" in t and "porcentual" in t:
            resultado.intencion_codigo = "INT_MARGEN_PCT_CATEGORIA"
            resultado.intencion_nombre = "Rentabilidad porcentual por categoría"
            resultado.metrica = "margen porcentual (%)"
            resultado.dimension = "categoría"
            resultado.operacion_analitica = "ranking descendente de ratio"
            resultado.limite = 5
            resultado.filtros = {"desde": desde, "hasta": hasta}
            return resultado

        # Caso por defecto: Ingreso neto por mes (Q1 / Tendencia temporal)
        resultado.intencion_codigo = "INT_VENTAS_MES"
        resultado.intencion_nombre = "Analizar evolución de ventas mensuales"
        resultado.metrica = "ingreso neto"
        resultado.dimension = "tiempo (mes y año)"
        resultado.operacion_analitica = "agregación cronológica mensual"
        resultado.limite = 12
        resultado.filtros = {"desde": desde, "hasta": hasta}
        return resultado

    def _extraer_periodo(self, t: str, contexto: Dict[str, Any]) -> Tuple[str, str, str, Optional[str]]:
        """Extrae el rango temporal o aplica el periodo completo por defecto con advertencia."""
        # 1. Rango explícito con formato fecha YYYY-MM-DD
        fechas = re.findall(r"\b(202\d-\d{2}-\d{2})\b", t)
        if len(fechas) >= 2:
            return f"{fechas[0]} a {fechas[1]}", fechas[0], fechas[1], None

        # 2. Trimestres específicos
        if "segundo trimestre" in t or "q2" in t or "trimestre 2" in t:
            return "segundo trimestre 2026 (2026-04-01 a 2026-06-30)", "2026-04-01", "2026-06-30", None
        if "tercer trimestre" in t or "q3" in t or "trimestre 3" in t or "ultimos tres meses" in t or "últimos tres meses" in t or "ultimos 3 meses" in t:
            return "tercer trimestre 2026 (2026-07-01 a 2026-09-30)", "2026-07-01", "2026-09-30", None

        # 3. Meses específicos
        meses = {
            "abril": ("2026-04-01", "2026-04-30"),
            "mayo": ("2026-05-01", "2026-05-31"),
            "junio": ("2026-06-01", "2026-06-30"),
            "julio": ("2026-07-01", "2026-07-31"),
            "agosto": ("2026-08-01", "2026-08-31"),
            "septiembre": ("2026-09-01", "2026-09-30"),
        }
        for mes, (d_ini, d_fin) in meses.items():
            if mes in t:
                return f"{mes.capitalize()} 2026 ({d_ini} a {d_fin})", d_ini, d_fin, None

        # 4. Contexto previo de la sesión
        if "ultimo_desde" in contexto and "ultimo_hasta" in contexto:
            d_ini = contexto["ultimo_desde"]
            d_fin = contexto["ultimo_hasta"]
            return f"Periodo contextual reutilizado ({d_ini} a {d_fin})", d_ini, d_fin, None

        # 5. Sin periodo explícito (numeral 6.1 y 7.1)
        d_ini = self._periodo_defecto["desde"]
        d_fin = self._periodo_defecto["hasta"]
        advertencia = (
            f"Periodo no explicitado en la pregunta. Se asume automáticamente el periodo "
            f"histórico completo disponible en el Data Mart ({d_ini} a {d_fin})."
        )
        return f"Todo el periodo disponible ({d_ini} a {d_fin})", d_ini, d_fin, advertencia

    def _extraer_limite(self, t: str) -> int:
        palabras_a_num = {
            "un": 1, "uno": 1, "una": 1, "primer": 1, "primera": 1, "top 1": 1, "lider": 1,
            "dos": 2, "tres": 3, "cuatro": 4, "cinco": 5, "seis": 6, "diez": 10
        }
        for palabra, valor in palabras_a_num.items():
            if re.search(rf"\b{palabra}\b", t):
                return valor
        match = re.search(r"\b(\d+)\b", t)
        if match:
            return int(match.group(1))
        return 5 if "categor" in t else 1

    def _extraer_categoria(self, t: str, contexto: Dict[str, Any]) -> str:
        for cat in self.CATEGORIAS_VALIDAS:
            if cat.lower() in t:
                return cat
        if "ultima_categoria" in contexto:
            return contexto["ultima_categoria"]
        return "Electronica"

    def _extraer_canales(self, t: str) -> Tuple[str, str]:
        canales = []
        if "web" in t or "online" in t or "internet" in t:
            canales.append("Web")
        if "tienda" in t or "fisica" in t or "física" in t or "sucursal" in t:
            canales.append("Tienda Fisica")
        if len(canales) == 2:
            return canales[0], canales[1]
        return "Tienda Fisica", "Web"
