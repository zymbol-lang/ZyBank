# El dinero en Zymbol — doctrina

> **Qué es este documento.** El punto de record de una decisión de diseño que
> ZyBank descubrió y que ningún otro documento tenía: **cómo se representa el
> dinero en un programa Zymbol**. Sale de [IDEA-ZYB-002](HALLAZGOS.md#idea-zyb-002).
>
> **Qué NO es.** No es una parte del lenguaje. `std/time` se justificaba más allá
> de este proyecto —toda aplicación que registre algo necesita una fecha, y no
> hay intérprete de órdenes en el navegador—; el dinero no. Moneda, exponente y
> formato local son conceptos de dominio, y su sitio es un **paquete
> distribuible** (`ZyModule`, versionado), no `std/`. Lo que sigue es la
> doctrina; la implementación de referencia es `núcleo/dinero.zy`, y su destino
> es salir de ZyBank y convertirse en ese paquete.
>
> Todo lo que aquí se afirma está medido contra el binario, no razonado.

---

## 1. Un importe es un entero en la unidad menor

`1050` no es «mil cincuenta». Es lo que la moneda diga que es: 10,50 USD,
1.050 CLP, 1,050 KWD. **El entero no cambia; cambia el exponente de la moneda.**

Nunca un flotante. La razón no es la que `núcleo/dinero.zy` daba en su cabecera
—volveremos a eso en §6—, y tampoco es el formateo. Es la **acumulación**, y
falla a magnitudes completamente domésticas:

```zymbol
f = 0.0
i = 0
n = 1
@ n <= 1000 {
    f = f + 0.10        // mil apuntes de diez céntimos
    i = i + 10
    n++
}
>> f ¶                        // 99.9999999999986
>> (f == 100.0) ¶             // #0
>> (i / 100) "," (i % 100) ¶  // 100,0
```

Mil apuntes de 0,10 € no dan 100,00 €. Y el saldo **no es igual** a cien, así
que cualquier comprobación de cuadre por igualdad falla. `0.1 + 0.2 == 0.3` da
`#0`, como en cualquier otro lenguaje con IEEE 754.

## 2. El exponente pertenece a la moneda, no al programa

Los exponentes reales de ISO 4217 son **0** (CLP, JPY), **2** (USD, EUR), **3**
(KWD, BHD) y **4** (el ariary malgache). Un programa que escriba `2` en su
código ha decidido por el usuario en qué moneda vive.

De ahí sale la regla que gobierna un formateador de dinero: **el número de
decimales no se conoce al escribir el código**. Llega en tiempo de ejecución,
desde la configuración de la moneda.

## 3. El rango: i53 en unidades menores

El entero de Zymbol es ±(2^53−1), *fail-closed* en los tres motores, así que un
importe llega hasta:

| exponente | máximo representable |
|---|---|
| 0 (CLP, JPY) | 9 007 199 254 740 991 |
| 2 (USD, EUR) | 90 071 992 547 409,91 |
| 3 (KWD) | 9 007 199 254 740,991 |

Noventa billones de euros al céntimo. No es un límite que un libro real vaya a
tocar, y conviene decirlo: **la razón para usar enteros no es el rango.**

## 4. Una división de dinero se reparte; no se redondea

Cien euros entre tres no son tres veces 33,33 — eso pierde un céntimo. Son
**33,34 + 33,33 + 33,33**. El resto se entrega de una unidad menor en una unidad
menor a las primeras partes, que es el reparto de la contabilidad.

El invariante es lo que hay que comprobar, no los valores: **las partes suman
exactamente el original**. `núcleo/dinero.zy::repartir` lo implementa y su suite
comprueba eso.

## 5. Leer lo que teclea una persona no puede abortar

Un importe tecleado es entrada, no un literal. `analizar` devuelve
`(válido, importe)` y nunca revienta. Dos reglas que no son obvias:

- Acepta el separador de miles **y** el decimal de la moneda, y también el punto
  ASCII, porque quien teclea en un terminal escribe lo que tiene en el teclado.
- Una moneda de exponente 0 **rechaza** la parte decimal en vez de redondearla
  en silencio: en un peso chileno, «1234,5» no es un importe. Redondear la
  entrada de alguien sin decírselo es peor que rechazarla.

## 6. Lo que el lenguaje sí resolvió, y lo que deliberadamente no

Dos cosas cambiaron bajo este módulo desde que se escribió, y su cabecera se
quedó atrás.

**`#.N|…|` ya admite precisión en tiempo de ejecución.** Decía «`#.n|x|` con `n`
variable es un error de análisis, comprobado», y eso dejó de ser cierto al
cerrarse [GAP-ZYB-001](HALLAZGOS.md#gap-zyb-001). Hoy `#.n|x|` se ejecuta.

**Y formatear por flotante es exacto casi siempre**, lo que desmonta el otro
argumento de esa cabecera. Medido sobre 400 000 importes:

| magnitud (unidades menores) | importes mal escritos |
|---|---|
| por debajo de 10^15 | **0** |
| de 10^15 al tope de i53 | **9,2 %** |

Es decir: un programa que convierta el entero a flotante solo para escribirlo
acierta hasta 10^15 unidades menores — diez billones de euros, si el exponente
es 2. Por encima empieza a desplazar un céntimo. **El formateo nunca fue la
razón** — §1 lo es. La conclusión del módulo era correcta; el motivo que daba,
no. Conviene que quede escrito, porque un motivo falso es la forma más rápida de
que alguien retire una regla que sí hacía falta.

**El par de separadores es del lenguaje; su grafía, de la escritura; la elección
entre los dos, de la moneda.** La `,` agrupa y el `.` divide, en toda escritura,
y no hay modo ni argumento que lo invierta —ver `interpreter/SYMBOLS.md` §6.2 y
[IDEA-ZYB-001](HALLAZGOS.md#idea-zyb-001)—. Por eso `agrupar(texto, separador)`
recibe el separador de `moneda["miles"]`: **no es `#,` reescrito a mano**, es
justo lo que el lenguaje decidió no hacer, y por eso vive aquí.

## 7. Trabajar sobre el texto, no sobre el número

`rellenar` y `agrupar` operan sobre el texto ya convertido. Esa es la razón de
que sobrevivan a un modo numeral activo: si la escritura en curso es devanagari,
`"" 7` ya vale `७`, y el módulo solo cuenta y antepone. **El carácter cero se le
pasa**, porque cada escritura tiene el suyo y este módulo no tiene por qué
saber cuál.

---

## Lo que le queda al paquete

Una incoherencia propia, no del motor: bajo `#٠٩#` el módulo compone cifras
árabes con un separador **ASCII** sacado de la configuración de la moneda,
mientras el lenguaje ya escribe `١٬٢٣٤٬٥٦٧٫٨٩` con los separadores de la
escritura. La regla que falta es de una línea: **si la moneda no impone un
separador, se toma el de la escritura activa**. Es trabajo del paquete.
