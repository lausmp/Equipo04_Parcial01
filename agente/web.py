"""
web.py
------
Panel Web Interactivo del Agente Analítico de IA (Flask).
Permite a la gerencia y al docente interactuar con el agente desde el navegador,
visualizar el desglose de interpretación (6.1), la consulta SQL ejecutada (6.2),
la evidencia con tabla de datos y advertencias (6.3), y el grafo de objetos BDOO (5.1).
"""
from __future__ import annotations

import json
from flask import Flask, jsonify, render_template_string, request
from .servicio import ServicioAgenteAnalitico

app = Flask(__name__)
servicio = ServicioAgenteAnalitico()

PLANTILLA_HTML = """
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Agente Analítico de IA - Equipo 04 | Parcial 01</title>
    <style>
        :root {
            --bg-color: #0f172a;
            --surface: #1e293b;
            --surface-hover: #334155;
            --primary: #38bdf8;
            --accent: #818cf8;
            --text-main: #f8fafc;
            --text-muted: #94a3b8;
            --success: #34d399;
            --warning: #fbbf24;
            --danger: #f87171;
            --border: #334155;
        }
        * { box-sizing: border-box; margin: 0; padding: 0; font-family: 'Segoe UI', system-ui, sans-serif; }
        body { background: var(--bg-color); color: var(--text-main); min-height: 100vh; padding: 24px; }
        .container { max-width: 1200px; margin: 0 auto; }
        header { border-bottom: 1px solid var(--border); padding-bottom: 16px; margin-bottom: 24px; }
        h1 { font-size: 1.8rem; color: var(--primary); display: flex; align-items: center; gap: 12px; }
        .subtitle { color: var(--text-muted); font-size: 0.95rem; margin-top: 4px; }
        .grid { display: grid; grid-template-columns: 1fr 340px; gap: 24px; }
        @media(max-width: 900px) { .grid { grid-template-columns: 1fr; } }
        .card { background: var(--surface); border: 1px solid var(--border); border-radius: 12px; padding: 20px; margin-bottom: 20px; }
        .card-title { font-size: 1.1rem; font-weight: 600; color: var(--accent); margin-bottom: 12px; }
        .search-box { display: flex; gap: 10px; }
        input[type="text"] {
            flex: 1; background: #0f172a; border: 1px solid var(--border); border-radius: 8px;
            padding: 12px 16px; color: #fff; font-size: 1rem; outline: none;
        }
        input[type="text"]:focus { border-color: var(--primary); }
        button {
            background: var(--primary); color: #0f172a; font-weight: 600; border: none;
            border-radius: 8px; padding: 12px 24px; cursor: pointer; transition: opacity 0.2s;
        }
        button:hover { opacity: 0.9; }
        .chips { display: flex; flex-wrap: wrap; gap: 8px; margin-top: 12px; }
        .chip {
            background: #0f172a; border: 1px solid var(--border); color: var(--text-muted);
            font-size: 0.8rem; padding: 6px 12px; border-radius: 20px; cursor: pointer; transition: all 0.2s;
        }
        .chip:hover { border-color: var(--primary); color: var(--primary); }
        .info-pill {
            display: inline-block; padding: 4px 10px; border-radius: 6px; font-size: 0.8rem;
            font-weight: 600; margin-right: 6px; margin-bottom: 6px;
        }
        .pill-blue { background: rgba(56, 189, 248, 0.15); color: var(--primary); }
        .pill-green { background: rgba(52, 211, 153, 0.15); color: var(--success); }
        .pill-yellow { background: rgba(251, 191, 36, 0.15); color: var(--warning); }
        .pill-red { background: rgba(248, 113, 113, 0.15); color: var(--danger); }
        .interpretacion-box {
            background: #0f172a; border-left: 4px solid var(--primary); padding: 12px 16px;
            border-radius: 0 8px 8px 0; font-size: 0.9rem; line-height: 1.5; margin-bottom: 16px;
        }
        table { width: 100%; border-collapse: collapse; margin-top: 12px; font-size: 0.9rem; }
        th, td { padding: 10px 12px; text-align: left; border-bottom: 1px solid var(--border); }
        th { background: #0f172a; color: var(--text-muted); font-weight: 600; }
        tr:hover { background: var(--surface-hover); }
        .evidence-item { display: flex; margin-bottom: 8px; font-size: 0.88rem; }
        .evidence-label { width: 160px; color: var(--text-muted); font-weight: 500; }
        .evidence-val { flex: 1; color: #fff; font-family: monospace; }
        .alert-box {
            background: rgba(251, 191, 36, 0.1); border: 1px solid rgba(251, 191, 36, 0.3);
            border-radius: 8px; padding: 12px; margin-top: 16px; font-size: 0.85rem; color: #fde68a;
        }
        .bdoo-stat { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #334155; font-size: 0.88rem; }
        .loader { display: none; text-align: center; padding: 20px; color: var(--primary); }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>⚡ Agente Analítico de IA - Equipo 04</h1>
            <div class="subtitle">Tópicos Especiales para la Gestión de Datos | Prof. Armen Djenanian | Parcial 01</div>
        </header>

        <div class="card">
            <div class="card-title">Consulta Gerencial en Lenguaje Natural</div>
            <div class="search-box">
                <input type="text" id="preguntaInput" placeholder="Ej: ¿Cuáles son las cinco categorías con mayor margen bruto?" />
                <button onclick="enviarPregunta()">Consultar</button>
            </div>
            <div class="chips">
                <span class="chip" onclick="seleccionarChip(this)">¿Cuál fue el ingreso neto por mes?</span>
                <span class="chip" onclick="seleccionarChip(this)">¿Cuáles son las cinco categorías con mayor margen bruto?</span>
                <span class="chip" onclick="seleccionarChip(this)">¿Qué sucursal presenta el ticket promedio más alto?</span>
                <span class="chip" onclick="seleccionarChip(this)">¿Qué segmento de clientes redujo más su volumen de compra?</span>
                <span class="chip" onclick="seleccionarChip(this)">¿Qué canal concentra el mayor valor de ventas?</span>
                <span class="chip" onclick="seleccionarChip(this)">Compare el margen de dos canales durante los últimos tres meses disponibles.</span>
                <span class="chip" onclick="seleccionarChip(this)">¿Qué producto lidera las ventas dentro de la categoría Electronica?</span>
                <span class="chip" onclick="seleccionarChip(this)">¿Cuál fue el mejor canal?</span>
            </div>
        </div>

        <div id="loader" class="loader">Consultando Data Mart y persistiendo en BDOO...</div>

        <div class="grid">
            <main id="resultadoPanel">
                <div class="card" id="cardResultado" style="display: none;">
                    <div class="card-title" id="tituloRespuesta">Respuesta Gerencial Sustentada</div>
                    <div class="interpretacion-box" id="interpretacionTexto"></div>
                    <div id="contenedorPills"></div>
                    <div id="contenedorTabla"></div>
                    <div id="contenedorEvidencia" style="margin-top: 16px;"></div>
                    <div id="contenedorAlertas"></div>
                </div>
            </main>

            <aside>
                <div class="card">
                    <div class="card-title">Estado de la BDOO (ODMG-3.0)</div>
                    <div class="bdoo-stat"><span>Sesión Actual:</span><strong id="sesionId">Cargando...</strong></div>
                    <div class="bdoo-stat"><span>Usuario:</span><span id="usuarioNombre">Dra. Mariana Rossi</span></div>
                    <div class="bdoo-stat"><span>Rol / Acceso:</span><span class="info-pill pill-blue">GERENCIAL</span></div>
                    <div class="bdoo-stat"><span>Total Objetos BDOO:</span><strong id="totalObjetos">-</strong></div>
                    <div class="bdoo-stat"><span>Preguntas Auditadas:</span><strong id="totalPreguntas">-</strong></div>
                    <div style="margin-top: 14px; font-size: 0.8rem; color: var(--text-muted); text-align: center;">
                        Persistencia por Alcance & Extents Activos
                    </div>
                </div>
            </aside>
        </div>
    </div>

    <script>
        function seleccionarChip(el) {
            document.getElementById('preguntaInput').value = el.innerText;
            enviarPregunta();
        }

        async function actualizarEstadoBDOO() {
            try {
                const res = await fetch('/api/bdoo/resumen');
                const data = await res.json();
                document.getElementById('sesionId').innerText = data.sesion_id;
                document.getElementById('totalObjetos').innerText = data.total_objetos;
                document.getElementById('totalPreguntas').innerText = data.preguntas;
            } catch(e) { console.error(e); }
        }

        async function enviarPregunta() {
            const texto = document.getElementById('preguntaInput').value.trim();
            if (!texto) return;

            document.getElementById('loader').style.display = 'block';
            document.getElementById('cardResultado').style.display = 'none';

            try {
                const res = await fetch('/api/consultar', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ pregunta: texto })
                });
                const data = await res.json();
                document.getElementById('loader').style.display = 'none';
                document.getElementById('cardResultado').style.display = 'block';

                // Interpretación
                document.getElementById('interpretacionTexto').innerHTML =
                    '<strong>Desglose de Interpretación (Numeral 6.1):</strong><br>' + data.interpretacion_formateada;

                // Pills
                const pills = document.getElementById('contenedorPills');
                pills.innerHTML = `
                    <span class="info-pill pill-blue">Métrica: ${data.respuesta.metrica_utilizada}</span>
                    <span class="info-pill pill-green">Dimensión: ${data.respuesta.dimension_analizada}</span>
                    <span class="info-pill pill-yellow">Periodo: ${data.respuesta.periodo_aplicado}</span>
                `;

                // Tabla
                const contTabla = document.getElementById('contenedorTabla');
                if (Array.isArray(data.respuesta.resultado_cuantitativo) && data.respuesta.resultado_cuantitativo.length > 0) {
                    const filas = data.respuesta.resultado_cuantitativo;
                    const cols = Object.keys(filas[0]);
                    let html = '<table><thead><tr>' + cols.map(c => `<th>${c.toUpperCase()}</th>`).join('') + '</tr></thead><tbody>';
                    for (const f of filas) {
                        html += '<tr>' + cols.map(c => `<td>${f[c] !== null ? f[c] : 'NULL'}</td>`).join('') + '</tr>';
                    }
                    html += '</tbody></table>';
                    contTabla.innerHTML = html;
                } else {
                    contTabla.innerHTML = `<div style="padding: 12px; color: var(--text-muted);">${JSON.stringify(data.respuesta.resultado_cuantitativo)}</div>`;
                }

                // Evidencia (6.3)
                const contEvid = document.getElementById('contenedorEvidencia');
                contEvid.innerHTML = `
                    <div style="border-top: 1px solid var(--border); padding-top: 12px;">
                        <div class="evidence-item"><div class="evidence-label">Regla de Cálculo:</div><div class="evidence-val">${data.respuesta.regla_calculo}</div></div>
                        <div class="evidence-item"><div class="evidence-label">Fuente Data Mart:</div><div class="evidence-val">${data.respuesta.fuentes_consultadas.join(', ')}</div></div>
                        <div class="evidence-item"><div class="evidence-label">Consulta Oficial:</div><div class="evidence-val">${data.respuesta.consulta_utilizada}</div></div>
                    </div>
                `;

                // Alertas
                const contAlert = document.getElementById('contenedorAlertas');
                if (data.respuesta.advertencias && data.respuesta.advertencias.length > 0) {
                    contAlert.innerHTML = '<div class="alert-box"><strong>Controles y Advertencias Metodológicas:</strong><br>' +
                        data.respuesta.advertencias.map(a => `• ${a}`).join('<br>') + '</div>';
                } else {
                    contAlert.innerHTML = '';
                }

                actualizarEstadoBDOO();
            } catch(e) {
                document.getElementById('loader').style.display = 'none';
                alert('Error al procesar consulta: ' + e);
            }
        }

        actualizarEstadoBDOO();
    </script>
</body>
</html>
"""


@app.route("/")
def index():
    return render_template_string(PLANTILLA_HTML)


@app.route("/api/consultar", methods=["POST"])
def consultar():
    req = request.get_json(force=True)
    texto = req.get("pregunta", "").strip()
    interpretacion, respuesta, _ = servicio.consultar(texto)
    return jsonify({
        "interpretacion_formateada": interpretacion.a_formato_documento(),
        "interpretacion_raw": {
            "intencion": interpretacion.intencion_nombre,
            "metrica": interpretacion.metrica,
            "dimension": interpretacion.dimension,
            "periodo": interpretacion.periodo,
            "operacion": interpretacion.operacion_analitica,
            "limite": interpretacion.limite,
            "filtros": interpretacion.filtros,
        },
        "respuesta": respuesta.a_diccionario(),
    })


@app.route("/api/bdoo/resumen", methods=["GET"])
def resumen_bdoo():
    resumen = servicio.obtener_resumen_bdoo()
    resumen["sesion_id"] = servicio.sesion_actual.id_sesion
    return jsonify(resumen)


def iniciar_servidor(puerto: int = 5000):
    print(f"\n[+] Iniciando Panel Web del Agente Analítico en: http://localhost:{puerto}")
    app.run(host="0.0.0.0", port=puerto, debug=False)


if __name__ == "__main__":
    iniciar_servidor()
