"""
usuario.py
----------
Representa a quien formula la pregunta en el sistema.
Demuestra encapsulamiento y herencia con especializaciones para usuarios
gerenciales y operativos, aplicando polimorfismo en el control de permisos analíticos.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional
from .base import EntidadPersistente


class Usuario(EntidadPersistente):
    """
    Clase base para representar un usuario que interactúa con el Agente Analítico.
    """

    def __init__(
        self,
        id_usuario: str,
        nombre: str,
        correo: str,
        rol: str = "ANALISTA",
        activo: bool = True,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(oid, fecha_creacion, fecha_modificacion, version)
        self._id_usuario: str = id_usuario
        self._nombre: str = nombre
        self._correo: str = correo
        self._rol: str = rol.upper()
        self._activo: bool = activo

    # Encapsulamiento
    @property
    def id_usuario(self) -> str:
        return self._id_usuario

    @property
    def nombre(self) -> str:
        return self._nombre

    @nombre.setter
    def nombre(self, nuevo_nombre: str) -> None:
        if not nuevo_nombre or not nuevo_nombre.strip():
            raise ValueError("El nombre de usuario no puede estar vacío.")
        self._nombre = nuevo_nombre.strip()
        self.registrar_modificacion()

    @property
    def correo(self) -> str:
        return self._correo

    @property
    def rol(self) -> str:
        return self._rol

    @property
    def activo(self) -> bool:
        return self._activo

    def desactivar(self) -> None:
        self._activo = False
        self.registrar_modificacion()

    def activar(self) -> None:
        self._activo = True
        self.registrar_modificacion()

    def puede_ejecutar(self, operacion: str) -> bool:
        """
        Método polimórfico de autorización de operaciones analíticas.
        Por defecto, un usuario general puede ejecutar consultas de solo lectura estándar.
        """
        if not self._activo:
            return False
        # Las operaciones de solo lectura del Data Mart están habilitadas
        operaciones_restringidas = {"ADMINISTRAR_CATALOGO", "VER_MARGEN_CONFIDENCIAL", "AUDITORIA_SCD2"}
        return operacion not in operaciones_restringidas

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "id_usuario": self._id_usuario,
            "nombre": self._nombre,
            "correo": self._correo,
            "rol": self._rol,
            "activo": self._activo,
        })
        return base

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> Usuario:
        return cls(
            id_usuario=datos["id_usuario"],
            nombre=datos["nombre"],
            correo=datos["correo"],
            rol=datos.get("rol", "ANALISTA"),
            activo=datos.get("activo", True),
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class UsuarioGerencial(Usuario):
    """
    Subclase especializada que representa un perfil de toma de decisiones gerenciales.
    Posee acceso ampliado a indicadores estratégicos, rentabilidad y análisis de márgenes.
    """

    def __init__(
        self,
        id_usuario: str,
        nombre: str,
        correo: str,
        departamento: str,
        cargo: str,
        nivel_acceso: str = "GERENCIAL",
        autoriza_descuentos: bool = True,
        activo: bool = True,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            id_usuario=id_usuario,
            nombre=nombre,
            correo=correo,
            rol="GERENCIAL",
            activo=activo,
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )
        self._departamento: str = departamento
        self._cargo: str = cargo
        self._nivel_acceso: str = nivel_acceso.upper()
        self._autoriza_descuentos: bool = autoriza_descuentos

    @property
    def departamento(self) -> str:
        return self._departamento

    @property
    def cargo(self) -> str:
        return self._cargo

    @property
    def nivel_acceso(self) -> str:
        return self._nivel_acceso

    @property
    def autoriza_descuentos(self) -> bool:
        return self._autoriza_descuentos

    def puede_ejecutar(self, operacion: str) -> bool:
        """
        Polimorfismo: El usuario gerencial tiene autorización para consultar
        márgenes confidenciales, evolución de canales y métricas de rentabilidad.
        """
        if not self._activo:
            return False
        # El usuario gerencial tiene acceso pleno al catálogo analítico
        return True

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "departamento": self._departamento,
            "cargo": self._cargo,
            "nivel_acceso": self._nivel_acceso,
            "autoriza_descuentos": self._autoriza_descuentos,
        })
        return base

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> UsuarioGerencial:
        return cls(
            id_usuario=datos["id_usuario"],
            nombre=datos["nombre"],
            correo=datos["correo"],
            departamento=datos.get("departamento", "Dirección Comercial"),
            cargo=datos.get("cargo", "Gerente"),
            nivel_acceso=datos.get("nivel_acceso", "GERENCIAL"),
            autoriza_descuentos=datos.get("autoriza_descuentos", True),
            activo=datos.get("activo", True),
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )


class UsuarioOperativo(Usuario):
    """
    Subclase para usuarios con permisos acotados a una sucursal o canal específico.
    """

    def __init__(
        self,
        id_usuario: str,
        nombre: str,
        correo: str,
        sucursal_asignada: Optional[str] = None,
        canal_asignado: Optional[str] = None,
        activo: bool = True,
        oid: Optional[str] = None,
        fecha_creacion: Optional[str] = None,
        fecha_modificacion: Optional[str] = None,
        version: int = 1,
    ) -> None:
        super().__init__(
            id_usuario=id_usuario,
            nombre=nombre,
            correo=correo,
            rol="OPERATIVO",
            activo=activo,
            oid=oid,
            fecha_creacion=fecha_creacion,
            fecha_modificacion=fecha_modificacion,
            version=version,
        )
        self._sucursal_asignada = sucursal_asignada
        self._canal_asignado = canal_asignado

    @property
    def sucursal_asignada(self) -> Optional[str]:
        return self._sucursal_asignada

    @property
    def canal_asignado(self) -> Optional[str]:
        return self._canal_asignado

    def puede_ejecutar(self, operacion: str) -> bool:
        if not self._activo:
            return False
        # Operaciones restringidas para usuarios operativos
        restringidas = {"VER_MARGEN_CONFIDENCIAL", "COMPARAR_CANALES_GLOBAL"}
        return operacion not in restringidas

    def a_diccionario(self) -> Dict[str, Any]:
        base = super().a_diccionario()
        base.update({
            "sucursal_asignada": self._sucursal_asignada,
            "canal_asignado": self._canal_asignado,
        })
        return base

    @classmethod
    def desde_diccionario(cls, datos: Dict[str, Any]) -> UsuarioOperativo:
        return cls(
            id_usuario=datos["id_usuario"],
            nombre=datos["nombre"],
            correo=datos["correo"],
            sucursal_asignada=datos.get("sucursal_asignada"),
            canal_asignado=datos.get("canal_asignado"),
            activo=datos.get("activo", True),
            oid=datos.get("oid"),
            fecha_creacion=datos.get("fecha_creacion"),
            fecha_modificacion=datos.get("fecha_modificacion"),
            version=datos.get("version", 1),
        )
