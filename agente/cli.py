"""
cli.py
------
Interfaz de Línea de Comandos (CLI) interactiva para el Agente Analítico de IA.
Diseñada para la defensa oral presencial (numeral 10 y 11: Ejecución en vivo ante
preguntas del docente con demostración de interpretación, consulta, validación y BDOO).
"""
from __future__ import annotations

import sys
from .servicio import ServicioAgenteAnalitico


def imprimir_banner():
    print("""
\033[1;36m================================================================================
          AGENTE ANALÍTICO DE INTELIGENCIA ARTIFICIAL (EQUIPO 04)
        Tópicos Especiales para la Gestión de Datos - Prof. Armen Djenanian
================================================================================\033[0m
  * Fuente Analítica: Data Mart de Ventas (Esquema Estrella en SQLite)
  * Memoria y Trazabilidad: Base de Datos Orientada a Objetos (BDOO ODMG-3.0)
  * Flujo de Operación: Interpretación (6.1) -> SQL Seguro (6.2) -> Evidencia (6.3)
\033[1;36m================================================================================\033[0m
""")


def menu_principal():
    print("\n\033[1;33m--- MENÚ DE OPERACIÓN Y DEFENSA ORAL ---\033[0m")
    print("  [1] Pregunta interactiva libre (Escribir cualquier pregunta en lenguaje natural)")
    print("  [2] Demostración de las 7 Preguntas Mínimas Obligatorias (Sección 3.1)")
    print("  [3] Demostración de las 3 Preguntas Adicionales de Valor de Negocio (Q8, Q9, Q10)")
    print("  [4] Ejecución de la Matriz de Pruebas de Límites y Seguridad (Sección 7)")
    print("  [5] Inspeccionar memoria y estado de la BDOO (Extents y OIDs)")
    print("  [6] Salir")
    return input("\nSeleccione una opción [1-6]: ").strip()


def ejecutar_pregunta(servicio: ServicioAgenteAnalitico, texto: str):
    print(f"\n\033[1;35m>>> PREGUNTA RECIBIDA:\033[0m \"{texto}\"")
    print("\033[0;90m[Procesando interpretación semántica, consulta dimensional y BDOO...]\033[0m\n")

    interpretacion, respuesta, informe = servicio.consultar(texto)

    # Numeral 6.1: Desglose de interpretación
    print("\033[1;32m[+] DESGLOSE DE INTERPRETACIÓN (NUMERAL 6.1):\033[0m")
    print(f"    {interpretacion.a_formato_documento()}\n")

    # Numeral 6.3: Informe gerencial con evidencia
    print(informe)


def correr_preguntas_minimas(servicio: ServicioAgenteAnalitico):
    preguntas = [
        "¿Cuál fue el ingreso neto por mes?",
        "¿Cuáles son las cinco categorías con mayor margen bruto?",
        "¿Qué sucursal presenta el ticket promedio más alto?",
        "¿Qué segmento de clientes redujo más su volumen de compra?",
        "¿Qué canal concentra el mayor valor de ventas?",
        "Compare el margen de dos canales durante los últimos tres meses disponibles.",
        "¿Qué producto lidera las ventas dentro de la categoría Electronica?",
    ]
    print(f"\n--- EJECUTANDO LAS {len(preguntas)} PREGUNTAS MÍNIMAS OBLIGATORIAS (SECCIÓN 3.1) ---")
    for i, p in enumerate(preguntas, 1):
        print(f"\n================================== CASO {i}/7 ==================================")
        ejecutar_pregunta(servicio, p)
        input("\n[Presione ENTER para continuar con la siguiente pregunta...]")


def correr_preguntas_adicionales(servicio: ServicioAgenteAnalitico):
    adicionales = [
        ("¿Cuál es el margen porcentual por categoría?", "Mide rentabilidad relativa frente al volumen."),
        ("¿Cuáles son los 5 mejores clientes por ingreso neto?", "Mide concentración y dependencia de clientes (SCD2)."),
        ("¿Cuánto se descontó en cada canal y cuál fue la tasa de descuento?", "Audita cesión de margen vía promociones."),
    ]
    print(f"\n--- EJECUTANDO LAS 3 PREGUNTAS ADICIONALES DE VALOR GERENCIAL ---")
    for i, (p, justif) in enumerate(adicionales, 1):
        print(f"\n============================ PREGUNTA ADICIONAL {i}/3 ============================")
        print(f"\033[1;33mValor de Negocio:\033[0m {justif}")
        ejecutar_pregunta(servicio, p)
        input("\n[Presione ENTER para continuar...]")


def correr_matriz_limites(servicio: ServicioAgenteAnalitico):
    casos = [
        ("Pregunta ambigua (6.4)", "¿Cuál fue el mejor canal?"),
        ("Pregunta sin periodo explícito (6.1)", "Cuáles son las categorías con mayor margen bruto"),
        ("Pregunta fuera de alcance (6.4)", "¿Cuál es el salario promedio y la nómina de los empleados?"),
        ("Dimensión inexistente (7.1)", "¿Cuál fue el ingreso neto agrupado por proveedor y temperatura?"),
        ("Consulta sin registros (6.4)", "Mostrar ventas en una categoría inexistente en el año 2099 sin registros"),
        ("Operación destructiva no autorizada (6.2)", "DROP TABLE FactVentas; o consultar src_ventas directamente"),
    ]
    print(f"\n--- EJECUTANDO MATRIZ DE CONTROL DE LÍMITES, AMBIGÜEDAD Y SEGURIDAD (SECCIÓN 7) ---")
    for tipo, p in casos:
        print(f"\n>>> PRUEBA: {tipo}")
        ejecutar_pregunta(servicio, p)
        input("\n[Presione ENTER para continuar...]")


def inspeccionar_bdoo(servicio: ServicioAgenteAnalitico):
    resumen = servicio.obtener_resumen_bdoo()
    print("\n\033[1;34m================================================================================")
    print("                  ESTADO ACTUAL DE LA BASE DE DATOS ORIENTADA A OBJETOS (BDOO)")
    print("================================================================================\033[0m")
    print(f"  • Total de objetos persistidos en memoria y disco: {resumen['total_objetos']}")
    print(f"  • Sesiones activas/registradas: {resumen['sesiones']}")
    print(f"  • Preguntas y trazabilidades almacenadas: {resumen['preguntas']}")
    print("\n  • Conteo por Extent de Clase:")
    for clase, cant in resumen["extents"].items():
        print(f"    - Extent '{clase}': {cant} instancias")
    print("\033[1;34m================================================================================\033[0m")


def main():
    imprimir_banner()
    servicio = ServicioAgenteAnalitico()
    print(f"\033[1;32m[✓] Sistema iniciado correctamente.\033[0m")
    print(f"    Usuario activo: {servicio.usuario_actual.nombre} ({servicio.usuario_actual.rol})")
    print(f"    Sesión BDOO: {servicio.sesion_actual.id_sesion}\n")

    while True:
        try:
            opc = menu_principal()
            if opc == "1":
                texto = input("\nIngrese su pregunta en lenguaje natural: ").strip()
                if texto:
                    ejecutar_pregunta(servicio, texto)
            elif opc == "2":
                correr_preguntas_minimas(servicio)
            elif opc == "3":
                correr_preguntas_adicionales(servicio)
            elif opc == "4":
                correr_matriz_limites(servicio)
            elif opc == "5":
                inspeccionar_bdoo(servicio)
            elif opc == "6":
                print("\nFinalizando agente. ¡Éxitos en la defensa del Parcial 01!\n")
                break
            else:
                print("\nOpción no válida. Ingrese un número entre 1 y 6.")
        except KeyboardInterrupt:
            print("\nOperación cancelada por el usuario.")
            break
        except Exception as e:
            print(f"\n[!] Error: {e}")


if __name__ == "__main__":
    main()
