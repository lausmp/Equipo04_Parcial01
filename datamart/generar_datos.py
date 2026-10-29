"""
generar_datos.py
----------------
Genera 02_datos_src.sql con datos de prueba para la capa OPERACIONAL (src_*).

- Es reproducible: usa una semilla fija (SEMILLA), asi todo el equipo obtiene
  exactamente los mismos datos.
- Los datos estan disenados para que TODAS las preguntas del enunciado tengan
  respuesta (ver comentarios "DISENO").

Uso:  python generar_datos.py
"""
import datetime as dt
import random
from pathlib import Path

SEMILLA = 42
FECHA_INI = dt.date(2026, 4, 1)    # DISENO: 6 meses completos (abril a septiembre)
FECHA_FIN = dt.date(2026, 9, 30)
INICIO_WHATSAPP = dt.date(2026, 6, 1)  # DISENO: WhatsApp no existe antes de junio
                                       # -> consulta de WhatsApp en abril/mayo da 0 registros

# (id, nombre, categoria, costo_unitario, precio_base)
# DISENO: 6 categorias (para que el "top 5" tenga sentido).
# P-17 no tiene costo (None) para demostrar que margen/costo quedan en NULL.
PRODUCTOS = [
    ("P-01", "Audifonos Bluetooth",  "Electronica", 18.0, 35.0),
    ("P-02", "Cargador Rapido",      "Electronica",  6.0, 14.0),
    ("P-03", "Teclado Mecanico",     "Electronica", 25.0, 55.0),
    ("P-04", "Licuadora",            "Hogar",       22.0, 45.0),
    ("P-05", "Juego de Sabanas",     "Hogar",       12.0, 30.0),
    ("P-06", "Lampara de Mesa",      "Hogar",        8.0, 22.0),
    ("P-07", "Camisa Casual",        "Ropa",         9.0, 25.0),
    ("P-08", "Jeans",                "Ropa",        14.0, 38.0),
    ("P-09", "Chaqueta",             "Ropa",        28.0, 70.0),
    ("P-10", "Balon de Futbol",      "Deportes",     7.0, 20.0),
    ("P-11", "Bicicleta Estatica",   "Deportes",    90.0, 180.0),
    ("P-12", "Pesas 5kg",            "Deportes",    10.0, 24.0),
    ("P-13", "Set de Bloques",       "Juguetes",     8.0, 20.0),
    ("P-14", "Muneca",               "Juguetes",     6.0, 16.0),
    ("P-15", "Carro Control Remoto", "Juguetes",    12.0, 32.0),
    ("P-16", "Cafe Premium",         "Alimentos",    4.0,  9.0),
    ("P-17", "Caja de Chocolates",   "Alimentos",   None, 12.0),
    ("P-18", "Aceite de Oliva",      "Alimentos",    5.0, 11.0),
]

NOMBRES = [
    "Ana Perez", "Luis Gomez", "Maria Rojas", "Carlos Diaz", "Sofia Marin",
    "Jorge Silva", "Laura Mora", "Pedro Ruiz", "Elena Vega", "Diego Torres",
    "Camila Rios", "Andres Paz", "Valeria Cruz", "Miguel Soto", "Daniela Leon",
    "Ricardo Pena", "Isabel Nunez", "Fernando Cano", "Gabriela Mejia", "Hector Luna",
    "Patricia Bravo", "Oscar Prieto", "Natalia Vera", "Raul Ibarra",
]
IDS_CLIENTES = [f"C{i:03d}" for i in range(1, 25)]

# DISENO: segmento inicial de cada cliente.
#   Regular:   C005 y C009-C016   | Premium: C001-C004, C006-C008 | Ocasional: C017-C024
def segmento_inicial(cid: str) -> str:
    n = int(cid[1:])
    if n == 5 or 9 <= n <= 16:
        return "Regular"
    if n >= 17:
        return "Ocasional"
    return "Premium"

# DISENO: C005 cambia de Regular a Premium el 1-jul-2026 (demuestra SCD Tipo 2).
CAMBIOS_SEGMENTO = {"C005": ("Premium", dt.date(2026, 7, 1))}

def segmento_en(cid: str, fecha: dt.date) -> str:
    if cid in CAMBIOS_SEGMENTO:
        nuevo, desde = CAMBIOS_SEGMENTO[cid]
        if fecha >= desde:
            return nuevo
    return segmento_inicial(cid)

# DISENO: el segmento "Ocasional" compra cada vez menos (para la pregunta
# "que segmento redujo mas su volumen de compra").
PESO_OCASIONAL = {4: 1.0, 5: 1.0, 6: 1.0, 7: 0.6, 8: 0.3, 9: 0.15}

def peso_cliente(cid: str, fecha: dt.date) -> float:
    seg = segmento_en(cid, fecha)
    if seg == "Premium":
        return 2.0
    if seg == "Regular":
        return 1.0
    return PESO_OCASIONAL[fecha.month]

SUCURSALES = [("Sucursal Centro", "Caracas"), ("Sucursal Norte", "Valencia"),
              ("Sucursal Este", "Maracaibo"), ("Sucursal Sur", "Barquisimeto")]


def sql_val(v) -> str:
    """Convierte un valor Python a literal SQL."""
    if v is None:
        return "NULL"
    if isinstance(v, str):
        return "'" + v.replace("'", "''") + "'"
    return repr(v)


def generar_ventas(rnd: random.Random) -> list[dict]:
    ventas = []
    n_ticket = 0
    dia = FECHA_INI
    while dia <= FECHA_FIN:
        for _ in range(rnd.choice([0, 1, 2, 2])):          # tickets del dia
            n_ticket += 1
            tid = f"T-{n_ticket:04d}"
            cid = rnd.choices(IDS_CLIENTES, weights=[peso_cliente(c, dia) for c in IDS_CLIENTES])[0]
            canales = [("Tienda Fisica", 5), ("Web", 3)]
            if dia >= INICIO_WHATSAPP:
                canales.append(("WhatsApp", 2))
            canal = rnd.choices([c for c, _ in canales], weights=[w for _, w in canales])[0]
            suc, ciudad = rnd.choice(SUCURSALES)
            for linea, prod in enumerate(rnd.sample(PRODUCTOS, rnd.randint(1, 3)), start=1):
                cantidad = rnd.randint(1, 3)
                precio = round(prod[4] * rnd.uniform(0.95, 1.05), 2)
                bruto = cantidad * precio
                desc = round(bruto * rnd.choice([0.05, 0.10, 0.15]), 2) if rnd.random() < 0.15 else 0.0
                ventas.append(dict(id_ticket=tid, linea=linea, fecha=dia.isoformat(),
                                   id_cliente=cid, id_producto=prod[0], canal=canal,
                                   sucursal=suc, ciudad=ciudad, cantidad=cantidad,
                                   precio_unitario=precio, descuento=desc))
        dia += dt.timedelta(days=1)

    # DISENO: excepciones plantadas a proposito para probar "Desconocido".
    tickets = sorted({v["id_ticket"] for v in ventas})
    elegidos = rnd.sample(tickets, 6)
    for t in elegidos[:3]:                     # cliente inexistente (clave sin correspondencia)
        for v in ventas:
            if v["id_ticket"] == t:
                v["id_cliente"] = "C999"
    for t in elegidos[3:5]:                    # cliente vacio (valor faltante)
        for v in ventas:
            if v["id_ticket"] == t:
                v["id_cliente"] = None
    for v in ventas:                           # canal vacio
        if v["id_ticket"] == elegidos[5]:
            v["canal"] = None
    libres = [v for v in ventas if v["id_ticket"] not in elegidos]
    libre = rnd.choice(libres)                 # producto inexistente
    libre["id_producto"] = "P-99"
    libre["descuento"] = 0.0
    return ventas


def main() -> Path:
    rnd = random.Random(SEMILLA)
    ventas = generar_ventas(rnd)
    salida = Path(__file__).with_name("02_datos_src.sql")

    lineas = [
        "-- =====================================================================",
        "-- 02_datos_src.sql  (GENERADO por generar_datos.py, semilla = %d)" % SEMILLA,
        "-- Datos de la capa OPERACIONAL. No editar a mano: volver a generar.",
        "-- =====================================================================",
        "",
        "-- Productos",
    ]
    for pid, nom, cat, costo, _ in PRODUCTOS:
        lineas.append("INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) "
                      f"VALUES ({sql_val(pid)}, {sql_val(nom)}, {sql_val(cat)}, {sql_val(costo)});")

    lineas += ["", "-- Historial de segmentos de clientes (una fila por version del cliente)"]
    for cid, nom in zip(IDS_CLIENTES, NOMBRES):
        lineas.append("INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) "
                      f"VALUES ({sql_val(cid)}, {sql_val(nom)}, {sql_val(segmento_inicial(cid))}, '2026-01-01');")
    for cid, (nuevo, desde) in CAMBIOS_SEGMENTO.items():
        nom = NOMBRES[IDS_CLIENTES.index(cid)]
        lineas.append("INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) "
                      f"VALUES ({sql_val(cid)}, {sql_val(nom)}, {sql_val(nuevo)}, '{desde.isoformat()}');")

    lineas += ["", "-- Ventas (una fila por linea de ticket)"]
    cols = ["id_ticket", "linea", "fecha", "id_cliente", "id_producto", "canal",
            "sucursal", "ciudad", "cantidad", "precio_unitario", "descuento"]
    for v in ventas:
        lineas.append(f"INSERT INTO src_ventas ({', '.join(cols)}) VALUES "
                      f"({', '.join(sql_val(v[c]) for c in cols)});")

    salida.write_text("\n".join(lineas) + "\n", encoding="utf-8")
    print(f"Generado {salida.name}: {len(ventas)} lineas de venta, "
          f"{len({v['id_ticket'] for v in ventas})} tickets.")
    return salida


if __name__ == "__main__":
    main()
