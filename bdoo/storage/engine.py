"""
engine.py
---------
Motor de Base de Datos Orientada a Objetos (BDOOEngine).
Implementa los principios teóricos del estándar ODMG-3.0:
1. Identidad de objetos (OID universal independiente del estado).
2. Extents de clases (colecciones tipadas de todas las instancias de una clase y sus subtipos).
3. Persistencia por alcance (Persistence by reachability en grafos de objetos).
4. Transacciones ACID (begin, commit, rollback) con persistencia física atómica.
5. Navegación directa por punteros/referencias sin costo de JOINs relacionales ni desajuste de impedancia (impedance mismatch).
"""
from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Set, Type, TypeVar

from ..model.base import EntidadPersistente

T = TypeVar("T", bound=EntidadPersistente)


class BDOOTransaccionError(Exception):
    """Excepción lanzada ante errores de transacción en la BDOO."""
    pass


class BDOOEngine:
    """
    Motor gestor de la Base de Datos Orientada a Objetos (OODBMS).
    Administra la memoria persistente, los extents de clases y el almacenamiento físico.
    """

    def __init__(self, ruta_archivo: Optional[Path] = None) -> None:
        self._ruta_archivo: Optional[Path] = Path(ruta_archivo) if ruta_archivo else None
        # Tabla universal de objetos por OID
        self._almacen_oid: Dict[str, EntidadPersistente] = {}
        # Extents: mapeo de NombreClase -> Set de OIDs
        self._extents: Dict[str, Set[str]] = {}
        # Estado transaccional
        self._en_transaccion: bool = False
        self._buffer_transaccion: Dict[str, EntidadPersistente] = {}
        self._buffer_eliminados: Set[str] = set()

    @property
    def total_objetos(self) -> int:
        return len(self._almacen_oid)

    def iniciar_transaccion(self) -> None:
        """Inicia una transacción atómica (BEGIN TRANSACTION)."""
        if self._en_transaccion:
            raise BDOOTransaccionError("Ya existe una transacción activa en la BDOO.")
        self._en_transaccion = True
        self._buffer_transaccion.clear()
        self._buffer_eliminados.clear()

    def guardar(self, objeto: EntidadPersistente) -> None:
        """
        Registra un objeto en la BDOO. Si hay transacción activa, lo encola
        en el buffer transaccional; si no, lo persiste inmediatamente.
        """
        if not isinstance(objeto, EntidadPersistente):
            raise TypeError(f"El objeto debe heredar de EntidadPersistente. Recibido: {type(objeto)}")

        if self._en_transaccion:
            self._buffer_transaccion[objeto.oid] = objeto
        else:
            self._registrar_en_memoria(objeto)
            self._persistir_en_disco()

    def guardar_grafo(self, raiz: EntidadPersistente) -> None:
        """
        Persistencia por alcance (Persistence by reachability):
        Guarda un objeto raíz y recorre recursivamente todos los objetos
        persistentes alcanzables desde sus atributos o colecciones.
        """
        visitados: Set[str] = set()

        def _recorrer(obj: Any):
            if isinstance(obj, EntidadPersistente):
                if obj.oid in visitados:
                    return
                visitados.add(obj.oid)
                self.guardar(obj)
                # Explorar atributos internos
                for valor in obj.__dict__.values():
                    _recorrer(valor)
            elif isinstance(obj, (list, tuple, set)):
                for elemento in obj:
                    _recorrer(elemento)
            elif isinstance(obj, dict):
                for v in obj.values():
                    _recorrer(v)

        _recorrer(raiz)

    def _registrar_en_memoria(self, objeto: EntidadPersistente) -> None:
        self._almacen_oid[objeto.oid] = objeto
        # Actualizar extents para la clase y sus superclases
        for cls in objeto.__class__.__mro__:
            if issubclass(cls, EntidadPersistente) and cls is not EntidadPersistente:
                nombre_clase = cls.__name__
                if nombre_clase not in self._extents:
                    self._extents[nombre_clase] = set()
                self._extents[nombre_clase].add(objeto.oid)

    def commit(self) -> None:
        """Confirma la transacción actual (COMMIT) y persiste en disco."""
        if not self._en_transaccion:
            raise BDOOTransaccionError("No hay una transacción activa para confirmar.")

        for oid in self._buffer_eliminados:
            if oid in self._almacen_oid:
                del self._almacen_oid[oid]
                for ext in self._extents.values():
                    ext.discard(oid)

        for obj in self._buffer_transaccion.values():
            self._registrar_en_memoria(obj)

        self._en_transaccion = False
        self._buffer_transaccion.clear()
        self._buffer_eliminados.clear()
        self._persistir_en_disco()

    def rollback(self) -> None:
        """Revierte los cambios de la transacción actual (ROLLBACK)."""
        if not self._en_transaccion:
            raise BDOOTransaccionError("No hay una transacción activa para revertir.")
        self._buffer_transaccion.clear()
        self._buffer_eliminados.clear()
        self._en_transaccion = False

    def obtener_por_oid(self, oid: str) -> Optional[EntidadPersistente]:
        """Recupera un objeto por su identidad OID en O(1)."""
        return self._almacen_oid.get(oid)

    def obtener_extent(self, clase: Type[T]) -> List[T]:
        """
        Retorna el Extent completo de una clase: todas las instancias de dicha clase
        y sus subtipos que residen en la BDOO.
        """
        nombre_clase = clase.__name__
        oids = self._extents.get(nombre_clase, set())
        return [self._almacen_oid[oid] for oid in oids if oid in self._almacen_oid]  # type: ignore

    def buscar(self, clase: Type[T], predicado: Callable[[T], bool]) -> List[T]:
        """
        Consulta declarativa sobre el extent de una clase aplicando un predicado booleano.
        """
        instancias = self.obtener_extent(clase)
        return [inst for inst in instancias if predicado(inst)]

    def _persistir_en_disco(self) -> None:
        """Vuelca el almacén de objetos al archivo físico en formato JSON estructurado."""
        if not self._ruta_archivo:
            return

        self._ruta_archivo.parent.mkdir(parents=True, exist_ok=True)
        datos = {
            "metadatos_bdoo": {
                "motor": "BDOOEngine ODMG-3.0 Compatible",
                "version": "1.0.0",
                "total_objetos": len(self._almacen_oid),
                "extents": {k: len(v) for k, v in self._extents.items()},
            },
            "objetos": {oid: obj.a_diccionario() for oid, obj in self._almacen_oid.items()},
        }
        self._ruta_archivo.write_text(json.dumps(datos, indent=2, ensure_ascii=False), encoding="utf-8")

    def exportar_dump(self, ruta_destino: Path) -> None:
        """Exporta un volcado completo de la BDOO a una ruta específica."""
        ruta_destino.parent.mkdir(parents=True, exist_ok=True)
        datos = {
            "metadatos": {
                "total_objetos": len(self._almacen_oid),
                "extents": {k: len(v) for k, v in self._extents.items()},
            },
            "objetos": [obj.a_diccionario() for obj in self._almacen_oid.values()],
        }
        ruta_destino.write_text(json.dumps(datos, indent=2, ensure_ascii=False), encoding="utf-8")

    def obtener_resumen_extents(self) -> Dict[str, int]:
        """Devuelve un conteo de objetos por cada extent registrado."""
        return {k: len(v) for k, v in self._extents.items()}
