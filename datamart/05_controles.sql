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
