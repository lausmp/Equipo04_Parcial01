-- =====================================================================
-- 04_consultas.sql
-- CATALOGO DE CONSULTAS PARAMETRIZADAS que usa el agente.
-- Los parametros se escriben :asi y los rellena el agente (nunca se
-- concatena texto del usuario dentro del SQL).
--
-- Convenciones:
--   * Fechas como 'AAAA-MM-DD' (desde/hasta inclusivos).
--   * Los rankings excluyen la fila "Desconocido" (sk = -1); el agente debe
--     advertir si hay ventas en "Desconocido".
--   * margen_bruto puede ser NULL (producto sin costo): SUM lo ignora; el
--     agente debe advertirlo.
--   * Para ejecutarlas con valores de ejemplo: python construir_y_probar.py
-- =====================================================================

-- [Q0] Periodo disponible en el Data Mart (para resolver "ultimos 3 meses", etc.)
-- Parametros: (ninguno)
SELECT MIN(t.fecha) AS primera_fecha, MAX(t.fecha) AS ultima_fecha
FROM FactVentas f
JOIN DimTiempo t ON t.sk_tiempo = f.sk_tiempo;

-- [Q1] Cual fue el ingreso neto por mes?
-- Parametros: :desde, :hasta
SELECT t.anio, t.mes, t.nombre_mes,
       ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
FROM FactVentas f
JOIN DimTiempo t ON t.sk_tiempo = f.sk_tiempo
WHERE t.fecha BETWEEN :desde AND :hasta
GROUP BY t.anio, t.mes, t.nombre_mes
ORDER BY t.anio, t.mes;

-- [Q2] Cuales son las N categorias con mayor margen bruto?
-- Parametros: :desde, :hasta, :n
SELECT p.categoria,
       ROUND(SUM(f.margen_bruto), 2) AS margen_bruto
FROM FactVentas f
JOIN DimProducto p ON p.sk_producto = f.sk_producto
JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
WHERE t.fecha BETWEEN :desde AND :hasta
  AND p.sk_producto <> -1
GROUP BY p.categoria
ORDER BY margen_bruto DESC
LIMIT :n;

-- [Q3] Que sucursal presenta el ticket promedio mas alto?
-- Ticket promedio = SUM(ingreso_neto) / COUNT(DISTINCT numero_ticket)
-- Parametros: :desde, :hasta, :n
SELECT s.nombre AS sucursal,
       COUNT(DISTINCT f.numero_ticket) AS tickets,
       ROUND(SUM(f.ingreso_neto) * 1.0 / COUNT(DISTINCT f.numero_ticket), 2) AS ticket_promedio
FROM FactVentas f
JOIN DimSucursal s ON s.sk_sucursal = f.sk_sucursal
JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
WHERE t.fecha BETWEEN :desde AND :hasta
  AND s.sk_sucursal <> -1
GROUP BY s.nombre
ORDER BY ticket_promedio DESC
LIMIT :n;

-- [Q4] Que segmento de clientes redujo mas su volumen de compra? (periodo A vs periodo B)
-- Volumen = SUM(cantidad). Usa el segmento vigente al momento de cada venta (SCD2).
-- variacion = volumen_b - volumen_a (la mas negativa es la mayor reduccion)
-- Parametros: :a_desde, :a_hasta, :b_desde, :b_hasta
WITH a AS (
    SELECT c.segmento, SUM(f.cantidad) AS volumen
    FROM FactVentas f
    JOIN DimCliente c ON c.sk_cliente = f.sk_cliente
    JOIN DimTiempo  t ON t.sk_tiempo  = f.sk_tiempo
    WHERE t.fecha BETWEEN :a_desde AND :a_hasta AND c.sk_cliente <> -1
    GROUP BY c.segmento
),
b AS (
    SELECT c.segmento, SUM(f.cantidad) AS volumen
    FROM FactVentas f
    JOIN DimCliente c ON c.sk_cliente = f.sk_cliente
    JOIN DimTiempo  t ON t.sk_tiempo  = f.sk_tiempo
    WHERE t.fecha BETWEEN :b_desde AND :b_hasta AND c.sk_cliente <> -1
    GROUP BY c.segmento
)
SELECT a.segmento,
       a.volumen                        AS volumen_a,
       COALESCE(b.volumen, 0)           AS volumen_b,
       COALESCE(b.volumen, 0) - a.volumen AS variacion
FROM a
LEFT JOIN b ON b.segmento = a.segmento
ORDER BY variacion ASC;

-- [Q5] Que canal concentra el mayor valor de ventas?
-- Parametros: :desde, :hasta, :n
SELECT ca.nombre AS canal,
       ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
FROM FactVentas f
JOIN DimCanal  ca ON ca.sk_canal = f.sk_canal
JOIN DimTiempo t  ON t.sk_tiempo = f.sk_tiempo
WHERE t.fecha BETWEEN :desde AND :hasta
  AND ca.sk_canal <> -1
GROUP BY ca.nombre
ORDER BY ingreso_neto DESC
LIMIT :n;

-- [Q6] Comparar el margen de dos canales (por mes) en un periodo (ej. ultimos 3 meses)
-- margen_pct = SUM(margen_bruto) / SUM(ingreso_neto)   (NO se promedian porcentajes)
-- Parametros: :canal1, :canal2, :desde, :hasta
SELECT ca.nombre AS canal, t.anio, t.mes, t.nombre_mes,
       ROUND(SUM(f.margen_bruto), 2) AS margen_bruto,
       ROUND(SUM(f.margen_bruto) * 100.0 / SUM(f.ingreso_neto), 2) AS margen_pct
FROM FactVentas f
JOIN DimCanal  ca ON ca.sk_canal = f.sk_canal
JOIN DimTiempo t  ON t.sk_tiempo = f.sk_tiempo
WHERE ca.nombre IN (:canal1, :canal2)
  AND t.fecha BETWEEN :desde AND :hasta
GROUP BY ca.nombre, t.anio, t.mes, t.nombre_mes
ORDER BY t.anio, t.mes, ca.nombre;

-- [Q7] Que producto lidera las ventas dentro de una categoria y periodo?
-- Criterio por defecto: ingreso neto (se muestran tambien las unidades).
-- Parametros: :categoria, :desde, :hasta
SELECT p.nombre AS producto,
       SUM(f.cantidad)               AS unidades,
       ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
FROM FactVentas f
JOIN DimProducto p ON p.sk_producto = f.sk_producto
JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
WHERE p.categoria = :categoria
  AND t.fecha BETWEEN :desde AND :hasta
GROUP BY p.nombre
ORDER BY ingreso_neto DESC
LIMIT 1;

-- [Q8] (Adicional) Margen porcentual por categoria
-- Valor: el margen absoluto engana; una categoria con mucho ingreso puede ser poco rentable.
-- Parametros: :desde, :hasta
SELECT p.categoria,
       ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto,
       ROUND(SUM(f.margen_bruto), 2) AS margen_bruto,
       ROUND(SUM(f.margen_bruto) * 100.0 / SUM(f.ingreso_neto), 2) AS margen_pct
FROM FactVentas f
JOIN DimProducto p ON p.sk_producto = f.sk_producto
JOIN DimTiempo   t ON t.sk_tiempo   = f.sk_tiempo
WHERE t.fecha BETWEEN :desde AND :hasta
  AND p.sk_producto <> -1
GROUP BY p.categoria
ORDER BY margen_pct DESC;

-- [Q9] (Adicional) Top N clientes por ingreso neto
-- Valor: mide la dependencia del negocio de pocos clientes.
-- Se agrupa por id_cliente (no por sk) para juntar todas las versiones SCD2 del cliente.
-- Parametros: :desde, :hasta, :n
SELECT c.id_cliente, c.nombre,
       ROUND(SUM(f.ingreso_neto), 2) AS ingreso_neto
FROM FactVentas f
JOIN DimCliente c ON c.sk_cliente = f.sk_cliente
JOIN DimTiempo  t ON t.sk_tiempo  = f.sk_tiempo
WHERE t.fecha BETWEEN :desde AND :hasta
  AND c.sk_cliente <> -1
GROUP BY c.id_cliente, c.nombre
ORDER BY ingreso_neto DESC
LIMIT :n;

-- [Q10] (Adicional) Descuento total y porcentaje de descuento por canal
-- Valor: detecta canales donde se esta cediendo margen via descuentos.
-- Parametros: :desde, :hasta
SELECT ca.nombre AS canal,
       ROUND(SUM(f.descuento), 2) AS descuento_total,
       ROUND(SUM(f.descuento) * 100.0 / SUM(f.ingreso_bruto), 2) AS descuento_pct
FROM FactVentas f
JOIN DimCanal  ca ON ca.sk_canal = f.sk_canal
JOIN DimTiempo t  ON t.sk_tiempo = f.sk_tiempo
WHERE t.fecha BETWEEN :desde AND :hasta
  AND ca.sk_canal <> -1
GROUP BY ca.nombre
ORDER BY descuento_pct DESC;
