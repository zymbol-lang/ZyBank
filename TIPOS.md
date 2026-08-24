# ZyBank — análisis de los tipos

> **Qué es este documento.** Un análisis del sistema de tipos de Zymbol, escrito
> desde la aplicación que lo puso a prueba. Nació de una pregunta concreta —
> [GAP-ZYB-009](HALLAZGOS.md#gap-zyb-009), cómo se pregunta si una columna vino
> `NULL` — y esa pregunta resultó no tener respuesta sin entender antes qué es
> `##_`, que es el único tipo del lenguaje que no se puede escribir.
>
> **Método.** Nada de lo que sigue está razonado desde la documentación: **todo
> está ejecutado**, y en los tres motores —`zytw` (tree-walker), `zyvm` (VM de
> registros) y `zyjs` (el del navegador)— porque una afirmación sobre el
> lenguaje que solo se ha probado en un motor es una afirmación sobre ese motor.
> Medido el **2026-08-24** con `zymbol 0.0.9`.
>
> **Lo que la medición encontró.** Cuatro divergencias vivas entre los tres
> motores, ninguna de las cuales el gate podía ver, y un fallo en ZyBank causado
> por el rodeo que la propia ficha de GAP-ZYB-009 proponía. Están en el § 6.
>
> **Resuelto el 2026-08-24 por la salida (a) del § 7**: `##_` pasa a escribirse.
> Con ello se cerraron GAP-ZYB-009, las cuatro divergencias, el fallo de la
> aplicación y **un quinto que apareció al implementarlo** —ERROR-ZYB-006, que
> lo bloqueaba—. Lo que sigue se deja como se midió, en presente: es el estado
> del que se partió, y una tabla a la que se le edita una fila es una tabla que
> nadie ejecutó nunca. Las correcciones están anotadas donde tocan.

---

## 1. El inventario

Once tipos, doce símbolos. `#?` devuelve una tupla `(símbolo, cuenta, valor)` y
el primer campo es lo que el valor **es**.

| Símbolo | Tipo | Cómo se escribe | `#?` de ejemplo |
|---|---|---|---|
| `###` | Entero | `42`, `-7` | `(###, 5, 12345)` |
| `##.` | Flotante | `3.5`, `1.5e10` | `(##., 3, 3.5)` |
| `##"` | Cadena | `"hola"` | `(##", 4, hola)` |
| `##'` | Carácter | `'a'`, `0d97` | `(##', 1, a)` |
| `##?` | Booleano | `#1`, `#0` | `(##?, 1, #1)` |
| `##]` | Arreglo | `[1, 2, 3]` | `(##], 3, [1, 2, 3])` |
| `##[` | Lista | `#[1, "dos"]` | `(##[, 2, …)` |
| `##)` | Tupla | `(1, 2)` | `(##), 2, (1, 2))` |
| `##(` | Diccionario | `#(a: 1)`, `#()` | `(##(, 2, (a: 1, b: 2))` |
| `##()` | Función | `f(x) { … }` | `(##(), 2, <funct/2>)` |
| `##->` | Lambda | `x -> x` | `(##->, 1, <lambd/1>)` |
| `##_` | Unit | **no se puede escribir** | `(##_, 0, )` |
| `##<Ident>` | Error | no se puede escribir | `(##Index, N, ##Index(…))` |

La **cuenta** no significa lo mismo en todos: dígitos del entero, longitud del
texto mostrado en el flotante, caracteres de la cadena, siempre 1 en carácter y
booleano, elementos en arreglo/lista/tupla, **claves** en el diccionario,
aridad en función y lambda, longitud del mensaje en un error, y 0 en Unit.

**El paradigma es icónico** (`SYMBOLS.md` § 8.3): cada símbolo es una miniatura
de la notación del tipo. La comilla de la cadena, el corchete que cierra un
arreglo, el paréntesis que cierra una tupla. Desde v0.0.9 los cuatro agregados
siguen además una regla propia — **la colección sin marca toma el delimitador de
cierre y la marcada el de apertura** —, que es lo que separó al diccionario de
la tupla. Solo dos de los doce no son icónicos y los dos están señalados en
`SYMBOLS.md`: `###`, porque un entero no tiene notación que retratar, y
`##<Ident>`, porque es una palabra.

---

## 2. Los básicos

**`###` Entero.** Entero seguro de ±(2⁵³−1). Salirse del rango es `##Range`, no
un número mal: es fail-closed en los tres motores desde v0.0.9. Por eso un
epoch en nanosegundos (~1.7e18) no cabe y `std/time` trabaja en milisegundos.

**`##.` Flotante.** IEEE-754 de doble precisión. `==` es **exacto**, sin
tolerancia: `0.1 + 0.2 == 0.3` es `#0`. La promoción Int/Float ocurre antes, así
que `1.0 == 1` es `#1`.

**`##"` Cadena y `##'` Carácter son tipos distintos**, y esa distinción cuesta
más de lo que parece hasta que se topa uno con ella. Un trozo de cadena es una
**cadena** aunque mida un carácter: `("abc"$[1..1])#?` contesta `##"`, y `##!`
sobre él aborta con *«requires a numeric value or Char, got String»* — en
ejecución, porque `zymbol check` lo deja pasar, que es la misma familia de hueco
que [ERROR-ZYB-002](HALLAZGOS.md#error-zyb-002). `pantalla/campo.zy` lleva una
tabla ASCII escrita a mano por esto exactamente.

**`##?` Booleano NO es numérico.** `#1` no es `1`: `(#1 == 1)` es `#0`. Se
escribe con `#`, que es la marca de meta/tipo, y no con una palabra.

**Y ninguno de los cinco es `##_`.** Medido: un Unit no es la cadena vacía, no
es cero, no es `#0`. A las tres preguntas contesta `#0`.

---

## 3. `##_` — qué es Unit, y qué no es

La pregunta que abrió este documento. Viniendo de un lenguaje tipado uno busca a
qué se parece —¿`void`? ¿`null`? ¿`NaN`?— y la respuesta es que se parece a dos
de los tres y a la vez es una cuarta cosa que sobra.

### 3.1 Qué produce un Unit

Todo esto, medido:

| Origen | Ejemplo |
|---|---|
| una función que termina sin `<~` | `nada() { }` |
| un `<~` sin valor | `sin_valor() { <~ }` |
| `null` decodificado de JSON | `js::decode("null")` |
| una columna que vino `NULL` | `fila.nota` |
| `query_value` que no encontró fila | *a propósito* — ver § 5 |
| una operación que solo actúa | `io::write(…)`, `db::exec(…)` |

### 3.2 `void`, sí

En C o en Java, `void` es una afirmación del **sistema de tipos**: «esta función
no devuelve nada». Zymbol no declara tipos, así que no tiene dónde escribirlo —
pero tiene el valor que resulta de ello, y es `##_`. Una función sin `<~`
devuelve Unit, y `#?` sobre lo devuelto lo dice.

La diferencia con `void` es real: en C, `void` **no es un valor** y no se puede
guardar en una variable. En Zymbol sí:

```zymbol
nada() { }
u = nada()          // esto es legal, y `u` vale ##_
```

### 3.3 `null`, también — y esto no es una analogía

`##_` **es** el null del lenguaje, y no se parece a él: lo es. Medido en los
tres motores, en las dos direcciones:

```zymbol
>> js::encode(u) ¶                    // → null
>> (js::decode("null")#?)[1] ¶        // → ##_
```

Un `NULL` de SQL llega como `Unit` por el mismo camino. Así que cuando ZyBank
lee `movimientos.categoría` de un traspaso —que no tiene categoría— lo que
recibe es exactamente el mismo valor que produce una función vacía.

### 3.4 `NaN`, **no** — y esto es lo que más se confunde

`NaN` no es un null: es un **flotante**. Zymbol lo tiene, es alcanzable, y su
tipo es `##.`:

```zymbol
inf = 1.0e400
a = inf - inf
>> a " tipo " (a#?)[1] ¶     // → NaN tipo ##.
>> (a == a) ¶                // → #0
```

`NaN == NaN` es `#0` en los tres motores, que es lo que dice IEEE-754 y lo que
hacen todos los lenguajes. `0.0 / 0.0` **no** produce NaN: es un error de
ejecución, «division by zero», también en los tres. A NaN se llega por
`inf - inf` o por `m::sqrt(-1.0)`.

**Un `NaN` es un número que no se pudo calcular. Un `##_` es la ausencia de
valor.** No tienen nada que ver, y confundirlos es el error clásico de quien
viene de un lenguaje donde ambos «significan que algo salió mal».

### 3.5 `undefined`, **no** — y esa es una buena noticia

JavaScript tiene *dos* nulls: `null` (ausencia declarada) y `undefined` (nunca
se asignó). Zymbol no tiene el segundo, y no por descuido: **un nombre que no
existe es un error de análisis**, antes de ejecutar nada.

```zymbol
>> jamas_definida ¶     // error: undefined variable 'jamas_definida'
```

Eso cierra la clase entera de fallos donde una variable mal escrita se propaga
como `undefined` hasta reventar en otro sitio. Es la decisión que ERROR-ZYB-002
señala **a medias**: el analizador la aplica a los nombres inexistentes y no a
los inalcanzables.

### 3.6 Cómo se pregunta hoy — y por qué la forma evidente está mal

Un Unit no contesta a ninguna de las preguntas que uno haría:

| pregunta | respuesta |
|---|---|
| `u$!` — ¿es un error? | `#0` |
| `u == ""` | `#0` |
| `u == 0` | `#0` |
| `u == #0` | `#0` |
| `>> u` | no imprime nada |

La única forma correcta que existe hoy es comparar el **símbolo de tipo**:

```zymbol
? (v#?)[1] == "##_" { … }
```

**Y la forma que sale sola está mal.** La ficha de GAP-ZYB-009 propone mirar la
*cuenta* en vez del símbolo, y es lo que `núcleo/almacén.zy::es_nulo` hace hoy:

```zymbol
es_nulo(v) {
    (_t, hay, _val) = v#?
    <~ hay == 0
}
```

La cuenta vale 0 para **cuatro** valores distintos, no uno. Medido:

```
es_nulo(nada())  →  #1     correcto
es_nulo("")      →  #1     MAL — es una cadena vacía
es_nulo([])      →  #1     MAL — es un arreglo vacío
es_nulo(#())     →  #1     MAL — es un diccionario vacío
```

`movimientos.glosa` es una columna TEXT y `''` es un valor corriente en ella, así
que **ZyBank contesta hoy que una glosa vacía vino `NULL`**. Es un fallo vivo de
la aplicación y su origen es el rodeo que la propia ficha proponía: cuando la
manera correcta de preguntar algo no existe, la que se inventa cada uno se
parece lo bastante a la correcta como para pasar las pruebas que a uno se le
ocurren.

### 3.7 El hueco, dicho en una línea

**Unit es el único tipo del lenguaje cuyo valor no se puede escribir.**

Los otros once tienen literal o declaración: `42`, `3.5`, `"hola"`, `'a'`, `#1`,
`[…]`, `#[…]`, `(…)`, `#(…)`, `f(x) { }`, `x -> x`. El único que no es `##_`, y
`x = ##_` no parsea. El valor es alcanzable —se guarda en una variable, viaja
dentro de una tupla, sale de una consulta— y el lenguaje no sabe nombrarlo.

**Es exactamente la forma de [GAP-ZYB-003](HALLAZGOS.md#gap-zyb-003)**, el
diccionario vacío: un valor que el programa podía tener y no podía escribir, y
que por eso obligaba a fabricarlo con un rodeo. Aquel se cerró dándole notación
propia.

> **CERRADO el 2026-08-24.** `##_` se escribe, en los tres motores y en las dos
> posiciones —literal y marca de «cualquier clase» en `:! ##_`—, y con eso el
> paradigma de tipos deja de tener un hueco: los doce símbolos nombran ahora
> valores que se pueden escribir. Ver `HALLAZGOS.md` § GAP-ZYB-009.

---

## 4. Los agregados

**`##]` Arreglo y `##[` Lista son un solo tipo.** `[…]` es homogéneo y se
comprueba; `#[…]` declara la mezcla y no. `[1,2] == #[1,2]` es `#1`. Lo que `#?`
distingue desde v0.0.9 es **lo que el arreglo contiene al preguntar**, no cómo
se escribió: un arreglo salido de `js::decode` contesta `##[` sin que haya una
marca en ninguna parte del programa, y `#[1,"dos"]$-[2]` contesta `##]`, porque
un solo entero no es una mezcla.

**`##)` Tupla.** Posicional, de tamaño fijo e **inmutable**. Su papel es mover
varios valores juntos: retornos múltiples y desestructuración.

**`##(` Diccionario.** Con claves, mutable, en orden de inserción. Desde v0.0.9
tiene notación propia porque la tupla y él compartían paréntesis y no
semántica — y el vacío, `#()`, no se podía escribir de ninguna otra manera.

**`##()` Función y `##->` Lambda.** Valores de primera clase los dos. Desde
v0.0.9 `==` sobre ellos es **identidad**: dos nombres de una función son
iguales, dos funciones con el mismo cuerpo no.

**`##<Ident>` Error.** El tipo **es** la clase: `##Index`, `##Div`, `##IO`,
`##DB`, `##Key`, `##Time`. Tampoco se puede escribir uno: `x = ##Index("a")` no
parsea, y eso está bien — un error se produce, no se declara. `##_` en posición
de clase (`:! ##_ { }`) atrapa cualquiera, que es la misma lectura del `_`: «el
que no se especifica».

---

## 5. Las dos vaciedades que `std/db` distingue, y la que no

Después de [BUG-ZYB-007](HALLAZGOS.md#bug-zyb-007) hay dos preguntas separadas y
cada una tiene su forma:

| pregunta | forma | qué llega |
|---|---|---|
| la consulta no encontró fila | `fila$!` | `##DB(query_one matched no rows)` |
| la columna vino `NULL` | *no la hay* | `Unit` |

Y hay un sitio donde el propio `GUIDE.md` declara que **no** se distinguen:
`query_value` devuelve `Unit` tanto si no hubo fila como si la columna era
`NULL`, a propósito, porque su resultado es un escalar y un escalar puede
legítimamente **ser** `NULL`. Ahí las dos vaciedades son de verdad el mismo
valor, y está escrito que lo son.

---

## 6. Lo que la medición encontró

Cuatro divergencias vivas entre los tres motores. **Ninguna la ve el gate**, y
las cuatro por el mismo motivo: `zyq consensus` compara lo que los programas
imprimen, y ningún archivo del corpus imprimía nada de esto.

### D-1 · `Unit == Unit` es `#0` en la VM

```zymbol
nada() { }
a = nada()
b = nada()
>> (a == b) ¶       // zytw #1 · zyjs #1 · zyvm #0
>> (a == a) ¶       // zytw #1 · zyjs #1 · zyvm #0
```

La VM dice que un Unit no es igual a sí mismo. La causa es la de siempre:
`cmp_direct` —el camino rápido de comparación, uno de los **dos** por los que
esta VM llega a la igualdad— no tiene brazo para `Unit`, así que cae en
`_ => 1`. Es la tercera vez que aparece esta forma exacta: DM-02 fue el brazo de
`Array` que faltaba, y BUG-ZYB-012 el de `Function`.

**Es bloqueante para la salida (a) del § 7**: si `##_` pasara a escribirse,
`v == ##_` daría la respuesta equivocada en la VM.

### D-2 · yuxtaponer un Unit da texto distinto

```zymbol
s = "" u
>> "[" s "]" ¶      // zytw [] · zyjs [] · zyvm [()]
```

La VM mete `()` donde los otros dos no meten nada. La ficha original decía que
esto abortaba el programa; eso se arregló en GAP-ZYB-008, y lo que quedó fue una
divergencia silenciosa: un programa que compone un mensaje con una columna nula
imprime cosas distintas según el motor.

### D-3 · un Unit dentro de un arreglo

```zymbol
a = [1, 2]
b = a $+ u
```

Los dos motores Rust lo **rechazan en análisis** —`cannot append Unit to [Int]`—
y el del navegador lo acepta y construye `[1, 2, ()]`, que además declara como
`##[`. Un programa que mete una columna nula en un arreglo corre en el
playground y no compila en la línea de órdenes.

### D-4 · `#?` sobre una función con nombre dice que es Unit

```zymbol
f(x, y) { <~ x }
g = f
>> (f#?) ¶      // zytw (##_, 0, ) · zyvm igual · zyjs (##(), 2, <funct/2>)
>> (g#?) ¶      // los tres: (##(), 2, <funct/2>)
```

Pasar por una variable arregla la respuesta, preguntar por el nombre no. La
causa está en `eval_type_metadata`: trata `Expr::Identifier` como caso especial
para poder contestar `##_` a una variable inexistente, y una función con nombre
**no es una variable** —vive en la tabla de funciones—, así que la búsqueda
falla y devuelve la metadata de Unit.

Y el caso especial que lo provoca **está muerto**: la variable inexistente no
llega nunca ahí, porque el analizador la rechaza antes (§ 3.5). Un rodeo para
un caso que no ocurre, que a cambio da una respuesta falsa en uno que sí.

**Las cuatro dicen lo mismo sobre `##_`**: es el valor que cada motor usa cuando
no sabe qué contestar, y por eso es donde se acumulan las respuestas
inventadas.

> **Las cuatro corregidas el 2026-08-24**, al implementar la salida (a).
> D-1 era el cuarto brazo que faltaba en `cmp_direct` de la VM, después de
> `Array` (DM-02), `NamedTuple` (DM-22) y `Function` (BUG-ZYB-012) — cuatro
> veces la misma forma en la misma función, que no comparte código con
> `Value::equals`. D-2 era la ruta de construcción de cadenas de la VM usando la
> forma anidada para un Unit suelto. D-4 eran **tres** casos especiales, uno por
> motor, y los tres borrados. Fijadas en
> `zyquality/corpus/collections/unidad_literal.zy`.
>
> **D-3 estaba mal enunciada y no es de `##_`.** Un Unit dentro de una colección
> es alcanzable en los tres motores por `js::decode("[1, null, 3]")`, se imprime
> `[1, (), 3]` y vuelve a `null` — los tres coinciden. Lo que divergía era otra
> cosa: el motor del navegador no implementaba la comprobación de homogeneidad.
>
> **Cerrado el 2026-08-24, y medirlo lo hizo más grande.** Eran DOS divergencias
> —`$+` de otro tipo y el literal anidado `[[1], ["x"]]`—, no una, y las dos
> están corregidas: el checker del navegador recuerda ahora el tipo de elemento
> de un arreglo, que es lo que hace falta para la forma que el código tiene de
> verdad (`a = [1,2]` y luego `a $+ "x"`, no un literal con un operador colgando).
> Fijadas en `reject/collections/07` y `08`.
>
> **Y aparecieron TRES agujeros que comparten los tres motores**: `$++`, `$+[i]`
> y `[i]$~` convierten un `[…]` en heterogéneo sin que nadie lo declare y sin
> que nadie avise, y `#?` contesta `##[` — una lista que nadie escribió. Como
> los tres coinciden, es un agujero de la regla y no un desacuerdo, y cerrarlo
> rechazaría programas que hoy corren: queda escrito en `REFERENCE.md` L46 y
> con sus bordes fijados en `corpus/collections/homogeneidad_bordes.zy`.
>
> **Y apareció una quinta al implementarlo**, que bloqueaba la salida (a):
> comparar un parámetro con `==` lo ataba a ese tipo, así que
> `es_nulo(v) { <~ v == ##_ }` solo se podía llamar con algo que ya fuera Unit.
> Es [ERROR-ZYB-006](HALLAZGOS.md#error-zyb-006), anterior a todo esto y de la
> misma forma que ERROR-ZYB-005; corregido con lo demás.

### A-1 · y el fallo de la aplicación

`núcleo/almacén.zy::es_nulo` contesta `#1` para `""`, `[]` y `#()` (§ 3.6).
Hay que corregirlo se decida lo que se decida en el § 7, y con la forma
correcta de hoy —comparar el símbolo, no la cuenta— si no entra ninguna otra.

---

## 7. Las salidas para GAP-ZYB-009

Evaluadas contra las ocho reglas de `SYMBOLS.md` § 17. La decisión no es de
quien escribe la aplicación.

### (a) `##_` pasa a poder escribirse

```zymbol
? fila.nota == ##_ { >> "vino NULL" ¶ }
glosa = fila.glosa
? glosa == ##_ { glosa = "" }
nada() { <~ ##_ }
```

| Regla | Veredicto |
|---|---|
| 1 · derivar, no inventar | **Cumple.** No hay marca nueva: `##_` ya existe, ya es el nombre de ese tipo y ya está en el registro del § 18. Lo que cambia es que se admite en posición de expresión, como `#(` pasó a admitirse. |
| 2 · un significado por marca | **Cumple.** `_` es «lo que no se especifica» en sus ocho usos, y el valor «sin valor» es esa misma lectura. |
| 6 · sin homógrafos | **Cumple.** El símbolo de tipo y el valor son la misma cosa: Unit tiene un solo valor, así que nombrar el tipo y nombrar el valor no se pueden distinguir ni hace falta. |
| 7 · icónico | **Cumple**, por herencia: `##_` ya lo era. |

**Precedente exacto**: `#()`, hace dos días. Mismo enunciado —un valor
alcanzable sin literal—, misma solución.
**Coste**: D-1 hay que corregirlo primero, o la VM contesta mal.
**Riesgo**: da una manera de *escribir* «nada», y alguien la usará como valor
por defecto. Es lo que pasa con `None` en Python, y se considera correcto.

### (b) un operador `$_`

```zymbol
? fila.nota$_ { >> "vino NULL" ¶ }
```

| Regla | Veredicto |
|---|---|
| 1 · derivar, no inventar | **Falla a medias.** `$` es la marca de colección y `$!` es su único predicado no-colección; extenderla a «es Unit» pide un contrato que hoy no tiene. |
| 5 · sin marca base nueva sin carácter documentado | `$_` no es marca base nueva, pero sí una combinación sin descripción previa. Habría que escribirla en `SYMBOLS.md` **antes** de implementarla. |
| 7 · icónico | **Cumple**: `_` retrata la ausencia. |

Se lee mejor como pregunta —y una pregunta es lo que es—, pero gasta una
combinación para lo que (a) hace con `==`.

### (c) solo documentar

Cero cambio en el lenguaje. `GUIDE.md` ya explica qué llega; faltaría añadir
cómo se pregunta.

**El argumento en contra está medido y es el § 3.6**: la forma correcta no es
la evidente, la evidente está mal, y la aplicación que descubrió el hallazgo la
tiene puesta hoy. Documentar una forma que hay que escribir a mano en cada
programa es aceptar que unos cuantos la escribirán mal.

### Decisión — **(a)**, tomada el 2026-08-24

Implementada en los tres motores, con D-1 corregido antes por ser bloqueante.
Y con una sorpresa que la lista de arriba no anticipaba: ERROR-ZYB-006, que
también la bloqueaba y que nadie había pisado porque hasta ahora no había
ninguna razón para comparar un parámetro contra un literal de tipo fijo.

**(a)**, con D-1 corregido antes. Es la que no gasta símbolo, la que repite una
decisión que este mismo proyecto tomó y validó hace dos días, y la única que
convierte la pregunta en una comparación en vez de en algo que cada aplicación
reinventa.

---

## Documentos relacionados

- [`HALLAZGOS.md`](HALLAZGOS.md) — el registro de hallazgos de ZyBank
- `interpreter/SYMBOLS.md` — el sistema de signos y las reglas del § 17
- `interpreter/COLLECTIONS.md` — el punto de record de los agregados
- `interpreter/REFERENCE.md` — taxonomía de errores y límites
