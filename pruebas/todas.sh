#!/usr/bin/env bash
# pruebas/todas.sh — las seis suites de ZyBank, en los dos motores.
#
# Cinco son Zymbol puro y las juzga `zyq expect` contra su golden; esta es la
# forma corta para ejecutarlas a mano. La sexta es el TUI, que necesita un pty
# y por eso es un guion.
#
# El motor del navegador NO participa: `std/db` no existe en él, y no tiene ni
# terminal ni sistema de archivos. Pedirle esto sería contar divergencias que
# solo dicen que un navegador no es una consola.
#
# EN: pruebas/todas.sh — ZyBank's six suites on both engines. Five are pure
# Zymbol judged by `zyq expect` against their goldens; this is the short form
# for running them by hand. The sixth is the TUI, which needs a pty. The browser
# engine does NOT take part: `std/db` does not exist there, and it has neither a
# terminal nor a filesystem.
#
# Estado de salida: 0 todo bien, 1 alguna suite falló, 2 no se pudo ejecutar.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"

# El `cd` va a la RAÍZ del proyecto y no a este directorio, que es donde
# estaría en cualquier otro sitio. Desde `pruebas/`, `zymbol run
# verificación_dinero.zy` no resuelve sus `<# ../núcleo/...` — el mismo archivo
# lanzado como `pruebas/verificación_dinero.zy` desde la raíz sí. Es
# BUG-ZYB-004, y hasta que se cierre este guion no puede correr desde donde vive.
#
# EN: the `cd` goes to the project ROOT, not to this directory where it would
# live anywhere else: from `pruebas/`, `zymbol run verificación_dinero.zy` does
# not resolve its `<# ../núcleo/...`, while the same file launched as
# `pruebas/verificación_dinero.zy` from the root does. BUG-ZYB-004.
cd "$ROOT" || exit 2
command -v zymbol >/dev/null || { echo "sin binario zymbol" >&2; exit 2; }

fallos=0
for suite in dinero dígitos idioma tabla almacén; do
    for motor in "" "--vm"; do
        nombre="${motor:---tw}"
        salida="$(zymbol run $motor "pruebas/verificación_$suite.zy" 2>&1)"
        if printf '%s' "$salida" | grep -q '^TODO BIEN$'; then
            printf 'ok    %-10s %s\n' "$suite" "$nombre"
        else
            printf 'FALLO %-10s %s\n' "$suite" "$nombre"
            printf '%s\n' "$salida" | grep '^FALLO' | sed 's/^/        /'
            fallos=$((fallos + 1))
        fi
    done
done

if bash "$HERE/verificación_tui.sh" >/dev/null 2>&1; then
    printf 'ok    %-10s tw == vm\n' "tui"
else
    rc=$?
    if [ "$rc" = 2 ]; then
        printf 'omitida %-8s (sin pty o sin base)\n' "tui"
    else
        printf 'FALLO %-10s los motores pintan distinto\n' "tui"
        fallos=$((fallos + 1))
    fi
fi

echo
if [ "$fallos" = 0 ]; then echo "TODO BIEN"; exit 0; fi
echo "SUITES CON FALLOS: $fallos"; exit 1
