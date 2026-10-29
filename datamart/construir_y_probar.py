"""
construir_y_probar.py
---------------------
1. Genera los datos (02_datos_src.sql) si no existen.
2. Construye datamart.db ejecutando 01, 02 y 03.
3. Ejecuta los controles (05) y muestra los resultados.
4. Ejecuta el catalogo de consultas (04) con parametros de ejemplo.
5. Arma ../EquipoXX_Datamart.sql (archivo unico a entregar) y comprueba que
   se puede reconstruir la base DESDE CERO usando solo ese archivo.

Uso:  python construir_y_probar.py
"""
import re
import sqlite3
from pathlib import Path

import generar_datos

AQUI = Path(__file__).parent
DB = AQUI / "datamart.db"
FINAL = AQUI.parent / "Equipo04_Datamart.sql"

# Parametros de ejemplo (el agente los calculara a partir de la pregunta)
PARAMS_BASE = {
    "desde": "2026-04-01", "hasta": "2026-09-30", "n": 5,
    "a_desde": "2026-04-01", "a_hasta": "2026-06-30",
    "b_desde": "2026-07-01", "b_hasta": "2026-09-30",
    "canal1": "Tienda Fisica", "canal2": "Web",
    "categoria": "Electronica",
}
PARAMS_POR_CONSULTA = {
    "Q3": {"n": 1}, "Q5": {"n": 1},
    "Q6": {"desde": "2026-07-01", "hasta": "2026-09-30"},   # ultimos 3 meses disponibles
    "Q9": {"n": 10},
    "Q7": {"desde": "2026-07-01", "hasta": "2026-09-30"},
}


def leer_sentencias(ruta: Path):
    """Devuelve [(titulo, sql)] separando por sentencia completa."""
    resultado, buf, titulo = [], "", ""
    for linea in ruta.read_text(encoding="utf-8").splitlines():
        if linea.startswith("-- ["):
            titulo = linea[3:].strip()
        buf += linea + "\n"
        if sqlite3.complete_statement(buf):
            if re.search(r"(?im)^\s*(select|with|insert)\b", buf):
                resultado.append((titulo, buf.strip()))
            buf = ""
    return resultado


def mostrar(titulo, cursor):
    print(f"\n>>> {titulo}")
    cols = [c[0] for c in cursor.description]
    print("    " + " | ".join(cols))
    filas = cursor.fetchall()
    if not filas:
        print("    (sin registros)")
    for fila in filas:
        print("    " + " | ".join(str(x) for x in fila))


def construir(conexion_sqls):
    if DB.exists():
        DB.unlink()
    con = sqlite3.connect(DB)
    con.execute("PRAGMA foreign_keys = ON")
    for texto in conexion_sqls:
        con.executescript(texto)
    con.commit()
    return con


def armar_final():
    partes = []
    for nombre in ["01_estructura.sql", "02_datos_src.sql", "03_carga_etl.sql",
                   "04_consultas.sql", "05_controles.sql"]:
        texto = (AQUI / nombre).read_text(encoding="utf-8")
        if nombre == "04_consultas.sql":
            # Las consultas llevan :parametros -> se incluyen comentadas para que
            # el archivo final se ejecute completo sin errores.
            texto = ("-- (Catalogo de consultas parametrizadas: se ejecutan desde el agente "
                     "con valores para los :parametros.\n-- Para probarlas a mano, "
                     "reemplaza cada :parametro por un valor y quita el prefijo '-- '.)\n"
                     + "\n".join(("-- " + l) if l.strip() else l for l in texto.splitlines()) + "\n")
        partes.append(f"-- >>>>>>>>>> {nombre} <<<<<<<<<<\n{texto}")
    FINAL.write_text("\n\n".join(partes), encoding="utf-8")


def main():
    if not (AQUI / "02_datos_src.sql").exists():
        generar_datos.main()

    archivos = [(AQUI / n).read_text(encoding="utf-8")
                for n in ["01_estructura.sql", "02_datos_src.sql", "03_carga_etl.sql"]]
    con = construir(archivos)
    print("Base construida:", DB.name)
    for tabla in ["src_ventas", "DimTiempo", "DimCliente", "DimProducto",
                  "DimCanal", "DimSucursal", "FactVentas"]:
        print(f"  {tabla:12s} {con.execute(f'SELECT COUNT(*) FROM {tabla}').fetchone()[0]} filas")

    print("\n================ CONTROLES (05_controles.sql) ================")
    for titulo, sql in leer_sentencias(AQUI / "05_controles.sql"):
        mostrar(titulo, con.execute(sql))

    print("\n================ CONSULTAS (04_consultas.sql) ================")
    for titulo, sql in leer_sentencias(AQUI / "04_consultas.sql"):
        clave = re.match(r"\[(Q\d+)\]", titulo).group(1)
        params = {**PARAMS_BASE, **PARAMS_POR_CONSULTA.get(clave, {})}
        mostrar(titulo, con.execute(sql, params))
    con.close()

    print("\n================ ARCHIVO FINAL ================")
    armar_final()
    con2 = construir([FINAL.read_text(encoding="utf-8")])
    n = con2.execute("SELECT COUNT(*) FROM FactVentas").fetchone()[0]
    print(f"{FINAL.name} reconstruye la base desde cero: FactVentas = {n} filas  -> OK")
    con2.close()


if __name__ == "__main__":
    main()
