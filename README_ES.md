# ZyBank

Un libro de cuentas personal escrito en Zymbol — ingresos y gastos, en cuatro
idiomas, sobre SQLite.

Es un **proyecto LDV** (`interpreter/LDV.md`): una aplicación construida para
averiguar qué no sabe decir todavía el lenguaje. El programa es el instrumento;
el producto son los hallazgos. Hay veinticinco en [HALLAZGOS.md](HALLAZGOS.md), entre
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

### Las palabras son las del oficio, no las del diccionario

Escribir el programa en español no es traducirlo: es escribirlo en el español
**de la contabilidad**. Una palabra corriente que ocupa el sitio de un término
del oficio miente sobre lo que hace el código, y lo hace en el idioma que se
supone que lo aclaraba.

| Término | Es | No es |
|---|---|---|
| **Abono** | crédito, haber — sube el saldo | «ingreso»: eso es la naturaleza, no el efecto |
| **Cargo** | débito, debe — baja el saldo | «descontar»: descontar es rebajar un precio, y no es lo contrario de abonar |
| **Importe** | la cantidad de un movimiento | «monto», que es el término suelto |
| **Glosa** | el texto que explica el movimiento | «nota», «descripción» |
| **Asiento** | la anotación completa | una de sus mitades |
| **Partida** | cada mitad de un asiento | un asiento suyo |
| **Traspaso** | mover dinero entre cuentas propias | «transferencia», que es a un tercero |
| **Apertura** | el asiento con el que empieza una cuenta | «saldo inicial», que suena a propiedad de la cuenta y no a hecho fechado |

Y son **dos ejes, no uno**. La **naturaleza** —ingreso, gasto, ajuste— dice de
qué es el movimiento y vive en la clave de la categoría y en su grupo. El
**sentido** —abono o cargo— dice hacia dónde mueve el saldo y vive en su propia
columna. Confundirlos es lo que hacía la columna `tipo`, que guardaba
«ingreso»/«gasto» en el sitio que decide el signo: por eso un ajuste no cabía en
ella —no es ingreso ni gasto— y había que colgarlo de uno de los dos fingiendo
que lo era.

## Cómo se usa

Necesita un binario `zymbol` con `std/db` (compilado desde fuente, o Windows) y
un DSN de ODBC llamado `zymbol_sqlite` — ver
`zyquality/corpus/stdlib/README-odbc.md`.

### A pantalla completa

```bash
zymbol run zybank_tui.zy
```

Es donde se opera el libro: dar de alta cuentas, anotar movimientos, corregirlos,
borrarlos, y **abonar o cargar**. Dos cosas existen solo aquí:

- **La validación ocurre mientras se teclea, y es numérica, no de texto.** El
  campo de importe no acepta una letra —no la escribe— y el punto decimal solo
  entra si la moneda tiene decimales: en pesos chilenos la tecla del punto no
  hace nada, en dólares admite dos dígitos detrás y en dinares kuwaitíes tres.
  No hay un estado inválido que corregir porque nunca llega a existir. Y se ve
  el importe formateado mientras se teclea: `1234` se lee `$1.234` en un campo
  CLP y `$12.34` en uno USD, con las mismas pulsaciones.

  El campo de **fecha** sigue la misma regla: se teclean dígitos y los guiones
  los pone el campo, así que «2026-08-2100» no se puede escribir. Y ENTER no
  confirma un `2026-02-31` — ocho dígitos bien colocados siguen pudiendo no ser
  un día. Un libro ordena por fecha y resume por periodo, así que una fecha que
  no existe no desordena la pantalla: desordena el dinero.
- **Un dígito no es «0».."9".** Un teclado hindi manda «२», uno bengalí «২», y
  los dos son el dos. El campo los acepta —trece escrituras: devanagari,
  bengalí, gurmukhi, gujarati, oriya, tamil, telugu, kannada, malayalam,
  tailandés, árabe, persa y ASCII— y guarda el **valor**, no la tecla, así que
  la misma cuenta admite que hoy se teclee en devanagari y mañana en ASCII. Lo
  que se pinta sigue a la escritura del idioma elegido. Aceptar solo ASCII sería
  localizar la salida y dejar la entrada sin localizar, que es peor que no
  localizar nada: le enseña al usuario una escritura que luego le rechaza.
- **El idioma cambia en vivo.** La tecla `i` rota el idioma y con él se mueven
  las etiquetas, los nombres de las categorías y la escritura de las cifras, sin
  recargar nada.

Teclas: `↑↓` o `jk` mover · `→` o `⏎` abrir · `←` o `⏎` volver · `n` nuevo ·
`e` editar · `x` borrar · `+` abonar · `-` cargar · `t` traspasar · `c` cuenta nueva ·
`r` resumen · `i` idioma · `q` salir.

**Las flechas funcionan, y durante un tiempo no.** `<<|` entrega una flecha ya
decodificada —`'↓'` es un carácter, no `ESC`+`[`+`B`— y un ESC suelto sigue
llegando como ESC, así que aceptarlas no cuesta la tecla de cancelar. La
aplicación las ignoraba porque una ficha decía que era imposible sin un
temporizador; la ficha razonaba sobre lo que manda el terminal y no sobre lo que
entrega el lenguaje: [GAP-ZYB-011](HALLAZGOS.md#gap-zyb-011), retirado. `jk` se
queda al lado, para quien viene de `vi`.

**Un traspaso es un asiento de dos partidas, no dos movimientos sueltos.** `t`
mueve dinero de la cuenta que se está mirando a otra: sale un **cargo** en el
origen y entra un **abono** en el destino, emparejados por una marca, sin
categoría y en una sola transacción — media transferencia no es un estado que la
base pueda tener. No se editan por separado (cambiar una mitad deja la otra
mintiendo) y borrar una borra las dos. El resumen los excluye: mover dinero de
una cuenta propia a otra no es un gasto ni un ingreso, y contarlo como tal
inflaría las dos columnas a la vez.

Si las cuentas están en monedas distintas, el programa **pide el importe que
llega** en vez de inventarse una tasa: quien mueve 100 000 CLP a una cuenta en
dólares sabe a cuánto se los cambiaron, y adivinarlo sería falsificar un asiento.

**Ninguna cifra de dinero vive fuera del libro.** El saldo de una cuenta es la
suma de sus movimientos y nada más — no hay columna de saldo que nadie pueda
contradecir. Abrir una cuenta con un importe escribe su **asiento de apertura**:
una línea con su fecha, su categoría «Apertura» y su importe, en la misma
transacción que crea la cuenta. Media apertura —cuenta creada, línea no— no es un
estado que la base pueda tener.

Hubo una columna `saldo_inicial`, y era el único dinero del programa que ninguna
línea explicaba. Se defendía diciendo que era «lo que había al abrir la cuenta»,
pero eso es precisamente un asiento: tiene fecha y tiene contrapartida. Si un
libro cuyo saldo **cambia** sin dejar rastro no es un libro de cuentas, uno cuyo
saldo **empieza** sin dejar rastro tampoco.

El asiento de apertura **no cuenta en el resumen**, por lo mismo que un traspaso:
su contrapartida es el patrimonio, no una cuenta de resultado. Abrir una cuenta
con veinte millones no es haber ganado veinte millones ese mes. Y por eso tampoco
se ofrece en el selector al anotar — lo que el resumen excluye no puede estar en
el selector, o sería una categoría invisible: el gasto se guarda, el saldo cambia
y la línea no sale en ningún resumen. Los **ajustes** sí están, porque sí cuentan.

**Abonar y cargar son movimientos, no un saldo que cambia.** Un ajuste deja su
línea, con su fecha y su glosa.

### Por órdenes

```bash
zymbol run zybank.zy iniciar                      # crea el esquema y siembra categorías
zymbol run zybank.zy nueva Corriente CLP 500000   # una cuenta
zymbol run zybank.zy anotar Corriente gasto.alimentación 25990 "Feria" 2026-08-01
zymbol run zybank.zy cuentas
zymbol run zybank.zy resumen Corriente 2026-08-01 2026-08-31
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
| `pantalla/` | la aplicación a pantalla completa: constantes de tecla, campos de entrada, pantallas |
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
