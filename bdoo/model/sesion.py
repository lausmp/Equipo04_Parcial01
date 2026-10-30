"""
sesion.py
---------
Agrupa la conversación y su contexto analítico.
Mantiene la memoria operativa de corto plazo y la agregación de preguntas
formuladas por un usuario específico durante una interacción continua.
"""
from __future__ import annotations

from datetime import datetime
from typing import Any, Dict, List, Optional, TYPE_CHECKING
from .base import EntidadPersistente

if TYPE_CHECKING:
    from .usuario import Usuario
    from .pregunta import Pregunta


class Sesion(EntidadPersistente):
    """
    Representa una sesión de trabajo de un usuario con el Agente Analítico.
    Conserva la trazabilidad conversacional y el contexto de negocio.
    """

    def __init__(
        self,
        id_sesion: str,
        usuario: Usuario,
        estado: str = "ACTIVA",
        fecha_fin: Optional[str] = None,
        preguntas: Optional[List[Pregunta]] = None,
        contexto_conversacional: Optional[Dict[str, Any]] = None,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(oid, fecha_creacion, fecha_modificacion, version)
        self._id_sesion: str = id_sesion
        self._usuario: Usuario = usuario
        self._estado: str = estado
        self._fecha_fin: Optional[str] = fecha_fin
        self._preguntas: List[Pregunta] = list(preguntas) if preguntas else []
        self._contexto_conversacional: Dict[str, Any] = dict(contexto_conversacional) if contexto_conversacional else {}

    @property
    def id_sesion(self) -> str:
        return self._id_sesion

    @property
    def usuario(self) -> Usuario:
        return self._usuario

    @property
    def estado(self) -> str:
        return self._estado

    @property
    def fecha_fin(self) -> Optional[str]:
        return self._fecha_fin

    @property
    def preguntas(self) -> List[Pregunta]:
        return list(self._preguntas)

    @property
    def contexto_conversacional(self) -> Dict[str, Any]:
        return dict(self._contexto_conversacional)

    def agregar_pregunta(self, pregunta: Pregunta) -> None:
        """Agrega una pregunta al hilo de la sesión y actualiza el contexto."""
        self._preguntas.append(pregunta)
        self.registrar_modificacion()

    def actualizar_contexto(self, clave: str, valor: Any) -> None:
        """Actualiza una variable contextual de la sesión (ej. último periodo usado)."""
        self._contexto_conversacional[clave] = valor
        self.registrar_modificacion()

    def obtener_contexto(self, clave: str, por_defecto: Any = None) -> Any:
        return self._contexto_conversacional.get(clave, por_defecto)

    def finalizar_sesion(self) -> None:
        self._estado = "FINALIZADA"
        self._fecha_fin = datetime.now().isoformat()
        self.registrar_modificacion()

    def obtener_ultima_pregunta(self) -> Optional[Pregunta]:
        return self._preguntas[-1] if self._preguntas else None

    def total_preguntas(self) -> int:
        return len(self._preguntas)

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "id_sesion": self._id_sesion,
            "usuario_oid": self._usuario.oid,
            "usuario_id": self._usuario.id_usuario,
            "estado": self._estado,
            "fecha_fin": self._fecha_fin,
            "preguntas_oids": [p.oid for p in self._preguntas],
            "total_preguntas": len(self._preguntas),
            "contexto_conversacional": self._contexto_conversacional,
        })
        return base
