"""
base.py
-------
Clase base para todas las entidades persistentes de la Base de Datos Orientada a Objetos.
Implementa el concepto fundamental de Object Identifier (OID) independiente de los
valores de sus atributos (principio ODMG-3.0 de identidad de objetos), marcas temporales
y control de versiones.
"""
from __future__ import annotations

import uuid
from abc import ABC, abstractmethod
from datetime import datetime
from typing import Any, Dict, Optional


class EntidadPersistente(ABC):
    """
    Clase base abstracta de persistencia para el modelo BDOO.

    Garantiza:
    1. Identidad de Objeto (OID): Inmutable e independiente de la clave primaria relacional.
    2. Metadatos de auditoría: fecha de creación y última modificación.
    3. Versionado: control de evolución del estado del objeto.
    4. Encapsulamiento: atributos protegidos accesibles solo mediante propiedades controladas.
    """

    def __init__(
        self,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        self._oid: str = oid if oid else self._generar_oid()
        ahora = datetime.now().isoformat()
        self._fecha_creacion: str = fecha_creacion if fecha_creacion else ahora
        self._fecha_modificacion: str = fecha_modificacion if fecha_modificacion else ahora
        self._version: int = version

    @classmethod
    def _prefijo_oid(cls) -> str:
        """Prefijo semántico para el OID según la clase concreta."""
        return cls.__name__[:4].upper()

    def _generar_oid(self) -> str:
        """Genera un identificador universal único (OID) para el objeto."""
        return f"{self._prefijo_oid()}-{uuid.uuid4().hex[:12].upper()}"

    # Encapsulamiento: Propiedades de solo lectura o controladas
    @property
    def oid(self) -> str:
        """Identificador de objeto (OID)."""
        return self._oid

    @property
    def fecha_creacion(self) -> str:
        return self._fecha_creacion

    @property
    def fecha_modificacion(self) -> str:
        return self._fecha_modificacion

    @property
    def version(self) -> int:
        return self._version

    def registrar_modificacion(self) -> None:
        """Actualiza la marca temporal de modificación e incrementa la versión."""
        self._fecha_modificacion = datetime.now().isoformat()
        self._version += 1

    @abstractmethod
    def a_diccionario(self) -> Dict[str, Any]:
        """
        Serializa el estado del objeto a un diccionario estructurado,
        incluyendo metadatos de tipo para permitir su reconstrucción polimórfica.
        """
        return {
            "__clase__": self.__class__.__name__,
            "__modulo__": self.__class__.__module__,
            "oid": self._oid,
            "fecha_creacion": self._fecha_creacion,
            "fecha_modificacion": self._fecha_modificacion,
            "version": self._version,
        }

    def __eq__(self, otro: object) -> bool:
        """Dos entidades son idénticas si comparten el mismo OID (identidad de objeto)."""
        if not isinstance(otro, EntidadPersistente):
            return False
        return self._oid == otro._oid

    def __hash__(self) -> int:
        return hash(self._oid)

    def __repr__(self) -> str:
        return f"<{self.__class__.__name__} OID={self._oid} v={self._version}>"
