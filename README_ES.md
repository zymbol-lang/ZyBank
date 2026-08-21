# ZyBank

Un libro de cuentas personal escrito en Zymbol — ingresos y gastos, en cuatro
idiomas, sobre SQLite.

Es un **proyecto LDV** (`interpreter/LDV.md`): una aplicación construida para
averiguar qué no sabe decir todavía el lenguaje. El programa es el instrumento;
el producto son los hallazgos. Hay diecinueve en [HALLAZGOS.md](HALLAZGOS.md), entre
ellos **dos divergencias de comportamiento entre motores** —cada uno rompe una
forma distinta de pasar una función entre módulos— y una tercera de
diagnóstico, en un lenguaje cuyo gate declara cero divergencias sobre 616
archivos de corpus.

El código está escrito en español, como `serpiente` y `Zofía`. Lo nuevo es el
dominio, que es con lo que el método escala de verdad (LDV § 6).

---

## Para qué sirve

El dinero es el único dominio donde un error de redondeo no es un error de
redondeo. Por eso:

**Un importe es un entero en la unidad menor de su moneda, nunca un flotante.**
Y el número de decimales es **configuración, no una constante**: el peso chileno
no tiene unidad menor en circulación (exponente 0), el dólar y el euro tienen
dos, el dinar kuwaití tiene tres. `1050` es `$1.050`, `$10.50` o `1.050 د.ك`
según en qué moneda esté, y el entero guardado no cambia.

Ese solo requisito destapó el primer hallazgo: `#.N|…|` necesita una precisión
**literal**, así que un formateador cuya precisión llega en tiempo de ejecución
no puede usarla en absoluto — y `#.2|10.5|` escribe `10.5`, no `10.50`.

## Cómo se usa

Necesita un binario `zymbol` con `std/db` (compilado desde fuente, o Windows) y
un DSN de ODBC llamado `zymbol_sqlite` — ver
`zyquality/corpus/stdlib/README-odbc.md`.

```bash
zymbol run zybank.zy iniciar                      # crea el esquema y siembra categorías
zymbol run zybank.zy nueva Corriente CLP 500000   # una cuenta
zymbol run zybank.zy anotar Corriente gasto.alimentación 25990 "Feria" 2026-08-01
zymbol run zybank.zy cuentas
zymbol run zybank.zy resumen Corriente 2026-08-01 2026-08-31
zymbol run zybank_tui.zy                          # el navegador a pantalla completa
```

**Los verbos se aceptan en los cuatro idiomas, siempre** — `zybank 口座`,
`zybank accounts`, `zybank खाते` y `zybank cuentas` son la misma orden. Solo la
*salida* sigue al idioma configurado. Traducir el verbo según el idioma activo
significaría que una orden que funciona hoy deje de funcionar mañana porque
alguien cambió una preferencia.

La configuración sigue una regla: **el archivo manda, la base recuerda.** El
`zybank.json` puede estar escrito en el idioma del usuario —
`{"言語": "hi", "通貨": "KWD"}` lo configura — gracias a `json::decode_map`.

## Disposición

| Directorio | Qué vive ahí |
|---|---|
| `núcleo/` | la aritmética del dinero, el esquema y `std/db`, la semilla, el ayudante de diccionarios |
| `configuración/` | la tabla de monedas, y de dónde salen el idioma y la moneda |
| `idioma/` | el despachador y cuatro catálogos (es · en · ja · hi) |
| `presentación/` | columnas medidas con `std/term`, nunca con `$#` |
| `interfaz/` | los verbos y la aplicación por órdenes |
| `pantalla/` | el navegador a pantalla completa |
| `pruebas/` | cinco suites, registradas en `zyquality/project/apps.toml` |

## Pruebas

```bash
bash pruebas/todas.sh                     # las cinco, en los dos motores
cd ../zyquality && bash project/run.sh --only zybank    # el gate
```

Cuatro suites son Zymbol puro y las juzga `zyq expect` contra sus goldens; la
quinta conduce el TUI por un pty de verdad y compara los dos motores byte a
byte. El motor del navegador no participa: `std/db` no existe en él, y no tiene
ni terminal ni sistema de archivos.

## Documentos

- [HALLAZGOS.md](HALLAZGOS.md) — los hallazgos. **El objeto del proyecto.**
- [README.md](README.md) — esto, en inglés.
