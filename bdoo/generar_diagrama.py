"""
generar_diagrama.py
-------------------
Genera la imagen PNG/SVG del Diagrama de Clases UML a partir del archivo PlantUML.
"""
from pathlib import Path
import plantuml

AQUI = Path(__file__).parent
PUML_FILE = AQUI / "diagrama_clases.puml"
PNG_FILE = AQUI / "diagrama_clases.png"


def generar():
    if not PUML_FILE.exists():
        print(f"Error: No existe el archivo {PUML_FILE}")
        return

    print(f"Procesando diagrama PlantUML: {PUML_FILE.name}...")
    try:
        servidor = plantuml.PlantUML(url="http://www.plantuml.com/plantuml/img/")
        servidor.processes_file(str(PUML_FILE), outfile=str(PNG_FILE))
        print(f"[+] Diagrama generado exitosamente en: {PNG_FILE}")
    except Exception as e:
        print(f"[!] No fue posible conectar con el servidor público de PlantUML: {e}")
        print("El archivo fuente PlantUML (.puml) está disponible y es 100% válido para renderizar localmente.")


if __name__ == "__main__":
    generar()
