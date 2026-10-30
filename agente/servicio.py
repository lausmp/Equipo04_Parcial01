"""
servicio.py
-----------
Fachada de servicio del Agente Analítico de IA.
Conecta la capa de presentación (CLI, Web o Pruebas) con el modelo de dominio BDOO,
el interpretador semántico y el Data Mart relacional.
"""
from __future__ import annotations

from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

from bdoo.catalogo import inicializar_catalogo_oficial
from bdoo.model.agente import AgenteAnalitico
from bdoo.model.pregunta import Pregunta
from bdoo.model.respuesta_agente import RespuestaAgente
from bdoo.model.sesion import Sesion
from bdoo.model.usuario import Usuario, UsuarioGerencial, UsuarioOperativo
from bdoo.storage.engine import BDOOEngine

from .formateador import FormateadorRespuesta
from .interpretador import InterpretadorPreguntas, ResultadoInterpretacion

RAIZ = Path(__file__).parent.parent
DIR_DATOS_BDOO = RAIZ / "bdoo" / "datos"
RUTA_ALMACEN_BDOO = DIR_DATOS_BDOO / "bdoo_almacen.json"
RUTA_DATAMART_DB = RAIZ / "datamart" / "datamart.db"


class ServicioAgenteAnalitico:
    """
    Controlador central del ciclo de vida del agente.
    """

    def __init__(
        self,
        ruta_datamart: Optional[Path] = None,
        ruta_bdoo_almacen: Optional[Path] = None,
    ) -> None:
        self._ruta_datamart = Path(ruta_datamart) if ruta_datamart else RUTA_DATAMART_DB
        self._ruta_bdoo = Path(ruta_bdoo_almacen) if ruta_bdoo_almacen else RUTA_ALMACEN_BDOO

        # 1. Iniciar BDOO
        self._motor_bdoo = BDOOEngine(ruta_archivo=self._ruta_bdoo)

        # 2. Iniciar Agente Analítico (Entidad BDOO)
        self._agente = AgenteAnalitico(
            nombre="Agente Analítico de Ventas - Equipo 04",
            version_agente="1.0.0",
            ruta_datamart=self._ruta_datamart,
            motor_bdoo=self._motor_bdoo,
        )
        self._motor_bdoo.guardar(self._agente)

        # 3. Cargar catálogo oficial de fuentes, consultas y reglas
        self._fuente_oficial = inicializar_catalogo_oficial(self._agente)
        self._agente.inicializar_periodo_datamart()

        # 4. Iniciar interpretador sintáctico-semántico
        self._interpretador = InterpretadorPreguntas(
            periodo_datamart_defecto=self._agente._periodo_disponible
        )

        # 5. Usuario y sesión por defecto
        self._usuario_actual = UsuarioGerencial(
            id_usuario="USR-GER-01",
            nombre="Dra. Mariana Rossi",
            correo="m.rossi@comercial.com",
            departamento="Dirección Comercial y Estrategia",
            cargo="Directora General",
            nivel_acceso="DIRECTIVO",
        )
        self._motor_bdoo.guardar(self._usuario_actual)
        self._sesion_actual = self._agente.crear_sesion(self._usuario_actual, id_sesion="SES-DEF-001")

    @property
    def agente(self) -> AgenteAnalitico:
        return self._agente

    @property
    def motor_bdoo(self) -> BDOOEngine:
        return self._motor_bdoo

    @property
    def sesion_actual(self) -> Sesion:
        return self._sesion_actual

    @property
    def usuario_actual(self) -> Usuario:
        return self._usuario_actual

    def cambiar_usuario(self, usuario: Usuario) -> Sesion:
        """Cambia el usuario activo e inicia una nueva sesión BDOO."""
        self._usuario_actual = usuario
        self._motor_bdoo.guardar(usuario)
        self._sesion_actual = self._agente.crear_sesion(usuario)
        return self._sesion_actual

    def consultar(
        self, texto_pregunta: str
    ) -> Tuple[ResultadoInterpretacion, RespuestaAgente, str]:
        """
        Procesa una pregunta en lenguaje natural:
        1. Interpreta la solicitud (numeral 6.1 y 6.4).
        2. Ejecuta el agente analítico con trazabilidad BDOO.
        3. Formatea la respuesta con evidencia ejecutiva (numeral 6.3).
        Retorna: (interpretacion, respuesta_objeto, informe_formateado_texto).
        """
        # Paso A: Interpretación semántica con desglose 6.1
        interpretacion = self._interpretador.interpretar(
            texto_pregunta, self._sesion_actual.contexto_conversacional
        )

        # Paso B: Ejecución a través del AgenteAnalitico (flujo 2.1 y persistencia BDOO)
        respuesta = self._agente.procesar_solicitud(texto_pregunta, self._sesion_actual)

        # Paso C: Formateo ejecutivo con evidencia
        informe_formateado = FormateadorRespuesta.a_texto_consola(respuesta, usar_colores=True)

        return interpretacion, respuesta, informe_formateado

    def obtener_trazabilidad_sesion(self) -> List[Dict[str, Any]]:
        """Obtiene la trazabilidad completa de todas las preguntas de la sesión actual."""
        return [p.obtener_trazabilidad_completa() for p in self._sesion_actual.preguntas]

    def obtener_resumen_bdoo(self) -> Dict[str, Any]:
        """Obtiene estadísticas de persistencia de la BDOO."""
        return {
            "total_objetos": self._motor_bdoo.total_objetos,
            "extents": self._motor_bdoo.obtener_resumen_extents(),
            "sesiones": len(self._motor_bdoo.obtener_extent(Sesion)),
            "preguntas": len(self._motor_bdoo.obtener_extent(Pregunta)),
        }
