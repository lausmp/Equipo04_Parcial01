# Parcial 01 – Agente Analítico de IA con Data Mart y BDOO
**Asignatura:** Tópicos Especiales para la Gestión de Datos  
**Profesor:** Armen Djenanian  
**Equipo:** Equipo 04  

---

## 📌 Arquitectura del Sistema
El proyecto implementa la solución completa solicitada en la evaluación, dividida en tres componentes coordinados:
1. **Componente A (Data Mart Analítico):** Esquema estrella en SQLite con tabla de hechos `FactVentas` a grano de línea de ticket, dimensiones (`DimTiempo`, `DimCliente` con SCD Tipo 2, `DimProducto`, `DimCanal`, `DimSucursal`), claves sustitutas y tratamiento de nulos/desconocidos ($sk=-1$).
2. **Componente B (Base de Datos Orientada a Objetos - BDOO):** Implementación del estándar ODMG-3.0 con 10 objetos mínimos, OID universal, extents de clase, persistencia por alcance, polimorfismo y transaccionalidad ACID (`bdoo/`).
3. **Componente C (Construcción del Agente Analítico):** Motor inteligente con interpretación semántica en lenguaje natural (6.1), acceso parametrizado seguro al Data Mart (6.2), respuesta con evidencia cuantitativa y metodológica (6.3), manejo de límites/ambigüedad (6.4) y trazabilidad completa (`agente/`).

---

## 🚀 Instrucciones de Ejecución

### 1. Requisitos Previos
Tener instalado Python 3.10 o superior. Las dependencias del proyecto se instalan con:
```bash
pip install -r requirements.txt
```

### 2. Ejecución del Agente en Consola (CLI Interactivo para Defensa Oral)
Inicia la consola interactiva con recuadros, menú guiado y modo libre para responder preguntas del docente en tiempo real:
```bash
python main.py
# o alternativamente:
python -m agente.cli
```

### 3. Ejecución del Panel Web (Dashboard Flask)
Inicia el servidor web interactivo para interactuar desde el navegador con visualización de tablas, evidencia y estado de la BDOO:
```bash
python -m agente.web
```
Luego abrir en el navegador: **`http://localhost:5000`**

### 4. Ejecución de Pruebas de la BDOO y Validación
Ejecuta la suite completa de pruebas orientadas a objetos y genera los artefactos de evidencia de la BDOO (Sección 8.4):
```bash
python -m bdoo.probar_bdoo
```

### 5. Generación de Entregables Oficiales (Excel, PDF, ZIP)
Regenera la matriz de pruebas obligatorias en Excel, el PDF y el ZIP oficial de entrega:
```bash
python -m agente.exportar_entregables
```

---

## 📁 Estructura del Repositorio y Entregables

- **`main.py`**: Punto de entrada principal para la defensa oral del agente.
- **`Equipo04_Datamart.sql`**: Script unificado de creación, carga, catálogo de consultas y conciliación del Data Mart.
- **`Equipo04_Pruebas.xlsx`**: Matriz de los 13 casos de prueba obligatorios formateada en Excel (Sección 8.5).
- **`Equipo04_Pruebas.pdf`**: Matriz de casos de prueba en PDF.
- **`Equipo04_AgenteIA.zip`**: Paquete comprimido con el código fuente del agente y la BDOO para Canvas (Sección 8.3).
- **`datamart/`**: Scripts modulares del Data Mart (01 al 05) y base de datos `datamart.db`.
- **`bdoo/`**: Código fuente de la BDOO (10 clases del dominio, jerarquías de herencia, motor de persistencia y diagrama de clases).
- **`agente/`**: Interpretador sintáctico-semántico, formateador ejecutivo, servicio central, CLI y aplicación Web.
- **`informe/`**:
  - `InformeComponenteA.pdf`: Informe técnico del Data Mart analítico.
  - `InformeComponenteB.pdf`: Informe técnico y justificación teórica de la BDOO.
  - `InformeComponenteC.pdf`: Informe técnico del Agente Analítico de IA.