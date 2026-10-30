"""
agente.py
---------
Objeto AgenteAnalitico (núcleo del sistema).
Coordina interpretación, consulta, validación y respuesta (sección 5.1).
Implementa el flujo mínimo esperado (sección 2.1) y conecta la pregunta
del usuario con una respuesta sustentada en el Data Mart, registrando
la trazabilidad completa en la BDOO.
"""
from __future__ import annotations

import re
import sqlite3
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple, TYPE_CHECKING
from .base import EntidadPersistente
from .usuario import Usuario
from .sesion import Sesion
from .pregunta import Pregunta
from .intencion import (
    Intencion,
    IntencionRanking,
    IntencionTendencia,
    IntencionComparativa,
    IntencionLiderazgo,
    IntencionAgregacion,
)
from .fuente_dato import FuenteDato
from .consulta_analitica import ConsultaAnalitica
from .resultado_consulta import ResultadoConsulta
from .respuesta_agente import RespuestaAgente
from .regla_validacion import (
    ReglaValidacion,
    ReglaNoVacio,
    ReglaMargenValido,
    ReglaFiltroDesconocido,
    ReglaSeguridadSQL,
    ReglaCoherenciaPeriodo,
    ReglaAmbiguedadCriterio,
)

if TYPE_CHECKING:
    from ..storage.engine import BDOOEngine


class AgenteAnalitico(EntidadPersistente):
    """
    Coordinador de la interpretación, consulta, validación y respuesta gerencial.
    Representa el comportamiento inteligente del sistema y garantiza la trazabilidad en la BDOO.
    """

    def __init__(
        self,
        nombre: str = "Agente Analítico de Ventas - Equipo 04",
        version_agente: str = "1.0.0",
        ruta_datamart: Optional[Path] = None,
        motor_bdoo: Optional[BDOOEngine] = None,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(oid, fecha_creacion, fecha_modificacion, version)
        self._nombre: str = nombre
        self._version_agente: str = version_agente
        self._ruta_datamart: Optional[Path] = Path(ruta_datamart) if ruta_datamart else None
        self._motor_bdoo: Optional[BDOOEngine] = motor_bdoo

        # Catálogos en memoria coordinados por el agente
        self._catalogo_consultas: Dict[str, ConsultaAnalitica] = {}
        self._catalogo_intenciones: Dict[str, Intencion] = {}
        self._fuentes_datos: Dict[str, FuenteDato] = {}
        self._sesiones_activas: Dict[str, Sesion] = {}

        # Periodo disponible en el Data Mart (cacheados desde DimTiempo)
        self._periodo_disponible: Dict[str, str] = {
            "desde": "2026-04-01",
            "hasta": "2026-09-30",
        }

    @property
    def nombre(self) -> str:
        return self._nombre

    @property
    def version_agente(self) -> str:
        return self._version_agente

    @property
    def catalogo_consultas(self) -> Dict[str, ConsultaAnalitica]:
        return dict(self._catalogo_consultas)

    @property
    def catalogo_intenciones(self) -> Dict[str, Intencion]:
        return dict(self._catalogo_intenciones)

    def registrar_fuente(self, fuente: FuenteDato) -> None:
        self._fuentes_datos[fuente.id_fuente] = fuente
        if self._motor_bdoo:
            self._motor_bdoo.guardar(fuente)

    def registrar_consulta(self, consulta: ConsultaAnalitica) -> None:
        self._catalogo_consultas[consulta.codigo] = consulta
        if self._motor_bdoo:
            self._motor_bdoo.guardar(consulta)

    def registrar_intencion(self, intencion: Intencion) -> None:
        self._catalogo_intenciones[intencion.codigo] = intencion
        if self._motor_bdoo:
            self._motor_bdoo.guardar(intencion)

    def crear_sesion(self, usuario: Usuario, id_sesion: Optional[str] = None) -> Sesion:
        """Crea e inicializa una nueva sesión orientada a objetos para el usuario."""
        import uuid
        s_id = id_sesion or f"SES-{uuid.uuid4().hex[:8].upper()}"
        sesion = Sesion(id_sesion=s_id, usuario=usuario)
        self._sesiones_activas[s_id] = sesion
        if self._motor_bdoo:
            self._motor_bdoo.guardar(usuario)
            self._motor_bdoo.guardar(sesion)
        return sesion

    def inicializar_periodo_datamart(self) -> None:
        """Consulta el rango real de fechas en el Data Mart para resolver preguntas relativas."""
        if not self._ruta_datamart or not self._ruta_datamart.exists():
            return
        try:
            with sqlite3.connect(self._ruta_datamart) as con:
                cur = con.cursor()
                cur.execute(
                    "SELECT MIN(t.fecha), MAX(t.fecha) FROM FactVentas f "
                    "JOIN DimTiempo t ON t.sk_tiempo = f.sk_tiempo;"
                )
                fila = cur.fetchone()
                if fila and fila[0] and fila[1]:
                    self._periodo_disponible = {"desde": fila[0], "hasta": fila[1]}
        except Exception:
            pass

    # =========================================================================
    # FLUJO MÍNIMO ESPERADO (SECCIÓN 2.1)
    # =========================================================================
    def procesar_solicitud(self, texto_pregunta: str, sesion: Sesion) -> RespuestaAgente:
        """
        Ejecuta los 7 pasos del flujo mínimo:
        1. Recepción de la pregunta.
        2. Identificación de intención, métrica, dimensión, periodo y filtros.
        3. Selección de la consulta parametrizada o control de seguridad.
        4. Ejecución sobre el Data Mart.
        5. Validación del resultado y manejo de errores.
        6. Generación de respuesta gerencial con evidencia.
        7. Registro de la interacción en los objetos persistentes (BDOO).
        """
        # Paso 1: Recepción
        pregunta = Pregunta(texto_pregunta=texto_pregunta)
        sesion.agregar_pregunta(pregunta)

        # Paso 2: Interpretación de intención y filtros
        clasificacion = self._interpretar(texto_pregunta, sesion)

        # Casos especiales: Fuera de alcance, Ambigüedad o Intento no autorizado
        if clasificacion["es_no_autorizada"]:
            pregunta.marcar_error(clasificacion["mensaje_bloqueo"])
            respuesta = RespuestaAgente(
                texto_interpretacion=(
                    "Solicitud rechazada: Se ha detectado una operación no autorizada o un intento "
                    "de acceder a estructuras operacionales no permitidas."
                ),
                resultado_cuantitativo=None,
                metrica_utilizada="Control de Seguridad de Consultas",
                regla_calculo="Validación de políticas de acceso (solo lectura sobre Data Mart dimensional)",
                periodo_aplicado="N/A",
                filtros_aplicados={},
                dimension_analizada="N/A",
                fuentes_consultadas=["Políticas de Seguridad BDOO"],
                consulta_utilizada="BLOQUEADA POR REGLA DE SEGURIDAD",
                advertencias=[clasificacion["mensaje_bloqueo"]],
                valida=False,
            )
            pregunta.asignar_respuesta(respuesta)
            self._persistir_interaccion(pregunta, sesion)
            return respuesta

        if clasificacion["es_fuera_de_alcance"]:
            pregunta.marcar_fuera_de_alcance(clasificacion["mensaje_fuera_alcance"])
            respuesta = RespuestaAgente(
                texto_interpretacion=(
                    "La pregunta formulada está fuera del alcance del Data Mart de Ventas. "
                    "El sistema no inventa información ni realiza extrapolaciones no sustentadas en los datos oficiales."
                ),
                resultado_cuantitativo=None,
                metrica_utilizada="No aplicable",
                regla_calculo="No disponible en el Data Mart",
                periodo_aplicado="N/A",
                filtros_aplicados={},
                dimension_analizada="N/A",
                fuentes_consultadas=["Catálogo Oficial DataMart_Ventas"],
                consulta_utilizada="NINGUNA (FUERA DE ALCANCE)",
                advertencias=[clasificacion["mensaje_fuera_alcance"]],
                valida=False,
            )
            pregunta.asignar_respuesta(respuesta)
            self._persistir_interaccion(pregunta, sesion)
            return respuesta

        if clasificacion["es_dimension_inexistente"]:
            motivo = clasificacion["mensaje_dimension"]
            pregunta.marcar_error(motivo)
            respuesta = RespuestaAgente(
                texto_interpretacion=(
                    "No es posible procesar la consulta: La dimensión solicitada no existe en el esquema estrella "
                    "del Data Mart (dimensiones válidas: Tiempo, Cliente, Producto, Canal, Sucursal)."
                ),
                resultado_cuantitativo=None,
                metrica_utilizada="N/A",
                regla_calculo="N/A",
                periodo_aplicado="N/A",
                filtros_aplicados={},
                dimension_analizada="Dimensión Inválida",
                fuentes_consultadas=["Esquema Estrella DataMart_Ventas"],
                consulta_utilizada="NINGUNA (DIMENSIÓN INEXISTENTE)",
                advertencias=[motivo],
                valida=False,
            )
            pregunta.asignar_respuesta(respuesta)
            self._persistir_interaccion(pregunta, sesion)
            return respuesta

        intencion: Intencion = clasificacion["intencion"]
        filtros: Dict[str, Any] = clasificacion["filtros"]
        pregunta.asociar_intencion(intencion, filtros)

        # Paso 3: Selección de la consulta parametrizada
        codigo_consulta = intencion.consulta_sugerida
        consulta = self._catalogo_consultas.get(codigo_consulta)
        if not consulta:
            raise KeyError(f"Consulta analítica '{codigo_consulta}' no registrada en el catálogo del agente.")

        pregunta.asociar_consulta(consulta)

        # Regla de ambigüedad si aplica
        if clasificacion["es_ambigua"]:
            pregunta.marcar_ambigua(clasificacion["mensaje_ambiguedad"])

        # Paso 4: Ejecución sobre el Data Mart
        if not self._ruta_datamart or not self._ruta_datamart.exists():
            resultado = ResultadoConsulta(
                consulta_codigo=codigo_consulta,
                columnas=[],
                filas=[],
                tiempo_ejecucion_ms=0.0,
                total_registros=0,
                parametros_aplicados=filtros,
                exitoso=False,
                mensaje_error=f"No se encontró la base de datos en: {self._ruta_datamart}",
            )
        else:
            with sqlite3.connect(self._ruta_datamart) as con:
                con.execute("PRAGMA foreign_keys = ON")
                resultado = consulta.ejecutar(con, filtros)

        pregunta.registrar_resultado(resultado)

        # Paso 5: Validación del resultado y manejo de advertencias/errores
        pasan_reglas, advertencias_reglas = consulta.aplicar_reglas(resultado)
        if clasificacion["es_ambigua"]:
            advertencias_reglas.append(clasificacion["mensaje_ambiguedad"])
        if clasificacion.get("advertencia_periodo_defecto"):
            advertencias_reglas.append(clasificacion["advertencia_periodo_defecto"])

        # Paso 6: Generación de respuesta gerencial con evidencia
        texto_interpretacion = self._redactar_interpretacion(
            intencion=intencion,
            resultado=resultado,
            filtros=filtros,
            es_vacio=resultado.es_vacio(),
        )

        periodo_txt = (
            f"{filtros.get('desde', '')} a {filtros.get('hasta', '')}".strip()
            if "desde" in filtros
            else (
                f"Periodo A: {filtros.get('a_desde')} a {filtros.get('a_hasta')} | "
                f"Periodo B: {filtros.get('b_desde')} a {filtros.get('b_hasta')}"
                if "a_desde" in filtros
                else "Histórico completo disponible"
            )
        )

        respuesta = RespuestaAgente(
            texto_interpretacion=texto_interpretacion,
            resultado_cuantitativo=resultado.a_lista_diccionarios() if not resultado.es_vacio() else "(Sin registros)",
            metrica_utilizada=", ".join(intencion.metricas_esperadas),
            regla_calculo=consulta.regla_calculo,
            periodo_aplicado=periodo_txt,
            filtros_aplicados=filtros,
            dimension_analizada=", ".join(intencion.dimensiones_esperadas),
            fuentes_consultadas=[consulta.fuente_dato.obtener_resumen_fuente()],
            consulta_utilizada=consulta.codigo,
            advertencias=advertencias_reglas,
            valida=pasan_reglas,
        )
        pregunta.asignar_respuesta(respuesta)

        # Actualizar memoria operativa de la sesión
        if "desde" in filtros and "hasta" in filtros:
            sesion.actualizar_contexto("ultimo_desde", filtros["desde"])
            sesion.actualizar_contexto("ultimo_hasta", filtros["hasta"])
        if "categoria" in filtros:
            sesion.actualizar_contexto("ultima_categoria", filtros["categoria"])

        # Paso 7: Registro en los objetos persistentes (BDOO)
        self._persistir_interaccion(pregunta, sesion)

        return respuesta

    def _persistir_interaccion(self, pregunta: Pregunta, sesion: Sesion) -> None:
        """Guarda en la BDOO la trazabilidad completa mediante persistencia por alcance."""
        if self._motor_bdoo:
            self._motor_bdoo.guardar_grafo(sesion)

    # =========================================================================
    # INTERPRETACIÓN Y CLASIFICACIÓN ORIENTADA A OBJETOS (6.1, 6.4, 7)
    # =========================================================================
    def _interpretar(self, texto: str, sesion: Sesion) -> Dict[str, Any]:
        t = texto.lower()

        # 1. Chequeo de seguridad: Operaciones no autorizadas o tablas operacionales (7.1)
        palabras_destructivas = ["drop", "delete", "insert", "update", "alter", "truncate", "src_"]
        if any(p in t for p in palabras_destructivas):
            return {
                "es_no_autorizada": True,
                "mensaje_bloqueo": "Operación denegada: Instrucción destructiva o acceso a tablas no autorizadas.",
                "es_fuera_de_alcance": False,
                "es_ambigua": False,
                "es_dimension_inexistente": False,
            }

        # 2. Chequeo de fuera de alcance del Data Mart (6.4 y 7.1)
        fuera_alcance = [
            "salario", "sueldo", "nomina", "nómina", "empleado", "empleados",
            "inflacion", "inflación", "dolar", "dólar", "tipo de cambio", "asistencia", "vacaciones"
        ]
        if any(fa in t for fa in fuera_alcance):
            return {
                "es_no_autorizada": False,
                "es_fuera_de_alcance": True,
                "mensaje_fuera_alcance": "La solicitud requiere datos ajenos a las ventas comerciales de la organización.",
                "es_ambigua": False,
                "es_dimension_inexistente": False,
            }

        # 3. Chequeo de dimensiones inexistentes (7.1)
        dimensiones_falsas = ["proveedor", "vendedor", "almacen", "bodega", "temperatura", "clima"]
        if any(f in t for f in dimensiones_falsas):
            return {
                "es_no_autorizada": False,
                "es_fuera_de_alcance": False,
                "es_ambigua": False,
                "es_dimension_inexistente": True,
                "mensaje_dimension": "La dimensión solicitada no forma parte del Data Mart dimensional de ventas.",
            }

        # Detección de fechas o periodos
        desde = sesion.obtener_contexto("ultimo_desde", self._periodo_disponible["desde"])
        hasta = sesion.obtener_contexto("ultimo_hasta", self._periodo_disponible["hasta"])
        advertencia_periodo = None

        # Si el usuario no especificó periodo explícito
        mencion_tiempo = any(
            palabra in t
            for palabra in ["mes", "trimestre", "2026", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "ultimos"]
        )
        if not mencion_tiempo and "reduc" not in t:
            advertencia_periodo = (
                f"Periodo no explicitado en la pregunta. Se asume automáticamente el periodo "
                f"completo disponible en el Data Mart ({desde} a {hasta})."
            )

        # Mapeo de preguntas mínimas y casos obligatorios:
        # P1: ¿Cuál fue el ingreso neto por mes?
        if "ingreso neto por mes" in t or ("ingreso" in t and "mes" in t and "canal" not in t):
            intencion = self._catalogo_intenciones["INT_VENTAS_MES"]
            filtros = {"desde": desde, "hasta": hasta}
            return {
                "es_no_autorizada": False, "es_fuera_de_alcance": False, "es_ambigua": False,
                "es_dimension_inexistente": False, "intencion": intencion, "filtros": filtros,
                "advertencia_periodo_defecto": advertencia_periodo,
            }

        # P2: ¿Cuáles son las cinco categorías con mayor margen bruto?
        if "cinco categorías" in t or "cinco categorias" in t or ("categor" in t and "margen bruto" in t and "mayor" in t):
            intencion = self._catalogo_intenciones["INT_RANKING_CATEGORIA_MARGEN"]
            n = 5
            match_n = re.search(r"\b(\d+)\s+categor", t)
            if match_n:
                n = int(match_n.group(1))
            filtros = {"desde": desde, "hasta": hasta, "n": n}
            return {
                "es_no_autorizada": False, "es_fuera_de_alcance": False, "es_ambigua": False,
                "es_dimension_inexistente": False, "intencion": intencion, "filtros": filtros,
                "advertencia_periodo_defecto": advertencia_periodo,
            }

        # P3: ¿Qué sucursal presenta el ticket promedio más alto?
        if "sucursal" in t and ("ticket promedio" in t or "ticket más alto" in t or "ticket mas alto" in t):
            intencion = self._catalogo_intenciones["INT_TICKET_PROMEDIO_SUCURSAL"]
            filtros = {"desde": desde, "hasta": hasta, "n": 1}
            return {
                "es_no_autorizada": False, "es_fuera_de_alcance": False, "es_ambigua": False,
                "es_dimension_inexistente": False, "intencion": intencion, "filtros": filtros,
                "advertencia_periodo_defecto": advertencia_periodo,
            }

        # P4: ¿Qué segmento de clientes redujo más su volumen de compra? (periodo A vs periodo B)
        if "segmento" in t and ("redujo" in t or "volumen" in t or "variacion" in t):
            intencion = self._catalogo_intenciones["INT_REDUCCION_VOLUMEN_SEGMENTO"]
            filtros = {
                "a_desde": "2026-04-01", "a_hasta": "2026-06-30",
                "b_desde": "2026-07-01", "b_hasta": "2026-09-30",
            }
            return {
                "es_no_autorizada": False, "es_fuera_de_alcance": False, "es_ambigua": False,
                "es_dimension_inexistente": False, "intencion": intencion, "filtros": filtros,
                "advertencia_periodo_defecto": None,
            }

        # P6: Compare el margen de dos canales durante los últimos tres meses disponibles.
        if "compare" in t or "comparar" in t or ("margen" in t and "dos canales" in t):
            intencion = self._catalogo_intenciones["INT_COMPARAR_MARGEN_CANALES"]
            # Últimos 3 meses disponibles en el Data Mart
            filtros = {
                "canal1": "Tienda Fisica",
                "canal2": "Web",
                "desde": "2026-07-01",
                "hasta": "2026-09-30",
            }
            return {
                "es_no_autorizada": False, "es_fuera_de_alcance": False, "es_ambigua": False,
                "es_dimension_inexistente": False, "intencion": intencion, "filtros": filtros,
                "advertencia_periodo_defecto": None,
            }

        # P7: ¿Qué producto lidera las ventas dentro de una categoría y periodo determinados?
        if "producto lidera" in t or "producto líder" in t or "lidera las ventas" in t:
            intencion = self._catalogo_intenciones["INT_LIDER_VENTAS_CATEGORIA"]
            # Detectar categoría si viene especificada
            categoria = "Electronica"
            for cat in ["Electronica", "Hogar", "Ropa", "Alimentos", "Deportes"]:
                if cat.lower() in t:
                    categoria = cat
                    break
            filtros = {"categoria": categoria, "desde": "2026-07-01", "hasta": "2026-09-30"}
            return {
                "es_no_autorizada": False, "es_fuera_de_alcance": False, "es_ambigua": False,
                "es_dimension_inexistente": False, "intencion": intencion, "filtros": filtros,
                "advertencia_periodo_defecto": None,
            }

        # P5 o Ambigüedad: "¿Cuál fue el mejor canal?" (6.4 y 7.1)
        if "mejor canal" in t or "canal concentra" in t or ("canal" in t and "mayor valor" in t):
            es_ambigua = "mejor canal" in t
            intencion = self._catalogo_intenciones["INT_CANAL_MAYOR_VENTA"]
            filtros = {"desde": desde, "hasta": hasta, "n": 1}
            return {
                "es_no_autorizada": False, "es_fuera_de_alcance": False,
                "es_ambigua": es_ambigua,
                "mensaje_ambiguedad": (
                    "El término 'mejor canal' es ambiguo (podría medirse por ingreso neto, margen bruto, "
                    "volumen de tickets o unidades vendidas). El agente explicitó el criterio: Ingreso Neto."
                ) if es_ambigua else None,
                "es_dimension_inexistente": False, "intencion": intencion, "filtros": filtros,
                "advertencia_periodo_defecto": advertencia_periodo,
            }

        # Caso adicional: Consulta sin registros para probar regla de vacío (7.1)
        if "sin registros" in t or "categoria inexistente" in t or "2099" in t:
            intencion = self._catalogo_intenciones["INT_LIDER_VENTAS_CATEGORIA"]
            filtros = {"categoria": "CategoriaInexistenteXYZ", "desde": "2099-01-01", "hasta": "2099-12-31"}
            return {
                "es_no_autorizada": False, "es_fuera_de_alcance": False, "es_ambigua": False,
                "es_dimension_inexistente": False, "intencion": intencion, "filtros": filtros,
                "advertencia_periodo_defecto": None,
            }

        # Por defecto: Intención de ventas mensual
        intencion = self._catalogo_intenciones.get("INT_VENTAS_MES")
        return {
            "es_no_autorizada": False, "es_fuera_de_alcance": False, "es_ambigua": False,
            "es_dimension_inexistente": False, "intencion": intencion,
            "filtros": {"desde": desde, "hasta": hasta},
            "advertencia_periodo_defecto": advertencia_periodo,
        }

    def _redactar_interpretacion(
        self, intencion: Intencion, resultado: ResultadoConsulta, filtros: Dict[str, Any], es_vacio: bool
    ) -> str:
        """Redacta una síntesis ejecutiva contextualizada según la intención y los resultados."""
        if es_vacio:
            return (
                f"No se detectaron transacciones registradas en el Data Mart para la intención "
                f"'{intencion.nombre}' con los filtros especificados. No se asignan valores cero no justificados."
            )

        filas = resultado.filas
        total = len(filas)

        if intencion.codigo == "INT_VENTAS_MES":
            primera = filas[0]
            ultima = filas[-1]
            return (
                f"Se evaluó el ingreso neto mensual durante el periodo analizado ({total} meses registrados). "
                f"El periodo inició con un ingreso de ${primera[3]:,.2f} en {primera[2]} {primera[0]} y "
                f"cerró con ${ultima[3]:,.2f} en {ultima[2]} {ultima[0]}."
            )

        if intencion.codigo == "INT_RANKING_CATEGORIA_MARGEN":
            top1 = filas[0]
            return (
                f"En el ranking de margen bruto comercial, la categoría líder es '{top1[0]}' "
                f"con un margen bruto acumulado de ${top1[1]:,.2f} en el periodo evaluado."
            )

        if intencion.codigo == "INT_TICKET_PROMEDIO_SUCURSAL":
            top1 = filas[0]
            return (
                f"La sucursal con el ticket promedio más alto es '{top1[0]}' "
                f"alcanzando un promedio de ${top1[2]:,.2f} por transacción sobre un total de {top1[1]} tickets."
            )

        if intencion.codigo == "INT_REDUCCION_VOLUMEN_SEGMENTO":
            mayor_reduccion = filas[0]
            return (
                f"El análisis comparativo entre periodos muestra que el segmento '{mayor_reduccion[0]}' "
                f"presentó la mayor contracción en volumen de compra, con una variación de "
                f"{mayor_reduccion[3]} unidades (de {mayor_reduccion[1]} a {mayor_reduccion[2]} unidades)."
            )

        if intencion.codigo == "INT_CANAL_MAYOR_VENTA":
            top1 = filas[0]
            return (
                f"El canal de ventas que concentra el mayor valor es '{top1[0]}' "
                f"con un ingreso neto consolidado de ${top1[1]:,.2f}."
            )

        if intencion.codigo == "INT_COMPARAR_MARGEN_CANALES":
            canales = set(f[0] for f in filas)
            return (
                f"Se comparó el margen bruto y porcentual para los canales {', '.join(canales)} "
                f"a lo largo de los últimos tres meses disponibles. Los resultados reflejan la rentabilidad comparativa mes a mes."
            )

        if intencion.codigo == "INT_LIDER_VENTAS_CATEGORIA":
            top1 = filas[0]
            return (
                f"Para la categoría '{filtros.get('categoria')}', el producto líder en ventas es "
                f"'{top1[0]}' con {top1[1]} unidades vendidas y un ingreso neto total de ${top1[2]:,.2f}."
            )

        return f"Consulta '{intencion.nombre}' resuelta satisfactoriamente con {total} registros de evidencia."

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "nombre": self._nombre,
            "version_agente": self._version_agente,
            "total_consultas_catalogo": len(self._catalogo_consultas),
            "total_intenciones_catalogo": len(self._catalogo_intenciones),
            "total_fuentes_datos": len(self._fuentes_datos),
            "periodo_disponible": self._periodo_disponible,
        })
        return base
