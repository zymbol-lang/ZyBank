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
> **Estado del ciclo.** En revisión desde el 2026-08-21. **Los once BUG están
> cerrados** —incluidos BUG-ZYB-009, 010 y 011, que aparecieron durante la
> propia revisión— y con ellos GAP-ZYB-001 y 008, ERROR-ZYB-003 y el
> ERROR-ZYB-005 que salió al comprobar un GAP. El gate va verde después de cada
> uno: `zyq suite` da *all gates pass*, con 637 archivos de corpus, **0
> divergencias** entre los tres motores y ningún retroceso de rendimiento.
>
> Quedan por decidir o implementar GAP-ZYB-002 a 006, 009 y 012, ERROR-ZYB-001 y
> 002, y las dos IDEA.
>
> Cerrar exige un cambio en el lenguaje o un rechazo razonado, y esa decisión no
> es de quien escribe la aplicación: las de esta tanda las tomó quien mantiene
> el lenguaje, hallazgo por hallazgo.

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

De los treinta hallazgos —11 BUG, 12 GAP, 5 ERROR, 2 IDEA— la mitad larga sale
de esas intersecciones y no de una característica aislada, que es el argumento
de `LDV.md` § 4 en concreto. Los dos peores lo dejan claro: pasar una función
entre módulos rompe en el tree-walker de una manera
([BUG-ZYB-001](#bug-zyb-001)) y en la VM de otra
([BUG-ZYB-005](#bug-zyb-005)), y hacen falta **tres** características compuestas
para llegar a cualquiera de los dos.

**La interfaz de pantalla completa añadió cinco más**, y una de ellas —
[BUG-ZYB-007](#bug-zyb-007) — llevaba desde el primer día en la CLI sin que
ninguna suite la viera, porque todas consultaban cosas que existían. Eso es la
tesis del método en pequeño: la superficie nueva no encontró un fallo *nuevo*,
encontró uno viejo que nadie había tenido motivo de pisar. Las otras cuatro
salen de que **nadie había escrito antes un campo de entrada en Zymbol**: el
teclado pierde el modificador Control y colapsa dos teclas en una
([BUG-ZYB-006](#bug-zyb-006)) y el tree-walker repinta un estado que ya se
había limpiado ([BUG-ZYB-008](#bug-zyb-008)).

**Seis** hallazgos de esta lista resultaron ser **falsos o mal enunciados**, y
merecen decirse aquí antes que en su ficha. Los dos últimos salieron al
revisarlos uno por uno: [GAP-ZYB-007](#gap-zyb-007) culpaba a la yuxtaposición
de un error del inferidor de tipos, y [GAP-ZYB-001](#gap-zyb-001) daba por
ausente un relleno de ceros que el lenguaje tenía, tras probarlo con el operador
de al lado —`#.N`, que devuelve un número— en vez de con el que formatea. Cinco
de los seis comparten la forma: se probó **el operador contiguo** al que
respondía la pregunta. El cuarto es
[BUG-ZYB-008](#bug-zyb-008), y no era falso sino **mal localizado**: decía que el
problema estaba en escribir dentro de `>>|`, y no tenía que ver con `>>|`, ni con
el teclado, ni con la pantalla completa. El caso mínimo son doce líneas de dos
funciones y una variable. Lo interesante es *por qué* se localizó mal: la
evidencia disponible —una interfaz de pantalla completa— admitía dos
explicaciones, y se eligió la que señalaba al constructo raro en vez de a la
llamada corriente. Los seis casos mínimos que se escribieron después salieron
todos de esa hipótesis, y ninguno la contradijo porque ninguno la ponía a
prueba. [GAP-ZYB-010](#gap-zyb-010) y
[GAP-ZYB-012](#gap-zyb-012) sostenían que no se puede ir de un carácter a su
número ni al revés. Sí se puede — `0d27` es ESC y `##!'७'` es 2413 — y los dos
salieron del mismo experimento incompleto: se probaron `###` y `#|…|`, y no
`##!`, que es el operador de esa pregunta. El coste fue trece tablas de glifos
escritas a mano y dos procesos del intérprete de órdenes por tecla pulsada, todo
ello para rodear algo que el lenguaje hacía desde v0.0.8.

[GAP-ZYB-011](#gap-zyb-011) es el tercero y el más caro de los tres, porque es
el único que llegó a los dedos de alguien: decía que las flechas no se pueden
usar sin perder ESC, razonando sobre los tres bytes que manda el terminal en
vez de probar lo que `<<|` entrega — que es **un** carácter, `'↓'`, con el ESC
suelto todavía distinguible. La aplicación ignoraba la flecha abajo, y una
lista que no responde a `↓` no parece una lista con otro convenio: parece una
lista rota. Lo destapó un usuario, no una suite, y no es casualidad — la
secuencia del arnés de pty entraba con `⏎` en la primera cuenta, así que la
navegación por la lista no se ejercitaba nunca. El hueco de cobertura y el
hallazgo falso se sostenían el uno al otro: nadie probaba las flechas porque
una ficha decía que eran imposibles, y la ficha seguía en pie porque nadie las
probaba.

La lección que se sacó de ellos sigue en pie y ahora se aplica a sí misma: una
aplicación descubre lo que un corpus no, **y también se equivoca de una manera
que un corpus no** — dando por ausente una capacidad tras probar el operador
equivocado. Un hallazgo contra el lenguaje no vale más que la prueba que lo
sostiene, y la prueba tiene que agotar los operadores que podrían responder,
no el primero que se pruebe. La que sí resistió es la que llevó hasta ahí: la
aplicación imprimía «$१२,३४५.०७» y le rechazaba al usuario el «१» que tecleaba,
y ningún caso de prueba lo iba a descubrir, porque un caso de prueba no tiene
teclado.

---

## Resumen

| ID | Tipo | Módulo | Contexto | Estado |
|----|------|--------|----------|--------|
| [BUG-ZYB-001](#bug-zyb-001) | BUG | intérprete (TW) | una lambda pierde los alias de módulo al invocarse dentro de otro módulo — **TW falla, VM y JS no** | **corregido** · v0.0.9 |
| [BUG-ZYB-002](#bug-zyb-002) | BUG | gramática / los 3 motores | `d[k]$~ "" v` asigna `""` y **descarta `v` sin decir nada** | **corregido** · v0.0.9 |
| [BUG-ZYB-003](#bug-zyb-003) | BUG | errores blandos | componer un mensaje con un error blando **aborta el programa** — solo el TW | **corregido** · v0.0.9 |
| [BUG-ZYB-004](#bug-zyb-004) | BUG | resolución de módulos | un `<# ../x` funciona o no **según cómo se nombre el archivo** al ejecutarlo | **corregido** · v0.0.9 |
| [BUG-ZYB-005](#bug-zyb-005) | BUG | compilador (VM) | pasar una función **de un módulo** a otro módulo funciona en TW y JS, y **falla en la VM** | **corregido** · v0.0.9 |
| [BUG-ZYB-006](#bug-zyb-006) | BUG | entrada de teclado | `<<|` entrega Ctrl+letra **como la letra**, y colapsa Tab y retroceso en un mismo valor | **corregido** · v0.0.9 |
| [BUG-ZYB-007](#bug-zyb-007) | BUG | `std/db` | `query_one` sin filas **no da el error blando que la documentación promete**; `$!` nunca se dispara | **corregido** · v0.0.9 |
| [BUG-ZYB-008](#bug-zyb-008) | BUG | estado de módulo (TW) | el estado del módulo leído **a través de una función que no lo nombra** da el valor anterior — TW sí, VM y JS no. No tenía que ver con `>>|` | **corregido** · v0.0.9 (MM-12) |
| [BUG-ZYB-009](#bug-zyb-009) | BUG | errores (TW) | `$!!` dentro de un `!?` **se captura como excepción** — TW sí, VM y JS no, y la documentación da la razón a estos dos | **corregido** · v0.0.9 |
| [BUG-ZYB-010](#bug-zyb-010) | BUG | errores (TW y VM) | un `:>` (finally) **no se ejecuta entero** cuando el bloque `!?` retorna: el TW se comía media sentencia, la VM se lo saltaba del todo | **corregido** · v0.0.9 |
| [BUG-ZYB-011](#bug-zyb-011) | BUG | errores (JS) | un `<~` escrito **dentro** de un `:>` retorna desde ahí en los dos motores Rust y se ignora en el del navegador | **corregido** · v0.0.9 |
| [GAP-ZYB-001](#gap-zyb-001) | GAP | formato numérico | ~~no hay precisión decimal en tiempo de ejecución **ni relleno de ceros**~~ — el relleno ya existía en `#,.N`; la precisión variable ya se puede escribir | **corregido · enunciado a medias** |
| [GAP-ZYB-002](#gap-zyb-002) | GAP | `std/` | no hay `std/time`: la fecha sale del intérprete de órdenes | abierto |
| [GAP-ZYB-003](#gap-zyb-003) | GAP | diccionario | no hay literal de diccionario vacío | abierto |
| [GAP-ZYB-004](#gap-zyb-004) | GAP | diccionario | las claves del literal deben ser identificadores | abierto |
| [GAP-ZYB-005](#gap-zyb-005) | GAP | módulos | una función de módulo no es un valor de primera clase | abierto |
| [GAP-ZYB-006](#gap-zyb-006) | GAP | CLI | un programa no puede fijar su código de salida | **corregido** · v0.0.9 |
| [GAP-ZYB-007](#gap-zyb-007) | GAP | gramática | ~~la yuxtaposición no se admite en argumentos de llamada~~ — sí se admite; el error era del inferidor de tipos ([ERROR-ZYB-005](#error-zyb-005)) | **retirado · era falso** |
| [GAP-ZYB-008](#gap-zyb-008) | GAP | conversión a texto | un agregado se imprime con `>>` pero no se puede llevar a una cadena — solo el TW | **corregido** · v0.0.9 |
| [GAP-ZYB-009](#gap-zyb-009) | GAP | `std/db` | no hay forma de preguntar si una columna vino `NULL`, ni queda documentado qué es | abierto |
| [GAP-ZYB-010](#gap-zyb-010) | GAP | literales | ~~no hay forma de escribir un carácter de control~~ — sí la hay: `0d27` es ESC, y `##!` da el punto de código | **retirado · era falso** |
| [GAP-ZYB-011](#gap-zyb-011) | GAP | TUI | ~~las flechas del teclado no se pueden usar sin perder la tecla ESC~~ — `<<|` las entrega decodificadas y ESC sigue llegando solo | **retirado · era falso** |
| [GAP-ZYB-012](#gap-zyb-012) | GAP | caracteres | ~~el lenguaje escribe 69 escrituras y no sabe leer ninguna~~ — `##!` sobre un `Char` da su punto de código; lo que falta es el predicado `es_dígito`, no la lectura | **muy reducido** |
| [ERROR-ZYB-001](#error-zyb-001) | ERROR | semántica | una sentencia que es solo un identificador no produce diagnóstico | abierto |
| [ERROR-ZYB-002](#error-zyb-002) | ERROR | `check` / semántica | leer una variable del archivo desde una función pasa `check` y revienta en ejecución | abierto |
| [ERROR-ZYB-003](#error-zyb-003) | ERROR | analizador | aviso **falso** en todo `@ x:col` escrito en el cuerpo del archivo, con una ayuda que no analiza | **corregido** · v0.0.9 |
| [ERROR-ZYB-004](#error-zyb-004) | ERROR | `check` / analizador | ~~`zymbol check` rechaza un `<# ../lib/util` que `zymbol run` ejecuta~~ — el convenio del punto dice que `# .lib_util` nombra la ruta entera; el archivo de la prueba estaba mal escrito | **retirado · era falso** |
| [ERROR-ZYB-005](#error-zyb-005) | ERROR | inferidor de tipos | yuxtaponer un parámetro lo obliga a ser `String`, así que **los dos motores Rust rechazan un programa correcto** que el del navegador ejecuta | **corregido** · v0.0.9 |
| [IDEA-ZYB-001](#idea-zyb-001) | IDEA | doctrina i18n | el formato numérico es un cuarto eje que `USERAPPI18N.md` no cubre | propuesta |
| [IDEA-ZYB-002](#idea-zyb-002) | IDEA | doctrina | el dinero como entero + exponente merece ser doctrina escrita | propuesta |

Los motores se nombran como en `zyquality/engines.toml`: **zytw** (tree-walker),
**zyvm** (VM de registros), **zyjs** (el del navegador). Toda reproducción se
ejecutó en los tres con `./zyq show`.

---

# BUG

## BUG-ZYB-001

**Una lambda pierde los alias de módulo cuando se invoca dentro de otro módulo. El tree-walker falla; la VM y el motor del navegador no.**

> **CORREGIDO** en v0.0.9. Una lambda lleva ahora los alias del ámbito donde se
> escribió, exactamente como ya hacía una función con nombre: el mecanismo
> existía y estaba cerrado con `if func.is_named_fn`, y las lambdas se creaban
> con el mapa vacío. Congelar los alias en la definición es seguro **por
> construcción**, porque el parser rechaza un `<#` escrito después de cualquier
> sentencia: cuando se evalúa una lambda, todos los imports del archivo ya
> están dentro. El mapa va tras un `Rc`, así que una lambda creada en un bucle
> cuesta un contador, no una copia. Casos en
> `corpus/modules_scope/zyb/`, los tres de la tabla de abajo.

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

> **CORREGIDO** en v0.0.9, en los tres. El valor de `$~` se analiza ahora como
> una expresión completa —yuxtaposición incluida—, que es lo que acepta el lado
> derecho de `=`, porque `d[k]$~ v` **es** una asignación: es como se escribe
> dentro de una colección. Antes se tomaba un solo postfix y el resto de la
> línea quedaba suelto. De paso funcionan `d[k]$~ 40 + 2` y
> `d[k]$~ "pre" v "post"`, que antes fallaban. Caso en
> `corpus/collections/dict_update_yuxtaposicion.zy`.
>
> **Corrección al enunciado de abajo: `$+` nunca fue el contraejemplo.** No
> acepta la yuxtaposición en su operando derecho, y nunca la aceptó. En
> `t = s$+ "" v` quien concatena es la **asignación**, no el `$+`; sobre un
> arreglo de enteros, `a$+ "" v` sigue fallando por el `""` a secas. La
> asimetría real no era entre dos operadores `$`, sino entre una **asignación**
> y una **sentencia de edición** — y es la misma que [GAP-ZYB-007](#gap-zyb-007)
> describe por el lado de los argumentos de llamada. La prueba original no lo vio
> porque estaba escrita dentro de un `>>`, que yuxtapone por su cuenta.

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

> **CORREGIDO** en v0.0.9. **Y era una divergencia, no un fallo de los tres**:
> la VM de registros y el motor del navegador ya concatenaban el error sin
> problema; solo el tree-walker abortaba. Eso hizo el arreglo trivial —no había
> nada que diseñar, solo que el tree-walker hiciera lo que los otros dos ya
> hacían— y hace la ficha original inexacta al presentarlo como propio del
> lenguaje entero. Caso en `corpus/errors/catchable/error_en_cadena.zy`, con el
> error construido a partir de un índice fuera de rango para que el mensaje sea
> el mismo en toda plataforma.

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

> **CORREGIDO** en v0.0.9, en `ModulePath::resolve_from` — la regla única, así
> que el tree-walker, el analizador semántico y el compilador de la VM se
> arreglaron a la vez. Salir de un nombre que **no es** un nombre de directorio
> añade ahora `..` en vez de hacer `pop`: `parent()` de `prog.zy` es `""`, y
> `PathBuf::pop` sobre `""` devuelve `false`; con `./prog.zy` es `"."`, donde
> `pop` sí funciona y **se traga el `../` en silencio**, que era el caso peor.
> Las rutas relativas siguen siéndolo, para que ningún diagnóstico —ni ningún
> golden que lo grabe— lleve dentro una ruta absoluta que cambia según la
> máquina. Cuatro pruebas unitarias en `zymbol-ast/src/modules.rs`; el corpus no
> puede cubrir esto, porque `zyq` invoca todos los archivos igual.
>
> **Corrección al enunciado: la ruta absoluta sí funcionaba.** El
> `failed to read file` del añadido de abajo era la variable `$PWD` de la prueba
> mal expandida, como el propio texto sospechaba. Comprobado con la ruta
> absoluta real: da `2`.

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

> **CORREGIDO** en v0.0.9. El compilador consultaba `module_scope` al compilar
> una **llamada** y no al compilar el mismo nombre como **valor**: esa asimetría
> era todo el fallo. Llamar a `_ayudante(x)` funcionaba y pasar `_ayudante` no.
> Caso en `corpus/modules_scope/zyb/fn_de_modulo_cruzando.zy`, junto al de
> [BUG-ZYB-001](#bug-zyb-001) y al tercero de la tabla —el que ya funcionaba—,
> que está ahí para que ningún arreglo lo rompa.

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

## BUG-ZYB-006

**`<<|` entrega Ctrl+letra como la letra, y colapsa el tabulador y el retroceso en un mismo valor.**

> **CORREGIDO** en v0.0.9, en los dos motores que tienen terminal. Cada tecla
> trae ahora lo que el terminal manda: Ctrl+A es `0d1`, Ctrl+S es `0d19`, el
> tabulador es `0d9` y el retroceso es `0d127`. **No hizo falta ningún símbolo
> nuevo**: `0dNN` ya escribe un carácter de control y `##!t < 32` ya hace la
> pregunta. ESC, ENTER y las flechas siguen igual, y se comprueban para que el
> arreglo no las rompiera.
>
> **Por qué ninguna suite lo veía**, que es más interesante que el fallo:
> `zyquality/tui/run.sh` comparaba los motores **entre sí**, y los dos estaban
> mal de la misma manera. Para un comparador eso es acuerdo, y lo era. Ahora un
> caso puede llevar un golden además del consenso —`keys_control.zy`— y un
> golden desfasado se cuenta aparte de una divergencia: son dos cosas
> distintas, y solo la primera puede detectar un fallo que los motores
> comparten. Es la misma división que `zyquality` ya hacía en todo lo demás.

Medido escribiendo a un archivo lo que `<<|` devuelve y mirando los bytes, con el
programa conducido por un pty de verdad:

| tecla enviada | byte recibido | qué significa |
|---|---|---|
| `Ctrl+A` `0x01` | `0x61` = `a` | **indistinguible de la letra `a`** |
| `Ctrl+C` `0x03` | `0x63` = `c` | indistinguible de `c` |
| `Ctrl+H` `0x08` | `0x68` = `h` | indistinguible de `h` |
| `Tab` `0x09` | `0x00` | |
| **retroceso** `0x7f` | `0x00` | **el mismo valor que el tabulador** |
| `ESC` `0x1b` | `0x1b` | correcto |
| `Enter` `0x0d` | `0x0a` | normalizado a LF — correcto y deseable |
| `ñ` `0xc3 0xb1` | `ñ` | correcto: llega un grapheme entero, no dos bytes |

Dos pérdidas distintas, y las dos son de información:

1. **El modificador Control desaparece.** Una aplicación de pantalla completa no
   puede ofrecer `Ctrl+S`, `Ctrl+Q` ni `Ctrl+C`, porque no puede distinguirlos de
   `s`, `q` y `c`. No es que la combinación no llegue: llega, disfrazada de otra
   tecla, que es peor — un atajo `Ctrl+X` se dispararía al escribir una `x` en un
   campo de texto.
2. **Dos teclas, un valor.** El tabulador y el retroceso son ambos `0x00`. En un
   campo numérico da igual, y este programa lo aprovecha (`pantalla/teclas.zy`
   trata las dos como «borrar»). En un formulario donde el tabulador saltase de
   campo sería imposible: cada salto borraría un carácter.

El valor en que colapsan, `0x00`, sí se puede escribir: es `0d0`, y
`pantalla/teclas.zy` compara contra él directamente. Lo que no se puede es
distinguir cuál de las dos teclas lo produjo, que es este hallazgo y no
[~~GAP-ZYB-010~~](#gap-zyb-010).

**Lo esperable** sería que `<<|` entregase la tecla sin traducir, y que una
aplicación pudiera preguntar por el modificador. Mientras tanto, cualquier TUI
escrita en Zymbol está limitada a teclas imprimibles, ESC y Enter.

---

## BUG-ZYB-007

**`query_one` sin filas no devuelve el error blando que la documentación promete. `$!` nunca se dispara, y el programa revienta después y en otro sitio.**

> **CORREGIDO** en v0.0.9: sin filas devuelve `##DB(query_one matched no rows)`,
> que es lo que `GUIDE.md` prometía desde el principio, así que `? fila$!` —la
> comprobación que la documentación indica— por fin se dispara.
>
> **Las dos preguntas quedan separadas**: una fila que no existe es un error
> blando; una columna que vino `NULL` sigue siendo `Unit`, y eso **no** se
> arregló — es [GAP-ZYB-009](#gap-zyb-009), abierto. `query_value` también
> mantiene `Unit` a propósito: su resultado es un escalar, y un escalar puede
> legítimamente *ser* `NULL`, así que ahí los dos vacíos sí son el mismo valor.
>
> En el programa, `es_nulo` se partió en dos: `sin_fila(v)` es `v$!` y `es_nulo(v)`
> se queda para la columna. `zybank anotar CuentaQueNoExiste …` responde ahora
> «No existe esa cuenta» en los dos motores — el mensaje que llevaba desde el
> primer día escrito, traducido a cuatro idiomas y muerto. Caso en
> `corpus/stdlib/stdlib_db_sin_filas.zy`.

`GUIDE.md` § `std/db` dice: *«`query` returns an array of rows, `query_one` a
single row (**or soft error**)»*. Así que la comprobación evidente —y la que la
documentación prescribe— es `? fila$!`.

```zymbol
hay = bd::query_one("c", "SELECT id, n FROM t WHERE id = ?", (1,))
>> hay$! ¶      // #0 — hay fila

no = bd::query_one("c", "SELECT id, n FROM t WHERE id = ?", (99,))
>> no$! ¶       // #0 — NO hay fila, y responde lo mismo
```

Sin filas devuelve `Unit`, exactamente igual que una columna `NULL`
([GAP-ZYB-009](#gap-zyb-009)), y `Unit` no es un error. De modo que:

```zymbol
cuenta = al::cuenta_por_nombre(nombre)
? cuenta$! {
    >> "no existe esa cuenta" ¶      // ← esta rama NUNCA se toma
    <~ 2
}
m = mon::obtener(cuenta.moneda)      // ← Runtime error: Cannot access member
                                     //   'moneda' on non-tuple value
```

**El daño es que el fallo aparece lejos de la causa.** El mensaje no habla de
filas ni de consultas: habla de una tupla, en una línea que está bien escrita.
Quien lo lea buscará el error donde no está.

**Dónde se pagó.** Estaba en la CLI **desde el primer día** y ninguna suite lo
vio, porque todas consultan cosas que existen. `zybank anotar CuentaQueNoExiste …`
respondía `Runtime error: Cannot access member 'moneda' on non-tuple value` en
lugar de «No existe esa cuenta», que era el mensaje ya escrito, ya traducido a
cuatro idiomas y muerto. Lo descubrió el TUI: al elegir una categoría de ajuste
que aún no existía, la misma forma falló en un sitio nuevo.

Corregido en el programa comprobando `es_nulo()` —la reflexión de tipo— en las
nueve consultas que podían no encontrar nada. La corrección en el lenguaje es
otra: o `query_one` devuelve el error blando que promete, o la documentación
dice que devuelve `Unit` y `$!` deja de ser la comprobación indicada.

---

## BUG-ZYB-008

**El estado de un módulo leído a través de una función que no lo nombra da el valor anterior a la escritura. El tree-walker sí; la VM y el motor del navegador no.**

> **CORREGIDO** en v0.0.9. Está en `interpreter/MEMORY_MODEL.md` como **MM-12**,
> con el resto de hallazgos del modelo de memoria, y el caso vive en
> `corpus/modules_scope/estado_por_intermedia.zy` — en el corpus, que es donde
> protege a los tres motores y no solo a esta aplicación.

> **Y el enunciado de arriba era casi todo falso.** No tenía que ver con `>>|`,
> ni con el teclado, ni con un bloque anidado, ni con la interfaz de pantalla
> completa. El caso mínimo son **doce líneas** sin nada de eso:
>
> ```zymbol
> # .min {
>     #> { correr }
>     v = "viejo"
>     _lee()   { >> "lee=[" v "]" ¶ }
>     _medio() { _lee() }
>     correr() {
>         v = "nuevo"
>         _lee()       // TW: nuevo · VM: nuevo · JS: nuevo
>         _medio()     // TW: VIEJO · VM: nuevo · JS: nuevo
>     }
> }
> ```
>
> La misma función, llamada directamente, ve el valor nuevo; llamada a través de
> una intermedia, ve el viejo. Eso es mucho más grave que un repintado: cualquier
> aplicación modular con un nivel de indirección leía estado obsoleto, y las
> tres aplicaciones LDV anteriores no lo notaron porque ninguna lo hacía.

**La causa.** Una escritura al estado del módulo llegaba al almacén solo cuando
retornaba el marco que la hizo. Hasta entonces la veía ese marco, y también lo
que ese marco llamara **directamente** — porque la inyección busca una copia
viva en el ámbito del llamante antes de recurrir al almacén. Una función en
medio que no menciona la variable, y por tanto no recibe nada de ella, y la
llamada siguiente lee el almacén, que aún no se ha enterado.

**Por qué los seis casos mínimos no lo cazaron**, que es la lección: todos
llamaban al lector **directamente**, y la llamada directa era justo la forma que
funcionaba. No estaban mal escritos; estaban escritos alrededor del agujero.

**Qué se observa.** `pantalla/tui.zy` guarda un aviso como estado del módulo. El
bucle principal lo pinta y lo limpia:

```zymbol
>>| {
    @:principal {
        ...
        _decir(alto - 1, ancho)      // otra función del módulo: LEE `aviso`
        aviso = ""                   // el bloque anidado: ESCRIBE `aviso`
        <<| t
        ? t == 'x' { _borrar(...) }  // una función del módulo: ESCRIBE `aviso`
    }
}
```

Conducido por un pty con la secuencia `⏎ x s i q` — abrir, borrar, confirmar,
cambiar de idioma, salir — instrumentando ambas funciones:

| vuelta | tree-walker | VM de registros |
|---|---|---|
| 3 · `_borrar` pone el aviso | `_decir ve aviso=[Borrado] largo=7` | igual |
| 3 · `correr` lo limpia | `tras-limpiar=[]` | igual |
| **4 · `_decir` vuelve a leer** | **`aviso=[Borrado] largo=7`** | `aviso=[] largo=0` |

En la vuelta 4 el tree-walker **repinta un aviso que ya se había borrado**. Y lo
que hace el caso interesante: en esa misma vuelta, la función que escribió sí ve
la cadena vacía — `correr` lee `""` y `_decir` lee `"Borrado"`, **a la vez, en el
mismo módulo, sobre la misma variable**. No es que la escritura se pierda: es
que dos funciones del mismo módulo ven dos valores.

La escritura hecha desde una función (`_borrar`) sí se propaga en los dos
motores. La que no se propaga es la del **bloque anidado**.

> Esto último es la conclusión equivocada, y conviene ver por qué se sacó. Es
> cierto que la escritura del bloque no se propagaba — pero tampoco la de una
> función, cuando la lectura venía por una intermedia. Lo que distinguía a los
> dos casos observados no era **quién escribía**, sino **por dónde se leía**:
> el aviso de `_borrar` se leía a través de `_pintar_cuentas`, que no lo nombra.
> Con la evidencia disponible las dos explicaciones encajaban, y se eligió la
> que miraba al sitio raro (`>>|`) en vez de al sitio corriente (una llamada).

**Reproducción.** `pruebas/verificación_tui.sh` la ejerce; a mano:

```bash
cd ZyBank
python3 ../zyquality/tui/ptydrive.py zymbol run     zybank_tui.zy -- '\r' x s i q > tw.txt
python3 ../zyquality/tui/ptydrive.py zymbol run --vm zybank_tui.zy -- '\r' x s i q > vm.txt
grep -ao '38;5;214m' tw.txt | wc -l    # 2 — el aviso se pinta dos veces
grep -ao '38;5;214m' vm.txt | wc -l    # 1
```

Cancelar el borrado (`x n i q`) lo reproduce igual, así que **no depende de que
se borre nada**: basta con haber pasado por la confirmación.

**Lo que NO lo reproduce**, comprobado uno por uno en los dos motores — seis
casos mínimos, todos coincidentes:

1. estado de módulo escrito por una función que además devuelve valor
   (HLZ-SRP-001, que es lo primero que uno sospecha);
2. estado escrito dentro de `? { }` y dentro de `@ { }`, incluso etiquetado;
3. estado escrito dentro de `>>| { }` y leído por otra función acto seguido;
4. lo mismo con una escritura previa hecha desde una función;
5. lo mismo dentro de un bucle, con lectura y escritura en vueltas distintas;
6. lo mismo con una lectura de teclado anidada en otro módulo, con su propio
   bucle de lectura — que es la forma exacta de `campo::confirmar`.

Ninguno diverge — y ahora se sabe por qué: **los seis llaman al lector
directamente**, que era la única forma que funcionaba. Lo que les faltaba a los
seis era una línea, la misma en todos: una función en medio.

**Cómo se encontró al final.** No construyendo un séptimo caso mínimo, sino al
revés: reduciendo desde la aplicación real hacia abajo. Primero la secuencia de
teclas —`⏎ x s q` no diverge y `⏎ x s i q` sí, así que hacía falta *una vuelta
más del bucle*, no la tecla `i`—, después el programa, quitando el módulo de
confirmación, luego el teclado, luego el `>>|`, luego el bucle. Lo que quedó son
doce líneas que no se parecen en nada al enunciado original.

Construir casos mínimos hacia arriba prueba las hipótesis que uno ya tiene.
Reducir hacia abajo desde algo que falla no necesita ninguna.

**Consecuencia para la suite.** `pruebas/verificación_tui.sh` vuelve a exigir
igualdad **byte a byte** entre los dos motores — 21 570 bytes idénticos — además
de la igualdad de saldos. Mientras el hallazgo estuvo abierto solo la reportaba,
para no convertir algo ya registrado en una alarma diaria; cerrado el hallazgo,
un byte de diferencia vuelve a ser lo que debe ser: un fallo.

---

---

## BUG-ZYB-009

**`$!!` dentro de un `!?` se capturaba como si fuera una excepción. El tree-walker sí; la VM y el motor del navegador no — y la documentación les daba la razón a ellos.**

> **CORREGIDO** en v0.0.9. Caso en `corpus/errors/catchable/propagar_no_es_lanzar.zy`.

No se buscó: salió de escribir el caso de prueba de
[BUG-ZYB-007](#bug-zyb-007). La forma natural de «capturar un fallo de la base»
pone un `$!!` dentro de un `!?`, y los tres motores dieron dos respuestas.

**Reproducción**, sin `std/db` y sin nada de la aplicación:

```zymbol
riesgoso(i) {
    !? { <~ [10, 20][i] } :! { <~ _err }
}

prueba(i) {
    !? {
        e = riesgoso(i)
        ? e$! { e$!! }
        <~ "sin error"
    } :! {
        <~ "CAPTURADO por :!"
    }
}

>> prueba(99) ¶
```

| motor | resultado |
|-------|-----------|
| zytw | `CAPTURADO por :!` |
| zyvm | `##Index(array index out of bounds: …)` |
| zyjs | `##Index(array index out of bounds: …)` |

**Lo que decide cuál es el correcto** no es la mayoría, es que está escrito.
`GUIDE.md` § «Value flow» dice: *«`$!!` is an **early return** … It does **not**
throw an exception, so it cannot be caught with `!?/:!`»*. El lenguaje separa a
propósito dos flujos —excepciones por `!?`/`:!`, valores por `$!`/`$!!`— y el
tree-walker los juntaba en el único sitio donde no deben encontrarse: una
función que propagaba un fallo hacia arriba era interceptada por su propia
cláusula de captura.

**La causa.** `execute_try` miraba **dentro** del retorno pendiente y, si el
valor era un error, se lo entregaba al `:!`. Un `<~` de un valor corriente ya
salía por ahí intacto; solo el error se desviaba. Hoy ningún retorno se desvía.

---

## BUG-ZYB-010

**Un `:>` no se ejecuta entero cuando el bloque `!?` retorna. El tree-walker imprimía media sentencia; la VM se lo salta del todo.**

> **CORREGIDO** en v0.0.9, en los dos motores. Caso en
> `corpus/errors/catchable/finally_con_retorno.zy`.

Es el tercer hallazgo salido de la misma verificación, y el más incómodo,
porque `:>` significa «pase lo que pase» y las tres implementaciones
entendían tres cosas distintas por «pase lo que pase».

**Reproducción.** Cinco líneas, y **sin ningún error de por medio** — solo un
`<~` dentro de un `!?` que tiene `:>`:

```zymbol
f() {
    !? {
        <~ "retornado"
    } :> {
        >> "limpieza" ¶
    }
}
>> f() ¶
```

| motor | antes | qué pasaba |
|-------|-------|------------|
| zytw | `limpiezaretornado` | ejecuta el `:>` pero **se come el `¶`** |
| zyvm | `retornado` | **no ejecuta el `:>`** |
| zyjs | `limpieza` `retornado` | correcto |

**Lo que lo explica en el tree-walker.** El bloque `:>` se ejecutaba con el
`ControlFlow::Return` todavía puesto, y `execute_block` se detiene en la
primera sentencia que ve mientras hay control de flujo pendiente. De ahí
«media sentencia»: el `>>` alcanzó a escribir el texto y el `¶` ya no. Medio
efecto es peor que ninguno, porque parece que funciona.

Se apartaba el retorno antes de correr el `:>` y se vuelve a poner después,
salvo que el propio `:>` levante control de flujo, que entonces gana él.

**Y en la VM era otra cosa.** El compilador emitía el bloque `:>` **en línea**,
detrás del try y del catch, y un `<~` retorna de la función saltándose esas
instrucciones limpiamente: el `:>` no corría en absoluto. Un `:>` que no corre no
libera lo que tenía que liberar, y esa es toda la razón de que exista la
cláusula.

Ahora cada `<~` alcanzable desde dentro de un `!?` emite antes una copia de los
`:>` pendientes, de dentro afuera — que es lo que la nota de `TryCatch` en el
bytecode llamaba «el compilador emite el bloque dos veces» y no hacía. Dos
consecuencias que hubo que perseguir, y que están en el caso de corpus:

- **La llamada de cola se anula dentro de un try con `:>`.** Un marco que
  todavía debe limpieza no puede ser reemplazado por la llamada siguiente. Fuera
  de un try la optimización sigue intacta, y el caso lo comprueba con una
  recursión de 100 000 vueltas que no cabría en la pila sin ella.
- **El valor de retorno se fija antes.** `compile_expr` sobre un identificador
  devuelve el registro **de la variable**, no una copia, así que `<~ v` seguido
  de `v = "otro"` dentro del `:>` devolvía `"otro"`. Se copia a un temporal, y
  solo cuando hay un `:>` que ejecutar.

**Lo que sigue abierto es otra cosa, y más pequeña**: un `<~` escrito **dentro**
del `:>`. Los dos motores Rust retornan desde ahí —como hacen Java y Python— y el
motor del navegador sigue hasta la sentencia posterior al try. Es anterior a todo
esto y no hay caso de corpus por lo mismo de siempre: hoy pondría el consenso en
rojo.

**Y hay que decir cómo se destapó**, porque es el argumento del método: el
fallo del tree-walker era **anterior** a todo esto y estaba oculto tras
[BUG-ZYB-009](#bug-zyb-009). Mientras un retorno con error se limpiaba antes
de llegar aquí, el `:>` de ese caso corría limpio; al arreglar 009 y dejar de
limpiarlo, el caso del error pasó por el mismo camino que el caso corriente
—que ya estaba roto— y lo hizo visible. Un arreglo no creó este fallo: le
quitó el sitio donde se escondía.


---

## BUG-ZYB-011

**Un `<~` escrito dentro de un `:>` retorna desde ahí en los dos motores Rust, y el del navegador lo ignora y sigue.**

> **CORREGIDO** en v0.0.9: **el `:>` es limpieza y no decide lo que la función
> devuelve.** Un `<~` dentro evalúa su expresión —puede tener efectos— y se
> descarta; el retorno que el bloque `!?` llevaba sigue su camino.
>
> Java y Python hacen lo contrario y dejan ganar al `finally`, y **los dos
> avisan contra ello en sus propias guías de estilo**. Zymbol se queda con el
> aviso en vez de con la característica: quien lee una función puede fiarse de
> que el valor que vuelve es el del `<~` que tiene delante. Los dos motores Rust
> se alinearon con el del navegador, que ya lo hacía así.
>
> Caso al pie de `corpus/errors/catchable/finally_con_retorno.zy`.

Es el residuo de [BUG-ZYB-010](#bug-zyb-010), y es anterior a él: salió al
comprobar que aquella corrección no rompía nada, no de la corrección.

**Reproducción.**

```zymbol
f() {
    !? {
        _x = 1
    } :> {
        <~ "desde el finally"
    }
    <~ "después del try"
}
>> f() ¶
```

| motor | resultado |
|-------|-----------|
| zytw | `desde el finally` |
| zyvm | `desde el finally` |
| zyjs | `después del try` |

**Cuál es el correcto no está escrito en ninguna parte**, que es la mitad del
hallazgo. Java y Python retornan desde el `finally` y descartan lo que hubiera
antes, así que los dos motores Rust siguen la convención más extendida; pero
`GUIDE.md` no dice nada de este caso, y por tanto los tres motores son
igualmente defendibles contra la documentación que hay.

Cerrarlo es primero decidir —¿el `:>` puede cambiar lo que devuelve la
función, o es solo limpieza?— y después alinear el motor que quede fuera. La
decisión importa más que la divergencia: un `:>` que puede secuestrar el valor
de retorno es una construcción de la que hay que desconfiar, y varios lenguajes
que la permiten avisan contra ella en su propia guía de estilo.

No hay caso de corpus mientras siga abierto: hoy pondría el consenso en rojo,
que es informar de lo mismo dos veces y a costa del gate.


# GAP

## GAP-ZYB-001

**No hay formateo decimal con precisión en tiempo de ejecución, ni relleno de ceros.**

> **CORREGIDO a medias, y el enunciado también lo estaba.**
>
> **El relleno de ceros ya existía**: `#,.2|10.5|` da `10.50` y siempre lo dio.
> La ficha afirma abajo que «eso no lo da ninguna forma del lenguaje», y es
> falso — probó `#.2|10.5|`, que es **otro operador**. `#.N` redondea y devuelve
> un **Float**; `#,.N` formatea y devuelve una **cadena**. Un `10.50` numérico
> *es* `10.5`, así que rellenarlo no significa nada hasta que hay texto. No son
> operadores hermanos escritos casi igual: son aritmética y formato.
>
> **La precisión en tiempo de ejecución sí faltaba, y ya está** (v0.0.9): la
> cuenta de decimales puede ser el nombre de una variable en `#,.n|x|`,
> `#.n|x|`, `#!n|x|` y `#^.n|x|`, en los tres motores. Un nombre y no una
> expresión cualquiera: el `|` que abre el valor es también como se escribe el
> `or` binario, y el motor del navegador lexea la cuenta dentro del token.
> Cuando haga falta más, se calcula antes:
>
> ```zymbol
> ancho = exp + 1
> >> #,.ancho|importe| ¶
> ```
>
> Caso en `corpus/casts/precision_en_ejecucion.zy`. Lo caro no fue el operador
> sino los **seis recorridos del analizador** que no sabían que ahí dentro había
> una expresión: sin ellos la destrucción automática liberaba la variable antes
> de que el operador la leyera.

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

> **CORREGIDO** en v0.0.9, **y sin gastar ningún símbolo**: un `<~` escrito
> fuera de toda función termina el programa, y su valor es el código de salida.
>
> Es la regla 1 de `SYMBOLS.md` § 17 —«derivar, no inventar»— en estado puro.
> El contrato de `<~` es «devuelve este valor a quien te llamó»; a una función
> la llama el código de alrededor y a un programa lo llama el sistema
> operativo, y lo que el sistema recibe de un programa es su código de salida.
> Un contrato leído en dos posiciones, no dos significados: la regla 6 no se
> activa.
>
> El valor **debe ser entero** y `zymbol check` rechaza cualquier otra cosa. La
> rama que sale es casi siempre la que menos se ejecuta, así que un error en
> tiempo de ejecución ahí aparecería el día en que ya había ido algo mal.
>
> **Y cerró una divergencia que nadie había reportado**, porque nadie escribe
> `<~` en el cuerpo de un archivo: la VM y el motor del navegador ya paraban el
> programa ahí —descartando el valor— y el tree-walker seguía leyendo el resto
> del archivo. El mismo programa imprimía cosas distintas con `--vm`. La forma
> ya estaba en el lenguaje; lo único que faltaba era su significado.
>
> Casos en `corpus/functions/salida_del_programa.zy` y
> `corpus/errors/semantic/salida_no_entera.zy`.
>
> **Y el arreglo destapó otro fallo, que es el motivo de tener un gate.** Una
> lambda de expresión con `$!!` dejaba un retorno pendiente que se escapaba al
> llamante: inofensivo mientras el nivel raíz ignoraba un retorno suelto, y no
> tanto en cuanto ese retorno pasó a ser el código de salida — `h = (x -> x$!!)`
> terminaba el programa a media línea. Lo cazó
> `corpus/lambdas/error_propagate_lambda.zy`, que existía desde v0.0.7.

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

> **RETIRADO — era falso.** La yuxtaposición **sí** se admite en los argumentos
> de una llamada, y siempre se admitió:
>
> ```zymbol
> f(x) { <~ "[" x "]" }
> resto = 7
> >> f("a" resto) ¶      // [a7]
> ```
>
> El error que la ficha describe abajo sale **igual sin yuxtaposición
> ninguna** — `g("x", 2)` lo produce— porque no era de la yuxtaposición: era del
> inferidor de tipos, que obligaba a `String` a todo parámetro yuxtapuesto. Eso
> es [ERROR-ZYB-005](#error-zyb-005), y está corregido.
>
> Es el cuarto hallazgo falso de este log y el segundo con la misma forma: se
> observó un error, se atribuyó al operador que estaba a la vista y no se probó
> la misma línea sin él.

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

> **CORREGIDO** en v0.0.9, y **era una divergencia**: la VM de registros y el
> motor del navegador ya concatenaban arreglos y diccionarios sin problema. El
> tree-walker mantenía una lista blanca para la yuxtaposición que `>>` no usaba,
> así que la misma yuxtaposición del mismo valor daba dos respuestas según dónde
> estuviera escrita. Ahora todo valor yuxtapone, y a exactamente lo que `>>`
> imprime. Caso en `corpus/collections/agregado_en_cadena.zy`.

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

## GAP-ZYB-010

> **RETIRADO — era falso.** Se conserva porque un hallazgo borrado no se
> puede aprender de él, y porque el error de método que lo produjo es el
> mismo que produjo [GAP-ZYB-012](#gap-zyb-012).

**Lo que decía:** que no hay forma de escribir un carácter de control, y que
fabricar ESC y RETROCESO obliga a salir al intérprete de órdenes.

**Lo que pasa de verdad:** un carácter se escribe también por su código, y eso
lleva en el lenguaje desde siempre. `GUIDE.md` § "Literals" lo dice en la misma
frase que los literales entre comillas simples:

```zymbol
0d27 == 0x1b       // #1 — ESC, en decimal y en hexadecimal
0d65 == 'A'        // #1 — es un literal de CARÁCTER
0d65 == 65         // #0 — y no un entero
```

Hay cuatro bases: `0d` decimal, `0x` hexadecimal, `0o` octal y `0b` binaria.
`0d0` es NUL, `0d27` es ESC, `0d127` es DEL. Y en la otra dirección, `##!` sobre
un `Char` devuelve su punto de código (v0.0.8), así que **sí se puede ir del
carácter al número y del número al carácter**, que es exactamente lo que el
hallazgo afirmaba que no.

**Por qué se dio por cierto.** La prueba que sostenía el hallazgo era:

```zymbol
>> ###c ¶      // Runtime error: ### requires a numeric value, got Char
>> #|c| ¶      // "a" — el carácter como texto
```

`###` es el cast que REDONDEA, y rechaza `Char` con razón; `#|…|` convierte a
texto. Ninguno de los dos es el operador de esta pregunta, y `##!` —que sí lo
es— nunca se probó. De ahí salió una conclusión general a partir de dos
operadores equivocados.

**Lo que costaba.** `pantalla/teclas.zy` fabricaba las dos teclas con `printf`:

```zymbol
_nul() { <~ (<\ "printf '\\000x'" \>)[1] }
_esc() { <~ (<\ "printf '\\033'" \>)[1] }
```

Y como `es_borrar(t)` y `es_escapar(t)` llamaban a esas funciones, el campo de
entrada **lanzaba hasta dos procesos del intérprete de órdenes por cada tecla
pulsada** — además de dejar de funcionar allí donde no haya `printf`. Hoy son
`t == 0d0` y `t == 0d27`, sin proceso ninguno. Los valores son los mismos: se
comprobó que las funciones viejas devolvían 0 y 27 antes de cambiarlas.

**Lo que sí queda.** Nada de este hallazgo. [BUG-ZYB-006](#bug-zyb-006) —que Tab
y retroceso colapsen en NUL y que Ctrl+letra llegue como la letra— es un
problema distinto y sigue abierto: ahí el valor se puede escribir perfectamente,
lo que no se puede es distinguir dos teclas que llegan iguales.

---

## GAP-ZYB-011

> **RETIRADO — era falso.** El lenguaje decodifica las flechas él mismo. Lo que
> el enunciado describía es una versión de `<<|` que entregaba los bytes crudos;
> la que hay no lo hace.

**Lo que decía:** que una flecha manda tres bytes —`ESC`, `[`, `A`— y `<<|` los
entrega en tres lecturas separadas, de modo que reconocerlas obligaría a leer
dos teclas más después de un ESC y pulsar ESC *de verdad* dejaría el programa
esperando teclas que no llegan. Sin un temporizador que consultar, no habría
forma de distinguir un ESC solo de un ESC que empieza una secuencia.

**Lo que pasa de verdad:** `<<|` entrega **un solo carácter** por flecha, y es
el glifo de la flecha. Está en `GUIDE.md` § "Key Input", en una tabla que
también mapea ENTER y ESC:

| Tecla | Valor |
|---|---|
| ↑ | `'↑'` (U+2191) |
| ↓ | `'↓'` (U+2193) |
| ← | `'←'` (U+2190) |
| → | `'→'` (U+2192) |
| ESC | `'\x1b'` |

Comprobado con un pty de verdad, mandando las secuencias byte a byte:

```
\x1b[A → '↑' (8593)    \x1b[B → '↓' (8595)    \x1b[D → '←' (8592)
\x1b   → 27            j      → 106
```

Un ESC suelto sigue llegando **como ESC**, que era justo lo que el enunciado
daba por perdido. No hace falta temporizador porque la separación no la hace la
aplicación: la hace el lenguaje.

**Por qué se dio por cierto.** El mismo defecto de método que en
[GAP-ZYB-010](#gap-zyb-010) y [GAP-ZYB-012](#gap-zyb-012): se razonó sobre lo
que un terminal manda —tres bytes, cierto— y no se probó lo que `<<|` entrega.
Tres hallazgos, un solo experimento que nadie hizo.

**Y costaba.** Este es el primero de los tres que llegó a los dedos de alguien:
la aplicación ignoraba `↓`, y una lista que no responde a la flecha no parece
una lista con otro convenio, parece una lista rota. El pie decía `jk` y la
suite de pty entraba con `⏎` en la primera cuenta, así que la navegación por la
lista no se ejercitaba nunca — el hueco de cobertura y el hallazgo falso se
tapaban el uno al otro.

**Qué se hizo.** `pantalla/teclas` declara `es_arriba`/`es_abajo`/
`es_izquierda`/`es_derecha`/`es_flecha`; la lista de cuentas, la de movimientos
y el selector de categorías aceptan las flechas **y** `j`/`k`; `←` vuelve como
ESC y `→` entra como ⏎; el campo de texto ignora una flecha en vez de
escribirla. La secuencia de `pruebas/verificación_tui.sh` empieza ahora con
`↓ ↑` y teclea una `←` dentro de una glosa, y las dos comprobaciones se
verificaron quitando la función para ver que fallan.

---

## GAP-ZYB-012

> **MUY REDUCIDO — el lenguaje sí sabe leer una cifra.** Lo que queda es una
> comodidad que falta, no un muro; el enunciado original era falso.

**Lo que decía:** que el lenguaje sabe ESCRIBIR cifras en 69 escrituras y no
sabe LEER ninguna, que no hay forma de llegar al punto de código de un carácter,
y que por tanto la única salida es una tabla de glifos por escritura.

**Lo que pasa de verdad:** `##!` sobre un `Char` devuelve su punto de código.
Está en `REFERENCE.md` § "Type Casts" —*`Char` → code point`*— y anunciado en
`GUIDE.md` como novedad de **v0.0.8**, en la misma línea que `std/term`, que
este programa ya usaba.

```zymbol
##!'७'  → 2413      ##!'7'  → 55      ##!'ñ' → 241
```

Comprobado además con teclado de verdad, no de memoria: pulsando «७» en un pty,
`<<|` entrega un `Char` y `##!` da 2413.

**Por qué se dio por cierto.** Igual que en
[GAP-ZYB-010](#gap-zyb-010): la prueba usó `###k`
—el cast que redondea, que rechaza `Char`— y `#|k|` —que convierte a texto—.
`##!` no se probó. Dos hallazgos distintos salieron del mismo experimento
incompleto, y el segundo llegó a citarse en `interpreter/README.md` como
ejemplo de lo que una aplicación descubre y un corpus no. La lección se
sostiene; el ejemplo no era este.

**Lo que sí queda, y es bastante menos.** No hay un predicado `es_dígito` de
serie, y una aplicación sigue teniendo que declarar el cero de cada escritura
que quiera aceptar. Pero eso ya no es una tabla de glifos: Unicode coloca las
diez cifras de una escritura en diez puntos de código **seguidos**, así que
`##!t` menos el cero da el valor.

Trece escrituras pasaron de **130 glifos copiados a mano** a **13 enteros**, y
nueve de ellos son la progresión `2406 + 128k`, porque un bloque índico ocupa
128 puntos. Ese era el coste real del rodeo — no la aritmética, sino que la
tabla estaba escrita en caracteres que nadie de este equipo lee de un vistazo, o
sea el sitio ideal para que se cuele uno equivocado y no lo note nadie nunca.
Un número mal copiado se ve; un glifo devanagari mal copiado, no.

**Lo que la suite comprueba ahora.** `pruebas/verificación_dígitos.zy` ya no
verifica que trece tablas estén bien copiadas: verifica **la premisa** de la que
depende la resta, y contra el propio lenguaje. Para cada escritura le pide que
escriba sus diez cifras con el mode-switch (`#०९#`) y comprueba que ocupan diez
puntos de código seguidos **y** que el primero es el cero declarado. Eso cubre
lo que un humano no puede revisar a ojo: que un bloque de Unicode no sea
contiguo daría un valor equivocado en silencio, y ninguna tabla lo delataría.

**Lo que faltaría de verdad.** Un predicado de dígito con su valor, coherente
con las 69 escrituras que el lenguaje ya reconoce para escribir — la vuelta del
mode-switch. Con eso una aplicación no tendría que declarar cero ninguno, y un
usuario con teclado lao o birmano podría teclear su importe sin que nadie edite
el programa. Es una comodidad, ya no un muro.

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

> **CORREGIDO** en v0.0.9. **No era una heurística mal calibrada**: un iterador
> se excluye de la destrucción automática porque el bucle es dueño de su tiempo
> de vida, y esa exclusión estaba implementada poniendo **la misma marca** que
> el analizador le reporta al programador. Una marca, dos trabajos. Ahora son
> dos: `loop_bound` excluye de la destrucción y no le dice nada a nadie.
>
> Caso en `corpus/errors/semantic/bucle_sin_aviso_falso.zy`, cuyo golden es su
> salida de `check` — y tiene que seguir vacía.

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

---

## ERROR-ZYB-004

> **RETIRADO — era falso, y el error estaba en la prueba.** El convenio del
> punto está documentado (`DOT_CONVENTION.md`): un nombre desnudo casa con el
> nombre del archivo (`# util` en `util.zy`), y **un punto delante nombra la
> ruta entera unida con `_`** (`# .lib_util` en `lib/util.zy`). El archivo de la
> reproducción escribía `# .util` dentro de `lib/util.zy`, que efectivamente
> está mal. `check` tenía razón y `run` es el que no comprueba.
>
> **Lo que sí quedaba era el mensaje**, y por eso engañó: decía *«does not match
> file name 'lib_util'»* sobre un archivo que no existe — `lib_util` es el
> nombre de MÓDULO que el convenio pide. Ahora dice qué escribir y cita el
> convenio.

**`zymbol check` rechaza un `<# ../lib/util` que `zymbol run` ejecuta sin problema. Compone el nombre de archivo esperado uniendo la ruta con `_`.**

Es el reverso exacto de [ERROR-ZYB-002](#error-zyb-002): allí `check` calla y la
ejecución revienta; aquí `check` grita y la ejecución funciona. De los dos, este
es el que impide trabajar: un programa correcto no pasa el analizador.

**Reproducción.** El mismo árbol de [BUG-ZYB-004](#bug-zyb-004):

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

```text
$ zymbol run   sub/prog.zy      → 2
$ zymbol check sub/prog.zy      → error: E001: Module name '.util' does not
                                    match file name 'lib_util'
```

`lib_util` no es el nombre de ningún archivo: es `lib/util` con el separador
cambiado por un guion bajo. El analizador toma la ruta entera del import y la
usa donde debería usar solo el último componente, así que **todo módulo
importado con una ruta de más de un componente** falla la comprobación. Ocurre
con las cuatro formas de invocar el archivo, incluida la ruta absoluta.

**Es anterior a la corrección de [BUG-ZYB-004](#bug-zyb-004)** — se comprobó
contra la invocación que ya funcionaba antes de tocar nada. Salió al verificar
aquella, no de ella.


---

## ERROR-ZYB-005

**Yuxtaponer un parámetro lo obliga a ser `String`. Los dos motores Rust rechazan un programa correcto; el del navegador lo ejecuta.**

> **CORREGIDO** en v0.0.9. Caso en `corpus/functions/param_yuxtapuesto.zy`.

No se buscó: salió de comprobar [GAP-ZYB-007](#gap-zyb-007), que atribuía a la
yuxtaposición un error que no era suyo.

**Reproducción.**

```zymbol
etiquetar(v) { <~ "[" v "]" }

>> etiquetar("texto") ¶
>> etiquetar(42) ¶
```

| motor | resultado |
|-------|-----------|
| zytw | `error: argument 1 has type Int, but function 'etiquetar' expects String` |
| zyvm | el mismo error |
| zyjs | `[texto]` y `[42]` |

**Y una línea más allá, lo mismo funciona.** `>> "[" n "]" ¶` con `n = 42`
imprime `[42]`: la yuxtaposición acepta Int, Float, Bool, Char y —desde
[GAP-ZYB-008](#gap-zyb-008)— arreglos y diccionarios. Lo único que cambiaba era
que el valor entrara por un parámetro.

**La causa.** El analizador anotaba `CompatibleWith(String)` para todo parámetro
que apareciera en una yuxtaposición, lo resolvía a `String` y luego rechazaba
cualquier otro tipo en la llamada. La restricción no describía nada real: la
yuxtaposición no restringe.

**Por qué ninguna suite lo vio, que es lo interesante.** Es una divergencia que
**rechaza** en vez de dar una respuesta distinta. El consenso compara lo que los
programas imprimen, y un programa que no compila no imprime nada; los goldens
comparan salidas, y no hay salida. Toda la maquinaria de este proyecto está
construida para cazar respuestas distintas, y esta era una **negativa**
distinta. El corpus no tenía ninguna función que compusiera un mensaje con un
número —cosa que hace casi cualquier función que componga un mensaje— porque
nadie puede escribir el caso que su compilador rechaza.


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
