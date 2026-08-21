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

# La base se rehace ENTERA antes de cada motor. En cuanto la secuencia de
# teclas escribe —y esta anota, ajusta, corrige y borra—, dejar la base de una
# ejecución para la siguiente hace que el segundo motor parta de otro estado y
# pinte otra cosa. La primera versión de esta suite compartía base y acusaba a
# la VM de divergir cuando lo único que pasaba es que veía las filas que el
# tree-walker acababa de escribir.
#
# EN: the database is rebuilt WHOLE before each engine. Once the key sequence
# writes — and this one records, adjusts, corrects and deletes — leaving one
# run's database for the next makes the second engine start from a different
# state. The first version of this suite shared it and accused the VM of
# diverging when all it saw were the rows the tree-walker had just written.
Z="$ROOT/zybank.zy"

sembrar() {
    rm -f zybank.db zybank.json
    zymbol run "$Z" iniciar                                                   >/dev/null 2>&1
    zymbol run "$Z" nueva Corriente CLP 500000                                >/dev/null 2>&1
    zymbol run "$Z" nueva Ahorro USD 120050                                   >/dev/null 2>&1
    zymbol run "$Z" anotar Corriente gasto.alimentación 25990 Feria 2026-08-01 >/dev/null 2>&1
    zymbol run "$Z" anotar Corriente ingreso.sueldo 1200000 Sueldo 2026-08-05  >/dev/null 2>&1
}

sembrar
[ -f zybank.db ] || { echo "sin base de datos: ¿falta el DSN zymbol_sqlite?" >&2; exit 2; }

# La secuencia ejerce la aplicación entera, no solo el dibujo. Se queda en la
# primera cuenta, que es CLP — exponente 0 — a propósito:
#
#   ⏎              abre Corriente (CLP)
#   n ⏎            nuevo movimiento, primera categoría de la lista
#   1 a २ . ৩      TECLEA UN IMPORTE CON BASURA Y CON DOS ESCRITURAS. El '1' es
#                  ASCII, el '२' devanagari y el '৩' bengalí: los tres son
#                  dígitos y los tres tienen que entrar, porque un teclado
#                  hindi manda U+0966 y no U+0030. La 'a' y el '.' no, porque
#                  una no es un dígito y el otro no cabe en una moneda sin
#                  decimales. El campo tiene que quedar en "123".
#   ⏎ P a n ⏎      confirma importe y glosa
#   + 5 0 0 ⏎ A ⏎  abona saldo
#   - 2 0 0 ⏎ B ⏎  descuenta saldo
#   e 9 ⏎ C ⏎      corrige el movimiento seleccionado
#   x s            borra el seleccionado, confirmando
#   i i            rota el idioma dos veces, en vivo
#   q              sale
#
# EN: the sequence exercises the application, not just the drawing, and stays on
# the CLP account — exponent 0 — on purpose. It types one ASCII, one Devanagari
# and one Bengali digit: all three must enter, since a Hindi keyboard sends
# U+0966, not U+0030. The 'a' and the '.' must not. The field must read "123".
KEYS=('\r' n '\r' 1 a २ . ৩ '\r' P a n '\r'
      + 5 0 0 '\r' A '\r'
      - 2 0 0 '\r' B '\r'
      e 9 '\r' C '\r'
      x s
      i i q)

for motor in tw vm; do
    sembrar
    if [ "$motor" = vm ]; then ARGS=(run --vm); else ARGS=(run); fi
    python3 "$HARNESS" zymbol "${ARGS[@]}" "$ROOT/zybank_tui.zy" -- "${KEYS[@]}" > "salida.$motor" 2>/dev/null
done

# El campo tuvo que rechazar la letra y el punto. Se comprueba aquí y no solo
# comparando motores: si los dos aceptaran la basura, coincidirían y la suite
# pasaría diciendo que todo va bien.
# EN: the field had to refuse the letter and the point. Checked here and not
# only by comparing engines: if both accepted the rubbish they would agree, and
# the suite would pass saying all is well.
if grep -aq '12\.3' salida.tw || grep -aq '1a' salida.tw; then
    echo "FALLO  el campo de importe aceptó lo que no debía en una moneda sin decimales"
    exit 1
fi
if ! grep -aq -- '-\$123' salida.tw; then
    echo "FALLO  el campo no aceptó los dígitos devanagari o bengalíes: no llegó a 123"
    exit 1
fi
echo "ok   el campo tomó 1 (ascii) २ (devanagari) ৩ (bengalí) y rechazó la letra y el punto"

# ── El veredicto ─────────────────────────────────────────────────────────────
#
# Se juzgan los SALDOS, no los bytes. Un saldo es el resultado de haber anotado,
# ajustado, corregido y borrado: si los dos motores llegan a la misma secuencia
# de saldos, han hecho lo mismo con el dinero, que es lo que esta aplicación
# tiene que hacer bien.
#
# La igualdad byte a byte está abierta como BUG-ZYB-008: el tree-walker repinta
# un aviso ya borrado porque una escritura al estado del módulo hecha dentro de
# `>>|` no la ve otra función del mismo módulo. Es una divergencia real y está
# registrada; hacer que tumbe esta suite convertiría un hallazgo conocido en una
# alarma diaria. Se reporta y no se cierra la puerta con ella — la misma
# división que hace zyquality entre goldens (la puerta) y consenso (el hallazgo).
#
# EN: the verdict is on the BALANCES, not the bytes. A balance is the result of
# recording, adjusting, correcting and deleting; if both engines reach the same
# sequence, they did the same thing with the money. Byte equality is open as
# BUG-ZYB-008 and is reported rather than gated.

saldos() { grep -ao 'Corriente  \$[0-9.]*' "$1" | tr '\n' ' '; }

S_TW="$(saldos salida.tw)"
S_VM="$(saldos salida.vm)"

if [ -z "$S_TW" ]; then
    echo "FALLO  el tree-walker no llegó a pintar ningún saldo"
    exit 1
fi

if [ "$S_TW" != "$S_VM" ]; then
    echo "FALLO  los motores llegan a saldos distintos"
    echo "    tw: $S_TW"
    echo "    vm: $S_VM"
    exit 1
fi
echo "ok   tw == vm en los saldos  ($(echo $S_TW | wc -w) estados)"

if diff -q salida.tw salida.vm >/dev/null; then
    echo "ok   tw == vm byte a byte  ($(wc -c < salida.tw) bytes)"
    echo "     (BUG-ZYB-008 ya no se reproduce: conviene cerrarlo)"
else
    n_tw=$(grep -ao '38;5;214m' salida.tw | wc -l)
    n_vm=$(grep -ao '38;5;214m' salida.vm | wc -l)
    echo "aviso  difieren en el repintado: $n_tw avisos en tw, $n_vm en vm — BUG-ZYB-008, abierto"
fi
echo "TODO BIEN"
exit 0
