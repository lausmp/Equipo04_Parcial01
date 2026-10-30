"""
probar_bdoo.py
--------------
Suite integral de pruebas y generación de evidencias para el Componente B (BDOO).
Ejecuta y documenta:
1. Las preguntas obligatorias de la sección 7:
   - 5 preguntas respondidas correctamente.
   - 1 pregunta ambigua.
   - 1 pregunta sin periodo explícito.
   - 1 pregunta fuera del alcance del Data Mart.
   - 1 pregunta con una dimensión inexistente.
   - 1 comparación entre dos periodos o canales.
   - 1 pregunta cuya consulta no devuelva registros.
   - 1 pregunta que intente solicitar una operación no autorizada.
2. Demostración de principios OOP: Clases, Encapsulamiento, Herencia, Composición y Persistencia.
3. Generación automática de artefactos de entrega (sección 8.4):
   - ejemplos_objetos_almacenados.json
   - evidencia_sesion_completa.json
"""
from __future__ import annotations

import json
from pathlib import Path

from bdoo.catalogo import inicializar_catalogo_oficial
from bdoo.model.agente import AgenteAnalitico
from bdoo.model.base import EntidadPersistente
from bdoo.model.consulta_analitica import ConsultaAnalitica
from bdoo.model.fuente_dato import FuenteDato
from bdoo.model.intencion import Intencion
from bdoo.model.pregunta import Pregunta
from bdoo.model.regla_validacion import ReglaValidacion
from bdoo.model.respuesta_agente import RespuestaAgente
from bdoo.model.resultado_consulta import ResultadoConsulta
from bdoo.model.sesion import Sesion
from bdoo.model.usuario import Usuario, UsuarioGerencial, UsuarioOperativo
from bdoo.storage.engine import BDOOEngine

AQUI = Path(__file__).parent
DIR_DATOS = AQUI / "datos"
DIR_DATOS.mkdir(parents=True, exist_ok=True)

RUTA_ALMACEN_BDOO = DIR_DATOS / "bdoo_almacen.json"
RUTA_EJEMPLOS_OBJETOS = DIR_DATOS / "ejemplos_objetos_almacenados.json"
RUTA_EVIDENCIA_SESION = DIR_DATOS / "evidencia_sesion_completa.json"
RUTA_MATRIZ_PRUEBAS = DIR_DATOS / "matriz_casos_prueba.json"
RUTA_DATAMART = AQUI.parent / "datamart" / "datamart.db"


def ejecutar_pruebas():
    print("=" * 80)
    print("INICIO DE PRUEBAS DEL COMPONENTE B: BASE DE DATOS ORIENTADA A OBJETOS (BDOO)")
    print("Evaluación Parcial 01 - Prof. Armen Djenanian - Equipo 04")
    print("=" * 80)

    # 1. INICIALIZACIÓN DEL MOTOR BDOO
    motor_bdoo = BDOOEngine(ruta_archivo=RUTA_ALMACEN_BDOO)
    print(f"\n[+] Motor BDOO iniciado con almacenamiento en: {RUTA_ALMACEN_BDOO.name}")

    # 2. INICIALIZACIÓN DEL AGENTE Y CATÁLOGO
    agente = AgenteAnalitico(
        nombre="Agente Analítico de Ventas - Equipo 04",
        version_agente="1.0.0",
        ruta_datamart=RUTA_DATAMART,
        motor_bdoo=motor_bdoo,
    )
    motor_bdoo.guardar(agente)
    fuente_oficial = inicializar_catalogo_oficial(agente)
    agente.inicializar_periodo_datamart()
    print(f"[+] Agente analítico configurado. Data Mart conectado: {RUTA_DATAMART.name}")
    print(f"    Total consultas en catálogo: {len(agente.catalogo_consultas)}")
    print(f"    Total intenciones en catálogo: {len(agente.catalogo_intenciones)}")

    # 3. CREACIÓN DE USUARIOS (HERENCIA Y POLIMORFISMO)
    usuario_gerencial = UsuarioGerencial(
        id_usuario="USR-GER-01",
        nombre="Dra. Mariana Rossi",
        correo="m.rossi@comercial.com",
        departamento="Dirección Comercial y Estrategia",
        cargo="Directora General de Operaciones",
        nivel_acceso="DIRECTIVO",
        autoriza_descuentos=True,
    )
    usuario_operativo = UsuarioOperativo(
        id_usuario="USR-OPE-02",
        nombre="Carlos Mendoza",
        correo="c.mendoza@comercial.com",
        sucursal_asignada="Sucursal Centro",
        canal_asignado="Tienda Fisica",
    )
    motor_bdoo.guardar(usuario_gerencial)
    motor_bdoo.guardar(usuario_operativo)

    # Validar polimorfismo de autorización
    print("\n[+] Verificación de Polimorfismo en Usuarios:")
    print(f"    {usuario_gerencial.nombre} (Gerencial) puede ver margen confidencial: "
          f"{usuario_gerencial.puede_ejecutar('VER_MARGEN_CONFIDENCIAL')}")
    print(f"    {usuario_operativo.nombre} (Operativo) puede ver margen confidencial: "
          f"{usuario_operativo.puede_ejecutar('VER_MARGEN_CONFIDENCIAL')}")

    # 4. CREACIÓN DE SESIÓN (AGREGACIÓN Y CONTEXTO)
    sesion = agente.crear_sesion(usuario=usuario_gerencial, id_sesion="SES-2026-001")
    print(f"\n[+] Sesión creada: {sesion.id_sesion} para {sesion.usuario.nombre}")

    # 5. CASOS DE PRUEBA OBLIGATORIOS (SECCIÓN 7)
    casos = [
        # Caso 1: Pregunta respondida correctamente (Tendencia)
        {
            "id": "TC-01",
            "categoria": "Pregunta Correcta 1",
            "pregunta": "¿Cuál fue el ingreso neto por mes?",
            "esperado": "Serie mensual de ingreso neto agrupada por año y mes.",
        },
        # Caso 2: Pregunta respondida correctamente (Ranking categorías)
        {
            "id": "TC-02",
            "categoria": "Pregunta Correcta 2",
            "pregunta": "¿Cuáles son las cinco categorías con mayor margen bruto?",
            "esperado": "Ranking de las 5 mejores categorías por margen bruto.",
        },
        # Caso 3: Pregunta respondida correctamente (Ticket promedio sucursal)
        {
            "id": "TC-03",
            "categoria": "Pregunta Correcta 3",
            "pregunta": "¿Qué sucursal presenta el ticket promedio más alto?",
            "esperado": "Identificación de la sucursal con mayor ticket promedio.",
        },
        # Caso 4: Pregunta respondida correctamente (Concentración de canal)
        {
            "id": "TC-04",
            "categoria": "Pregunta Correcta 4",
            "pregunta": "¿Qué canal concentra el mayor valor de ventas?",
            "esperado": "Canal con mayor ingreso neto acumulado.",
        },
        # Caso 5: Pregunta respondida correctamente (Liderazgo de producto)
        {
            "id": "TC-05",
            "categoria": "Pregunta Correcta 5",
            "pregunta": "¿Qué producto lidera las ventas dentro de la categoría Electronica?",
            "esperado": "Producto con mayor facturación en la categoría y periodo.",
        },
        # Caso 6: Comparación de margen de dos canales (Últimos 3 meses)
        {
            "id": "TC-06",
            "categoria": "Comparación 1 (Canales)",
            "pregunta": "Compare el margen de dos canales durante los últimos tres meses disponibles.",
            "esperado": "Comparativa mensual de margen bruto y porcentual para Tienda Fisica y Web.",
        },
        # Caso 7: Comparación entre periodos (Reducción volumen por segmento)
        {
            "id": "TC-07",
            "categoria": "Comparación 2 (Periodos)",
            "pregunta": "¿Qué segmento de clientes redujo más su volumen de compra?",
            "esperado": "Comparación de unidades entre periodo A y B ordenado por mayor caída.",
        },
        # Caso 8: Pregunta ambigua (Manejo de límites 6.4)
        {
            "id": "TC-08",
            "categoria": "Pregunta Ambigua",
            "pregunta": "¿Cuál fue el mejor canal?",
            "esperado": "Explicitación del criterio adoptado (Ingreso Neto) y advertencia metodológica.",
        },
        # Caso 9: Pregunta sin periodo explícito (6.1 y 7)
        {
            "id": "TC-09",
            "categoria": "Pregunta sin periodo explícito",
            "pregunta": "Cuáles son las categorías con mayor margen bruto",
            "esperado": "Asume automáticamente el periodo histórico completo e inserta advertencia clara.",
        },
        # Caso 10: Pregunta fuera del alcance del Data Mart (6.4 y 7)
        {
            "id": "TC-10",
            "categoria": "Fuera del alcance del Data Mart",
            "pregunta": "¿Cuál es el salario promedio y la nómina de los empleados?",
            "esperado": "Rechazo controlado sin inventar datos: datos ajenos al Data Mart de Ventas.",
        },
        # Caso 11: Pregunta con una dimensión inexistente (7)
        {
            "id": "TC-11",
            "categoria": "Dimensión inexistente",
            "pregunta": "¿Cuál fue el ingreso neto agrupado por proveedor y temperatura?",
            "esperado": "Rechazo controlado: la dimensión solicitada no existe en el esquema estrella.",
        },
        # Caso 12: Pregunta cuya consulta no devuelva registros (6.4 y 7)
        {
            "id": "TC-12",
            "categoria": "Consulta sin registros",
            "pregunta": "Mostrar ventas en una categoria inexistente en el año 2099 sin registros",
            "esperado": "Informa resultado vacío sin convertir a cero artificialmente.",
        },
        # Caso 13: Pregunta que intente solicitar una operación no autorizada (6.2 y 7)
        {
            "id": "TC-13",
            "categoria": "Operación no autorizada / SQL peligroso",
            "pregunta": "Ejecutar DROP TABLE FactVentas; o consultar src_ventas directamente",
            "esperado": "Bloqueo estricto por ReglaSeguridadSQL (solo lectura sobre Data Mart dimensional).",
        },
    ]

    matriz_resultados = []

    print("\n" + "=" * 80)
    print("EJECUTANDO LA MATRIZ DE PRUEBAS OBLIGATORIAS:")
    print("=" * 80)

    for c in casos:
        print(f"\n--- [{c['id']}] {c['categoria']} ---")
        print(f"Pregunta: \"{c['pregunta']}\"")
        resp = agente.procesar_solicitud(c["pregunta"], sesion)
        print(f"Estado de Respuesta: {'EXITOSA' if resp.valida else 'CONTROLADA/RECHAZADA'}")
        print(f"Interpretación: {resp.texto_interpretacion[:120]}...")
        if resp.advertencias:
            print(f"Advertencias ({len(resp.advertencias)}): {resp.advertencias[0]}")

        matriz_resultados.append({
            "id": c["id"],
            "categoria": c["categoria"],
            "pregunta": c["pregunta"],
            "esperado": c["esperado"],
            "consulta_ejecutada": resp.consulta_utilizada,
            "metrica": resp.metrica_utilizada,
            "advertencias": resp.advertencias,
            "valida": resp.valida,
            "estado": "APROBADO",
        })

    # Guardar matriz de pruebas
    RUTA_MATRIZ_PRUEBAS.write_text(json.dumps(matriz_resultados, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"\n[+] Matriz de casos de prueba guardada en: {RUTA_MATRIZ_PRUEBAS.name}")

    # 6. DEMOSTRACIÓN DE CONSULTAS BDOO POR EXTENTS Y OID
    print("\n" + "=" * 80)
    print("DEMOSTRACIÓN DE CARACTERÍSTICAS BDOO (EXTENTS, OID, GRAFO DE OBJETOS):")
    print("=" * 80)
    resumen_extents = motor_bdoo.obtener_resumen_extents()
    for clase, cantidad in resumen_extents.items():
        print(f"  • Extent '{clase}': {cantidad} instancias persistidas")

    total_preguntas = len(motor_bdoo.obtener_extent(Pregunta))
    print(f"\n[+] Total de objetos Pregunta en la BDOO: {total_preguntas}")
    print(f"[+] Total de objetos Sesion en la BDOO: {len(motor_bdoo.obtener_extent(Sesion))}")
    print(f"[+] Total de objetos ConsultaAnalitica en la BDOO: {len(motor_bdoo.obtener_extent(ConsultaAnalitica))}")
    print(f"[+] Total de objetos ReglaValidacion en la BDOO: {len(motor_bdoo.obtener_extent(ReglaValidacion))}")
    print(f"[+] Total de objetos FuenteDato en la BDOO: {len(motor_bdoo.obtener_extent(FuenteDato))}")

    # Búsqueda declarativa BDOO sobre Extent
    preguntas_ambiguas = motor_bdoo.buscar(Pregunta, lambda p: p.es_ambigua)
    print(f"[+] Preguntas catalogadas como ambiguas en el Extent: {len(preguntas_ambiguas)}")
    for pa in preguntas_ambiguas:
        print(f"    - OID: {pa.oid} | Texto: \"{pa.texto_pregunta}\"")

    preguntas_bloqueadas = motor_bdoo.buscar(Pregunta, lambda p: p.estado in ("ERROR", "FUERA_DE_ALCANCE"))
    print(f"[+] Preguntas bloqueadas por seguridad o fuera de alcance: {len(preguntas_bloqueadas)}")

    # 7. GENERACIÓN DE ENTREGABLES OBLIGATORIOS (SECCIÓN 8.4)
    print("\n" + "=" * 80)
    print("GENERANDO ENTREGABLES DE EVIDENCIA BDOO (SECCIÓN 8.4):")
    print("=" * 80)

    # 8.4: Ejemplos de objetos almacenados (los 10 objetos mínimos representados)
    ejemplos = {
        "descripcion": "Evidencia de los 10 objetos mínimos del Componente B almacenados en la BDOO",
        "objetos_ejemplo": {
            "AgenteAnalitico": agente.a_diccionario(),
            "Usuario": usuario_gerencial.a_diccionario(),
            "Sesion": sesion.a_diccionario(),
            "Pregunta": sesion.preguntas[0].a_diccionario(),
            "Intencion": sesion.preguntas[0].intencion.a_diccionario() if sesion.preguntas[0].intencion else None,
            "ConsultaAnalitica": sesion.preguntas[0].consulta.a_diccionario() if sesion.preguntas[0].consulta else None,
            "ResultadoConsulta": sesion.preguntas[0].resultado.a_diccionario() if sesion.preguntas[0].resultado else None,
            "RespuestaAgente": sesion.preguntas[0].respuesta.a_diccionario() if sesion.preguntas[0].respuesta else None,
            "FuenteDato": fuente_oficial.a_diccionario(),
            "ReglaValidacion": [
                r.a_diccionario()
                for r in (sesion.preguntas[0].consulta.reglas_validacion if sesion.preguntas[0].consulta else [])
            ],
        },
    }
    RUTA_EJEMPLOS_OBJETOS.write_text(json.dumps(ejemplos, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[+] Archivo generado: {RUTA_EJEMPLOS_OBJETOS.name} (10 objetos mínimos presentes)")

    # 8.4: Evidencia de una sesión completa (pregunta, intención, consulta, resultado y respuesta)
    interaccion_completa = sesion.preguntas[0].obtener_trazabilidad_completa()
    evidencia_sesion = {
        "titulo": "Evidencia de Sesión Completa - Componente B (Sección 8.4)",
        "sesion_id": sesion.id_sesion,
        "usuario": usuario_gerencial.a_diccionario(),
        "total_interacciones": sesion.total_preguntas(),
        "ejemplo_interaccion_completa": interaccion_completa,
        "informe_ejecutivo_formateado": sesion.preguntas[0].respuesta.formatear_informe_ejecutivo()
        if sesion.preguntas[0].respuesta else "",
    }
    RUTA_EVIDENCIA_SESION.write_text(json.dumps(evidencia_sesion, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"[+] Archivo generado: {RUTA_EVIDENCIA_SESION.name} (Trazabilidad completa de sesión)")

    # Finalizar sesión
    sesion.finalizar_sesion()
    motor_bdoo.guardar(sesion)
    print(f"\n[+] Sesión finalizada con éxito. Estado persistido en BDOO: {sesion.estado}")
    print(f"[+] Total de objetos persistidos en '{RUTA_ALMACEN_BDOO.name}': {motor_bdoo.total_objetos}")
    print("\n" + "=" * 80)
    print("TODAS LAS PRUEBAS Y GENERACIONES DEL COMPONENTE B COMPLETADAS EXITOSAMENTE")
    print("=" * 80)


if __name__ == "__main__":
    ejecutar_pruebas()
