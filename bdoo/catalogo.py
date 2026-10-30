"""
catalogo.py
-----------
Inicializa y configura el catálogo oficial de objetos analíticos de la BDOO:
- FuenteDato oficial (Data Mart de Ventas).
- Reglas de validación polimórficas.
- Consultas analíticas parametrizadas (Q0 a Q10).
- Intenciones analíticas asociadas.
"""
from __future__ import annotations

from typing import Tuple
from .model.fuente_dato import FuenteDato
from .model.regla_validacion import (
    ReglaNoVacio,
    ReglaMargenValido,
    ReglaFiltroDesconocido,
    ReglaSeguridadSQL,
    ReglaCoherenciaPeriodo,
    ReglaAmbiguedadCriterio,
)
from .model.consulta_analitica import ConsultaAnalitica
from .model.intencion import (
    IntencionRanking,
    IntencionTendencia,
    IntencionComparativa,
    IntencionLiderazgo,
    IntencionAgregacion,
)
from .model.agente import AgenteAnalitico


def inicializar_catalogo_oficial(agente: AgenteAnalitico) -> FuenteDato:
    """Registra todas las fuentes, reglas, consultas e intenciones en el agente analítico."""

    # 1. FUENTE DE DATO OFICIAL
    fuente_oficial = FuenteDato(
        id_fuente="SRC_DATAMART_VENTAS",
        nombre_data_mart="DataMart_Ventas",
        tabla_hechos="FactVentas",
        tablas_dimensiones=[
            "DimTiempo", "DimCliente", "DimProducto", "DimCanal", "DimSucursal"
        ],
        campos_utilizados=[
            "sk_tiempo", "sk_cliente", "sk_producto", "sk_canal", "sk_sucursal",
            "numero_ticket", "numero_linea", "cantidad", "precio_unitario",
            "descuento", "ingreso_bruto", "ingreso_neto", "costo_total", "margen_bruto"
        ],
        descripcion_grano="Una fila representa una línea de producto vendida dentro de un ticket.",
        tipo_almacen="SQLITE_DIMENSIONAL",
        es_fuente_oficial=True,
    )
    agente.registrar_fuente(fuente_oficial)

    # 2. REGLAS DE VALIDACIÓN GLOBALES Y ESPECÍFICAS
    reg_no_vacio = ReglaNoVacio()
    reg_margen = ReglaMargenValido()
    reg_desconocido = ReglaFiltroDesconocido()
    reg_seguridad = ReglaSeguridadSQL()
    reg_periodo = ReglaCoherenciaPeriodo()
    reg_ambiguedad = ReglaAmbiguedadCriterio("Ingreso Neto")

    # 3. CATÁLOGO DE CONSULTAS PARAMETRIZADAS (Q0 - Q10)
    # Q0: Periodo disponible
    q0 = ConsultaAnalitica(
        codigo="Q0",
        nombre="Periodo disponible en el Data Mart",
        descripcion="Obtiene la fecha mínima y máxima registrada en FactVentas con DimTiempo.",
        plantilla_sql="""
        SELECT MIN(t.fecha) AS primera_fecha, MAX(t.fecha) AS ultima_fecha
        FROM FactVentas f
        JOIN DimTiempo t ON t.sk_tiempo = f.sk_tiempo;
        """,
        parametros_esperados=[],
        fuente_dato=fuente_oficial,
        regla_calculo="Rango temporal: MIN(fecha) a MAX(fecha) en FactVentas",
        reglas_validacion=[reg_seguridad, reg_no_vacio],
    )

    # Q1: Ingreso neto por mes
    q1 = ConsultaAnalitica(
        codigo="Q1",
        nombre="Ingreso neto por mes",
        descripcion="Calcula el ingreso neto acumulado agrupado por año y mes.",
        plantilla_sql="""
        SELECT t.anio, t.mes, t.nombre_mes,
               ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
        FROM FactVentas f
        JOIN DimTiempo t ON t.sk_tiempo = f.sk_tiempo
        WHERE t.fecha BETWEEN :desde AND :hasta
        GROUP BY t.anio, t.mes, t.nombre_mes
        ORDER BY t.anio, t.mes;
        """,
        parametros_esperados=["desde", "hasta"],
        fuente_dato=fuente_oficial,
        regla_calculo="Ingreso neto = SUM(ingreso_neto) = SUM(ingreso_bruto - descuento)",
        reglas_validacion=[reg_seguridad, reg_periodo, reg_no_vacio],
    )

    # Q2: N categorías con mayor margen bruto
    q2 = ConsultaAnalitica(
        codigo="Q2",
        nombre="Top N categorías con mayor margen bruto",
        descripcion="Ranking descendente de categorías según margen bruto acumulado.",
        plantilla_sql="""
        SELECT p.categoria,
               ROUND(SUM(f.margen_bruto), 2) AS margen_bruto
        FROM FactVentas f
        JOIN DimProducto p ON p.sk_producto = f.sk_producto
        JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
        WHERE t.fecha BETWEEN :desde AND :hasta
          AND p.sk_producto <> -1
        GROUP BY p.categoria
        ORDER BY margen_bruto DESC
        LIMIT :n;
        """,
        parametros_esperados=["desde", "hasta", "n"],
        fuente_dato=fuente_oficial,
        regla_calculo="Margen bruto = SUM(ingreso_neto - costo_total) donde costo IS NOT NULL",
        reglas_validacion=[reg_seguridad, reg_periodo, reg_no_vacio, reg_margen, reg_desconocido],
    )

    # Q3: Sucursal con ticket promedio más alto
    q3 = ConsultaAnalitica(
        codigo="Q3",
        nombre="Sucursal con ticket promedio más alto",
        descripcion="Calcula el ticket promedio por sucursal excluyendo centinelas.",
        plantilla_sql="""
        SELECT s.nombre AS sucursal,
               COUNT(DISTINCT f.numero_ticket) AS tickets,
               ROUND(SUM(f.ingreso_neto) * 1.0 / COUNT(DISTINCT f.numero_ticket), 2) AS ticket_promedio
        FROM FactVentas f
        JOIN DimSucursal s ON s.sk_sucursal = f.sk_sucursal
        JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
        WHERE t.fecha BETWEEN :desde AND :hasta
          AND s.sk_sucursal <> -1
        GROUP BY s.nombre
        ORDER BY ticket_promedio DESC
        LIMIT :n;
        """,
        parametros_esperados=["desde", "hasta", "n"],
        fuente_dato=fuente_oficial,
        regla_calculo="Ticket promedio = SUM(ingreso_neto) / COUNT(DISTINCT numero_ticket)",
        reglas_validacion=[reg_seguridad, reg_periodo, reg_no_vacio, reg_desconocido],
    )

    # Q4: Segmento que más redujo volumen de compra (periodo A vs periodo B)
    q4 = ConsultaAnalitica(
        codigo="Q4",
        nombre="Reducción de volumen de compra por segmento de cliente",
        descripcion="Compara volumen de unidades compradas por segmento entre dos periodos (SCD2).",
        plantilla_sql="""
        WITH a AS (
            SELECT c.segmento, SUM(f.cantidad) AS volumen
            FROM FactVentas f
            JOIN DimCliente c ON c.sk_cliente = f.sk_cliente
            JOIN DimTiempo  t ON t.sk_tiempo  = f.sk_tiempo
            WHERE t.fecha BETWEEN :a_desde AND :a_hasta AND c.sk_cliente <> -1
            GROUP BY c.segmento
        ),
        b AS (
            SELECT c.segmento, SUM(f.cantidad) AS volumen
            FROM FactVentas f
            JOIN DimCliente c ON c.sk_cliente = f.sk_cliente
            JOIN DimTiempo  t ON t.sk_tiempo  = f.sk_tiempo
            WHERE t.fecha BETWEEN :b_desde AND :b_hasta AND c.sk_cliente <> -1
            GROUP BY c.segmento
        )
        SELECT a.segmento,
               a.volumen                        AS volumen_a,
               COALESCE(b.volumen, 0)           AS volumen_b,
               COALESCE(b.volumen, 0) - a.volumen AS variacion
        FROM a
        LEFT JOIN b ON b.segmento = a.segmento
        ORDER BY variacion ASC;
        """,
        parametros_esperados=["a_desde", "a_hasta", "b_desde", "b_hasta"],
        fuente_dato=fuente_oficial,
        regla_calculo="Variación = volumen_B - volumen_A (la cifra más negativa representa la mayor reducción)",
        reglas_validacion=[reg_seguridad, reg_periodo, reg_no_vacio, reg_desconocido],
    )

    # Q5: Canal que concentra mayor valor de ventas
    q5 = ConsultaAnalitica(
        codigo="Q5",
        nombre="Canal con mayor valor de ventas",
        descripcion="Ranking de canales ordenados por ingreso neto acumulado.",
        plantilla_sql="""
        SELECT ca.nombre AS canal,
               ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
        FROM FactVentas f
        JOIN DimCanal  ca ON ca.sk_canal = f.sk_canal
        JOIN DimTiempo t  ON t.sk_tiempo = f.sk_tiempo
        WHERE t.fecha BETWEEN :desde AND :hasta
          AND ca.sk_canal <> -1
        GROUP BY ca.nombre
        ORDER BY ingreso_neto DESC
        LIMIT :n;
        """,
        parametros_esperados=["desde", "hasta", "n"],
        fuente_dato=fuente_oficial,
        regla_calculo="Ingreso neto = SUM(ingreso_neto)",
        reglas_validacion=[reg_seguridad, reg_periodo, reg_no_vacio, reg_desconocido, reg_ambiguedad],
    )

    # Q6: Comparar el margen de dos canales durante los últimos 3 meses
    q6 = ConsultaAnalitica(
        codigo="Q6",
        nombre="Comparativa de margen entre dos canales",
        descripcion="Calcula margen bruto y porcentaje de margen por mes para dos canales específicos.",
        plantilla_sql="""
        SELECT ca.nombre AS canal, t.anio, t.mes, t.nombre_mes,
               ROUND(SUM(f.margen_bruto), 2) AS margen_bruto,
               ROUND(SUM(f.margen_bruto) * 100.0 / SUM(f.ingreso_neto), 2) AS margen_pct
        FROM FactVentas f
        JOIN DimCanal  ca ON ca.sk_canal = f.sk_canal
        JOIN DimTiempo t  ON t.sk_tiempo = f.sk_tiempo
        WHERE ca.nombre IN (:canal1, :canal2)
          AND t.fecha BETWEEN :desde AND :hasta
        GROUP BY ca.nombre, t.anio, t.mes, t.nombre_mes
        ORDER BY t.anio, t.mes, ca.nombre;
        """,
        parametros_esperados=["canal1", "canal2", "desde", "hasta"],
        fuente_dato=fuente_oficial,
        regla_calculo="Margen % = SUM(margen_bruto) * 100.0 / SUM(ingreso_neto) (no se promedian porcentajes)",
        reglas_validacion=[reg_seguridad, reg_periodo, reg_no_vacio, reg_margen],
    )

    # Q7: Producto que lidera las ventas dentro de una categoría y periodo
    q7 = ConsultaAnalitica(
        codigo="Q7",
        nombre="Producto líder de ventas en una categoría",
        descripcion="Identifica el producto con mayor ingreso neto dentro de una categoría y periodo.",
        plantilla_sql="""
        SELECT p.nombre AS producto,
               SUM(f.cantidad)               AS unidades,
               ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
        FROM FactVentas f
        JOIN DimProducto p ON p.sk_producto = f.sk_producto
        JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
        WHERE p.categoria = :categoria
          AND t.fecha BETWEEN :desde AND :hasta
        GROUP BY p.nombre
        ORDER BY ingreso_neto DESC
        LIMIT 1;
        """,
        parametros_esperados=["categoria", "desde", "hasta"],
        fuente_dato=fuente_oficial,
        regla_calculo="Liderazgo medido por mayor ingreso neto total (y conteo de unidades)",
        reglas_validacion=[reg_seguridad, reg_periodo, reg_no_vacio],
    )

    # Q8: Margen porcentual por categoría (Adicional 1)
    q8 = ConsultaAnalitica(
        codigo="Q8",
        nombre="Margen porcentual por categoría",
        descripcion="Calcula el ratio de rentabilidad porcentual por categoría para evaluar eficiencia.",
        plantilla_sql="""
        SELECT p.categoria,
               ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto,
               ROUND(SUM(f.margen_bruto), 2) AS margen_bruto,
               ROUND(SUM(f.margen_bruto) * 100.0 / SUM(f.ingreso_neto), 2) AS margen_pct
        FROM FactVentas f
        JOIN DimProducto p ON p.sk_producto = f.sk_producto
        JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
        WHERE t.fecha BETWEEN :desde AND :hasta
          AND p.sk_producto <> -1
        GROUP BY p.categoria
        ORDER BY margen_pct DESC;
        """,
        parametros_esperados=["desde", "hasta"],
        fuente_dato=fuente_oficial,
        regla_calculo="Margen % = SUM(margen_bruto) * 100.0 / SUM(ingreso_neto)",
        reglas_validacion=[reg_seguridad, reg_periodo, reg_no_vacio, reg_margen, reg_desconocido],
    )

    # Q9: Top N clientes por ingreso neto (Adicional 2)
    q9 = ConsultaAnalitica(
        codigo="Q9",
        nombre="Top N clientes por ingreso neto",
        descripcion="Evalúa la concentración de ventas por cliente agrupando versiones SCD2.",
        plantilla_sql="""
        SELECT c.id_cliente, c.nombre,
               ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
        FROM FactVentas f
        JOIN DimCliente c ON c.sk_cliente = f.sk_cliente
        JOIN DimTiempo  t ON t.sk_tiempo  = f.sk_tiempo
        WHERE t.fecha BETWEEN :desde AND :hasta
          AND c.sk_cliente <> -1
        GROUP BY c.id_cliente, c.nombre
        ORDER BY ingreso_neto DESC
        LIMIT :n;
        """,
        parametros_esperados=["desde", "hasta", "n"],
        fuente_dato=fuente_oficial,
        regla_calculo="Ingreso neto acumulado agrupado por clave natural id_cliente (unifica versiones SCD2)",
        reglas_validacion=[reg_seguridad, reg_periodo, reg_no_vacio, reg_desconocido],
    )

    # Q10: Descuento total y porcentaje por canal (Adicional 3)
    q10 = ConsultaAnalitica(
        codigo="Q10",
        nombre="Descuento total y porcentaje por canal",
        descripcion="Audita el volumen y tasa de descuento comercial concedida en cada canal.",
        plantilla_sql="""
        SELECT ca.nombre AS canal,
               ROUND(SUM(f.descuento), 2) AS descuento_total,
               ROUND(SUM(f.descuento) * 100.0 / SUM(f.ingreso_bruto), 2) AS descuento_pct
        FROM FactVentas f
        JOIN DimCanal  ca ON ca.sk_canal = f.sk_canal
        JOIN DimTiempo t  ON t.sk_tiempo = f.sk_tiempo
        WHERE t.fecha BETWEEN :desde AND :hasta
          AND ca.sk_canal <> -1
        GROUP BY ca.nombre
        ORDER BY descuento_pct DESC;
        """,
        parametros_esperados=["desde", "hasta"],
        fuente_dato=fuente_oficial,
        regla_calculo="Descuento % = SUM(descuento) * 100.0 / SUM(ingreso_bruto)",
        reglas_validacion=[reg_seguridad, reg_periodo, reg_no_vacio, reg_desconocido],
    )

    for q in [q0, q1, q2, q3, q4, q5, q6, q7, q8, q9, q10]:
        agente.registrar_consulta(q)

    # 4. CATÁLOGO DE INTENCIONES ANALÍTICAS
    intenciones = [
        IntencionTendencia(
            codigo="INT_VENTAS_MES",
            nombre="Analizar evolución de ventas mensuales",
            descripcion="Consulta el ingreso neto consolidado mes a mes.",
            metricas_esperadas=["ingreso_neto"],
            consulta_sugerida="Q1",
        ),
        IntencionRanking(
            codigo="INT_RANKING_CATEGORIA_MARGEN",
            nombre="Identificar categorías más rentables",
            descripcion="Determina el Top N de categorías con mayor margen bruto comercial.",
            metricas_esperadas=["margen_bruto"],
            dimensiones_esperadas=["DimProducto"],
            consulta_sugerida="Q2",
            limite_defecto=5,
        ),
        IntencionRanking(
            codigo="INT_TICKET_PROMEDIO_SUCURSAL",
            nombre="Evaluar eficiencia de ticket por sucursal",
            descripcion="Clasifica las sucursales por el valor de su ticket promedio.",
            metricas_esperadas=["ticket_promedio"],
            dimensiones_esperadas=["DimSucursal"],
            consulta_sugerida="Q3",
            limite_defecto=1,
        ),
        IntencionComparativa(
            codigo="INT_REDUCCION_VOLUMEN_SEGMENTO",
            nombre="Detectar contracción de compra por segmento",
            descripcion="Compara variaciones en volumen de compra de clientes entre periodos.",
            tipo_comparacion="PERIODOS",
            metricas_esperadas=["volumen", "variacion"],
            dimensiones_esperadas=["DimCliente"],
            consulta_sugerida="Q4",
        ),
        IntencionRanking(
            codigo="INT_CANAL_MAYOR_VENTA",
            nombre="Determinar canal de mayor concentración de venta",
            descripcion="Identifica el canal que genera el mayor ingreso neto.",
            metricas_esperadas=["ingreso_neto"],
            dimensiones_esperadas=["DimCanal"],
            consulta_sugerida="Q5",
            limite_defecto=1,
        ),
        IntencionComparativa(
            codigo="INT_COMPARAR_MARGEN_CANALES",
            nombre="Comparativa mensual de margen entre canales",
            descripcion="Evalúa margen bruto y porcentual mes a mes para dos canales.",
            tipo_comparacion="CANALES",
            metricas_esperadas=["margen_bruto", "margen_pct"],
            dimensiones_esperadas=["DimCanal", "DimTiempo"],
            consulta_sugerida="Q6",
        ),
        IntencionLiderazgo(
            codigo="INT_LIDER_VENTAS_CATEGORIA",
            nombre="Producto líder por categoría",
            descripcion="Identifica el producto con mayor venta en una categoría y periodo.",
            metricas_esperadas=["ingreso_neto", "unidades"],
            consulta_sugerida="Q7",
        ),
        IntencionAgregacion(
            codigo="INT_MARGEN_PCT_CATEGORIA",
            nombre="Rentabilidad porcentual por categoría",
            descripcion="Mide el margen porcentual sobre ingreso neto por categoría.",
            metricas_esperadas=["margen_pct"],
            dimensiones_esperadas=["DimProducto"],
            consulta_sugerida="Q8",
        ),
        IntencionRanking(
            codigo="INT_TOP_CLIENTES",
            nombre="Top N clientes por ingreso neto",
            descripcion="Ranking de los mejores clientes unificando historia SCD2.",
            metricas_esperadas=["ingreso_neto"],
            dimensiones_esperadas=["DimCliente"],
            consulta_sugerida="Q9",
            limite_defecto=10,
        ),
        IntencionAgregacion(
            codigo="INT_DESCUENTO_CANAL",
            nombre="Impacto de descuentos por canal",
            descripcion="Mide descuento total y tasa de descuento sobre ingreso bruto.",
            metricas_esperadas=["descuento_total", "descuento_pct"],
            dimensiones_esperadas=["DimCanal"],
            consulta_sugerida="Q10",
        ),
    ]

    for it in intenciones:
        agente.registrar_intencion(it)

    return fuente_oficial
