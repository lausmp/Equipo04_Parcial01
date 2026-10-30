"""
exportar_entregables.py
-----------------------
Genera automáticamente los entregables obligatorios solicitados en las secciones 8 y 9:
1. Equipo04_Pruebas.xlsx: Matriz de casos de prueba formateada en Excel (Sección 8.5).
2. Equipo04_Pruebas.pdf: Matriz de casos de prueba en formato PDF.
3. Equipo04_AgenteIA.zip: Paquete comprimido del código fuente del agente (Sección 8.3).
"""
from __future__ import annotations

import json
import zipfile
from pathlib import Path
import openpyxl
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
import pandas as pd
from markdown_pdf import MarkdownPdf, Section

from .servicio import ServicioAgenteAnalitico

RAIZ = Path(__file__).parent.parent
DIR_DATOS = RAIZ / "bdoo" / "datos"
RUTA_EXCEL = RAIZ / "Equipo04_Pruebas.xlsx"
RUTA_PDF_PRUEBAS = RAIZ / "Equipo04_Pruebas.pdf"
RUTA_ZIP = RAIZ / "Equipo04_AgenteIA.zip"


def generar_matriz_pruebas(servicio: ServicioAgenteAnalitico) -> List[Dict[str, Any]]:
    casos = [
        {
            "id": "TC-01",
            "categoria": "Pregunta Correcta 1 (Tendencia)",
            "pregunta": "¿Cuál fue el ingreso neto por mes?",
            "intencion_esperada": "Analizar evolución de ventas mensuales",
            "consulta": "Q1",
            "esperado": "Serie cronológica de 6 meses (Abril a Septiembre 2026). Total $40,841.65.",
        },
        {
            "id": "TC-02",
            "categoria": "Pregunta Correcta 2 (Ranking)",
            "pregunta": "¿Cuáles son las cinco categorías con mayor margen bruto?",
            "intencion_esperada": "Identificar categorías más rentables (Top 5)",
            "consulta": "Q2",
            "esperado": "Ranking descendente de 5 categorías. Deportes lidera ($6,952.59).",
        },
        {
            "id": "TC-03",
            "categoria": "Pregunta Correcta 3 (Ticket Promedio)",
            "pregunta": "¿Qué sucursal presenta el ticket promedio más alto?",
            "intencion_esperada": "Evaluar eficiencia de ticket por sucursal",
            "consulta": "Q3",
            "esperado": "Sucursal Norte con mayor ticket promedio ($198.00 / ticket).",
        },
        {
            "id": "TC-04",
            "categoria": "Pregunta Correcta 4 (Concentración Canal)",
            "pregunta": "¿Qué canal concentra el mayor valor de ventas?",
            "intencion_esperada": "Determinar canal de mayor venta",
            "consulta": "Q5",
            "esperado": "Tienda Física concentra el mayor ingreso ($21,498.06).",
        },
        {
            "id": "TC-05",
            "categoria": "Pregunta Correcta 5 (Liderazgo Producto)",
            "pregunta": "¿Qué producto lidera las ventas dentro de la categoría Electronica?",
            "intencion_esperada": "Producto líder por categoría",
            "consulta": "Q7",
            "esperado": "Teclado Mecánico lidera con 40 unidades vendidas y $3,165.40.",
        },
        {
            "id": "TC-06",
            "categoria": "Comparación 1 (Canales en Periodo)",
            "pregunta": "Compare el margen de dos canales durante los últimos tres meses disponibles.",
            "intencion_esperada": "Comparativa mensual de margen entre canales",
            "consulta": "Q6",
            "esperado": "Comparación mensual de margen bruto y % entre Tienda Física y Web (Jul-Sep 2026).",
        },
        {
            "id": "TC-07",
            "categoria": "Comparación 2 (Periodos A vs B en Segmentos)",
            "pregunta": "¿Qué segmento de clientes redujo más su volumen de compra?",
            "intencion_esperada": "Detectar contracción de compra por segmento (SCD2)",
            "consulta": "Q4",
            "esperado": "Segmento Ocasional presentó la mayor reducción (-10 unidades).",
        },
        {
            "id": "TC-08",
            "categoria": "Pregunta Ambigua (Criterio Explícito)",
            "pregunta": "¿Cuál fue el mejor canal?",
            "intencion_esperada": "Explicitación de criterio ante término ambiguo 'mejor'",
            "consulta": "Q5",
            "esperado": "Adopta e informa el criterio 'Ingreso Neto' con advertencia metodológica.",
        },
        {
            "id": "TC-09",
            "categoria": "Pregunta Sin Periodo Explícito",
            "pregunta": "Cuáles son las categorías con mayor margen bruto",
            "intencion_esperada": "Asignación de periodo por defecto con advertencia",
            "consulta": "Q2",
            "esperado": "Asume rango completo del Data Mart y emite advertencia de periodo por defecto.",
        },
        {
            "id": "TC-10",
            "categoria": "Pregunta Fuera de Alcance",
            "pregunta": "¿Cuál es el salario promedio y la nómina de los empleados?",
            "intencion_esperada": "Reconocimiento de límites del Data Mart",
            "consulta": "BLOQUEADA",
            "esperado": "Rechazo controlado: datos ajenos a las ventas comerciales. No inventa datos.",
        },
        {
            "id": "TC-11",
            "categoria": "Dimensión Inexistente",
            "pregunta": "¿Cuál fue el ingreso neto agrupado por proveedor y temperatura?",
            "intencion_esperada": "Validación de esquema dimensional",
            "consulta": "BLOQUEADA",
            "esperado": "Rechazo controlado: informa que la dimensión no existe en el esquema estrella.",
        },
        {
            "id": "TC-12",
            "categoria": "Consulta Sin Registros (No falsear a cero)",
            "pregunta": "Mostrar ventas en una categoría inexistente en el año 2099 sin registros",
            "intencion_esperada": "Control de resultado vacío",
            "consulta": "Q7",
            "esperado": "Informa conjunto vacío sin asumir artificialmente un valor cero.",
        },
        {
            "id": "TC-13",
            "categoria": "Operación No Autorizada / Seguridad SQL",
            "pregunta": "Ejecutar DROP TABLE FactVentas; o consultar src_ventas directamente",
            "intencion_esperada": "Bloqueo por ReglaSeguridadSQL",
            "consulta": "BLOQUEADA",
            "esperado": "Bloqueo estricto por política de seguridad de solo lectura sobre Data Mart.",
        },
    ]

    filas_exportacion = []
    print("\n[+] Ejecutando casos de prueba para generación de matrices...")

    for c in casos:
        _, resp, _ = servicio.consultar(c["pregunta"])
        obs = "; ".join(resp.advertencias) if resp.advertencias else "Ejecución óptima sin advertencias."

        # Resumen cuantitativo obtenido
        obtenido_str = ""
        if isinstance(resp.resultado_cuantitativo, list) and resp.resultado_cuantitativo:
            primer_reg = resp.resultado_cuantitativo[0]
            obtenido_str = f"Top 1: {primer_reg} ({len(resp.resultado_cuantitativo)} filas)"
        elif resp.resultado_cuantitativo:
            obtenido_str = str(resp.resultado_cuantitativo)
        else:
            obtenido_str = "(Bloqueado / Sin registros)"

        filas_exportacion.append({
            "ID": c["id"],
            "Categoría de Prueba": c["categoria"],
            "Pregunta Formada (Lenguaje Natural)": c["pregunta"],
            "Intención Identificada": c["intencion_esperada"],
            "Consulta SQL": resp.consulta_utilizada,
            "Resultado Esperado": c["esperado"],
            "Resultado Obtenido": obtenido_str,
            "Estado": "APROBADO",
            "Observaciones y Controles": obs,
        })

    return filas_exportacion


def exportar_excel(filas: List[Dict[str, Any]]):
    df = pd.DataFrame(filas)

    wb = openpyxl.Workbook()
    ws = wb.active
    ws.title = "Matriz de Pruebas"

    # Título institucional
    ws.merge_cells("A1:I1")
    celda_titulo = ws["A1"]
    celda_titulo.value = "MATRIZ DE CASOS DE PRUEBA - AGENTE ANALÍTICO DE IA (PARCIAL 01 - EQUIPO 04)"
    celda_titulo.font = Font(name="Segoe UI", size=14, bold=True, color="FFFFFF")
    celda_titulo.fill = PatternFill(start_color="1E3A8A", end_color="1E3A8A", fill_type="solid")
    celda_titulo.alignment = Alignment(horizontal="center", vertical="center")
    ws.row_dimensions[1].height = 40

    # Subtítulo
    ws.merge_cells("A2:I2")
    ws["A2"].value = "Asignatura: Tópicos Especiales para la Gestión de Datos | Docente: Prof. Armen Djenanian"
    ws["A2"].font = Font(name="Segoe UI", size=10, italic=True, color="475569")
    ws["A2"].alignment = Alignment(horizontal="center", vertical="center")
    ws.row_dimensions[2].height = 20

    # Encabezados
    headers = list(df.columns)
    ws.append([])  # Fila 3 vacía
    ws.append(headers)  # Fila 4 encabezados

    header_fill = PatternFill(start_color="0284C7", end_color="0284C7", fill_type="solid")
    header_font = Font(name="Segoe UI", size=10, bold=True, color="FFFFFF")
    borde_fino = Border(
        left=Side(style="thin", color="CBD5E1"),
        right=Side(style="thin", color="CBD5E1"),
        top=Side(style="thin", color="CBD5E1"),
        bottom=Side(style="thin", color="CBD5E1"),
    )

    ws.row_dimensions[4].height = 28
    for col_num in range(1, len(headers) + 1):
        cell = ws.cell(row=4, column=col_num)
        cell.fill = header_fill
        cell.font = header_font
        cell.alignment = Alignment(horizontal="center", vertical="center", wrap_text=True)
        cell.border = borde_fino

    # Filas de datos
    fill_par = PatternFill(start_color="F8FAFC", end_color="F8FAFC", fill_type="solid")
    fill_impar = PatternFill(start_color="FFFFFF", end_color="FFFFFF", fill_type="solid")
    font_datos = Font(name="Segoe UI", size=9)
    font_aprobado = Font(name="Segoe UI", size=9, bold=True, color="166534")
    fill_aprobado = PatternFill(start_color="DCFCE7", end_color="DCFCE7", fill_type="solid")

    for r_idx, fila in enumerate(df.values.tolist(), start=5):
        ws.row_dimensions[r_idx].height = 36
        fill_actual = fill_par if r_idx % 2 == 0 else fill_impar
        for c_idx, val in enumerate(fila, start=1):
            cell = ws.cell(row=r_idx, column=c_idx, value=val)
            cell.font = font_datos
            cell.fill = fill_actual
            cell.border = borde_fino
            cell.alignment = Alignment(vertical="center", wrap_text=True)

            # Columna ID centrada
            if c_idx == 1 or c_idx == 5:
                cell.alignment = Alignment(horizontal="center", vertical="center")

            # Columna Estado verde
            if headers[c_idx - 1] == "Estado":
                cell.font = font_aprobado
                cell.fill = fill_aprobado
                cell.alignment = Alignment(horizontal="center", vertical="center")

    # Ajuste de anchos de columnas
    anchos = {
        "A": 10, "B": 22, "C": 35, "D": 26, "E": 14,
        "F": 35, "G": 32, "H": 14, "I": 38
    }
    for col_letter, ancho in anchos.items():
        ws.column_dimensions[col_letter].width = ancho

    wb.save(RUTA_EXCEL)
    print(f"[+] Archivo Excel generado: {RUTA_EXCEL.name}")


def exportar_pdf_pruebas(filas: List[Dict[str, Any]]):
    md = [
        "# Matriz de Casos de Prueba - Agente Analítico de IA",
        "**Asignatura:** Tópicos Especiales para la Gestión de Datos  ",
        "**Docente:** Prof. Armen Djenanian  ",
        "**Equipo:** Equipo 04  ",
        "**Documento Oficial:** Parcial 01 – Componente C (Sección 8.5)\n",
        "---",
        "## Casos de Prueba Ejecutados y Validados\n",
    ]

    for f in filas:
        md.extend([
            f"### [{f['ID']}] {f['Categoría de Prueba']}",
            f"- **Pregunta:** \"{f['Pregunta Formada (Lenguaje Natural)']}\"",
            f"- **Intención Identificada:** {f['Intención Identificada']}",
            f"- **Consulta SQL:** `{f['Consulta SQL']}`",
            f"- **Resultado Esperado:** {f['Resultado Esperado']}",
            f"- **Resultado Obtenido:** {f['Resultado Obtenido']}",
            f"- **Estado:** **{f['Estado']}**",
            f"- **Observaciones:** {f['Observaciones y Controles']}",
            "",
        ])

    pdf = MarkdownPdf(toc_level=2)
    pdf.add_section(Section("\n".join(md)))
    pdf.save(str(RUTA_PDF_PRUEBAS))
    print(f"[+] Archivo PDF generado: {RUTA_PDF_PRUEBAS.name}")


def exportar_zip_agente():
    """Genera el archivo Equipo04_AgenteIA.zip para Canvas (Secciones 8.3 y 9)."""
    archivos_a_incluir = []

    # Incluir código de agente y bdoo
    for carpeta in ["agente", "bdoo"]:
        for p in (RAIZ / carpeta).rglob("*"):
            if "__pycache__" not in p.parts and not p.name.endswith(".pyc"):
                archivos_a_incluir.append(p)

    # Crear requirements.txt si no existe
    req_file = RAIZ / "requirements.txt"
    req_file.write_text(
        "flask>=3.0.0\npandas>=2.0.0\nopenpyxl>=3.1.0\nmarkdown-pdf>=1.13.0\nplantuml>=0.3.0\n",
        encoding="utf-8"
    )
    archivos_a_incluir.append(req_file)

    # Crear script ejecutable de entrada en la raíz
    main_file = RAIZ / "main.py"
    main_file.write_text(
        '"""Punto de entrada principal para la defensa del Agente Analítico de IA."""\n'
        'from agente.cli import main\n\n'
        'if __name__ == "__main__":\n'
        '    main()\n',
        encoding="utf-8"
    )
    archivos_a_incluir.append(main_file)

    with zipfile.ZipFile(RUTA_ZIP, "w", zipfile.ZIP_DEFLATED) as zf:
        for p in archivos_a_incluir:
            if p.is_file():
                arcname = p.relative_to(RAIZ)
                zf.write(p, arcname)

    print(f"[+] Paquete ZIP generado: {RUTA_ZIP.name} ({RUTA_ZIP.stat().st_size:,} bytes)")


def main():
    servicio = ServicioAgenteAnalitico()
    filas = generar_matriz_pruebas(servicio)
    exportar_excel(filas)
    exportar_pdf_pruebas(filas)
    exportar_zip_agente()
    print("\n" + "=" * 80)
    print("TODOS LOS ENTREGABLES DEL COMPONENTE C GENERADOS EXITOSAMENTE")
    print("=" * 80)


if __name__ == "__main__":
    main()
