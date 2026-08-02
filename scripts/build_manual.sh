#!/bin/bash
# Genera el manual en PDF a partir de docs/manual.html.
#
# Se usa Chrome sin interfaz porque respeta el CSS de impresión (@page, saltos
# de página y colores) y no hace falta instalar nada más.
#
# Uso: scripts/build_manual.sh

set -euo pipefail

cd "$(dirname "$0")/.."

CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || { echo "No se encuentra Google Chrome"; exit 1; }

"$CHROME" \
  --headless \
  --disable-gpu \
  --no-pdf-header-footer \
  --virtual-time-budget=5000 \
  --print-to-pdf="MANUAL.pdf" \
  "file://$PWD/docs/manual.html" 2>/dev/null

echo "MANUAL.pdf generado"
