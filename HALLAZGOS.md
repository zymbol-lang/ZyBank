# ZyBank — hallazgos

> **Qué es este documento.** El registro de lo que la construcción de ZyBank
> descubrió sobre **el lenguaje**, no sobre la aplicación. Es el artefacto
> primario del proyecto según `interpreter/LDV.md` § 3.6: una aplicación
> terminada sin log no ha validado nada, porque no queda nada sobre lo que otro
> pueda actuar.
>
> **Forma.** La canónica de `LDV.md` § 5.2 para un proyecto nuevo: archivo
> `HALLAZGOS.md`, secciones `BUG` / `GAP` / `ERROR` / `IDEA`, tabla resumen
> arriba, e identificadores **con ámbito de proyecto** (`BUG-ZYB-001`, no
> `BUG-001`) desde la primera entrada. चतुरङ्गम् fue el primero en adoptarla; este
> es el segundo, y además con el nombre de archivo que el decálogo pide.
>
> **Estado del ciclo.** ROJO. Ningún hallazgo está cerrado: cerrar exige un
> cambio en el lenguaje o un rechazo razonado, y esa decisión no es de quien
> escribe la aplicación.

---

## Por qué este dominio

`LDV.md` § 6 dice que el método escala con la **distancia de dominio**, no con
el tamaño, y que un tercer juego de terminal no validaría casi nada. Los siete
proyectos anteriores fueron una CLI sobre un servicio HTTP, dos TUI, cálculo
científico, un auditor de código y dos juegos de tablero. Ninguno tenía:

| | dónde aparece en ZyBank |
|---|---|
| **persistencia real** | `std/db` sobre SQLite — 5 archivos de corpus lo tocaban y **ninguna aplicación** |
| **aritmética de dinero** | entero en unidad menor, con el número de decimales como **configuración**, no como constante |
| **diccionarios** | llegaron en v0.0.9 y ninguna aplicación los usaba: el catálogo, la tabla de monedas, las preferencias y los verbos son diccionarios |
| **datos que sobreviven al idioma** | lo guardado son claves; los nombres se traducen al mostrarse, y una base creada en japonés se lee en español |
| **configuración con precedencia** | archivo JSON sobre lo recordado en la base |

De los diecinueve hallazgos —5 BUG, 9 GAP, 3 ERROR, 2 IDEA— la mitad larga sale
de esas intersecciones y no de una característica aislada, que es el argumento
de `LDV.md` § 4 en concreto. Los dos peores lo dejan claro: pasar una función
entre módulos rompe en el tree-walker de una manera
([BUG-ZYB-001](#bug-zyb-001)) y en la VM de otra
([BUG-ZYB-005](#bug-zyb-005)), y hacen falta **tres** características compuestas
para llegar a cualquiera de los dos.

---

## Resumen

| ID | Tipo | Módulo | Contexto | Estado |
|----|------|--------|----------|--------|
| [BUG-ZYB-001](#bug-zyb-001) | BUG | intérprete (TW) | una lambda pierde los alias de módulo al invocarse dentro de otro módulo — **TW falla, VM y JS no** | abierto |
| [BUG-ZYB-002](#bug-zyb-002) | BUG | gramática / los 3 motores | `d[k]$~ "" v` asigna `""` y **descarta `v` sin decir nada** | abierto |
| [BUG-ZYB-003](#bug-zyb-003) | BUG | errores blandos | componer un mensaje con un error blando **aborta el programa** | abierto |
| [BUG-ZYB-004](#bug-zyb-004) | BUG | resolución de módulos | un `<# ../x` funciona o no **según cómo se nombre el archivo** al ejecutarlo | abierto |
| [BUG-ZYB-005](#bug-zyb-005) | BUG | compilador (VM) | pasar una función **de un módulo** a otro módulo funciona en TW y JS, y **falla en la VM** | abierto |
| [GAP-ZYB-001](#gap-zyb-001) | GAP | formato numérico | no hay precisión decimal en tiempo de ejecución ni relleno de ceros | abierto |
| [GAP-ZYB-002](#gap-zyb-002) | GAP | `std/` | no hay `std/time`: la fecha sale del intérprete de órdenes | abierto |
| [GAP-ZYB-003](#gap-zyb-003) | GAP | diccionario | no hay literal de diccionario vacío | abierto |
| [GAP-ZYB-004](#gap-zyb-004) | GAP | diccionario | las claves del literal deben ser identificadores | abierto |
| [GAP-ZYB-005](#gap-zyb-005) | GAP | módulos | una función de módulo no es un valor de primera clase | abierto |
| [GAP-ZYB-006](#gap-zyb-006) | GAP | CLI | un programa no puede fijar su código de salida | abierto |
| [GAP-ZYB-007](#gap-zyb-007) | GAP | gramática | la yuxtaposición no se admite en argumentos de llamada | abierto |
| [GAP-ZYB-008](#gap-zyb-008) | GAP | conversión a texto | un agregado se imprime con `>>` pero no se puede llevar a una cadena | abierto |
| [GAP-ZYB-009](#gap-zyb-009) | GAP | `std/db` | no hay forma de preguntar si una columna vino `NULL`, ni queda documentado qué es | abierto |
| [ERROR-ZYB-001](#error-zyb-001) | ERROR | semántica | una sentencia que es solo un identificador no produce diagnóstico | abierto |
| [ERROR-ZYB-002](#error-zyb-002) | ERROR | `check` / semántica | leer una variable del archivo desde una función pasa `check` y revienta en ejecución | abierto |
| [ERROR-ZYB-003](#error-zyb-003) | ERROR | analizador | aviso **falso** en todo `@ x:col` escrito en el cuerpo del archivo, con una ayuda que no analiza | abierto |
| [IDEA-ZYB-001](#idea-zyb-001) | IDEA | doctrina i18n | el formato numérico es un cuarto eje que `USERAPPI18N.md` no cubre | propuesta |
| [IDEA-ZYB-002](#idea-zyb-002) | IDEA | doctrina | el dinero como entero + exponente merece ser doctrina escrita | propuesta |

Los motores se nombran como en `zyquality/engines.toml`: **zytw** (tree-walker),
**zyvm** (VM de registros), **zyjs** (el del navegador). Toda reproducción se
ejecutó en los tres con `./zyq show`.

---

# BUG

## BUG-ZYB-001

**Una lambda pierde los alias de módulo cuando se invoca dentro de otro módulo. El tree-walker falla; la VM y el motor del navegador no.**

Es una divergencia entre motores, en un lenguaje cuyo gate declara **cero**
divergencias sobre 614 archivos de corpus. No estaba cubierta porque hacen falta
**tres** cosas a la vez: una lambda, que use un alias de módulo, y que se invoque
desde dentro de otro módulo. Ninguna de las tres por separado falla.

**Reproducción.**

```zymbol
// m/base.zy
# .base {
    #> { doble }
    doble(x) { <~ x * 2 }
}

// m/usa.zy
# .usa {
    #> { aplicar }
    aplicar(f, v) { <~ f(v) }
}

// prueba.zy
<# ./m/base => b
<# ./m/usa => u

env = (x) -> b::doble(x)
>> "local: " env(5) ¶                    // los tres: 10
>> "cruzando: " u::aplicar(env, 5) ¶     // zytw: error
```

| motor | resultado |
|-------|-----------|
| zytw | `Runtime error: undefined module alias: 'b'`, exit 1 |
| zyvm | `cruzando: 10`, exit 0 |
| zyjs | `cruzando: 10`, exit 0 |

**Qué lo delimita.** Se probaron las tres variantes por separado:

| caso | zytw | zyvm |
|------|------|------|
| lambda **sin** alias de módulo, cruzando | 6 | 6 |
| **función con nombre** que usa el alias, cruzando | 10 | 10 |
| **lambda** que usa el alias, cruzando | **error** | 10 |

Una función con nombre lleva sus alias consigo; una lambda no. El fallo está en
la lambda, no en el cruce de módulos.

**Por qué importa más de lo que parece.** Una lambda es el rodeo natural de
[GAP-ZYB-005](#gap-zyb-005) — como una función de módulo no se puede pasar como
valor, se la envuelve. Así que el rodeo de un hueco cae dentro de un bug, y el
programa acaba necesitando el rodeo del rodeo: una función **con nombre** que
envuelve a la de módulo. Está en `interfaz/cli.zy`, `_crear_categoría`, con el
comentario que dice qué se podrá volver a simplificar el día que esto se cierre.

**Sugerido para el corpus** (paso *refactor* de `LDV.md` § 4): tres archivos
mínimos con su golden, uno por caso de la tabla, en `corpus/modules_scope/`. El
que falla hoy es el único que hace falta para proteger la corrección; los otros
dos son los que impiden que el arreglo rompa lo que ya funcionaba.

---

## BUG-ZYB-002

**`d[k]$~ "" v` asigna la cadena vacía y descarta `v`, sin error, sin aviso y en los tres motores.**

**Reproducción.**

```zymbol
v = "X"
d = (z: "")

d["a"]$~ "" v
>> "[" d["a"] "]" ¶        // los tres motores: []     ← se perdió la v

s = "b"
>> "[" s$+ "" v "]" ¶      // los tres motores: [bX]   ← aquí sí concatena

d["c"]$~ ("" v)
>> "[" d["c"] "]" ¶        // los tres motores: [X]    ← con paréntesis, bien
```

**La asimetría es el hallazgo.** `$+` acepta la yuxtaposición en su operando
derecho; `$~` no. Son dos operadores `$` binarios de la misma familia, escritos
igual, y hacen cosas distintas con la misma expresión. Nada lo dice.

**Por qué es silencioso.** `d["a"]$~ "" v` no es una expresión mal formada: son
**dos sentencias**. La primera asigna `""`; la segunda es `v`, un identificador
suelto, que es una sentencia válida sin efecto y sin diagnóstico
([ERROR-ZYB-001](#error-zyb-001)). Con tres trozos —`d["a"]$~ "pre" v "post"`—
sí hay error de análisis, porque una cadena no puede empezar una sentencia. O
sea: **el caso de dos trozos es el único que calla, y es el frecuente.**

**Los tres motores coinciden**, así que no es un fallo de implementación sino de
diseño más diagnóstico. Es una decisión de lenguaje, y por eso queda abierta:
o `$~` acepta la yuxtaposición como `$+`, o un identificador suelto deja de ser
una sentencia silenciosa, o se documenta que ahí hacen falta paréntesis. Las
tres cierran el agujero; no es de quien escribe la aplicación elegir cuál.

**Dónde se pagó.** `configuración/preferencias.zy`: la configuración leída de un
JSON llegaba con **todos los valores vacíos** y la aplicación arrancaba con los
predeterminados como si el archivo no existiera. Ni error ni aviso. Se tardó más
en encontrarlo que en escribir el módulo.

---

## BUG-ZYB-003

**Componer un mensaje con un error blando aborta el programa. `>>` sí sabe imprimirlo.**

`GUIDE.md` § `std/db` promete que un fallo de SQL devuelve *«un error blando
`##DB(...)` comprobable con `$!` y capturable con `!? … :! ##DB`»*. La promesa
de un error blando es que se puede manejar. Manejarlo es, casi siempre,
decírselo a alguien — y eso es lo que aborta.

**Reproducción.**

```zymbol
<# std/db => bd
bd::connect("c", "DSN=zymbol_sqlite;Database=q.db;")
bd::exec("c", "CREATE TABLE t(k TEXT PRIMARY KEY)")
bd::exec("c", "INSERT INTO t(k) VALUES('a')")
r = bd::exec("c", "INSERT INTO t(k) VALUES('a')")   // viola la clave única

>> "es error blando: " r$! ¶    // #1
>> "imprimir: " r ¶             // ##DB(ODBC emitted an error … UNIQUE constraint failed)
s = "" r                        // Runtime error: cannot juxtapose value of
                                // type Error(ErrorValue { … }) in string context
```

La segunda línea demuestra que el intérprete **sabe** renderizar el valor: lo
imprime entero, con su tipo y su mensaje. La tercera aborta.

**Por qué es un bug y no una carencia de conversión.** El patrón natural para
propagar un fallo hacia arriba es exactamente el que revienta:

```zymbol
r = bd::exec(c, sql, params)
? r$! { <~ (#0, "" r) }        // ← aborta aquí, en el manejo del error
```

Un error blando se convierte en uno duro **en el camino del manejo de errores**,
que es el único sitio donde nunca debería pasar. Y el aborto ocurre en la rama
de fallo, la que menos se ejecuta en las pruebas: el programa funciona hasta el
día en que algo va mal, y entonces falla de una segunda manera peor.

**Rodeo.** No convertir nunca: devolver el valor de error tal cual y dejar que
la capa que lo muestra use `>>`. Está en `núcleo/almacén.zy` (todas las
funciones que devuelven `(#0, error)`) y en `interfaz/cli.zy`, donde cada
`>> err ¶` lleva la anotación de por qué no puede ser `>> "" err ¶`.

El coste es que un error no se puede meter en una cadena más larga, ni
registrar, ni traducir, ni acompañar de contexto. Solo imprimirse solo.

**Emparentado con [GAP-ZYB-008](#gap-zyb-008)**, que es lo mismo para arreglos y
diccionarios. La diferencia por la que este va aparte: un arreglo que no se
puede convertir es una molestia; un error que no se puede convertir rompe el
manejo de errores.

---

## BUG-ZYB-004

**Un `<# ../módulo` se resuelve o no según cómo se nombre el archivo en la línea de órdenes. Y falla con tres mensajes distintos.**

**Reproducción.** Dos directorios hermanos y un import que sube un nivel:

```zymbol
// rel/lib/util.zy
# .util {
    #> { dos }
    dos() { <~ 2 }
}

// rel/sub/prog.zy
<# ../lib/util => u
>> u::dos() ¶
```

| invocación | resultado |
|---|---|
| `cd rel && zymbol run sub/prog.zy` | `2` |
| `cd rel/sub && zymbol run prog.zy` | `Runtime error: module not found: ["lib", "util"]` |
| `cd rel/sub && zymbol run ./prog.zy` | `Runtime error: module not found: lib/util.zy` |
| `cd rel/sub && zymbol run --vm prog.zy` | `Runtime error: module not found: lib/util.zy` |

El archivo es el mismo, el import es el mismo y el árbol de directorios es el
mismo. Lo único que cambia es cómo se escribe la ruta al invocarlo — y
`zymbol run prog.zy` desde el directorio donde está el programa es la forma más
natural que existe de ejecutar algo.

**Tres mensajes para un fallo.** `["lib", "util"]` (una lista de componentes),
`lib/util.zy` (una ruta) y, en el tree-walker, **uno u otro según se escriba
`prog.zy` o `./prog.zy`**. Eso son dos caminos de código distintos resolviendo
lo mismo, que es lo que hay que mirar antes que el síntoma. Ninguno de los tres
menciona `../`, que es la parte que no se resolvió.

Añadido: `zymbol run "$PWD/rel/sub/prog.zy"` desde `/tmp` respondió
`Error: failed to read file`, sin más — el `$PWD` de la prueba era otro, pero el
mensaje tampoco dice qué esperaba.

**Emparentado con lo ya conocido.** El proyecto tiene registrada una divergencia
TW/VM de «module not found» cuya mitad de rutas relativas quedó abierta, y
`ModulePath::resolve_from` se introdujo en v0.0.8 como *la regla única de
resolución* compartida por el tree-walker, el analizador semántico y el
compilador de la VM. Estos cuatro casos dicen que la unificación no llegó al
punto donde se decide el directorio base a partir del argumento de la línea de
órdenes.

**Lo que costó aquí.** `pruebas/todas.sh` hacía `cd` a su propio directorio
antes de lanzar las suites — lo que hace cualquier guion de pruebas — y las
cinco fallaron a la vez con «module not found», después de haber pasado todas
ejecutadas a mano desde la raíz. El runner lleva ahora un `cd` a la raíz del
proyecto y un comentario que explica por qué no puede estar donde estaría.

---

## BUG-ZYB-005

**Pasar como valor una función definida dentro de un módulo, a otro módulo, falla en la VM. El tree-walker y el motor del navegador la ejecutan.**

Es el **simétrico** de [BUG-ZYB-001](#bug-zyb-001), y juntos son el hallazgo de
verdad: cada motor tiene su propio agujero al pasar funciones entre módulos, y
no son el mismo agujero.

**Reproducción.**

```zymbol
// m/usa.zy
# .usa {
    #> { aplicar }
    aplicar(f, v) { <~ f(v) }
}

// m/pasa.zy
# .pasa {
    <# ./usa => u
    #> { prueba }
    _mas_uno(x) { <~ x + 1 }
    prueba() { <~ u::aplicar(_mas_uno, 5) }
}

// prueba.zy
<# ./m/pasa => p
>> p::prueba() ¶
```

| motor | resultado |
|-------|-----------|
| zytw | `6` |
| zyvm | `Runtime error: '_mas_uno' is undefined — did you mean '_mas_uno°'?` |
| zyjs | `6` |

**Lo que lo delimita.** La misma función escrita en el **ámbito del archivo**, y
no dentro de un módulo, funciona en los tres:

```zymbol
<# ./m/usa => u
mas_uno(x) { <~ x + 1 }
>> u::aplicar(mas_uno, 5) ¶      // zytw 6 · zyvm 6 · zyjs 6
```

Así que no es «pasar funciones» lo que la VM no sabe: es pasar una función cuyo
ámbito de definición es un **módulo**. El compilador no lleva ese ámbito consigo
en el valor.

**El par completo, que es lo que hay que mirar junto:**

| qué se pasa a otro módulo | zytw | zyvm | zyjs |
|---|---|---|---|
| lambda que usa un alias de módulo | **error** | 6 | 6 |
| función definida en un módulo | 6 | **error** | 6 |
| función definida en el ámbito del archivo | 6 | 6 | 6 |

De las tres formas de pasar una función entre módulos, **cada motor Rust rompe
una distinta**, y la única que funciona en los tres es la que no se puede usar
dentro de un módulo — que es donde vive el código de una aplicación. En la
práctica: **hoy no hay forma de escribir una función de orden superior entre
módulos que funcione en los dos motores Rust.**

Y el mensaje de la VM sugiere `_mas_uno°`, la definición caliente, que no tiene
nada que ver: empuja hacia un rodeo inexistente en lugar de nombrar el problema.

**Cómo se descubrió.** No al escribir el código —el tree-walker lo ejecutaba— ni
en las suites, que corren en los dos motores pero no ejercitan `iniciar`. Salió
al empaquetar: un `.zyp` arranca en `--vm` por omisión, así que la primera
ejecución del paquete fue también la primera vez que esa línea corrió en la VM.

**Cómo se rodeó.** No se rodeó: se quitó la orden de orden superior.
`núcleo/semilla.zy` ya no recibe la función que crea categorías, sino que expone
la lista y quien la tiene la recorre. Es mejor diseño de todos modos —la semilla
no tiene por qué saber que existe una base de datos— pero conviene decir que
llegó a esa forma por un bug y no por gusto.

---

# GAP

## GAP-ZYB-001

**No hay formateo decimal con precisión en tiempo de ejecución, ni relleno de ceros.**

Es el hueco que decide la forma del programa entero, porque el número de
decimales de un importe **es configuración**: el peso chileno no tiene unidad
menor en circulación (exponente 0), el dólar y el euro tienen dos, el dinar
kuwaití tres.

```zymbol
>> #.2|10.5| ¶      // 10.5   — no 10.50: no rellena
n = 2
>> #.n|10.5| ¶      // error: expected integer precision after '#.'
```

La precisión de `#.N|…|` **tiene que ser un literal**, así que un formateador
cuya precisión llega en tiempo de ejecución no puede usarla en absoluto. Y aunque
pudiera, `#.2|10.5|` da `10.5`: para dinero hace falta `10.50`, y eso no lo da
ninguna forma del lenguaje.

**Rodeo.** `núcleo/dinero.zy` — unas 40 líneas de aritmética entera: separar
signo, dividir por 10^exponente, sacar el resto, rellenarlo con ceros hasta el
ancho, agrupar los millares de tres en tres, y decidir el lado del símbolo. Es
código correcto y no debería tener que existir en cada programa que maneje
dinero.

**No es la primera vez.** `zyquality/bench/lib_time.zy` líneas 26–38 rellena
milisegundos a mano con una cadena de tres ramas (`ms < 10` → `".00"`, `ms < 100`
→ `".0"`, si no `"."`). El mismo hueco, parcheado en el sitio hace versiones. Que
dos programas sin relación escriban el mismo rodeo es la señal de que falta algo
en el lenguaje y no en los programas.

---

## GAP-ZYB-002

**No hay `std/time`. La fecha sale del intérprete de órdenes.**

```zymbol
hoy() {
    #09#                      // obligatorio: el modo numeral alcanza al shell
    <~ <\ "date +%F" \>
}
```

Un movimiento contable **es** una fecha; no hay aplicación de este dominio sin
ella. Y la única forma de obtenerla es salir del lenguaje, lo que según
`LDV.md` § 3.4 ya cuenta como estado rojo.

**Lo que arrastra:**

1. **Dependencia del sistema.** `date +%F` no existe en Windows sin más, y es
   justo la plataforma donde `std/db` **sí** viene incluido (el binario Linux
   prebuilt no lo trae). La aplicación que más necesita la base es la que peor
   consigue la fecha.
2. **Ninguna aritmética de fechas.** «El mes pasado», «los últimos 30 días»,
   «¿cuántos días lleva vencido?» — nada de eso se puede calcular. `resumen`
   pide el rango completo escrito a mano por eso.
3. **Se lo lleva por delante el modo numeral.** Con `#०९#` activo, `date +%F`
   devolvería la fecha en devanagari y dejaría de ser ISO 8601. Hay que forzar
   `#09#` antes de cada llamada, y acordarse.
4. **Nada de esto corre en el navegador**, donde no hay shell.

**Relacionado:** `zyquality/bench/lib_time.zy` ya documenta que un epoch en
nanosegundos (~1.7e18) no cabe en el entero i53 y hay que pedir microsegundos.
Un `std/time` nace con esa restricción ya conocida.

---

## GAP-ZYB-003

**No hay literal de diccionario vacío.**

```zymbol
d = ()          // error: expected expression, found RParen
```

El **valor** existe: quitarle a `(a: 1)` su única clave deja un `()` cuyo `$#`
es 0, y se imprime `()`. Solo que no se puede escribir.

```zymbol
d = (a: 1)
d$-["a"]
>> d " " d$# ¶      // () 0
```

Cualquier diccionario que se llene en tiempo de ejecución —un catálogo, una fila
leída de la base, una configuración fusionada— tiene que nacer con una clave
inventada y perderla después. Está en `núcleo/mapa.zy::vacío()`, en un solo
sitio del programa a propósito.

---

## GAP-ZYB-004

**Las claves de un literal de diccionario deben ser identificadores.**

```zymbol
c = ("gasto.alimentación": "Alimentación")   // error de análisis
```

`d["gasto.alimentación"]$~ v` sí las añade y `d["…"]` sí las lee: **la
restricción es solo del literal**. Pero las claves que este programa necesita
escribir son exactamente las que el literal no admite — las que están guardadas
en la base, las que vienen de un JSON, las que llevan prefijo de dominio.

`COLLECTIONS.md` § 5 dice que la clave calculada es *«lo que hace de esto un
diccionario y no un registro»*, y que el corchete existe porque *«una clave JSON
puede ser cualquier cadena»*. El literal se quedó del lado del registro.

**Rodeo.** Los catálogos se escriben como listas de pares y `núcleo/mapa.zy`
las convierte. Se lee bien y encima es la forma que tendría un catálogo cargado
de un archivo — pero es un rodeo, y son 52 claves × 4 idiomas que no se pueden
escribir como lo que son.

---

## GAP-ZYB-005

**Una función de módulo no es un valor de primera clase. Una función local sí.**

```zymbol
<# ./m/base => b
aplicar(f, v) { <~ f(v) }
local(x) { <~ x + 1 }

>> aplicar(local, 5) ¶        // 6 — una función local viaja bien
h = b::doble                  // error: expected '(' for module function call
>> aplicar(b::doble, 5) ¶     // error: el mismo
```

La asimetría es lo grave: en una aplicación modular casi toda función vive en un
módulo, así que el 90% de las funciones no son pasables. Se pierden las HOF
justo donde más sirven — inyectar la operación que un módulo genérico debe
aplicar, que es lo que `núcleo/semilla.zy::sembrar(crear)` quería hacer para no
depender de `núcleo/almacén`.

**Rodeo, y el rodeo del rodeo.** Envolver en lambda funciona… salvo cuando la
lambda cruza a otro módulo, que es [BUG-ZYB-001](#bug-zyb-001). Hay que envolver
en una función **con nombre**.

---

## GAP-ZYB-006

**Un programa no puede fijar su código de salida.**

No hay ninguna forma. `\\` es una nueva línea (`SYMBOLS.md` línea 405, variante
libre de `¶`), no una salida. El `ROADMAP.md` menciona el código de salida de
`zymbol check` — la herramienta —, no el del programa.

Para una aplicación de línea de órdenes el código de salida **es** el contrato
con quien la invoca: `zybank anotar … && echo ok`, un `Makefile`, un gate de CI,
cualquier guion. Sin él la única forma de saber si algo fue mal es analizar el
texto de salida — y ese texto está traducido a cuatro idiomas.

`interfaz/cli.zy` calcula el código correcto en cada orden (0, 1 o 2) y
`zybank.zy` no puede hacer más que imprimirlo.

**Por qué no había salido antes:** las suites del proyecto deciden por goldens,
comparando salida. Un proyecto que solo se prueba comparando texto nunca echa de
menos el código de salida.

---

## GAP-ZYB-007

**La concatenación por yuxtaposición no se admite en los argumentos de una llamada.**

```zymbol
frac = rellenar("" resto, exp, cero)      // error: expected ')' after function arguments
x = "" resto                              // fuera de la llamada, bien
frac = rellenar(x, exp, cero)             // así sí
```

Funciona en asignación, en `>>` y en `<~`, pero no como argumento. Obliga a una
variable intermedia por cada valor que se convierta a texto al llamar. Es menor
comparado con el resto, pero es de la misma familia que
[BUG-ZYB-002](#bug-zyb-002): la yuxtaposición vale en unos sitios y no en otros,
y no hay regla escrita que diga cuáles.

---

## GAP-ZYB-008

**Un agregado se puede imprimir pero no se puede llevar a una cadena.**

```zymbol
a = [1, 2, 3]
>> "arr: " a ¶      // arr: [1, 2, 3]   ← funciona
s = "" a            // Runtime error: cannot juxtapose value of type
                    // Array([Int(1), Int(2), Int(3)]) in string context
```

La misma yuxtaposición, el mismo valor, y el resultado depende de dónde esté
escrita. Igual con un diccionario: `>> "d: " t ¶` imprime `d: (x: 1)` y
`s = "" t` falla.

El intérprete **sabe** producir esa representación —la imprime— pero no la deja
salir a una variable. Así que no se puede meter un arreglo en un mensaje de
error, ni en una línea de registro, ni en un valor que se guarde, ni compararlo
como texto en una prueba. Solo imprimirlo.

Es la misma familia que [BUG-ZYB-002](#bug-zyb-002) y
[GAP-ZYB-007](#gap-zyb-007): la yuxtaposición vale en unos sitios y no en otros,
y no hay regla escrita que diga cuáles. Los tres juntos sugieren que lo que
falta es una regla, no tres parches.

**Dónde se pagó.** `pruebas/verificación_dinero.zy` quería comprobar la forma
del reparto comparando `"" d::repartir(10000, 3)` con `"[3334, 3333, 3333]"`.
Hay que comparar elemento por elemento.

---

## GAP-ZYB-009

**No hay forma de preguntar si una columna vino `NULL`, y `std/db` no documenta qué llega cuando viene.**

Una columna opcional es lo corriente en cualquier esquema. Aquí lo son
`movimientos.categoría` (los asientos de un traspaso no tienen categoría) y
`movimientos.traspaso` (los movimientos corrientes no pertenecen a ninguno).

Un `NULL` de SQL llega como `Unit`, y no responde a ninguna de las preguntas
que uno haría:

```zymbol
f = bd::query_one("c", "SELECT m FROM t WHERE id = 1")   // m es NULL

>> f.m$!      ¶     // #0   — NO es un error
>> (f.m == "")¶     // #0   — NO es la cadena vacía
>> (f.m == 0) ¶     // #0   — NO es cero
>> f.m        ¶     //      — se imprime como nada
s = "" f.m          // Runtime error: cannot juxtapose value of type Unit
```

La única forma es destructurar la reflexión de tipo y leer un campo cuyo
significado no está escrito en ninguna parte:

```zymbol
es_nulo(v) {
    (_t, hay, _val) = v#?
    <~ hay == 0
}
```

**Lo documentado y lo no documentado.** `GUIDE.md` dice `null ↔ Unit` — en la
sección de **`std/json`**. La sección de `std/db` describe las filas como
`NamedTuple`s con una entrada por columna y no menciona `NULL` ni una vez, que
es la primera pregunta que se hace quien lee una columna opcional.

**Lo que costó.** El código escrito de la forma natural, `? f.categoría$! { … }`,
**no da error**: `$!` responde `#0` para un `NULL` igual que para un valor, así
que la rama simplemente no se toma nunca y la etiqueta correcta no aparece. Otro
fallo silencioso, y en el mismo sitio donde uno cree estar comprobando algo.

Lo mínimo sería documentarlo; lo razonable, un `$∅` o equivalente que pregunte
directamente, dado que `$!` ya existe para la pregunta hermana.

---

# ERROR

## ERROR-ZYB-001

**Una sentencia que es solo un identificador no produce ni error, ni aviso, ni nada en `zymbol check`.**

```zymbol
v = "X"
v          // no hace nada; nadie dice nada
```

`zymbol check` responde `No errors or warnings`.

Por sí solo es inofensivo. Lo que lo hace un hallazgo es que es **el mecanismo
que vuelve silencioso a [BUG-ZYB-002](#bug-zyb-002)**: cuando el análisis parte
`d[k]$~ "" v` en dos, el resto cae en esta sentencia sin efecto y desaparece sin
ruido. Si un identificador suelto fuera un aviso, aquel fallo se habría visto al
escribirlo en vez de tres módulos más tarde.

El analizador ya avisa de variables sin usar y de tiempos de vida ambiguos, así
que la maquinaria para decirlo ya está.

---

## ERROR-ZYB-002

**Usar una variable del ámbito del archivo dentro de una función pasa `zymbol check` limpio y revienta en tiempo de ejecución.**

Que una función no alcance el ámbito del archivo está documentado y es
deliberado (`GUIDE.md` § 10b: una llamada directa es *isolated*). El hallazgo no
es la regla: es que **el analizador conoce la regla y no la aplica**.

```zymbol
n = 0
f() { <~ n }         // zymbol check → No errors or warnings
>> f() ¶             // Runtime error: 'n' is undefined — did you mean 'n°'?
```

Y sin embargo sí detecta el nombre que no existe en ninguna parte:

```zymbol
f() { <~ jamás_definida + 1 }    // error: undefined variable 'jamás_definida'
```

O sea: el analizador **busca el nombre y lo encuentra** en el ámbito del
archivo, que es precisamente el ámbito que la función no puede ver. Un nombre
inexistente se detecta; uno existente pero inalcanzable, no. Es el peor reparto
posible, porque el segundo caso es el que un programador escribe sin darse
cuenta — el primero se ve al teclearlo.

**Lo que costó aquí.** Las cuatro suites de `pruebas/` llevaban un contador
`fallos` de archivo que las funciones de comprobación incrementaban. Pasaban
`check`, y pasaban al ejecutarse **mientras no fallara nada**: la rama que toca
el contador es la del fallo. Una suite que no puede informar de un fallo —que
aborta en vez de contarlo— es exactamente el defecto que `zyquality` documenta
en los runners que decidían con `grep -q FAIL`, y aquí lo habría escondido el
analizador.

El mensaje de ejecución, además, sugiere `n°` (definición caliente), que es un
mecanismo de ámbito de bucle y no lo que hace falta aquí; empuja hacia un rodeo
en lugar de hacia el aislamiento que la regla pide.

---

## ERROR-ZYB-003

**Todo bucle `@ x:colección` escrito en el cuerpo del archivo produce un aviso falso, y la solución que el propio aviso sugiere no analiza.**

```zymbol
l = ["a", "b"]
@ c:l {
    >> c ¶
}
```

```text
warning: ambiguous lifetime for 'c'
  = note: variable is modified inside a loop
  = help: consider using explicit lifetime annotation
```

`c` no se modifica en ninguna parte. El bucle es la forma idiomática de recorrer
una colección, tres líneas, sin nada raro.

**La condición exacta** — importa, porque explica por qué esto no había salido:

| dónde está el bucle | aviso |
|---|---|
| cuerpo del archivo | **sí** |
| dentro de una función | no |
| dentro de un módulo | no |

Se dispara con cualquier forma: literal (`@ c:["a"]`), variable, rango
(`@ i:1..3`), llamada (`@ c:f()`) y diccionario. Dos bucles dan dos avisos.

Los seis proyectos LDV anteriores tienen **cero** avisos de estos, comprobado
sobre `serpiente/dibujo.zy`, los tres módulos de `GO/表示/`, `Chaturanga/दर्शनम्/चित्रणम्.zy`
y los siete de `klingon_galaxy/` — porque en una aplicación todo el código vive
en funciones y módulos. Lo que se escribe en el cuerpo de un archivo son los
**guiones y las suites de prueba**, que es exactamente lo que este proyecto
tiene y lo que aquellos delegaban en `bash`.

**La ayuda empeora el aviso.** Sugiere una anotación explícita de tiempo de
vida, que es el operador `°`. Pero la forma que haría falta en la posición del
iterador no se puede escribir:

```zymbol
@ c°:l { … }        // error: expected '{' to start block
```

Lo único que lo silencia es `_c` — el prefijo de *no usada* — y ponérselo a una
variable que sí se usa es mentir en el código para callar un aviso falso. Peor
el remedio.

**Por qué merece arreglarse y no ignorarse.** Un aviso falso en la construcción
más común del lenguaje enseña a no leer los avisos. Y los avisos de este
analizador son buenos: `ambiguous lifetime` de verdad, variables sin usar,
tiempos de vida en acumuladores. Este los devalúa a todos.

---

# IDEA

## IDEA-ZYB-001

**El formato numérico es un cuarto eje de i18n, y `USERAPPI18N.md` no lo cubre.**

El documento reconoce tres mecanismos: capas de reexportación para el código,
módulos despachadores para el texto, y el modo numeral para la escritura de las
cifras. ZyBank necesita un cuarto, que es independiente de los tres:

| eje | ejemplo |
|-----|---------|
| idioma del texto | `Saldo` / `Balance` / `残高` |
| escritura de las cifras | `1234` / `१२३४` |
| **formato del número** | `1.234,56` / `1,234.56` / `1234.560` |
| moneda | símbolo, lado, exponente |

Que son ejes distintos se ve al cruzarlos: hindi con dinar kuwaití da
`-२५.९९० د.ك` — cifras devanagari, símbolo árabe, tres decimales — y está bien,
porque el idioma de quien lee no dice en qué moneda tiene el dinero. Un
`std/format` o una sección nueva de `USERAPPI18N.md` evitaría que cada
aplicación redescubra esto.

## IDEA-ZYB-002

**El dinero como entero en la unidad menor merece estar escrito como doctrina.**

`COLLECTIONS.md` es el punto de record de las colecciones porque tres formas de
equivocarse con ellas se repetían. El dinero tiene la misma propiedad: en cuanto
alguien escriba `saldo = 10.50` en Zymbol, tendrá el mismo error de redondeo
binario que en cualquier otro lenguaje, y no habrá nada que lo prevenga.

Lo que ZyBank demuestra que hay que decir: el importe es un entero en la unidad
menor; el exponente pertenece a la **moneda**, no al programa; el rango i53
aguanta ±90 billones de céntimos; y una división de dinero se reparte
(`dinero::repartir`) en vez de redondearse, porque las partes tienen que sumar
exactamente el total.
