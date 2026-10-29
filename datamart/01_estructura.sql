-- =====================================================================
-- 01_estructura.sql
-- Data Mart de Ventas (esquema estrella) - SQLite
--
-- GRANO de FactVentas:
--   Una fila representa una linea de producto vendida dentro de un ticket.
--
-- Nota: si ejecutas en DB Browser for SQLite, activa la opcion
-- "Foreign Keys" (Edit > Preferences > Database) para que se validen las FK.
-- =====================================================================
PRAGMA foreign_keys = ON;

-- Reinicio limpio (permite volver a ejecutar el script desde cero)
DROP TABLE IF EXISTS FactVentas;
DROP TABLE IF EXISTS DimTiempo;
DROP TABLE IF EXISTS DimCliente;
DROP TABLE IF EXISTS DimProducto;
DROP TABLE IF EXISTS DimCanal;
DROP TABLE IF EXISTS DimSucursal;
DROP TABLE IF EXISTS src_ventas;
DROP TABLE IF EXISTS src_productos;
DROP TABLE IF EXISTS src_clientes_historial;

-- =====================================================================
-- CAPA OPERACIONAL (simula el sistema transaccional de origen)
-- Tablas planas, sin claves sustitutas y sin restricciones: asi llegan
-- los datos reales (pueden traer nulos o claves inexistentes).
-- =====================================================================
CREATE TABLE src_clientes_historial (
    id_cliente    TEXT,
    nombre        TEXT,
    segmento      TEXT,
    vigente_desde TEXT            -- fecha desde la que rige este segmento
);

CREATE TABLE src_productos (
    id_producto    TEXT,
    nombre         TEXT,
    categoria      TEXT,
    costo_unitario REAL
);

CREATE TABLE src_ventas (
    id_ticket       TEXT,
    linea           INTEGER,
    fecha           TEXT,         -- 'AAAA-MM-DD'
    id_cliente      TEXT,
    id_producto     TEXT,
    canal           TEXT,
    sucursal        TEXT,
    ciudad          TEXT,
    cantidad        INTEGER,
    precio_unitario REAL,
    descuento       REAL
);

-- =====================================================================
-- CAPA ANALITICA: DIMENSIONES (todas con clave sustituta sk_*)
-- =====================================================================
CREATE TABLE DimTiempo (
    sk_tiempo  INTEGER PRIMARY KEY,          -- formato AAAAMMDD, ej. 20260315
    fecha      TEXT    NOT NULL UNIQUE,      -- 'AAAA-MM-DD'
    anio       INTEGER NOT NULL,
    trimestre  INTEGER NOT NULL CHECK (trimestre BETWEEN 1 AND 4),
    mes        INTEGER NOT NULL CHECK (mes BETWEEN 1 AND 12),
    nombre_mes TEXT    NOT NULL,
    dia        INTEGER NOT NULL
);

-- SCD TIPO 2: cada cambio de segmento genera una NUEVA fila (version) del cliente.
CREATE TABLE DimCliente (
    sk_cliente   INTEGER PRIMARY KEY AUTOINCREMENT,
    id_cliente   TEXT    NOT NULL,           -- clave natural (del sistema origen)
    nombre       TEXT    NOT NULL,
    segmento     TEXT    NOT NULL,
    fecha_inicio TEXT    NOT NULL,           -- inicio de vigencia de esta version
    fecha_fin    TEXT,                       -- NULL = version vigente
    es_actual    INTEGER NOT NULL CHECK (es_actual IN (0, 1)),
    UNIQUE (id_cliente, fecha_inicio)
);

CREATE TABLE DimProducto (
    sk_producto    INTEGER PRIMARY KEY AUTOINCREMENT,
    id_producto    TEXT NOT NULL UNIQUE,
    nombre         TEXT NOT NULL,
    categoria      TEXT NOT NULL,
    costo_unitario REAL                      -- NULL si el costo no esta registrado
);

CREATE TABLE DimCanal (
    sk_canal INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre   TEXT NOT NULL UNIQUE
);

CREATE TABLE DimSucursal (
    sk_sucursal INTEGER PRIMARY KEY AUTOINCREMENT,
    nombre      TEXT NOT NULL UNIQUE,
    ciudad      TEXT
);

-- =====================================================================
-- CAPA ANALITICA: TABLA DE HECHOS
-- PK (numero_ticket, numero_linea) = garantiza el grano y evita duplicados.
-- numero_ticket es una DIMENSION DEGENERADA (sirve para contar tickets).
-- Metricas aditivas: cantidad, ingreso_bruto, descuento, ingreso_neto,
--                    costo_total, margen_bruto.
-- No aditivas: precio_unitario (y margen % / ticket promedio, que se
--              calculan al consultar, no se guardan).
-- =====================================================================
CREATE TABLE FactVentas (
    sk_tiempo       INTEGER NOT NULL REFERENCES DimTiempo(sk_tiempo),
    sk_cliente      INTEGER NOT NULL REFERENCES DimCliente(sk_cliente),
    sk_producto     INTEGER NOT NULL REFERENCES DimProducto(sk_producto),
    sk_canal        INTEGER NOT NULL REFERENCES DimCanal(sk_canal),
    sk_sucursal     INTEGER NOT NULL REFERENCES DimSucursal(sk_sucursal),
    numero_ticket   TEXT    NOT NULL,
    numero_linea    INTEGER NOT NULL,
    cantidad        INTEGER NOT NULL CHECK (cantidad > 0),
    precio_unitario REAL    NOT NULL CHECK (precio_unitario >= 0),
    descuento       REAL    NOT NULL DEFAULT 0 CHECK (descuento >= 0),
    ingreso_bruto   REAL    NOT NULL,        -- cantidad * precio_unitario
    ingreso_neto    REAL    NOT NULL,        -- ingreso_bruto - descuento
    costo_total     REAL,                    -- cantidad * costo_unitario (NULL si no hay costo)
    margen_bruto    REAL,                    -- ingreso_neto - costo_total (NULL si no hay costo)
    PRIMARY KEY (numero_ticket, numero_linea)
);

CREATE INDEX ix_fact_tiempo   ON FactVentas(sk_tiempo);
CREATE INDEX ix_fact_cliente  ON FactVentas(sk_cliente);
CREATE INDEX ix_fact_producto ON FactVentas(sk_producto);
CREATE INDEX ix_fact_canal    ON FactVentas(sk_canal);
CREATE INDEX ix_fact_sucursal ON FactVentas(sk_sucursal);

-- =====================================================================
-- FILAS "DESCONOCIDO" (sk = -1)
-- Reciben las ventas con clave nula o sin correspondencia, para no perder
-- ingresos ni romper la integridad referencial. Se cuentan como excepcion.
-- =====================================================================
INSERT INTO DimCliente (sk_cliente, id_cliente, nombre, segmento, fecha_inicio, fecha_fin, es_actual)
VALUES (-1, 'DESCONOCIDO', 'Desconocido', 'Desconocido', '1900-01-01', NULL, 1);

INSERT INTO DimProducto (sk_producto, id_producto, nombre, categoria, costo_unitario)
VALUES (-1, 'DESCONOCIDO', 'Desconocido', 'Desconocido', NULL);

INSERT INTO DimCanal (sk_canal, nombre)
VALUES (-1, 'Desconocido');

INSERT INTO DimSucursal (sk_sucursal, nombre, ciudad)
VALUES (-1, 'Desconocida', NULL);
