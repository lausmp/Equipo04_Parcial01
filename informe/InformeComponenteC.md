# Informe Técnico: Componente C (Construcción del Agente Analítico de IA)
**Asignatura:** Tópicos Especiales para la Gestión de Datos  
**Docente:** Prof. Armen Djenanian  
**Equipo:** Equipo 04  
**Evaluación:** Parcial 01 – Construcción de un Agente Analítico de IA con Data Mart y BDOO  

---

## 1. Introducción y Propósito del Agente

El **Componente C** materializa el comportamiento inteligente del sistema: un prototipo funcional de Agente Analítico de IA capaz de recibir preguntas gerenciales formuladas en lenguaje natural, interpretar su intención analítica, seleccionar y parametrizar consultas seguras contra el Data Mart dimensional, validar la calidad e integridad de los datos mediante reglas polimórficas de negocio, y producir una respuesta ejecutiva sustentada en evidencia cuantitativa y metodológica, registrando cada paso en la Base de Datos Orientada a Objetos (BDOO).

### Principio Rector y Aislamiento de Capas
- **El Data Mart relacional** es la única fuente oficial de la verdad analítica del negocio.
- **La BDOO** almacena las sesiones, usuarios, preguntas, intenciones, consultas preparadas, resultados, evidencias y auditorías.
- **El Agente Analítico** actúa como puente orquestador: no inventa datos, no alucina y rechaza cualquier solicitud fuera del dominio de ventas.

---

## 2. Flujo Mínimo Esperado (Numeral 2.1)

El agente implementa estrictamente las 7 etapas secuenciales establecidas en las bases de la evaluación:

```
[1. Pregunta Usuario]
        │
        ▼
[2. Interpretación Semántica] ──> Intención, Métrica, Dimensión, Periodo, Filtros, Operación, Límite
        │
        ▼
[3. Selección de Consulta]   ──> Catálogo Parametrizado Q0..Q10 (Previene inyección SQL)
        │
        ▼
[4. Ejecución en Data Mart]  ──> SQLite Dimensional (FactVentas + Dimensiones)
        │
        ▼
[5. Validación por Reglas]   ──> ReglaNoVacio, ReglaMargenValido, ReglaDesconocido, ReglaSeguridad
        │
        ▼
[6. Respuesta con Evidencia] ──> Síntesis Ejecutiva + Tabla + Métricas + Regla Cálculo + Advertencias
        │
        ▼
[7. Persistencia en BDOO]    ──> Registro en grafo de objetos (Sesión, Pregunta, Resultado, Respuesta)
```

---

## 3. Interpretación de Preguntas (Numeral 6.1)

El módulo [`agente/interpretador.py`](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/agente/interpretador.py) analiza cada solicitud e identifica con precisión los 7 componentes analíticos obligatorios:

1. **Intención:** La necesidad de negocio subyacente (ej. *Analizar rentabilidad*, *Evolución de ventas*, *Comparativa de canales*).
2. **Métrica:** Métrica aditiva o no aditiva a calcular (`ingreso_neto`, `margen_bruto`, `ticket_promedio`, `cantidad`, `margen_pct`, `descuento_pct`).
3. **Dimensión:** Dimensión o jerarquía dimensional a filtrar/agrupar (`DimTiempo`, `DimCliente`, `DimProducto`, `DimCanal`, `DimSucursal`).
4. **Periodo:** Rango temporal explícito (`AAAA-MM-DD`), relativo (*segundo trimestre*, *últimos 3 meses*) o contextual heredado de la sesión.
5. **Filtros:** Valores específicos aplicados (ej. `categoria = 'Electronica'`, `canal1 = 'Tienda Fisica'`, `canal2 = 'Web'`).
6. **Operación Analítica:** `RANKING_DESC`, `EVOLUCION_TEMPORAL`, `COMPARACION_DIRECTA`, `MAX_LIDERAZGO`, `AGREGACION`.
7. **Cantidad de Resultados (Límite):** Número de filas de salida (ej. Top 1, Top 5, Top 10).

### Ejemplo de Salida del Interpretador (Exacta al Documento)
```text
Pregunta: "¿Cuál fue la categoría con mayor margen durante el segundo trimestre?"
Desglose: Intención: Identificar categorías más rentables | Métrica: margen bruto | Dimensión: categoría de producto | Periodo: segundo trimestre 2026 (2026-04-01 a 2026-06-30) | Operación: ranking descendente | Límite: 1
```

---

## 4. Acceso Seguro al Data Mart (Numeral 6.2)

El agente adopta un enfoque de **Catálogo de Consultas Parametrizadas** (`ConsultaAnalitica`), garantizando:
1. **Inmunidad ante Inyección SQL:** Los parámetros del usuario (`:desde`, `:hasta`, `:n`, `:categoria`, `:canal1`, `:canal2`) se vinculan exclusivamente mediante *parameter binding* nativo de SQLite; nunca se realiza concatenación de texto libre dentro de sentencias SQL.
2. **Bloqueo de Operaciones Destructivas:** La clase `ReglaSeguridadSQL` analiza cualquier sentencia y bloquea de manera inmediata palabras clave como `DROP`, `DELETE`, `UPDATE`, `INSERT`, `ALTER`, `TRUNCATE` o `ATTACH`.
3. **Aislamiento de la Capa Operacional:** Prohíbe estrictamente consultas directas a tablas de origen (`src_*`), forzando que todo análisis se resuelva sobre las tablas dimensionales oficiales (`FactVentas`, `DimTiempo`, `DimCliente`, `DimProducto`, `DimCanal`, `DimSucursal`).

---

## 5. Respuesta Gerencial con Evidencia (Numeral 6.3)

Cada respuesta generada por el agente contiene sin excepción los 7 elementos de evidencia exigidos:
1. **Resultado Cuantitativo o Categórico:** Tabla estructurada con valores numéricos formateados (separadores de miles y decimales a dos dígitos).
2. **Métrica Utilizada y Regla de Cálculo:** Definición matemática y conceptual explícita (ej. `Ticket promedio = SUM(ingreso_neto) / COUNT(DISTINCT numero_ticket)`).
3. **Periodo y Filtros Aplicados:** Rango de fechas y filtros acotados.
4. **Dimensión Analizada:** Dimensiones involucradas en la agrupación o corte.
5. **Interpretación Gerencial Breve:** Síntesis narrativa orientada a directores y tomadores de decisión.
6. **Fuente Consultada:** Tabla de hechos, tablas de dimensiones y código de consulta oficial ejecutada.
7. **Advertencias Metodológicas:** Controles de calidad activados por las reglas polimórficas (exclusión de claves sustitutas centinela `sk = -1`, notas sobre productos con costos nulos, advertencias por periodo asumido por defecto).

---

## 6. Manejo de Límites, Ambigüedad y Casos Extremos (Numeral 6.4)

| Caso Límite | Comportamiento Implementado | Justificación Metodológica |
| :--- | :--- | :--- |
| **Preguntas Fuera de Alcance** | Rechazo controlado con advertencia explícita: *"La solicitud requiere datos ajenos a las ventas comerciales de la organización."* | El agente no inventa información ni presupone datos ausentes en el Data Mart (ej. salarios, nómina, clima). |
| **Expresiones Ambiguas** *(ej. "¿cuál fue el mejor canal?")* | Detección de ambigüedad mediante `ReglaAmbiguedadCriterio`. El agente explicita y aplica el criterio: *"Se adoptó Ingreso Neto como criterio de medición oficial"* y advierte que podría medirse por margen o volumen. | Cumple el numeral 6.4, evitando respuestas arbitrarias sin fundamento. |
| **Pregunta Sin Periodo Explícito** | Asume automáticamente el periodo histórico completo disponible en el Data Mart (`2026-04-03` a `2026-09-30`) y emite una advertencia de auditoría destacada. | Permite responder al usuario sin fallar, dejando constancia de que no hubo acotamiento temporal en la pregunta. |
| **Ausencia de Registros** | Notifica que no existen transacciones registradas para los filtros solicitados sin asumir artificialmente un valor de cero. | Cumple la regla rectora: no inventar datos ni asumir cero cuando no existe evidencia transaccional justificable. |
| **Dimensión Inexistente** | Rechazo controlado informando que la dimensión (ej. *proveedor*, *temperatura*) no forma parte del esquema estrella. | Previene errores SQL y educa al usuario sobre las dimensiones válidas. |
| **Operación No Autorizada** | Bloqueo preventivo por `ReglaSeguridadSQL`. La consulta no llega a ejecutarse en SQLite y se registra la infracción en la BDOO. | Garantiza la integridad y seguridad del Data Mart. |

---

## 7. Las Tres Preguntas Adicionales de Valor Gerencial (Numeral 3.1)

En cumplimiento del numeral 3.1, el equipo incorporó 3 consultas adicionales de alta relevancia estratégica:

### Q8: Margen Porcentual por Categoría
- **Pregunta:** *"¿Cuál es el margen porcentual por categoría?"*
- **Regla de Cálculo:** `Margen % = SUM(margen_bruto) * 100.0 / SUM(ingreso_neto)`
- **Valor para el Negocio:** El margen absoluto puede ser engañoso: una categoría con gran facturación puede tener una rentabilidad muy baja debido a costos elevados. Esta métrica permite a la gerencia identificar qué líneas de producto generan mayor retorno por dólar vendido.

### Q9: Top N Clientes por Ingreso Neto (Unificación SCD2)
- **Pregunta:** *"¿Cuáles son los 5 clientes con mayor ingreso neto?"*
- **Regla de Cálculo:** `SUM(ingreso_neto)` agrupando por clave natural `id_cliente` (no por `sk_cliente`).
- **Valor para el Negocio:** Permite medir la concentración de la cartera (principio de Pareto) y evaluar el riesgo de dependencia de grandes cuentas. Al agrupar por `id_cliente`, unifica todas las versiones históricas que un cliente tuvo al cambiar de segmento (SCD Tipo 2).

### Q10: Descuento Total y Tasa de Descuento por Canal
- **Pregunta:** *"¿Cuánto se descontó en cada canal y cuál fue la tasa de descuento?"*
- **Regla de Cálculo:** `Descuento % = SUM(descuento) * 100.0 / SUM(ingreso_bruto)`
- **Valor para el Negocio:** Audita las políticas promocionales y detecta fugas de margen. Si un canal (ej. Web) presenta una tasa de descuento desproporcionada frente a las tiendas físicas, la gerencia puede renegociar promociones o ajustar la estrategia comercial.

---

## 8. Interfaces para la Defensa Oral y Ejecución en Vivo (Numeral 10 y 11)

Para garantizar el cumplimiento de los criterios de evaluación de **Prototipo y demostración (20%)** y **Ejecución en vivo ante una pregunta del docente (10%)**, el equipo implementó dos interfaces interactivas:

### 8.1 Interfaz de Línea de Comandos Interactiva (CLI)
Punto de entrada principal:
```bash
python main.py
# o alternativamente:
python -m agente.cli
```
**Características del CLI:**
- Menú interactivo con recuadros y formato ANSI a colores.
- Modo libre: permite escribir cualquier pregunta en lenguaje natural en tiempo real durante la defensa.
- Modo de demostración guiada de las 7 preguntas mínimas obligatorias.
- Modo de ejecución de las 3 preguntas adicionales de valor de negocio.
- Modo de verificación de límites, ambigüedad y bloqueos de seguridad.
- Módulo de inspección en vivo de los extents y objetos de la BDOO.

### 8.2 Panel Web Interactivo (Flask)
Punto de entrada para entorno gráfico:
```bash
python -m agente.web
```
Disponible en `http://localhost:5000`, ofreciendo una experiencia moderna con:
- Campo de consulta en lenguaje natural y chips de acceso rápido a las preguntas obligatorias.
- Visualización en tiempo real del desglose de interpretación (6.1).
- Tabla interactiva con los datos cuantitativos del Data Mart.
- Ficha técnica de evidencia (fuente oficial, regla de cálculo, SQL ejecutado y advertencias).
- Monitor lateral del estado de la BDOO (sesión actual, usuario activo, conteo de objetos y extents).

---

## 9. Entregables Generados para Canvas (Numeral 8 y 9)

1. **Matriz de Casos de Prueba en Excel:** [`Equipo04_Pruebas.xlsx`](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/Equipo04_Pruebas.xlsx) (formateada con estilos corporativos, anchos automáticos y estado verde APROBADO para los 13 casos).
2. **Matriz de Casos de Prueba en PDF:** [`Equipo04_Pruebas.pdf`](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/Equipo04_Pruebas.pdf).
3. **Paquete ZIP del Código Fuente del Agente:** [`Equipo04_AgenteIA.zip`](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/Equipo04_AgenteIA.zip) (contiene la estructura organizada de `bdoo/`, `agente/`, `requirements.txt`, `README.md` y `main.py`).
4. **Informe Técnico:** [`informe/InformeComponenteC.md`](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/informe/InformeComponenteC.md) y [`informe/InformeComponenteC.pdf`](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/informe/InformeComponenteC.pdf).
