# Informe Técnico: Componente B (Base de Datos Orientada a Objetos - BDOO)
**Asignatura:** Tópicos Especiales para la Gestión de Datos  
**Docente:** Prof. Armen Djenanian  
**Equipo:** Equipo 04  
**Evaluación:** Parcial 01 – Agente Analítico de IA con Data Mart y BDOO  

---

## 1. Introducción y Principio Rector

El presente documento detalla el diseño, la justificación arquitectónica y la implementación técnica del **Componente B: Base de Datos Orientada a Objetos (BDOO)**, desarrollado para el soporte del Agente Analítico de IA.

### Principio Rector de la Solución
> *"El Data Mart contiene la verdad analítica del negocio; la BDOO representa los objetos, comportamientos, sesiones, memoria operativa y trazabilidad del agente; el agente conecta la pregunta del usuario con una respuesta sustentada."*

Bajo este principio, se ha impuesto una **estricta separación de responsabilidades**:
- **La BDOO no duplica las tablas dimensionales** ni almacena transacciones de ventas (`FactVentas`), evitando redundancia inútil.
- Su función exclusiva es modelar el dominio conversacional y operativo del agente: quién pregunta, en qué sesión, qué intención se reconoció, qué consulta parametrizada se seleccionó, qué controles de calidad se aplicaron, qué evidencia se obtuvo y qué respuesta formal se devolvió a la gerencia.

---

## 2. Justificación Técnica: BDOO frente a Base Relacional (Defensa Oral)

En la defensa del parcial (secciones 8.4 y 11), una de las preguntas fundamentales del docente es: *¿Por qué utilizar una BDOO para el agente y qué ventajas ofrece frente a modelar la trazabilidad en tablas relacionales?*

### 2.1 Eliminación del Desajuste de Impedancia (Object-Relational Impedance Mismatch)
En un modelo relacional tradicional, persistir una estructura de interacciones conversacionales requiere normalizar el grafo en múltiples tablas (`usuarios`, `sesiones`, `preguntas`, `intenciones`, `consultas`, `reglas_aplicadas`, `respuestas`, `advertencias`). Esto introduce:
1. Fragmentación artificial de entidades que conceptualmente forman un solo grafo de memoria.
2. Elevado costo de reconstrucción mediante múltiples `JOIN` relacionales cada vez que el agente necesita recuperar el contexto de la sesión o auditar una pregunta.
3. Incapacidad de las tablas relacionales para almacenar **comportamiento y polimorfismo** (una fila en una tabla SQL no tiene métodos ejecutables).

En contraste, la **BDOO almacena directamente el grafo de objetos**, conservando en un solo artefacto tanto el estado como los métodos de validación, compilación y autorización.

### 2.2 Principios ODMG-3.0 Implementados
El motor implementado (`BDOOEngine`) respeta las especificaciones del estándar internacional **ODMG-3.0 (Object Data Management Group)**:
1. **Identidad de Objeto (OID):** Cada objeto posee un identificador inmutable y único en el universo de persistencia, completamente independiente de sus atributos de negocio.
2. **Persistencia por Alcance (Persistence by Reachability):** Al persistir un objeto raíz (por ejemplo, una `Sesion`), el motor recorre transitivamente los objetos referenciados (`Usuario`, `Pregunta`, `Intencion`, `ConsultaAnalitica`, `ResultadoConsulta`, `RespuestaAgente`) y los almacena manteniendo intactas sus referencias por punteros.
3. **Extents de Clase:** Para cada clase y superclase se mantiene un índice tipado que agrupa todas las instancias activas, permitiendo consultas declarativas de tipo `motor.obtener_extent(Pregunta)` o `motor.buscar(Pregunta, predicado)` en tiempo $O(1)$.
4. **Control Transaccional ACID:** Soporte de operaciones `iniciar_transaccion()`, `commit()` y `rollback()`, garantizando atomicidad y consistencia en el volcado físico a disco (`bdoo_almacen.json`).

---

## 3. Catálogo de los 10 Objetos Mínimos Implementados

El modelo cumple con exactitud la lista de los 10 objetos mínimos exigidos en la Sección 5.1 del documento de evaluación:

| Objeto | Clase Implementada | Responsabilidad y Comportamiento |
| :--- | :--- | :--- |
| **1. AgenteAnalitico** | `AgenteAnalitico` | Coordinador central del flujo analítico. Administra el catálogo de consultas, intenciones y fuentes; gestiona sesiones, orquesta la interpretación, ejecuta las consultas en el Data Mart y genera las respuestas. |
| **2. Usuario** | `Usuario`, `UsuarioGerencial`, `UsuarioOperativo` | Modela a la persona que formula la pregunta. Aplica herencia y polimorfismo para control de roles y permisos sobre métricas confidenciales. |
| **3. Sesion** | `Sesion` | Agrupa el diálogo conversacional de un usuario, su historial de preguntas y la memoria operativa de contexto (último periodo consultado, última categoría). |
| **4. Pregunta** | `Pregunta` | Conserva el texto original, fecha/hora, filtros detectados, estado de auditoría y referencias completas a la intención, consulta, resultado y respuesta. |
| **5. Intencion** | `Intencion` (y subclases especializadas) | Representa la necesidad analítica identificada (métrica, dimensión, periodo, filtros y operación de ranking, tendencia, comparativa o liderazgo). |
| **6. ConsultaAnalitica** | `ConsultaAnalitica` | Encapsula la plantilla SQL parametrizada (`:param`), la regla de cálculo formal, la referencia a la fuente de datos oficial y su colección de reglas de validación. |
| **7. ResultadoConsulta** | `ResultadoConsulta` | Conserva los datos devueltos por SQLite, nombres de columnas, total de registros, tiempo de ejecución en milisegundos y estado técnico de la ejecución. |
| **8. RespuestaAgente** | `RespuestaAgente` | Almacena la síntesis ejecutiva, evidencia cuantitativa, fórmula de negocio, periodo, filtros, fuentes oficiales consultadas y lista de advertencias de calidad. |
| **9. FuenteDato** | `FuenteDato` | Identifica formalmente el Data Mart (`DataMart_Ventas`), la tabla de hechos (`FactVentas`), las dimensiones, los campos permitidos y el grano del negocio. |
| **10. ReglaValidacion** | `ReglaValidacion` (y subclases polimórficas) | Representa los controles aplicados antes de responder: verificación de resultados vacíos, auditoría de márgenes nulos, exclusión de claves centinela y seguridad SQL. |

---

## 4. Demostración de los Pilares de la Programación Orientada a Objetos

La rúbrica de evaluación (Sección 11) asigna un **20%** a la verificación de *Clases, encapsulamiento, herencia, composición y persistencia*. A continuación se documenta cómo se cumple cada pilar:

### 4.1 Encapsulamiento
- Todos los atributos internos de las clases utilizan convención de visibilidad protegida/privada (`_oid`, `_texto_pregunta`, `_filas`, `_estado`).
- El acceso se realiza exclusivamente mediante propiedades `@property` de solo lectura o métodos con validación de invariantes (por ejemplo, validación de nombres no vacíos, control de fechas o cambios de estado auditados mediante `registrar_modificacion()`).

### 4.2 Herencia
Se diseñaron tres jerarquías de herencia sustantivas en el dominio:
1. **Jerarquía Base de Persistencia:**  
   `EntidadPersistente` $\rightarrow$ Heredada por todas las 10 entidades del dominio, proveyendo OID universal, versionado optimista y serialización polimórfica (`a_diccionario`).
2. **Jerarquía de Usuarios:**  
   `Usuario` $\rightarrow$ Especializada en `UsuarioGerencial` (con acceso irrestricto a márgenes y autorizaciones estratégicas) y `UsuarioOperativo` (con restricciones por sucursal).
3. **Jerarquía de Intenciones Analíticas:**  
   `Intencion` $\rightarrow$ Especializada según el tipo de análisis:
   - `IntencionRanking` (agrega parámetro de límite $N$).
   - `IntencionTendencia` (agrega parámetros de serie temporal `:desde`, `:hasta`).
   - `IntencionComparativa` (agrega validación de dos canales o dos periodos $A$ vs $B$).
   - `IntencionLiderazgo` (agrega filtro obligatorio de categoría).
   - `IntencionAgregacion` (ratios porcentuales).
4. **Jerarquía de Reglas de Validación:**  
   `ReglaValidacion` $\rightarrow$ Especializada en 6 reglas concretas de negocio y seguridad.

### 4.3 Polimorfismo
El polimorfismo se evidencia en puntos clave del diseño:
- **Patrón Strategy en `ReglaValidacion.validar(resultado, consulta)`:**  
  La clase `ConsultaAnalitica` invoca `regla.validar(...)` sobre su lista heterogénea de reglas sin conocer su tipo concreto. Cada regla concreta ejecuta su lógica particular:
  - `ReglaNoVacio` evalúa si el resultado no trajo filas y emite la advertencia de no convertir en cero.
  - `ReglaMargenValido` advierte si los productos sin costo distorsionan el margen bruto.
  - `ReglaSeguridadSQL` bloquea sentencias destructivas (`DROP`, `DELETE`) o intentos de consultar tablas operacionales `src_*`.
- **Autorización polimórfica en `Usuario.puede_ejecutar(operacion)`:**  
  Sobrescrito en `UsuarioGerencial` y `UsuarioOperativo` para aplicar reglas de acceso diferenciadas según el rol.
- **Validación de parámetros en `Intencion.validar_parametros(params)`:**  
  Cada subclase de intención impone sus propias restricciones a los filtros detectados.

### 4.4 Composición y Agregación
- **Composición Fuerte ($*--$):**  
  - Una `Sesion` compone una lista ordenada de objetos `Pregunta`. Si la sesión se destruye, sus preguntas se destruyen con ella.
  - Una `ConsultaAnalitica` compone su conjunto de objetos `ReglaValidacion`.
- **Agregación ($o--$):**  
  - Una `Sesion` agrega un `Usuario` (el usuario existe independientemente de las sesiones que abra).
  - Un `AgenteAnalitico` agrega el catálogo de `ConsultaAnalitica` y `FuenteDato`.
- **Asociación y Trazabilidad:**  
  - Cada `Pregunta` referencia a su `Intencion`, a su `ConsultaAnalitica`, al `ResultadoConsulta` devuelto y a la `RespuestaAgente` producida, consolidando el ciclo de vida completo.

---

## 5. Diagrama de Clases UML del Componente B

El modelo se encuentra formalizado en el archivo [diagrama_clases.puml](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/bdoo/diagrama_clases.puml) y renderizado en imagen de alta resolución en [diagrama_clases.png](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/bdoo/diagrama_clases.png).

```
+---------------------------------------------------------------------------------------+
|                                EntidadPersistente (Abstract)                          |
+---------------------------------------------------------------------------------------+
| # _oid: String                                                                        |
| # _fecha_creacion: String                                                             |
| # _fecha_modificacion: String                                                         |
| # _version: Integer                                                                   |
+---------------------------------------------------------------------------------------+
| + oid: String                                                                         |
| + registrar_modificacion(): void                                                      |
| + {abstract} a_diccionario(): Dict                                                    |
+---------------------------------------------------------------------------------------+
                 ^
                 |-- Usuario <|-- UsuarioGerencial, UsuarioOperativo
                 |-- Sesion (1) *-- (*) Pregunta
                 |-- Pregunta (1) --> (1) Intencion <|-- Ranking, Tendencia, Comparativa
                 |-- Pregunta (1) --> (1) ConsultaAnalitica (1) *-- (*) ReglaValidacion
                 |-- Pregunta (1) --> (1) ResultadoConsulta
                 |-- Pregunta (1) --> (1) RespuestaAgente
                 |-- ConsultaAnalitica (1) --> (1) FuenteDato
                 |-- AgenteAnalitico o-- Consultas, Intenciones, Sesiones, Fuentes
```

---

## 6. Resultados de las Pruebas Obligatorias (Sección 7)

La suite de pruebas automatizadas [probar_bdoo.py](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/bdoo/probar_bdoo.py) se ejecutó sobre la base oficial `datamart.db` (458 registros en `FactVentas`). Los 13 casos obligatorios fueron superados con éxito:

| ID | Categoría Obligatoria | Pregunta Evaluada | Consulta / Intención | Estado | Evidencia y Manejo de Límites |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-01** | Pregunta Correcta 1 | *¿Cuál fue el ingreso neto por mes?* | `Q1` / Tendencia | **APROBADO** | Responde 6 meses (Abril a Septiembre 2026). Total $40,841.65. |
| **TC-02** | Pregunta Correcta 2 | *¿Cuáles son las cinco categorías con mayor margen bruto?* | `Q2` / Ranking | **APROBADO** | Top 1 Deportes ($6,952.59). Advertencia de exclusión de sk=-1 y costos nulos. |
| **TC-03** | Pregunta Correcta 3 | *¿Qué sucursal presenta el ticket promedio más alto?* | `Q3` / Ranking | **APROBADO** | Sucursal Norte ($198.00/ticket). Excluye ticket centinela. |
| **TC-04** | Pregunta Correcta 4 | *¿Qué canal concentra el mayor valor de ventas?* | `Q5` / Ranking | **APROBADO** | Tienda Física lidera con $21,498.06. |
| **TC-05** | Pregunta Correcta 5 | *¿Qué producto lidera las ventas en la categoría Electronica?* | `Q7` / Liderazgo | **APROBADO** | Teclado Mecánico lidera con 40 unidades y $3,165.40. |
| **TC-06** | Comparación Canales | *Compare el margen de dos canales durante los últimos 3 meses.* | `Q6` / Comparativa | **APROBADO** | Compara Web vs Tienda Física mes a mes (Julio, Agosto, Septiembre). |
| **TC-07** | Comparación Periodos | *¿Qué segmento de clientes redujo más su volumen de compra?* | `Q4` / Comparativa | **APROBADO** | Segmento Ocasional presentó la mayor reducción (-10 unidades en SCD2). |
| **TC-08** | Pregunta Ambigua | *¿Cuál fue el mejor canal?* | `Q5` / Ambigüedad | **APROBADO** | `ReglaAmbiguedadCriterio`: Explicita que adoptó *Ingreso Neto* como criterio. |
| **TC-09** | Sin Periodo Explícito | *Cuáles son las categorías con mayor margen bruto* | `Q2` / Defecto | **APROBADO** | Adopta automáticamente el rango completo y añade advertencia metodológica. |
| **TC-10** | Fuera de Alcance | *¿Cuál es el salario promedio y la nómina de los empleados?* | N/A (Bloqueada) | **APROBADO** | Reconoce que no pertenece al Data Mart de Ventas y no inventa datos. |
| **TC-11** | Dimensión Inexistente | *¿Cuál fue el ingreso neto agrupado por proveedor y temperatura?* | N/A (Bloqueada) | **APROBADO** | Informa que la dimensión no existe en el esquema estrella. |
| **TC-12** | Consulta Sin Registros | *Mostrar ventas en una categoría inexistente en 2099* | `Q7` / Vacío | **APROBADO** | `ReglaNoVacio`: Notifica resultado vacío sin falsear a cero. |
| **TC-13** | Operación No Autorizada | *Ejecutar DROP TABLE FactVentas; o consultar src_ventas* | N/A (Bloqueada) | **APROBADO** | `ReglaSeguridadSQL`: Bloquea instrucciones destructivas y acceso a tablas operacionales. |

---

## 7. Entregables Generados para la BDOO (Sección 8.4)

En cumplimiento estricto del numeral 8.4 de la pauta de evaluación, se han generado los siguientes artefactos verificables:

1. **Código fuente de clases:** Paquete modular [bdoo](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/bdoo) con modelos, motor de almacenamiento y catálogo.
2. **Diagrama de clases UML:** Archivo fuente [diagrama_clases.puml](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/bdoo/diagrama_clases.puml) y renderizado [diagrama_clases.png](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/bdoo/diagrama_clases.png).
3. **Mecanismo de persistencia y justificación:** Documentado en este informe y encapsulado en [engine.py](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/bdoo/storage/engine.py).
4. **Ejemplos de objetos almacenados:** [ejemplos_objetos_almacenados.json](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/bdoo/datos/ejemplos_objetos_almacenados.json) (con muestras serializadas de los 10 objetos mínimos).
5. **Evidencia de una sesión completa:** [evidencia_sesion_completa.json](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/bdoo/datos/evidencia_sesion_completa.json) (con la traza exhaustiva de usuario, sesión, pregunta, intención, consulta, resultado y respuesta).
6. **Almacén físico BDOO:** [bdoo_almacen.json](file:///c:/Users/Prueba/Documents/universidad/materias/tepgd/Equipo04_Parcial01/bdoo/datos/bdoo_almacen.json) (con 68 objetos persistidos y distribuidos en 23 extents de clases).
