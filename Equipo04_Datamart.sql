-- >>>>>>>>>> 01_estructura.sql <<<<<<<<<<
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


-- >>>>>>>>>> 02_datos_src.sql <<<<<<<<<<
-- =====================================================================
-- 02_datos_src.sql  (GENERADO por generar_datos.py, semilla = 42)
-- Datos de la capa OPERACIONAL. No editar a mano: volver a generar.
-- =====================================================================

-- Productos
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-01', 'Audifonos Bluetooth', 'Electronica', 18.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-02', 'Cargador Rapido', 'Electronica', 6.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-03', 'Teclado Mecanico', 'Electronica', 25.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-04', 'Licuadora', 'Hogar', 22.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-05', 'Juego de Sabanas', 'Hogar', 12.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-06', 'Lampara de Mesa', 'Hogar', 8.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-07', 'Camisa Casual', 'Ropa', 9.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-08', 'Jeans', 'Ropa', 14.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-09', 'Chaqueta', 'Ropa', 28.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-10', 'Balon de Futbol', 'Deportes', 7.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-11', 'Bicicleta Estatica', 'Deportes', 90.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-12', 'Pesas 5kg', 'Deportes', 10.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-13', 'Set de Bloques', 'Juguetes', 8.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-14', 'Muneca', 'Juguetes', 6.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-15', 'Carro Control Remoto', 'Juguetes', 12.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-16', 'Cafe Premium', 'Alimentos', 4.0);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-17', 'Caja de Chocolates', 'Alimentos', NULL);
INSERT INTO src_productos (id_producto, nombre, categoria, costo_unitario) VALUES ('P-18', 'Aceite de Oliva', 'Alimentos', 5.0);

-- Historial de segmentos de clientes (una fila por version del cliente)
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C001', 'Ana Perez', 'Premium', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C002', 'Luis Gomez', 'Premium', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C003', 'Maria Rojas', 'Premium', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C004', 'Carlos Diaz', 'Premium', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C005', 'Sofia Marin', 'Regular', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C006', 'Jorge Silva', 'Premium', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C007', 'Laura Mora', 'Premium', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C008', 'Pedro Ruiz', 'Premium', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C009', 'Elena Vega', 'Regular', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C010', 'Diego Torres', 'Regular', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C011', 'Camila Rios', 'Regular', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C012', 'Andres Paz', 'Regular', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C013', 'Valeria Cruz', 'Regular', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C014', 'Miguel Soto', 'Regular', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C015', 'Daniela Leon', 'Regular', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C016', 'Ricardo Pena', 'Regular', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C017', 'Isabel Nunez', 'Ocasional', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C018', 'Fernando Cano', 'Ocasional', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C019', 'Gabriela Mejia', 'Ocasional', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C020', 'Hector Luna', 'Ocasional', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C021', 'Patricia Bravo', 'Ocasional', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C022', 'Oscar Prieto', 'Ocasional', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C023', 'Natalia Vera', 'Ocasional', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C024', 'Raul Ibarra', 'Ocasional', '2026-01-01');
INSERT INTO src_clientes_historial (id_cliente, nombre, segmento, vigente_desde) VALUES ('C005', 'Sofia Marin', 'Premium', '2026-07-01');

-- Ventas (una fila por linea de ticket)
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0001', 1, '2026-04-03', 'C004', 'P-18', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 10.48, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0001', 2, '2026-04-03', 'C004', 'P-03', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 55.56, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0001', 3, '2026-04-03', 'C004', 'P-14', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 16.24, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0002', 1, '2026-04-03', 'C004', 'P-14', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 15.64, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0003', 1, '2026-04-04', 'C002', 'P-09', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 69.72, 20.92);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0003', 2, '2026-04-04', 'C002', 'P-02', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 14.07, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0004', 1, '2026-04-04', 'C013', 'P-03', 'Web', 'Sucursal Norte', 'Valencia', 2, 57.67, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0004', 2, '2026-04-04', 'C013', 'P-02', 'Web', 'Sucursal Norte', 'Valencia', 1, 13.83, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0004', 3, '2026-04-04', 'C013', 'P-08', 'Web', 'Sucursal Norte', 'Valencia', 2, 36.72, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0005', 1, '2026-04-05', 'C015', 'P-06', 'Web', 'Sucursal Centro', 'Caracas', 2, 21.73, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0005', 2, '2026-04-05', 'C015', 'P-08', 'Web', 'Sucursal Centro', 'Caracas', 3, 38.72, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0005', 3, '2026-04-05', 'C015', 'P-18', 'Web', 'Sucursal Centro', 'Caracas', 2, 11.38, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0006', 1, '2026-04-05', 'C004', 'P-09', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 72.89, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0006', 2, '2026-04-05', 'C004', 'P-03', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 53.98, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0007', 1, '2026-04-06', 'C021', 'P-05', 'Web', 'Sucursal Norte', 'Valencia', 3, 30.18, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0007', 2, '2026-04-06', 'C021', 'P-08', 'Web', 'Sucursal Norte', 'Valencia', 3, 37.73, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0008', 1, '2026-04-06', NULL, 'P-16', 'Web', 'Sucursal Norte', 'Valencia', 1, 8.69, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0008', 2, '2026-04-06', NULL, 'P-03', 'Web', 'Sucursal Norte', 'Valencia', 3, 54.57, 16.37);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0008', 3, '2026-04-06', NULL, 'P-02', 'Web', 'Sucursal Norte', 'Valencia', 3, 14.69, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0009', 1, '2026-04-09', 'C017', 'P-06', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 23.0, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0009', 2, '2026-04-09', 'C017', 'P-15', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 33.51, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0010', 1, '2026-04-09', 'C009', 'P-17', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 12.32, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0010', 2, '2026-04-09', 'C009', 'P-07', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 26.05, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0010', 3, '2026-04-09', 'C009', 'P-05', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 28.56, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0011', 1, '2026-04-10', 'C004', 'P-16', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 9.43, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0012', 1, '2026-04-10', 'C002', 'P-17', 'Web', 'Sucursal Norte', 'Valencia', 1, 12.51, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0012', 2, '2026-04-10', 'C002', 'P-14', 'Web', 'Sucursal Norte', 'Valencia', 3, 15.52, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0013', 1, '2026-04-11', 'C008', 'P-08', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 37.38, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0014', 1, '2026-04-11', 'C004', 'P-02', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 14.5, 0.73);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0014', 2, '2026-04-11', 'C004', 'P-08', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 38.64, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0014', 3, '2026-04-11', 'C004', 'P-03', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 56.23, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0015', 1, '2026-04-12', 'C004', 'P-04', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 45.72, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0016', 1, '2026-04-12', 'C007', 'P-04', 'Web', 'Sucursal Centro', 'Caracas', 3, 44.28, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0016', 2, '2026-04-12', 'C007', 'P-02', 'Web', 'Sucursal Centro', 'Caracas', 1, 13.57, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0016', 3, '2026-04-12', 'C007', 'P-13', 'Web', 'Sucursal Centro', 'Caracas', 1, 19.84, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0017', 1, '2026-04-13', 'C021', 'P-18', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 11.52, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0018', 1, '2026-04-14', 'C003', 'P-02', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 13.3, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0018', 2, '2026-04-14', 'C003', 'P-06', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 21.53, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0019', 1, '2026-04-15', 'C003', 'P-18', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 10.51, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0019', 2, '2026-04-15', 'C003', 'P-02', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 13.52, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0019', 3, '2026-04-15', 'C003', 'P-11', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 186.32, 9.32);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0020', 1, '2026-04-15', 'C014', 'P-08', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 38.6, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0020', 2, '2026-04-15', 'C014', 'P-02', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 14.61, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0020', 3, '2026-04-15', 'C014', 'P-03', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 53.98, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0021', 1, '2026-04-16', 'C014', 'P-01', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 35.42, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0022', 1, '2026-04-19', 'C009', 'P-08', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 37.18, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0023', 1, '2026-04-20', 'C012', 'P-18', 'Web', 'Sucursal Centro', 'Caracas', 1, 10.74, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0023', 2, '2026-04-20', 'C012', 'P-10', 'Web', 'Sucursal Centro', 'Caracas', 3, 20.11, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0023', 3, '2026-04-20', 'C012', 'P-04', 'Web', 'Sucursal Centro', 'Caracas', 3, 43.7, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0024', 1, '2026-04-20', 'C015', 'P-02', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 13.89, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0024', 2, '2026-04-20', 'C015', 'P-03', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 54.08, 5.41);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0025', 1, '2026-04-21', 'C016', 'P-01', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 36.41, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0025', 2, '2026-04-21', 'C016', 'P-04', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 45.37, 4.54);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0025', 3, '2026-04-21', 'C016', 'P-03', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 53.95, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0026', 1, '2026-04-23', 'C004', 'P-18', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 11.27, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0026', 2, '2026-04-23', 'C004', 'P-14', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 16.58, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0027', 1, '2026-04-23', 'C019', 'P-11', 'Web', 'Sucursal Centro', 'Caracas', 2, 185.44, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0028', 1, '2026-04-24', 'C005', 'P-02', 'Web', 'Sucursal Centro', 'Caracas', 1, 13.58, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0028', 2, '2026-04-24', 'C005', 'P-16', 'Web', 'Sucursal Centro', 'Caracas', 2, 8.82, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0029', 1, '2026-04-25', 'C004', 'P-09', 'Web', 'Sucursal Sur', 'Barquisimeto', 2, 68.96, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0029', 2, '2026-04-25', 'C004', 'P-03', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 57.65, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0030', 1, '2026-04-28', 'C003', 'P-04', 'Web', 'Sucursal Este', 'Maracaibo', 3, 44.71, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0031', 1, '2026-04-28', 'C999', 'P-07', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 25.52, 3.83);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0031', 2, '2026-04-28', 'C999', 'P-09', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 71.54, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0032', 1, '2026-04-29', 'C007', 'P-11', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 176.57, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0032', 2, '2026-04-29', 'C007', 'P-04', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 45.89, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0032', 3, '2026-04-29', 'C007', 'P-10', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 19.84, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0033', 1, '2026-04-30', 'C013', 'P-10', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 20.57, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0033', 2, '2026-04-30', 'C013', 'P-07', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 24.91, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0034', 1, '2026-05-01', 'C009', 'P-03', 'Web', 'Sucursal Norte', 'Valencia', 1, 56.75, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0034', 2, '2026-05-01', 'C009', 'P-10', 'Web', 'Sucursal Norte', 'Valencia', 3, 19.62, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0034', 3, '2026-05-01', 'C009', 'P-11', 'Web', 'Sucursal Norte', 'Valencia', 1, 171.44, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0035', 1, '2026-05-02', 'C012', 'P-07', 'Web', 'Sucursal Sur', 'Barquisimeto', 2, 24.75, 7.42);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0035', 2, '2026-05-02', 'C012', 'P-13', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 20.79, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0036', 1, '2026-05-02', 'C021', 'P-17', 'Web', 'Sucursal Norte', 'Valencia', 2, 11.46, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0037', 1, '2026-05-04', 'C003', 'P-17', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 11.94, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0037', 2, '2026-05-04', 'C003', 'P-14', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 15.92, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0038', 1, '2026-05-04', 'C020', 'P-08', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 38.81, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0038', 2, '2026-05-04', 'C020', 'P-09', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 68.74, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0038', 3, '2026-05-04', 'C020', 'P-15', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 30.88, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0039', 1, '2026-05-05', 'C015', 'P-18', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 10.52, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0039', 2, '2026-05-05', 'C015', 'P-15', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 33.3, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0040', 1, '2026-05-07', 'C008', 'P-14', 'Web', 'Sucursal Este', 'Maracaibo', 2, 15.55, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0040', 2, '2026-05-07', 'C008', 'P-08', 'Web', 'Sucursal Este', 'Maracaibo', 1, 37.58, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0041', 1, '2026-05-07', 'C018', 'P-18', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 11.45, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0042', 1, '2026-05-10', 'C003', 'P-13', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 19.91, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0042', 2, '2026-05-10', 'C003', 'P-11', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 176.01, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0043', 1, '2026-05-10', 'C008', 'P-18', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 11.55, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0044', 1, '2026-05-14', 'C004', 'P-05', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 30.51, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0045', 1, '2026-05-15', 'C008', 'P-04', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 47.09, 2.35);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0046', 1, '2026-05-16', 'C011', 'P-07', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 25.48, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0046', 2, '2026-05-16', 'C011', 'P-03', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 56.08, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0047', 1, '2026-05-16', 'C015', 'P-18', 'Web', 'Sucursal Centro', 'Caracas', 3, 10.86, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0047', 2, '2026-05-16', 'C015', 'P-14', 'Web', 'Sucursal Centro', 'Caracas', 2, 15.22, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0048', 1, '2026-05-17', 'C002', 'P-05', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 30.07, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0048', 2, '2026-05-17', 'C002', 'P-14', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 16.49, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0048', 3, '2026-05-17', 'C002', 'P-06', 'Web', 'Sucursal Sur', 'Barquisimeto', 2, 21.92, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0049', 1, '2026-05-17', 'C012', 'P-09', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 68.21, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0050', 1, '2026-05-18', 'C006', 'P-16', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 8.87, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0051', 1, '2026-05-18', 'C005', 'P-01', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 34.09, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0051', 2, '2026-05-18', 'C005', 'P-17', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 12.31, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0051', 3, '2026-05-18', 'C005', 'P-07', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 25.53, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0052', 1, '2026-05-21', 'C004', 'P-12', 'Web', 'Sucursal Este', 'Maracaibo', 2, 25.19, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0052', 2, '2026-05-21', 'C004', 'P-16', 'Web', 'Sucursal Este', 'Maracaibo', 2, 9.18, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0052', 3, '2026-05-21', 'C004', 'P-18', 'Web', 'Sucursal Este', 'Maracaibo', 2, 10.7, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0053', 1, '2026-05-21', 'C006', 'P-07', 'Web', 'Sucursal Norte', 'Valencia', 3, 24.96, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0054', 1, '2026-05-22', 'C024', 'P-12', 'Web', 'Sucursal Este', 'Maracaibo', 1, 23.53, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0055', 1, '2026-05-22', 'C002', 'P-10', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 20.75, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0055', 2, '2026-05-22', 'C002', 'P-05', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 29.94, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0055', 3, '2026-05-22', 'C002', 'P-16', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 8.78, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0056', 1, '2026-05-25', 'C009', 'P-05', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 31.35, 4.7);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0057', 1, '2026-05-25', 'C002', 'P-13', 'Web', 'Sucursal Norte', 'Valencia', 2, 20.72, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0057', 2, '2026-05-25', 'C002', 'P-15', 'Web', 'Sucursal Norte', 'Valencia', 2, 32.22, 9.67);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0057', 3, '2026-05-25', 'C002', 'P-17', 'Web', 'Sucursal Norte', 'Valencia', 1, 12.54, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0058', 1, '2026-05-26', 'C005', 'P-18', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 1, 10.62, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0059', 1, '2026-05-27', 'C006', 'P-15', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 32.92, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0059', 2, '2026-05-27', 'C006', 'P-03', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 56.67, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0059', 3, '2026-05-27', 'C006', 'P-08', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 38.17, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0060', 1, '2026-05-27', 'C022', 'P-06', 'Web', 'Sucursal Centro', 'Caracas', 2, 22.21, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0061', 1, '2026-05-28', 'C008', 'P-13', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 19.16, 3.83);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0061', 2, '2026-05-28', 'C008', 'P-09', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 68.76, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0061', 3, '2026-05-28', 'C008', 'P-16', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 8.76, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0062', 1, '2026-05-28', 'C020', 'P-09', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 70.13, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0062', 2, '2026-05-28', 'C020', 'P-02', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 13.55, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0062', 3, '2026-05-28', 'C020', 'P-06', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 22.69, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0063', 1, '2026-05-29', 'C006', 'P-11', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 183.49, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0064', 1, '2026-05-29', 'C023', 'P-03', 'Web', 'Sucursal Centro', 'Caracas', 2, 54.03, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0064', 2, '2026-05-29', 'C023', 'P-11', 'Web', 'Sucursal Centro', 'Caracas', 2, 186.57, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0065', 1, '2026-05-31', 'C007', 'P-16', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 8.79, 0.88);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0065', 2, '2026-05-31', 'C007', 'P-15', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 33.22, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0065', 3, '2026-05-31', 'C007', 'P-02', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 14.66, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0066', 1, '2026-05-31', 'C004', 'P-14', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 15.94, 0.8);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0066', 2, '2026-05-31', 'C004', 'P-03', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 57.38, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0066', 3, '2026-05-31', 'C004', 'P-08', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 37.14, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0067', 1, '2026-06-01', 'C004', 'P-17', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 12.46, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0068', 1, '2026-06-01', 'C005', 'P-17', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 11.74, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0068', 2, '2026-06-01', 'C005', 'P-09', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 70.56, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0069', 1, '2026-06-02', 'C008', 'P-18', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 11.41, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0069', 2, '2026-06-02', 'C008', 'P-13', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 20.14, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0069', 3, '2026-06-02', 'C008', 'P-15', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 30.54, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0070', 1, '2026-06-03', 'C007', 'P-02', 'Web', 'Sucursal Norte', 'Valencia', 3, 14.65, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0070', 2, '2026-06-03', 'C007', 'P-05', 'Web', 'Sucursal Norte', 'Valencia', 1, 31.12, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0071', 1, '2026-06-03', 'C010', 'P-05', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 30.84, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0071', 2, '2026-06-03', 'C010', 'P-03', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 56.06, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0072', 1, '2026-06-04', 'C020', 'P-16', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 3, 8.61, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0072', 2, '2026-06-04', 'C020', 'P-02', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 2, 14.7, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0073', 1, '2026-06-04', 'C008', 'P-06', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 21.0, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0073', 2, '2026-06-04', 'C008', 'P-10', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 19.72, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0074', 1, '2026-06-05', 'C010', 'P-06', 'Web', 'Sucursal Norte', 'Valencia', 1, 22.24, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0075', 1, '2026-06-06', 'C009', 'P-09', 'Web', 'Sucursal Norte', 'Valencia', 2, 71.17, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0075', 2, '2026-06-06', 'C009', 'P-15', 'Web', 'Sucursal Norte', 'Valencia', 2, 33.28, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0076', 1, '2026-06-07', 'C002', 'P-14', 'WhatsApp', 'Sucursal Este', 'Maracaibo', 2, 15.52, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0076', 2, '2026-06-07', 'C002', 'P-09', 'WhatsApp', 'Sucursal Este', 'Maracaibo', 2, 67.25, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0076', 3, '2026-06-07', 'C002', 'P-15', 'WhatsApp', 'Sucursal Este', 'Maracaibo', 2, 32.24, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0077', 1, '2026-06-08', 'C001', 'P-01', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 3, 35.86, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0077', 2, '2026-06-08', 'C001', 'P-02', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 2, 14.39, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0078', 1, '2026-06-08', 'C018', 'P-09', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 71.02, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0078', 2, '2026-06-08', 'C018', 'P-05', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 28.6, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0078', 3, '2026-06-08', 'C018', 'P-04', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 1, 43.16, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0079', 1, '2026-06-09', 'C003', 'P-17', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 12.5, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0079', 2, '2026-06-09', 'C003', 'P-09', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 71.73, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0079', 3, '2026-06-09', 'C003', 'P-06', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 21.93, 1.1);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0080', 1, '2026-06-09', 'C020', 'P-12', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 23.43, 2.34);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0080', 2, '2026-06-09', 'C020', 'P-03', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 56.37, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0080', 3, '2026-06-09', 'C020', 'P-13', 'Web', 'Sucursal Sur', 'Barquisimeto', 2, 20.64, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0081', 1, '2026-06-11', 'C008', 'P-08', 'Web', 'Sucursal Este', 'Maracaibo', 3, 37.25, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0081', 2, '2026-06-11', 'C008', 'P-03', 'Web', 'Sucursal Este', 'Maracaibo', 1, 52.5, 5.25);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0081', 3, '2026-06-11', 'C008', 'P-15', 'Web', 'Sucursal Este', 'Maracaibo', 1, 30.71, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0082', 1, '2026-06-12', 'C007', 'P-05', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 30.35, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0082', 2, '2026-06-12', 'C007', 'P-14', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 15.25, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0082', 3, '2026-06-12', 'C007', 'P-04', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 44.75, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0083', 1, '2026-06-13', 'C002', 'P-13', 'Web', 'Sucursal Este', 'Maracaibo', 2, 19.38, 3.88);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0084', 1, '2026-06-13', 'C002', 'P-11', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 188.8, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0085', 1, '2026-06-14', 'C002', 'P-07', 'Web', 'Sucursal Norte', 'Valencia', 1, 25.72, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0085', 2, '2026-06-14', 'C002', 'P-08', 'Web', 'Sucursal Norte', 'Valencia', 2, 39.36, 3.94);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0085', 3, '2026-06-14', 'C002', 'P-11', 'Web', 'Sucursal Norte', 'Valencia', 3, 175.51, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0086', 1, '2026-06-16', NULL, 'P-11', 'Web', 'Sucursal Norte', 'Valencia', 2, 171.94, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0086', 2, '2026-06-16', NULL, 'P-01', 'Web', 'Sucursal Norte', 'Valencia', 3, 33.65, 10.09);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0086', 3, '2026-06-16', NULL, 'P-06', 'Web', 'Sucursal Norte', 'Valencia', 2, 22.03, 6.61);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0087', 1, '2026-06-17', 'C023', 'P-01', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 36.22, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0087', 2, '2026-06-17', 'C023', 'P-02', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 13.99, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0088', 1, '2026-06-20', 'C012', 'P-18', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 11.03, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0088', 2, '2026-06-20', 'C012', 'P-11', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 178.74, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0088', 3, '2026-06-20', 'C012', 'P-13', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 20.71, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0089', 1, '2026-06-20', 'C017', 'P-15', 'Web', 'Sucursal Norte', 'Valencia', 2, 31.48, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0089', 2, '2026-06-20', 'C017', 'P-08', 'Web', 'Sucursal Norte', 'Valencia', 2, 38.87, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0090', 1, '2026-06-21', 'C014', 'P-16', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 1, 8.63, 1.29);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0090', 2, '2026-06-21', 'C014', 'P-03', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 56.71, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0090', 3, '2026-06-21', 'C014', 'P-17', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 12.55, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0091', 1, '2026-06-21', 'C014', 'P-02', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 13.45, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0091', 2, '2026-06-21', 'C014', 'P-10', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 20.31, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0091', 3, '2026-06-21', 'C014', 'P-17', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 11.82, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0092', 1, '2026-06-23', 'C011', 'P-09', 'WhatsApp', 'Sucursal Centro', 'Caracas', 2, 71.42, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0092', 2, '2026-06-23', 'C011', 'P-01', 'WhatsApp', 'Sucursal Centro', 'Caracas', 2, 34.48, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0092', 3, '2026-06-23', 'C011', 'P-06', 'WhatsApp', 'Sucursal Centro', 'Caracas', 1, 22.15, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0093', 1, '2026-06-23', 'C003', 'P-17', 'Web', 'Sucursal Centro', 'Caracas', 1, 11.85, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0094', 1, '2026-06-24', 'C007', 'P-05', 'Web', 'Sucursal Centro', 'Caracas', 1, 30.76, 1.54);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0095', 1, '2026-06-25', 'C008', 'P-09', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 67.3, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0095', 2, '2026-06-25', 'C008', 'P-07', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 25.45, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0096', 1, '2026-06-25', 'C010', 'P-02', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 1, 13.72, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0096', 2, '2026-06-25', 'C010', 'P-01', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 1, 35.92, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0097', 1, '2026-06-28', 'C017', 'P-08', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 37.61, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0097', 2, '2026-06-28', 'C017', 'P-17', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 11.42, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0097', 3, '2026-06-28', 'C017', 'P-12', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 24.18, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0098', 1, '2026-06-28', 'C015', 'P-01', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 36.05, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0098', 2, '2026-06-28', 'C015', 'P-11', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 187.56, 28.13);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0099', 1, '2026-06-29', 'C008', 'P-10', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 19.67, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0099', 2, '2026-06-29', 'C008', 'P-11', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 182.4, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0100', 1, '2026-06-30', 'C022', 'P-04', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 1, 43.9, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0101', 1, '2026-07-01', 'C014', 'P-16', 'Web', 'Sucursal Norte', 'Valencia', 3, 9.38, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0101', 2, '2026-07-01', 'C014', 'P-15', 'Web', 'Sucursal Norte', 'Valencia', 3, 33.56, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0101', 3, '2026-07-01', 'C014', 'P-17', 'Web', 'Sucursal Norte', 'Valencia', 3, 11.78, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0102', 1, '2026-07-02', 'C007', 'P-02', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 13.95, 2.79);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0102', 2, '2026-07-02', 'C007', 'P-12', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 22.98, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0102', 3, '2026-07-02', 'C007', 'P-03', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 55.63, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0103', 1, '2026-07-02', 'C007', 'P-07', 'Web', 'Sucursal Centro', 'Caracas', 3, 24.94, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0103', 2, '2026-07-02', 'C007', 'P-11', 'Web', 'Sucursal Centro', 'Caracas', 1, 179.11, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0104', 1, '2026-07-03', 'C024', 'P-08', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 37.76, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0105', 1, '2026-07-03', 'C008', 'P-13', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 20.36, 6.11);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0105', 2, '2026-07-03', 'C008', 'P-14', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 15.74, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0106', 1, '2026-07-04', 'C005', 'P-03', 'Web', 'Sucursal Norte', 'Valencia', 2, 53.96, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0106', 2, '2026-07-04', 'C005', 'P-05', 'Web', 'Sucursal Norte', 'Valencia', 3, 29.68, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0107', 1, '2026-07-04', 'C022', 'P-11', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 183.07, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0107', 2, '2026-07-04', 'C022', 'P-05', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 29.59, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0107', 3, '2026-07-04', 'C022', 'P-03', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 54.13, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0108', 1, '2026-07-05', 'C004', 'P-04', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 46.51, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0108', 2, '2026-07-05', 'C004', 'P-17', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 12.19, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0109', 1, '2026-07-06', 'C010', 'P-99', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 21.7, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0109', 2, '2026-07-06', 'C010', 'P-15', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 32.35, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0109', 3, '2026-07-06', 'C010', 'P-02', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 13.63, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0110', 1, '2026-07-07', 'C020', 'P-10', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 20.05, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0110', 2, '2026-07-07', 'C020', 'P-13', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 20.6, 2.06);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0111', 1, '2026-07-07', 'C001', 'P-04', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 43.13, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0111', 2, '2026-07-07', 'C001', 'P-17', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 12.49, 2.5);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0111', 3, '2026-07-07', 'C001', 'P-18', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 11.49, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0112', 1, '2026-07-08', 'C019', 'P-13', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 3, 19.75, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0113', 1, '2026-07-08', 'C002', 'P-11', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 173.48, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0114', 1, '2026-07-09', 'C013', 'P-01', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 34.15, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0114', 2, '2026-07-09', 'C013', 'P-03', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 57.42, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0115', 1, '2026-07-09', 'C007', 'P-04', 'Web', 'Sucursal Norte', 'Valencia', 1, 44.64, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0115', 2, '2026-07-09', 'C007', 'P-02', 'Web', 'Sucursal Norte', 'Valencia', 2, 13.39, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0116', 1, '2026-07-10', 'C010', 'P-05', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 1, 30.34, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0116', 2, '2026-07-10', 'C010', 'P-10', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 19.37, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0116', 3, '2026-07-10', 'C010', 'P-14', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 16.76, 7.54);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0117', 1, '2026-07-10', 'C008', 'P-16', 'Web', 'Sucursal Centro', 'Caracas', 3, 8.9, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0117', 2, '2026-07-10', 'C008', 'P-02', 'Web', 'Sucursal Centro', 'Caracas', 3, 13.32, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0118', 1, '2026-07-11', 'C004', 'P-11', 'Web', 'Sucursal Centro', 'Caracas', 2, 180.83, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0118', 2, '2026-07-11', 'C004', 'P-05', 'Web', 'Sucursal Centro', 'Caracas', 1, 30.99, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0118', 3, '2026-07-11', 'C004', 'P-02', 'Web', 'Sucursal Centro', 'Caracas', 3, 13.97, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0119', 1, '2026-07-11', 'C002', 'P-10', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 19.09, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0120', 1, '2026-07-13', 'C021', 'P-02', 'Web', 'Sucursal Sur', 'Barquisimeto', 2, 13.8, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0120', 2, '2026-07-13', 'C021', 'P-07', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 24.58, 7.37);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0121', 1, '2026-07-13', 'C007', 'P-11', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 183.46, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0121', 2, '2026-07-13', 'C007', 'P-06', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 21.49, 6.45);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0122', 1, '2026-07-15', 'C010', 'P-04', 'WhatsApp', 'Sucursal Este', 'Maracaibo', 2, 45.72, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0122', 2, '2026-07-15', 'C010', 'P-03', 'WhatsApp', 'Sucursal Este', 'Maracaibo', 3, 56.2, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0123', 1, '2026-07-15', 'C007', 'P-14', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 16.27, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0123', 2, '2026-07-15', 'C007', 'P-09', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 72.11, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0123', 3, '2026-07-15', 'C007', 'P-02', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 13.5, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0124', 1, '2026-07-16', 'C001', 'P-13', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 19.31, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0124', 2, '2026-07-16', 'C001', 'P-02', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 13.82, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0125', 1, '2026-07-16', 'C009', 'P-09', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 66.68, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0125', 2, '2026-07-16', 'C009', 'P-08', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 37.57, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0126', 1, '2026-07-17', 'C015', 'P-10', 'Web', 'Sucursal Norte', 'Valencia', 1, 19.27, 0.96);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0126', 2, '2026-07-17', 'C015', 'P-16', 'Web', 'Sucursal Norte', 'Valencia', 3, 8.95, 4.03);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0126', 3, '2026-07-17', 'C015', 'P-07', 'Web', 'Sucursal Norte', 'Valencia', 2, 25.42, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0127', 1, '2026-07-17', 'C008', 'P-06', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 22.02, 2.2);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0128', 1, '2026-07-18', 'C004', 'P-12', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 24.92, 7.48);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0128', 2, '2026-07-18', 'C004', 'P-15', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 32.7, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0128', 3, '2026-07-18', 'C004', 'P-05', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 30.97, 6.19);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0129', 1, '2026-07-20', 'C007', 'P-06', 'Web', 'Sucursal Norte', 'Valencia', 3, 22.9, 3.43);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0129', 2, '2026-07-20', 'C007', 'P-05', 'Web', 'Sucursal Norte', 'Valencia', 3, 28.96, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0129', 3, '2026-07-20', 'C007', 'P-14', 'Web', 'Sucursal Norte', 'Valencia', 2, 16.7, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0130', 1, '2026-07-20', 'C022', 'P-09', 'Web', 'Sucursal Este', 'Maracaibo', 1, 70.95, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0131', 1, '2026-07-21', 'C011', 'P-06', 'Web', 'Sucursal Centro', 'Caracas', 3, 22.27, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0131', 2, '2026-07-21', 'C011', 'P-05', 'Web', 'Sucursal Centro', 'Caracas', 2, 31.03, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0131', 3, '2026-07-21', 'C011', 'P-18', 'Web', 'Sucursal Centro', 'Caracas', 1, 10.54, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0132', 1, '2026-07-22', 'C011', 'P-01', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 36.6, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0132', 2, '2026-07-22', 'C011', 'P-16', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 8.92, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0132', 3, '2026-07-22', 'C011', 'P-10', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 19.12, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0133', 1, '2026-07-22', 'C007', 'P-11', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 173.35, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0133', 2, '2026-07-22', 'C007', 'P-12', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 23.05, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0134', 1, '2026-07-24', 'C007', 'P-13', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 20.93, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0134', 2, '2026-07-24', 'C007', 'P-14', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 16.69, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0135', 1, '2026-07-24', 'C003', 'P-10', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 19.18, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0135', 2, '2026-07-24', 'C003', 'P-16', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 9.42, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0136', 1, '2026-07-25', 'C001', 'P-18', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 10.92, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0136', 2, '2026-07-25', 'C001', 'P-01', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 34.53, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0137', 1, '2026-07-25', 'C001', 'P-18', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 1, 10.87, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0137', 2, '2026-07-25', 'C001', 'P-10', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 19.56, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0138', 1, '2026-07-27', 'C023', 'P-12', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 24.02, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0138', 2, '2026-07-27', 'C023', 'P-05', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 28.62, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0138', 3, '2026-07-27', 'C023', 'P-07', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 25.05, 7.51);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0139', 1, '2026-07-28', 'C005', 'P-10', 'Web', 'Sucursal Norte', 'Valencia', 3, 20.66, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0139', 2, '2026-07-28', 'C005', 'P-11', 'Web', 'Sucursal Norte', 'Valencia', 3, 181.13, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0140', 1, '2026-07-30', 'C005', 'P-10', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 20.93, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0140', 2, '2026-07-30', 'C005', 'P-01', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 35.27, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0140', 3, '2026-07-30', 'C005', 'P-16', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 8.98, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0141', 1, '2026-07-30', 'C013', 'P-08', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 38.28, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0142', 1, '2026-07-31', 'C001', 'P-07', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 25.69, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0142', 2, '2026-07-31', 'C001', 'P-14', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 16.36, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0143', 1, '2026-08-01', 'C008', 'P-13', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 2, 20.82, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0143', 2, '2026-08-01', 'C008', 'P-11', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 2, 183.17, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0143', 3, '2026-08-01', 'C008', 'P-06', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 3, 22.32, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0144', 1, '2026-08-02', 'C003', 'P-10', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 20.41, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0145', 1, '2026-08-02', 'C007', 'P-04', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 46.43, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0145', 2, '2026-08-02', 'C007', 'P-13', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 19.58, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0146', 1, '2026-08-04', 'C018', 'P-07', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 24.43, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0147', 1, '2026-08-04', 'C004', 'P-02', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 14.57, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0148', 1, '2026-08-05', 'C001', 'P-05', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 31.39, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0149', 1, '2026-08-06', 'C006', 'P-07', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 2, 24.46, 2.45);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0149', 2, '2026-08-06', 'C006', 'P-10', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 3, 20.15, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0150', 1, '2026-08-08', 'C006', 'P-16', 'WhatsApp', 'Sucursal Centro', 'Caracas', 3, 9.42, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0150', 2, '2026-08-08', 'C006', 'P-06', 'WhatsApp', 'Sucursal Centro', 'Caracas', 1, 20.92, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0151', 1, '2026-08-10', 'C004', 'P-17', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 2, 11.73, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0152', 1, '2026-08-10', 'C005', 'P-06', 'Web', 'Sucursal Este', 'Maracaibo', 2, 22.15, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0152', 2, '2026-08-10', 'C005', 'P-01', 'Web', 'Sucursal Este', 'Maracaibo', 1, 35.39, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0152', 3, '2026-08-10', 'C005', 'P-11', 'Web', 'Sucursal Este', 'Maracaibo', 2, 185.89, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0153', 1, '2026-08-12', 'C010', 'P-11', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 1, 175.69, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0153', 2, '2026-08-12', 'C010', 'P-08', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 39.73, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0154', 1, '2026-08-12', 'C012', 'P-08', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 37.27, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0154', 2, '2026-08-12', 'C012', 'P-02', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 14.59, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0154', 3, '2026-08-12', 'C012', 'P-04', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 45.86, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0155', 1, '2026-08-13', 'C005', 'P-05', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 31.47, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0155', 2, '2026-08-13', 'C005', 'P-15', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 32.16, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0156', 1, '2026-08-13', 'C008', 'P-03', 'Web', 'Sucursal Norte', 'Valencia', 3, 54.71, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0157', 1, '2026-08-17', 'C008', 'P-15', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 32.27, 14.52);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0157', 2, '2026-08-17', 'C008', 'P-04', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 46.39, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0157', 3, '2026-08-17', 'C008', 'P-07', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 24.79, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0158', 1, '2026-08-18', 'C010', 'P-09', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 68.03, 20.41);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0158', 2, '2026-08-18', 'C010', 'P-01', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 35.7, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0159', 1, '2026-08-18', 'C001', 'P-10', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 2, 19.36, 5.81);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0160', 1, '2026-08-19', 'C005', 'P-13', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 3, 20.93, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0160', 2, '2026-08-19', 'C005', 'P-03', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 1, 55.84, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0161', 1, '2026-08-19', 'C003', 'P-08', 'Web', 'Sucursal Norte', 'Valencia', 2, 37.86, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0161', 2, '2026-08-19', 'C003', 'P-01', 'Web', 'Sucursal Norte', 'Valencia', 2, 35.11, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0161', 3, '2026-08-19', 'C003', 'P-17', 'Web', 'Sucursal Norte', 'Valencia', 1, 11.95, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0162', 1, '2026-08-20', 'C019', 'P-14', 'Web', 'Sucursal Centro', 'Caracas', 3, 16.43, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0163', 1, '2026-08-22', 'C003', 'P-02', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 13.36, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0163', 2, '2026-08-22', 'C003', 'P-08', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 36.93, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0164', 1, '2026-08-24', 'C007', 'P-11', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 188.74, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0164', 2, '2026-08-24', 'C007', 'P-08', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 37.24, 11.17);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0164', 3, '2026-08-24', 'C007', 'P-10', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 20.82, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0165', 1, '2026-08-25', 'C008', 'P-13', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 19.83, 5.95);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0165', 2, '2026-08-25', 'C008', 'P-17', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 12.31, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0165', 3, '2026-08-25', 'C008', 'P-11', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 176.41, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0166', 1, '2026-08-25', 'C014', 'P-18', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 1, 10.88, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0166', 2, '2026-08-25', 'C014', 'P-17', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 2, 12.18, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0167', 1, '2026-08-26', 'C002', 'P-09', 'Web', 'Sucursal Norte', 'Valencia', 2, 71.22, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0168', 1, '2026-08-26', 'C016', 'P-07', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 26.14, 2.61);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0168', 2, '2026-08-26', 'C016', 'P-11', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 173.11, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0169', 1, '2026-08-27', 'C017', 'P-08', 'Web', 'Sucursal Norte', 'Valencia', 2, 37.55, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0169', 2, '2026-08-27', 'C017', 'P-11', 'Web', 'Sucursal Norte', 'Valencia', 2, 176.55, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0170', 1, '2026-08-27', 'C016', 'P-07', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 24.78, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0170', 2, '2026-08-27', 'C016', 'P-12', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 24.58, 3.69);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0171', 1, '2026-08-28', 'C004', 'P-08', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 38.59, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0171', 2, '2026-08-28', 'C004', 'P-16', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 9.24, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0172', 1, '2026-08-28', 'C012', 'P-12', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 23.14, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0173', 1, '2026-08-29', 'C017', 'P-02', 'Web', 'Sucursal Centro', 'Caracas', 1, 13.88, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0173', 2, '2026-08-29', 'C017', 'P-03', 'Web', 'Sucursal Centro', 'Caracas', 1, 52.62, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0173', 3, '2026-08-29', 'C017', 'P-18', 'Web', 'Sucursal Centro', 'Caracas', 1, 11.01, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0174', 1, '2026-08-30', 'C010', 'P-01', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 35.78, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0175', 1, '2026-08-30', 'C004', 'P-04', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 45.11, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0176', 1, '2026-08-31', 'C014', 'P-12', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 23.9, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0177', 1, '2026-08-31', 'C011', 'P-02', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 13.83, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0177', 2, '2026-08-31', 'C011', 'P-03', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 52.3, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0177', 3, '2026-08-31', 'C011', 'P-13', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 20.69, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0178', 1, '2026-09-01', 'C008', 'P-02', 'WhatsApp', 'Sucursal Centro', 'Caracas', 3, 14.54, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0178', 2, '2026-09-01', 'C008', 'P-08', 'WhatsApp', 'Sucursal Centro', 'Caracas', 1, 39.61, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0178', 3, '2026-09-01', 'C008', 'P-07', 'WhatsApp', 'Sucursal Centro', 'Caracas', 2, 26.0, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0179', 1, '2026-09-01', 'C001', 'P-07', 'WhatsApp', 'Sucursal Este', 'Maracaibo', 3, 24.11, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0180', 1, '2026-09-02', 'C016', 'P-13', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 19.28, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0180', 2, '2026-09-02', 'C016', 'P-11', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 172.41, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0180', 3, '2026-09-02', 'C016', 'P-18', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 10.51, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0181', 1, '2026-09-02', 'C014', 'P-01', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 34.97, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0181', 2, '2026-09-02', 'C014', 'P-09', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 69.52, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0182', 1, '2026-09-03', 'C002', 'P-03', 'Web', 'Sucursal Norte', 'Valencia', 1, 54.34, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0182', 2, '2026-09-03', 'C002', 'P-18', 'Web', 'Sucursal Norte', 'Valencia', 1, 11.26, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0182', 3, '2026-09-03', 'C002', 'P-09', 'Web', 'Sucursal Norte', 'Valencia', 1, 67.14, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0183', 1, '2026-09-03', 'C006', 'P-03', 'Web', 'Sucursal Centro', 'Caracas', 1, 54.62, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0184', 1, '2026-09-04', 'C002', 'P-11', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 178.45, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0184', 2, '2026-09-04', 'C002', 'P-13', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 20.8, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0184', 3, '2026-09-04', 'C002', 'P-01', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 35.25, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0185', 1, '2026-09-04', 'C005', 'P-16', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 8.7, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0185', 2, '2026-09-04', 'C005', 'P-05', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 29.95, 5.99);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0186', 1, '2026-09-05', 'C011', 'P-04', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 42.78, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0186', 2, '2026-09-05', 'C011', 'P-05', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 29.64, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0187', 1, '2026-09-06', 'C005', 'P-11', 'WhatsApp', 'Sucursal Norte', 'Valencia', 2, 176.66, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0187', 2, '2026-09-06', 'C005', 'P-07', 'WhatsApp', 'Sucursal Norte', 'Valencia', 2, 24.48, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0188', 1, '2026-09-06', 'C999', 'P-13', 'Web', 'Sucursal Norte', 'Valencia', 2, 19.73, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0188', 2, '2026-09-06', 'C999', 'P-09', 'Web', 'Sucursal Norte', 'Valencia', 1, 70.65, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0189', 1, '2026-09-08', 'C016', 'P-03', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 55.73, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0189', 2, '2026-09-08', 'C016', 'P-14', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 15.45, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0189', 3, '2026-09-08', 'C016', 'P-16', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 8.62, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0190', 1, '2026-09-08', 'C007', 'P-02', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 14.38, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0190', 2, '2026-09-08', 'C007', 'P-12', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 23.2, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0190', 3, '2026-09-08', 'C007', 'P-03', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 57.66, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0191', 1, '2026-09-09', 'C019', 'P-01', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 34.16, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0192', 1, '2026-09-09', 'C007', 'P-12', 'Web', 'Sucursal Norte', 'Valencia', 2, 24.65, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0192', 2, '2026-09-09', 'C007', 'P-13', 'Web', 'Sucursal Norte', 'Valencia', 3, 19.3, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0193', 1, '2026-09-10', 'C002', 'P-05', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 29.44, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0194', 1, '2026-09-10', 'C003', 'P-15', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 32.63, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0195', 1, '2026-09-11', 'C001', 'P-04', 'Web', 'Sucursal Centro', 'Caracas', 3, 43.85, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0195', 2, '2026-09-11', 'C001', 'P-06', 'Web', 'Sucursal Centro', 'Caracas', 1, 21.63, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0196', 1, '2026-09-11', 'C006', 'P-14', 'Web', 'Sucursal Norte', 'Valencia', 2, 15.25, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0197', 1, '2026-09-12', 'C006', 'P-07', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 25.77, 3.87);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0197', 2, '2026-09-12', 'C006', 'P-18', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 10.66, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0197', 3, '2026-09-12', 'C006', 'P-09', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 67.3, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0198', 1, '2026-09-13', 'C999', 'P-13', 'Web', 'Sucursal Sur', 'Barquisimeto', 2, 20.69, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0198', 2, '2026-09-13', 'C999', 'P-04', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 45.93, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0198', 3, '2026-09-13', 'C999', 'P-12', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 24.22, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0199', 1, '2026-09-13', 'C004', 'P-12', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 23.14, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0200', 1, '2026-09-14', 'C008', 'P-18', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 10.77, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0200', 2, '2026-09-14', 'C008', 'P-06', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 2, 22.26, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0200', 3, '2026-09-14', 'C008', 'P-17', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 1, 11.98, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0201', 1, '2026-09-15', 'C018', 'P-16', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 9.31, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0201', 2, '2026-09-15', 'C018', 'P-14', 'Web', 'Sucursal Sur', 'Barquisimeto', 1, 16.1, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0202', 1, '2026-09-15', 'C003', 'P-10', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 20.49, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0202', 2, '2026-09-15', 'C003', 'P-06', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 22.02, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0202', 3, '2026-09-15', 'C003', 'P-15', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 32.88, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0203', 1, '2026-09-16', 'C007', 'P-07', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 25.83, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0203', 2, '2026-09-16', 'C007', 'P-14', 'Web', 'Sucursal Sur', 'Barquisimeto', 2, 16.6, 3.32);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0203', 3, '2026-09-16', 'C007', 'P-04', 'Web', 'Sucursal Sur', 'Barquisimeto', 2, 46.63, 4.66);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0204', 1, '2026-09-16', 'C012', 'P-14', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 16.5, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0204', 2, '2026-09-16', 'C012', 'P-06', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 21.67, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0204', 3, '2026-09-16', 'C012', 'P-05', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 29.01, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0205', 1, '2026-09-17', 'C004', 'P-14', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 1, 16.79, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0206', 1, '2026-09-17', 'C002', 'P-11', 'WhatsApp', 'Sucursal Norte', 'Valencia', 1, 184.71, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0207', 1, '2026-09-18', 'C002', 'P-15', NULL, 'Sucursal Sur', 'Barquisimeto', 3, 32.94, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0207', 2, '2026-09-18', 'C002', 'P-03', NULL, 'Sucursal Sur', 'Barquisimeto', 2, 55.09, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0208', 1, '2026-09-18', 'C016', 'P-01', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 36.65, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0208', 2, '2026-09-18', 'C016', 'P-03', 'Tienda Fisica', 'Sucursal Sur', 'Barquisimeto', 3, 54.22, 24.4);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0209', 1, '2026-09-19', 'C003', 'P-09', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 2, 68.86, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0209', 2, '2026-09-19', 'C003', 'P-11', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 186.34, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0210', 1, '2026-09-19', 'C015', 'P-15', 'Web', 'Sucursal Centro', 'Caracas', 1, 30.8, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0211', 1, '2026-09-20', 'C006', 'P-05', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 3, 29.41, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0212', 1, '2026-09-20', 'C015', 'P-03', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 57.22, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0212', 2, '2026-09-20', 'C015', 'P-12', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 2, 24.3, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0213', 1, '2026-09-21', 'C006', 'P-07', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 23.94, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0214', 1, '2026-09-22', 'C001', 'P-05', 'Web', 'Sucursal Centro', 'Caracas', 1, 29.19, 1.46);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0214', 2, '2026-09-22', 'C001', 'P-16', 'Web', 'Sucursal Centro', 'Caracas', 1, 8.83, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0215', 1, '2026-09-22', 'C002', 'P-05', 'Web', 'Sucursal Norte', 'Valencia', 3, 30.45, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0215', 2, '2026-09-22', 'C002', 'P-03', 'Web', 'Sucursal Norte', 'Valencia', 3, 53.42, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0215', 3, '2026-09-22', 'C002', 'P-01', 'Web', 'Sucursal Norte', 'Valencia', 2, 35.41, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0216', 1, '2026-09-23', 'C002', 'P-13', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 2, 20.58, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0216', 2, '2026-09-23', 'C002', 'P-12', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 23.0, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0216', 3, '2026-09-23', 'C002', 'P-14', 'Tienda Fisica', 'Sucursal Centro', 'Caracas', 3, 16.35, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0217', 1, '2026-09-25', 'C003', 'P-13', 'Web', 'Sucursal Norte', 'Valencia', 1, 19.99, 2.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0217', 2, '2026-09-25', 'C003', 'P-10', 'Web', 'Sucursal Norte', 'Valencia', 3, 20.19, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0217', 3, '2026-09-25', 'C003', 'P-02', 'Web', 'Sucursal Norte', 'Valencia', 1, 14.68, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0218', 1, '2026-09-25', 'C002', 'P-18', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 2, 11.5, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0218', 2, '2026-09-25', 'C002', 'P-06', 'WhatsApp', 'Sucursal Sur', 'Barquisimeto', 1, 22.19, 1.11);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0219', 1, '2026-09-28', 'C007', 'P-13', 'Web', 'Sucursal Sur', 'Barquisimeto', 3, 20.07, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0219', 2, '2026-09-28', 'C007', 'P-03', 'Web', 'Sucursal Sur', 'Barquisimeto', 2, 52.71, 5.27);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0220', 1, '2026-09-28', 'C020', 'P-03', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 3, 54.66, 0.0);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0220', 2, '2026-09-28', 'C020', 'P-10', 'Tienda Fisica', 'Sucursal Este', 'Maracaibo', 1, 19.12, 1.91);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0221', 1, '2026-09-30', 'C008', 'P-01', 'Tienda Fisica', 'Sucursal Norte', 'Valencia', 3, 33.73, 10.12);
INSERT INTO src_ventas (id_ticket, linea, fecha, id_cliente, id_producto, canal, sucursal, ciudad, cantidad, precio_unitario, descuento) VALUES ('T-0222', 1, '2026-09-30', 'C017', 'P-12', 'Web', 'Sucursal Este', 'Maracaibo', 1, 24.6, 0.0);


-- >>>>>>>>>> 03_carga_etl.sql <<<<<<<<<<
-- =====================================================================
-- 03_carga_etl.sql
-- Carga del Data Mart desde la capa operacional (src_*).
-- Orden: dimensiones primero, tabla de hechos al final.
-- Requiere SQLite >= 3.25 (funciones de ventana: LEAD).
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1. Dimensiones simples (las filas "Desconocido" ya existen, sk = -1)
-- ---------------------------------------------------------------------
INSERT INTO DimCanal (nombre)
SELECT DISTINCT canal
FROM src_ventas
WHERE canal IS NOT NULL;

INSERT INTO DimSucursal (nombre, ciudad)
SELECT DISTINCT sucursal, ciudad
FROM src_ventas
WHERE sucursal IS NOT NULL;

INSERT INTO DimProducto (id_producto, nombre, categoria, costo_unitario)
SELECT id_producto, nombre, categoria, costo_unitario
FROM src_productos;

-- ---------------------------------------------------------------------
-- 2. DimTiempo: una fila por cada dia entre la primera y la ultima venta
-- ---------------------------------------------------------------------
WITH RECURSIVE d(f) AS (
    SELECT MIN(fecha) FROM src_ventas
    UNION ALL
    SELECT date(f, '+1 day') FROM d WHERE f < (SELECT MAX(fecha) FROM src_ventas)
)
INSERT INTO DimTiempo (sk_tiempo, fecha, anio, trimestre, mes, nombre_mes, dia)
SELECT CAST(strftime('%Y%m%d', f) AS INTEGER),
       f,
       CAST(strftime('%Y', f) AS INTEGER),
       (CAST(strftime('%m', f) AS INTEGER) + 2) / 3,
       CAST(strftime('%m', f) AS INTEGER),
       CASE strftime('%m', f)
            WHEN '01' THEN 'Enero'      WHEN '02' THEN 'Febrero'   WHEN '03' THEN 'Marzo'
            WHEN '04' THEN 'Abril'      WHEN '05' THEN 'Mayo'      WHEN '06' THEN 'Junio'
            WHEN '07' THEN 'Julio'      WHEN '08' THEN 'Agosto'    WHEN '09' THEN 'Septiembre'
            WHEN '10' THEN 'Octubre'    WHEN '11' THEN 'Noviembre' ELSE 'Diciembre'
       END,
       CAST(strftime('%d', f) AS INTEGER)
FROM d;

-- ---------------------------------------------------------------------
-- 3. DimCliente con SCD TIPO 2
--    Cada fila de src_clientes_historial es una version del cliente.
--    fecha_fin = dia anterior al inicio de la siguiente version (NULL si es la ultima).
-- ---------------------------------------------------------------------
INSERT INTO DimCliente (id_cliente, nombre, segmento, fecha_inicio, fecha_fin, es_actual)
SELECT id_cliente,
       nombre,
       segmento,
       vigente_desde,
       date(LEAD(vigente_desde) OVER (PARTITION BY id_cliente ORDER BY vigente_desde), '-1 day'),
       CASE WHEN LEAD(vigente_desde) OVER (PARTITION BY id_cliente ORDER BY vigente_desde) IS NULL
            THEN 1 ELSE 0 END
FROM src_clientes_historial;

-- ---------------------------------------------------------------------
-- 4. FactVentas
--    - LEFT JOIN + COALESCE(..., -1): claves nulas o inexistentes caen en "Desconocido".
--    - El cliente se busca por la VERSION VIGENTE EN LA FECHA de la venta (SCD2).
--    - Reglas de calculo:
--        ingreso_bruto = cantidad * precio_unitario
--        ingreso_neto  = ingreso_bruto - descuento
--        costo_total   = cantidad * costo_unitario   (NULL si no hay costo)
--        margen_bruto  = ingreso_neto - costo_total  (NULL si no hay costo)
-- ---------------------------------------------------------------------
INSERT INTO FactVentas (sk_tiempo, sk_cliente, sk_producto, sk_canal, sk_sucursal,
                        numero_ticket, numero_linea, cantidad, precio_unitario, descuento,
                        ingreso_bruto, ingreso_neto, costo_total, margen_bruto)
SELECT CAST(strftime('%Y%m%d', v.fecha) AS INTEGER),
       COALESCE(c.sk_cliente, -1),
       COALESCE(p.sk_producto, -1),
       COALESCE(ca.sk_canal, -1),
       COALESCE(s.sk_sucursal, -1),
       v.id_ticket,
       v.linea,
       v.cantidad,
       v.precio_unitario,
       COALESCE(v.descuento, 0),
       ROUND(v.cantidad * v.precio_unitario, 2),
       ROUND(v.cantidad * v.precio_unitario - COALESCE(v.descuento, 0), 2),
       ROUND(v.cantidad * p.costo_unitario, 2),
       ROUND(v.cantidad * v.precio_unitario - COALESCE(v.descuento, 0) - v.cantidad * p.costo_unitario, 2)
FROM src_ventas v
LEFT JOIN DimCliente  c  ON c.id_cliente = v.id_cliente
                        AND v.fecha BETWEEN c.fecha_inicio AND COALESCE(c.fecha_fin, '9999-12-31')
LEFT JOIN DimProducto p  ON p.id_producto = v.id_producto
LEFT JOIN DimCanal    ca ON ca.nombre = v.canal
LEFT JOIN DimSucursal s  ON s.nombre = v.sucursal;


-- >>>>>>>>>> 04_consultas.sql <<<<<<<<<<
-- (Catalogo de consultas parametrizadas: se ejecutan desde el agente con valores para los :parametros.
-- Para probarlas a mano, reemplaza cada :parametro por un valor y quita el prefijo '-- '.)
-- -- =====================================================================
-- -- 04_consultas.sql
-- -- CATALOGO DE CONSULTAS PARAMETRIZADAS que usa el agente.
-- -- Los parametros se escriben :asi y los rellena el agente (nunca se
-- -- concatena texto del usuario dentro del SQL).
-- --
-- -- Convenciones:
-- --   * Fechas como 'AAAA-MM-DD' (desde/hasta inclusivos).
-- --   * Los rankings excluyen la fila "Desconocido" (sk = -1); el agente debe
-- --     advertir si hay ventas en "Desconocido".
-- --   * margen_bruto puede ser NULL (producto sin costo): SUM lo ignora; el
-- --     agente debe advertirlo.
-- --   * Para ejecutarlas con valores de ejemplo: python construir_y_probar.py
-- -- =====================================================================

-- -- [Q0] Periodo disponible en el Data Mart (para resolver "ultimos 3 meses", etc.)
-- -- Parametros: (ninguno)
-- SELECT MIN(t.fecha) AS primera_fecha, MAX(t.fecha) AS ultima_fecha
-- FROM FactVentas f
-- JOIN DimTiempo t ON t.sk_tiempo = f.sk_tiempo;

-- -- [Q1] Cual fue el ingreso neto por mes?
-- -- Parametros: :desde, :hasta
-- SELECT t.anio, t.mes, t.nombre_mes,
--        ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
-- FROM FactVentas f
-- JOIN DimTiempo t ON t.sk_tiempo = f.sk_tiempo
-- WHERE t.fecha BETWEEN :desde AND :hasta
-- GROUP BY t.anio, t.mes, t.nombre_mes
-- ORDER BY t.anio, t.mes;

-- -- [Q2] Cuales son las N categorias con mayor margen bruto?
-- -- Parametros: :desde, :hasta, :n
-- SELECT p.categoria,
--        ROUND(SUM(f.margen_bruto), 2) AS margen_bruto
-- FROM FactVentas f
-- JOIN DimProducto p ON p.sk_producto = f.sk_producto
-- JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
-- WHERE t.fecha BETWEEN :desde AND :hasta
--   AND p.sk_producto <> -1
-- GROUP BY p.categoria
-- ORDER BY margen_bruto DESC
-- LIMIT :n;

-- -- [Q3] Que sucursal presenta el ticket promedio mas alto?
-- -- Ticket promedio = SUM(ingreso_neto) / COUNT(DISTINCT numero_ticket)
-- -- Parametros: :desde, :hasta, :n
-- SELECT s.nombre AS sucursal,
--        COUNT(DISTINCT f.numero_ticket) AS tickets,
--        ROUND(SUM(f.ingreso_neto) * 1.0 / COUNT(DISTINCT f.numero_ticket), 2) AS ticket_promedio
-- FROM FactVentas f
-- JOIN DimSucursal s ON s.sk_sucursal = f.sk_sucursal
-- JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
-- WHERE t.fecha BETWEEN :desde AND :hasta
--   AND s.sk_sucursal <> -1
-- GROUP BY s.nombre
-- ORDER BY ticket_promedio DESC
-- LIMIT :n;

-- -- [Q4] Que segmento de clientes redujo mas su volumen de compra? (periodo A vs periodo B)
-- -- Volumen = SUM(cantidad). Usa el segmento vigente al momento de cada venta (SCD2).
-- -- variacion = volumen_b - volumen_a (la mas negativa es la mayor reduccion)
-- -- Parametros: :a_desde, :a_hasta, :b_desde, :b_hasta
-- WITH a AS (
--     SELECT c.segmento, SUM(f.cantidad) AS volumen
--     FROM FactVentas f
--     JOIN DimCliente c ON c.sk_cliente = f.sk_cliente
--     JOIN DimTiempo  t ON t.sk_tiempo  = f.sk_tiempo
--     WHERE t.fecha BETWEEN :a_desde AND :a_hasta AND c.sk_cliente <> -1
--     GROUP BY c.segmento
-- ),
-- b AS (
--     SELECT c.segmento, SUM(f.cantidad) AS volumen
--     FROM FactVentas f
--     JOIN DimCliente c ON c.sk_cliente = f.sk_cliente
--     JOIN DimTiempo  t ON t.sk_tiempo  = f.sk_tiempo
--     WHERE t.fecha BETWEEN :b_desde AND :b_hasta AND c.sk_cliente <> -1
--     GROUP BY c.segmento
-- )
-- SELECT a.segmento,
--        a.volumen                        AS volumen_a,
--        COALESCE(b.volumen, 0)           AS volumen_b,
--        COALESCE(b.volumen, 0) - a.volumen AS variacion
-- FROM a
-- LEFT JOIN b ON b.segmento = a.segmento
-- ORDER BY variacion ASC;

-- -- [Q5] Que canal concentra el mayor valor de ventas?
-- -- Parametros: :desde, :hasta, :n
-- SELECT ca.nombre AS canal,
--        ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
-- FROM FactVentas f
-- JOIN DimCanal  ca ON ca.sk_canal = f.sk_canal
-- JOIN DimTiempo t  ON t.sk_tiempo = f.sk_tiempo
-- WHERE t.fecha BETWEEN :desde AND :hasta
--   AND ca.sk_canal <> -1
-- GROUP BY ca.nombre
-- ORDER BY ingreso_neto DESC
-- LIMIT :n;

-- -- [Q6] Comparar el margen de dos canales (por mes) en un periodo (ej. ultimos 3 meses)
-- -- margen_pct = SUM(margen_bruto) / SUM(ingreso_neto)   (NO se promedian porcentajes)
-- -- Parametros: :canal1, :canal2, :desde, :hasta
-- SELECT ca.nombre AS canal, t.anio, t.mes, t.nombre_mes,
--        ROUND(SUM(f.margen_bruto), 2) AS margen_bruto,
--        ROUND(SUM(f.margen_bruto) * 100.0 / SUM(f.ingreso_neto), 2) AS margen_pct
-- FROM FactVentas f
-- JOIN DimCanal  ca ON ca.sk_canal = f.sk_canal
-- JOIN DimTiempo t  ON t.sk_tiempo = f.sk_tiempo
-- WHERE ca.nombre IN (:canal1, :canal2)
--   AND t.fecha BETWEEN :desde AND :hasta
-- GROUP BY ca.nombre, t.anio, t.mes, t.nombre_mes
-- ORDER BY t.anio, t.mes, ca.nombre;

-- -- [Q7] Que producto lidera las ventas dentro de una categoria y periodo?
-- -- Criterio por defecto: ingreso neto (se muestran tambien las unidades).
-- -- Parametros: :categoria, :desde, :hasta
-- SELECT p.nombre AS producto,
--        SUM(f.cantidad)               AS unidades,
--        ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
-- FROM FactVentas f
-- JOIN DimProducto p ON p.sk_producto = f.sk_producto
-- JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
-- WHERE p.categoria = :categoria
--   AND t.fecha BETWEEN :desde AND :hasta
-- GROUP BY p.nombre
-- ORDER BY ingreso_neto DESC
-- LIMIT 1;

-- -- [Q8] (Adicional) Margen porcentual por categoria
-- -- Valor: el margen absoluto engana; una categoria con mucho ingreso puede ser poco rentable.
-- -- Parametros: :desde, :hasta
-- SELECT p.categoria,
--        ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto,
--        ROUND(SUM(f.margen_bruto), 2) AS margen_bruto,
--        ROUND(SUM(f.margen_bruto) * 100.0 / SUM(f.ingreso_neto), 2) AS margen_pct
-- FROM FactVentas f
-- JOIN DimProducto p ON p.sk_producto = f.sk_producto
-- JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
-- WHERE t.fecha BETWEEN :desde AND :hasta
--   AND p.sk_producto <> -1
-- GROUP BY p.categoria
-- ORDER BY margen_pct DESC;

-- -- [Q9] (Adicional) Top N clientes por ingreso neto
-- -- Valor: mide la dependencia del negocio de pocos clientes.
-- -- Se agrupa por id_cliente (no por sk) para juntar todas las versiones SCD2 del cliente.
-- -- Parametros: :desde, :hasta, :n
-- SELECT c.id_cliente, c.nombre,
--        ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
-- FROM FactVentas f
-- JOIN DimCliente c ON c.sk_cliente = f.sk_cliente
-- JOIN DimTiempo  t ON t.sk_tiempo  = f.sk_tiempo
-- WHERE t.fecha BETWEEN :desde AND :hasta
--   AND c.sk_cliente <> -1
-- GROUP BY c.id_cliente, c.nombre
-- ORDER BY ingreso_neto DESC
-- LIMIT :n;

-- -- [Q10] (Adicional) Descuento total y porcentaje de descuento por canal
-- -- Valor: detecta canales donde se esta cediendo margen via descuentos.
-- -- Parametros: :desde, :hasta
-- SELECT ca.nombre AS canal,
--        ROUND(SUM(f.descuento), 2) AS descuento_total,
--        ROUND(SUM(f.descuento) * 100.0 / SUM(f.ingreso_bruto), 2) AS descuento_pct
-- FROM FactVentas f
-- JOIN DimCanal  ca ON ca.sk_canal = f.sk_canal
-- JOIN DimTiempo t  ON t.sk_tiempo = f.sk_tiempo
-- WHERE t.fecha BETWEEN :desde AND :hasta
--   AND ca.sk_canal <> -1
-- GROUP BY ca.nombre
-- ORDER BY descuento_pct DESC;


-- >>>>>>>>>> 05_controles.sql <<<<<<<<<<
-- =====================================================================
-- 05_controles.sql
-- Controles de calidad, integridad referencial y conciliacion.
-- Cada control indica el resultado esperado. Guardar capturas para el informe.
-- =====================================================================

-- [C1] Integridad referencial: ventas huerfanas por dimension
-- Esperado: 0 en todas las filas
SELECT 'huerfanas_tiempo' AS control, COUNT(*) AS filas
FROM FactVentas f LEFT JOIN DimTiempo d ON d.sk_tiempo = f.sk_tiempo WHERE d.sk_tiempo IS NULL
UNION ALL
SELECT 'huerfanas_cliente', COUNT(*)
FROM FactVentas f LEFT JOIN DimCliente d ON d.sk_cliente = f.sk_cliente WHERE d.sk_cliente IS NULL
UNION ALL
SELECT 'huerfanas_producto', COUNT(*)
FROM FactVentas f LEFT JOIN DimProducto d ON d.sk_producto = f.sk_producto WHERE d.sk_producto IS NULL
UNION ALL
SELECT 'huerfanas_canal', COUNT(*)
FROM FactVentas f LEFT JOIN DimCanal d ON d.sk_canal = f.sk_canal WHERE d.sk_canal IS NULL
UNION ALL
SELECT 'huerfanas_sucursal', COUNT(*)
FROM FactVentas f LEFT JOIN DimSucursal d ON d.sk_sucursal = f.sk_sucursal WHERE d.sk_sucursal IS NULL;

-- [C2] Duplicados en el grano (ticket + linea)
-- Esperado: 0 filas duplicadas
SELECT COUNT(*) AS grupos_duplicados
FROM (SELECT numero_ticket, numero_linea
      FROM FactVentas
      GROUP BY numero_ticket, numero_linea
      HAVING COUNT(*) > 1);

-- [C3] Conciliacion de totales: fuente (src_ventas) vs Data Mart (FactVentas)
-- Esperado: estado = OK en todas las filas
SELECT control, fuente, datamart, ROUND(fuente - datamart, 2) AS diferencia,
       CASE WHEN ROUND(fuente - datamart, 2) = 0 THEN 'OK' ELSE 'DIFERENCIA' END AS estado
FROM (
    SELECT 'filas' AS control,
           (SELECT COUNT(*) FROM src_ventas) * 1.0 AS fuente,
           (SELECT COUNT(*) FROM FactVentas) * 1.0 AS datamart
    UNION ALL
    SELECT 'tickets',
           (SELECT COUNT(DISTINCT id_ticket) FROM src_ventas) * 1.0,
           (SELECT COUNT(DISTINCT numero_ticket) FROM FactVentas) * 1.0
    UNION ALL
    SELECT 'cantidad',
           (SELECT SUM(cantidad) FROM src_ventas) * 1.0,
           (SELECT SUM(cantidad) FROM FactVentas) * 1.0
    UNION ALL
    SELECT 'ingreso_bruto',
           (SELECT ROUND(SUM(ROUND(cantidad * precio_unitario, 2)), 2) FROM src_ventas),
           (SELECT ROUND(SUM(ingreso_bruto), 2) FROM FactVentas)
    UNION ALL
    SELECT 'descuento',
           (SELECT ROUND(SUM(COALESCE(descuento, 0)), 2) FROM src_ventas),
           (SELECT ROUND(SUM(descuento), 2) FROM FactVentas)
    UNION ALL
    SELECT 'ingreso_neto',
           (SELECT ROUND(SUM(ROUND(cantidad * precio_unitario - COALESCE(descuento, 0), 2)), 2) FROM src_ventas),
           (SELECT ROUND(SUM(ingreso_neto), 2) FROM FactVentas)
);

-- [C4] Excepciones: ventas cargadas en "Desconocido" (documentar en el informe)
-- Esperado: conteos coherentes con las excepciones sembradas en los datos
SELECT 'ventas con cliente desconocido' AS excepcion, COUNT(*) AS filas FROM FactVentas WHERE sk_cliente = -1
UNION ALL
SELECT 'ventas con producto desconocido', COUNT(*) FROM FactVentas WHERE sk_producto = -1
UNION ALL
SELECT 'ventas con canal desconocido', COUNT(*) FROM FactVentas WHERE sk_canal = -1
UNION ALL
SELECT 'ventas con sucursal desconocida', COUNT(*) FROM FactVentas WHERE sk_sucursal = -1
UNION ALL
SELECT 'ventas sin costo (costo_total NULL)', COUNT(*) FROM FactVentas WHERE costo_total IS NULL;

-- [C5] SCD2 sano: cada cliente real debe tener exactamente UNA version actual
-- Esperado: 0 filas
SELECT id_cliente, SUM(es_actual) AS versiones_actuales
FROM DimCliente
WHERE sk_cliente <> -1
GROUP BY id_cliente
HAVING SUM(es_actual) <> 1;

-- [C6] SCD2: clientes con mas de una version (demuestra que se conserva la historia)
-- Esperado: al menos 1 cliente (C005)
SELECT sk_cliente, id_cliente, nombre, segmento, fecha_inicio, fecha_fin, es_actual
FROM DimCliente
WHERE id_cliente IN (SELECT id_cliente FROM DimCliente GROUP BY id_cliente HAVING COUNT(*) > 1)
ORDER BY id_cliente, fecha_inicio;

-- [C7] SCD2: ventas asociadas a una version de cliente que NO cubre la fecha de la venta
-- Esperado: 0
SELECT COUNT(*) AS ventas_con_version_incorrecta
FROM FactVentas f
JOIN DimCliente c ON c.sk_cliente = f.sk_cliente
JOIN DimTiempo  t ON t.sk_tiempo  = f.sk_tiempo
WHERE f.sk_cliente <> -1
  AND NOT (t.fecha BETWEEN c.fecha_inicio AND COALESCE(c.fecha_fin, '9999-12-31'));

-- [C8] Coherencia de las reglas de calculo
-- Esperado: 0 en todas las filas
SELECT 'ingreso_neto <> bruto - descuento' AS control, COUNT(*) AS filas
FROM FactVentas WHERE ABS(ingreso_neto - (ingreso_bruto - descuento)) > 0.01
UNION ALL
SELECT 'margen <> neto - costo', COUNT(*)
FROM FactVentas WHERE costo_total IS NOT NULL AND ABS(margen_bruto - (ingreso_neto - costo_total)) > 0.01
UNION ALL
SELECT 'margen con costo NULL', COUNT(*)
FROM FactVentas WHERE costo_total IS NULL AND margen_bruto IS NOT NULL;
