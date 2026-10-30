"""
Módulo de Almacenamiento y Persistencia de la BDOO.
"""
from .engine import BDOOEngine, BDOOTransaccionError

__all__ = ["BDOOEngine", "BDOOTransaccionError"]
