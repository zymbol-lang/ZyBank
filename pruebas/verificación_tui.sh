#!/usr/bin/env bash
# pruebas/verificación_tui.sh — el navegador a pantalla completa, en los dos motores.
#
# `>>|` y `<<|` necesitan un terminal de verdad: un programa que lee de una
# tubería no llega nunca a modo crudo, así que `zyq` —que le da a cada motor un
# descriptor de archivo— no puede ejercitar esto. Se usa el arnés del propio
# proyecto, `zyquality/tui/ptydrive.py`, que reserva un pty y va mandando las
# teclas conforme el programa las pide.
#
# Lo que compara: la MISMA secuencia de teclas en el tree-walker y en la VM,
# byte a byte. La secuencia recorre a propósito los dos idiomas con escritura
# de cifras distinta, porque el cambio de idioma en vivo es lo único que este
# programa hace y la CLI no.
#
# EN: pruebas/verificación_tui.sh — the full-screen browser on both engines.
# `>>|` and `<<|` need a real terminal, so `zyq` structurally cannot exercise
# them; this uses the project's own pty harness. It compares the SAME key
# sequence on the tree-walker and the VM, byte for byte. The sequence crosses
# two locales with different digit scripts on purpose.
#
# Nota: las variables de este guion van sin acentos — bash no admite
# identificadores con tilde, y este archivo es shell, no Zymbol.
#
# Estado de salida: 0 los motores coinciden, 1 no, 2 no se pudo ejecutar.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
HARNESS="${ZYQUALITY_HOME:-$ROOT/../zyquality}/tui/ptydrive.py"

[ -f "$HARNESS" ] || { echo "sin arnés de pty: $HARNESS" >&2; exit 2; }
command -v zymbol >/dev/null || { echo "sin binario zymbol" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 2

# Una base conocida. Las fechas van explícitas: el reloj no forma parte
# de lo que se comprueba.
Z="$ROOT/zybank.zy"
zymbol run "$Z" iniciar                                              >/dev/null 2>&1
zymbol run "$Z" nueva Corriente CLP 500000                           >/dev/null 2>&1
zymbol run "$Z" nueva Ahorro USD 120050                              >/dev/null 2>&1
zymbol run "$Z" anotar Corriente gasto.alimentación 25990 Feria 2026-08-01 >/dev/null 2>&1
zymbol run "$Z" anotar Corriente ingreso.sueldo 1200000 Sueldo 2026-08-05  >/dev/null 2>&1
[ -f zybank.db ] || { echo "sin base de datos: ¿falta el DSN zymbol_sqlite?" >&2; exit 2; }

# j baja · ⏎ entra · i rota el idioma dos veces · r resumen · q sale
KEYS=(j '\r' i i r q)

for motor in tw vm; do
    if [ "$motor" = vm ]; then ARGS=(run --vm); else ARGS=(run); fi
    python3 "$HARNESS" zymbol "${ARGS[@]}" "$ROOT/zybank_tui.zy" -- "${KEYS[@]}" > "salida.$motor" 2>/dev/null
done

if diff -q salida.tw salida.vm >/dev/null; then
    echo "ok   tw == vm  ($(wc -c < salida.tw) bytes, $(grep -c . salida.tw) líneas)"
    echo "TODO BIEN"
    exit 0
fi
echo "FALLO  el tree-walker y la VM pintan cosas distintas"
diff <(sed 's/\x1b\[[0-9;]*[A-Za-z]/|/g' salida.tw) \
     <(sed 's/\x1b\[[0-9;]*[A-Za-z]/|/g' salida.vm) | head -20
exit 1
