# Notas verificadas sobre Yomidict

Este documento reúne las conclusiones contrastadas que necesita el cargador de
Yomidict. Se pueden combinar todas las familias de bancos en un mismo
diccionario; ni los esquemas ni el importador oficial las hacen excluyentes.

## Qué significa `format` en Yomidict

`format` es la versión del esquema interno de Yomidict. No indica si el
diccionario es de términos, kanji, frecuencia, etc.; tampoco es la `revision`
del contenido.

Lo importante es esto:

| `format` | Estructura |
|---|---|
| `1` | Formato antiguo. Las definiciones y significados aparecen como elementos restantes de la lista. |
| `2` | Formato de transición: agrupa esas colecciones en arrays e introduce la estructura moderna. |
| `3` | Mantiene esencialmente los bancos de `2`, pero formaliza en `index.json` si las secuencias son significativas mediante `sequenced`. |

Ejemplo simplificado:

```jsonc
// format 1
["猫", "ねこ", "", "", 0, "gato", "felino"]

// format 2/3
["猫", "ねこ", "", "", 0, ["gato", "felino"], 123, ""]
```

En kanji ocurre algo equivalente:

```jsonc
// format 1
["猫", "ビョウ", "ねこ", "", "cat", "feline"]

// format 2/3
["猫", "ビョウ", "ねこ", "", ["cat", "feline"], {}]
```

La revelación importante está en el importador actual: solo pregunta si la
versión es `1`; para cualquier otra utiliza el schema V3. Por tanto, Yomitan
actualmente interpreta `2` y `3` con el mismo esquema de bancos. Puede verse en
el [importador oficial](https://github.com/yomidevs/yomitan/blob/master/ext/js/dictionary/dictionary-importer.js)
y en el
[schema del índice](https://raw.githubusercontent.com/yomidevs/yomitan/master/ext/data/schemas/dictionary-index-schema.json).

Históricamente ocurrió esto:

1. `format: 2` cambió las listas para agrupar glosarios y significados.
2. Mientras todavía se llamaba `2`, añadieron metadatos, secuencia y
   `termTags`.
3. Después añadieron `sequenced` al índice y
   [subieron el número a 3](https://github.com/FooSoft/yomichan-import/commit/f0e6fa281212cb1f3147e9f51eaaa87241983f20).

Eso explica por qué no hay una diferencia clara entre `2` y `3`: sus bancos
finales son prácticamente iguales. La distinción real está principalmente en
el índice y en la fiabilidad de la información de secuencia.

Para el cargador:

```go
switch index.Format {
case 1:
	// Decodificador antiguo.
case 2, 3:
	// Decodificador moderno.
default:
	// Formato no soportado.
}
```

Además, `index.json` puede usar el campo antiguo `version` como alias de
`format`; si aparecen ambos, `format` tiene precedencia, igual que en Yomitan.

Existe una pequeña porquería histórica: `format 2` fue modificado varias veces
sin cambiar el número. Un diccionario `2` muy antiguo podría tener seis campos
por término en vez de ocho. No merece la pena complicar ahora el diseño, pero
el error debe decir claramente qué estructura recibió. Para crear nuevos
Yomidict, siempre debemos emitir `format: 3`.

## Qué es `termTags`

`termTags` no es una familia de bancos ni un archivo. Es un campo contenido
dentro de cada entrada de `term_bank`.

Una entrada moderna de términos tiene, de forma simplificada, estas posiciones:

```text
[
  término,
  lectura,
  definitionTags,
  reglas,
  puntuación,
  glosario,
  secuencia,
  termTags
]
```

Los dos campos de tags son cadenas con nombres separados por espacios:

- `definitionTags` describe la definición concreta representada por esa
  entrada.
- `termTags` describe el término o forma escrita en conjunto.

En el JSON, `termTags` es literalmente un `string`, no un array:

```json
"common archaic"
```

Ese valor referencia dos tags, `common` y `archaic`. La cadena vacía `""`
significa que el término no tiene tags. Como el espacio actúa como separador,
el nombre individual de un tag no puede contener espacios. Al cargarlo podemos
conservar el valor original o dividirlo y representarlo en memoria como
`[]string`; eso no cambia que en Yomidict se serialice como una cadena.

Ambos contienen referencias por nombre al catálogo compartido de `tag_bank`.
Por eso no existe ningún `term_tag_bank_N.json`.

Por ejemplo:

```json
[
  "猫",
  "ねこ",
  "n",
  "",
  0,
  ["gato"],
  123,
  "common"
]
```

Aquí `n` es un tag de la definición y `common` es un tag del término. Los
detalles de ambos nombres —categoría, orden, notas y puntuación— pueden estar
definidos en `tag_bank_1.json`.

Por tanto:

```go
allBankKinds = [...]string{"term", "term_meta", "kanji", "kanji_meta", "tag"}
```

solo enumera las familias de **archivos banco** que pueden existir:

```text
term_bank_N.json
term_meta_bank_N.json
kanji_bank_N.json
kanji_meta_bank_N.json
tag_bank_N.json
```

No enumera todos los campos internos de sus entradas. `termTags`,
`definitionTags`, `glosario`, `secuencia`, etc. viven dentro de una entrada de
`term_bank`; no son bancos independientes.

### `termTags` entre `format 2` y `format 3`

El paso final de `format 2` a `format 3` no cambió la representación de
`termTags`: siguió siendo el octavo campo de `term_bank` y una cadena de nombres
separados por espacios.

La complicación histórica es que `termTags` se añadió mientras el formato aún
se llamaba `2`. Por eso:

- Un diccionario `format: 2` tardío puede tener la misma entrada de ocho campos
  que `format: 3`, incluido `termTags`.
- Un diccionario `format: 2` muy antiguo puede tener solamente los seis campos
  anteriores y no contener ni `sequence` ni `termTags`.
- El cargador actual de Yomitan trata `format 2` y `format 3` con el
  [schema moderno de términos](https://raw.githubusercontent.com/yomidevs/yomitan/master/ext/data/schemas/dictionary-term-bank-v3-schema.json),
  de modo que espera la forma moderna.

Por tanto, `termTags` pertenece a la entrada moderna tanto
si el índice declara `2` como si declara `3`. La diferencia fundamental del
salto a `3` fue declarar `sequenced` en `index.json`.

## Qué significa `sequenced`

`sequenced` es un booleano de `index.json` que declara si el diccionario
contiene información de secuencia para relacionar términos:

```json
{
  "title": "Ejemplo",
  "revision": "1",
  "format": 3,
  "sequenced": true
}
```

Cada entrada moderna de `term_bank` contiene en su séptima posición un entero
llamado `sequence`:

```json
["猫", "ねこ", "", "", 0, ["gato"], 123, ""]
```

Aquí `123` es la secuencia. Varias entradas con la misma secuencia se consideran
relacionadas y Yomitan puede mostrarlas agrupadas. No es necesariamente una
posición dentro del archivo ni el número del banco.

La agrupación no se hace simplemente por el texto del término. Una fila de
`term_bank` representa una forma buscable concreta, mientras que una misma
entrada léxica original puede producir varias filas por tener diferentes
grafías, lecturas o partes de la definición.

Por ejemplo, en Jitendex estas dos filas comparten la secuencia `1000200`:

```text
1000200  阿吽の呼吸    あうんのこきゅう
1000200  あうんの呼吸  あうんのこきゅう
```

Los términos escritos son distintos, pero representan variantes de la misma
entrada léxica y pueden mostrarse juntos.

En este ejemplo no hay una fila principal que contenga la definición y otra
que se limite a apuntar hacia ella. Las dos filas contienen el glosario
completo, y sus valores de `glossary` son exactamente iguales como JSON. Ambas
incluyen estas tres definiciones:

```text
the harmonizing, mentally and physically, of two parties engaged in an activity
singing from the same hymn-sheet
dancing to the same beat
```

También contienen exactamente el mismo contenido estructurado:

- Los mismos indicadores de expresión, sustantivo y expresión idiomática.
- La misma lista de formas: `阿吽の呼吸` y `あうんの呼吸`.
- La misma atribución a la entrada `1000200` de JMdict.
- La misma lectura `あうんのこきゅう`.
- Los mismos `definitionTags`, reglas y `termTags`, que están vacíos.

Sus únicos campos diferentes son:

| Campo | Primera fila | Segunda fila |
|---|---|---|
| `term` | `阿吽の呼吸` | `あうんの呼吸` |
| `score` | `0` | `-1` |

Por tanto, Jitendex duplica aquí la definición para que cualquiera de las dos
grafías sea directamente buscable, mientras que `sequence: 1000200` permite
reconocer que ambas filas proceden de una única entrada léxica.

También existe el problema inverso: el mismo texto no garantiza que se trate
de la misma entrada. Jitendex contiene:

```text
1000220  明白  めいはく
1000225  明白  あからさま
```

Agrupar solamente por el campo `term` mezclaría estas dos entradas, mientras
que sus secuencias diferentes mantienen separadas las dos lecturas y sus
significados correspondientes.

Por tanto, `sequence` actúa como identificador de agrupación de la entrada
léxica de origen:

- Une variantes escritas o lecturas que pertenecen a esa misma entrada.
- Mantiene separados homógrafos que coinciden en la escritura pero pertenecen
  a entradas léxicas diferentes.
- Puede reunir varias filas generadas a partir de diferentes partes o sentidos
  de una misma entrada original.

Su utilidad práctica es que, al buscar una de las variantes, Yomitan puede
reconstruir y mostrar la entrada léxica completa con sus formas relacionadas,
en lugar de presentar cada fila técnica como si fuera un resultado
independiente o de fusionar resultados solo porque su texto coincide.

- Con `"sequenced": true`, el diccionario afirma que esos números pueden usarse
  para relacionar y agrupar entradas.
- Con `"sequenced": false`, o si el campo falta, no se debe confiar en
  `sequence` para formar esos grupos.

`sequenced` tampoco significa que los archivos `term_bank_1.json`,
`term_bank_2.json`, etc. estén correctamente numerados; esa continuidad es otra
validación independiente.

El [schema oficial del índice](https://raw.githubusercontent.com/yomidevs/yomitan/master/ext/data/schemas/dictionary-index-schema.json)
lo define como la indicación de que el diccionario contiene información de
secuencia para términos relacionados. El
[schema de `term_bank`](https://raw.githubusercontent.com/yomidevs/yomitan/master/ext/data/schemas/dictionary-term-bank-v3-schema.json)
define `sequence` como el número que permite mostrar juntos los términos que lo
comparten.

### Lo que `sequence` no indica

El valor numérico de `sequence` no indica frecuencia, popularidad, relevancia,
calidad ni el orden en que Yomitan debe mostrar las entradas. Un número mayor no
significa «más frecuente» y uno menor tampoco significa «menos frecuente».

Para interpretar `sequence`, la operación importante es comprobar la igualdad:

```go
if a.Sequence == b.Sequence {
	// Pueden proceder de la misma entrada léxica.
}
```

No debemos atribuir significado léxico a comparaciones como:

```go
a.Sequence < b.Sequence
```

En diccionarios derivados de JMdict, `sequence` suele conservar el `ent_seq`
original. JMdict lo define como un número único para identificar cada entrada.
Cuando se crea una entrada nueva, normalmente se le asigna el siguiente número
disponible; una edición de una entrada existente suele conservar su número.
Por eso un número más alto podría reflejar incidentalmente una creación más
reciente dentro de JMdict, pero no es una garantía útil y sigue sin decir nada
sobre su frecuencia. Esto se explica en la
[DTD oficial de JMdict](https://www.edrdg.org/jmdict/jmdict_dtd_h.html) y en la
[ayuda de JMdictDB](https://www.edrdg.org/jmwsgi/edhelp.py?svc=jmdict).

Además, Yomidict es un formato genérico: un diccionario que no proceda de
JMdict puede generar sus propios números. Por tanto, los consumidores deben
conservar `sequence` como una clave opaca de agrupación del diccionario de
origen, no convertirla en una medida universal ni utilizarla como identificador
global entre diccionarios diferentes.

### Dónde se representa la frecuencia

Yomidict dispone de campos específicos para popularidad y frecuencia:

1. El quinto campo de una entrada de `term_bank` es `score`. El
   [schema oficial](https://raw.githubusercontent.com/yomidevs/yomitan/master/ext/data/schemas/dictionary-term-bank-v3-schema.json)
   indica que los valores negativos representan entradas más raras, los
   positivos entradas más frecuentes, y que también se usa para ordenar
   resultados.
2. Los bancos `term_meta_bank_N.json` pueden contener registros con modo
   `freq`, destinados a almacenar información de frecuencia más explícita.
3. `frequencyMode` en `index.json` puede indicar si esos datos representan
   ocurrencias o un ranking.

En el ejemplo anterior de la secuencia `1000200`, las dos variantes comparten
el mismo `sequence`, pero sus puntuaciones son diferentes:

```text
阿吽の呼吸    score  0
あうんの呼吸  score -1
```

La pequeña diferencia de prioridad está expresada por `score`; no por el valor
`1000200` de `sequence`.
