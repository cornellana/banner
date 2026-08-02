#!/bin/bash
# Genera MANUAL.pdf a partir de docs/manual.html.
#
# Se imprime con Chrome sin interfaz porque respeta el CSS de impresión —tamaño
# de página, saltos y colores— y no obliga a instalar nada más.
#
# Si falta docs/proyeccion-tv.jpg (la foto del rótulo en un televisor, que no se
# puede capturar del simulador), esa figura se omite y el manual se genera igual.
#
# Uso: scripts/build_manual.sh

set -euo pipefail

cd "$(dirname "$0")/.."

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "No se encuentra Google Chrome"; exit 1; }

FUENTE="docs/manual.html"
TEMPORAL="docs/.manual-imprimible.html"

python3 - "$FUENTE" "$TEMPORAL" <<'PY'
import pathlib, re, sys

fuente, destino = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
html = fuente.read_text()

for figura in re.findall(r'\s*<figure class="foto">.*?</figure>', html, re.S):
    imagen = re.search(r'src="([^"]+)"', figura)
    if imagen and not (fuente.parent / imagen.group(1)).exists():
        html = html.replace(figura, "")
        print(f"aviso: falta {imagen.group(1)}, se omite esa figura")

destino.write_text(html)
PY

"$CHROME" \
  --headless \
  --disable-gpu \
  --no-pdf-header-footer \
  --virtual-time-budget=5000 \
  --print-to-pdf="MANUAL.pdf" \
  "file://$PWD/$TEMPORAL" 2>/dev/null

rm -f "$TEMPORAL"
echo "MANUAL.pdf generado"
