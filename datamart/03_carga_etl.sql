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
