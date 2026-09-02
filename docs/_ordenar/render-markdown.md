# Renderizado y ancho visible de Markdown

Estado verificado el 13 de agosto de 2026 con render-markdown.nvim
`f422cb5c6855f150e2ddcfaf44e7157b98b34f6a`.

## Objetivo ordenado

1. Tratar las definiciones CommonMark `[id]: destino "title"` como enlaces estructurados.
2. Permitir navegación y rename independientes del identificador y del destino.
3. Separar la integración de `render-markdown` en módulos mantenibles.
4. Completar el renderizado que el plugin no proporciona para definiciones y referencias.
5. Medir el ancho que realmente ocupa Neovim: texto después de conceal más texto virtual.
6. Usar ese ancho en el reenvolvido propio y, después, auditar la cadena completa de formateadores.

## Estructura

```text
lua/lzy/render-markdown/
├── init.lua    # opciones, setup, tema y keymaps
├── code.lua    # avisos de fences vacíos y sin cerrar, y cabecera de los que no llevan lenguaje
├── cursor.lua  # cursor contextual de H1
├── inline.lua  # extensiones del handler markdown_inline
├── links.lua   # definiciones, referencias, iconos y ancho de icono
├── spoilers.lua # spoilers inline, bloques e inyección Markdown
└── tags.lua    # chip de color de los tags `#tag`
```

`require("lzy.render-markdown")` conserva la misma API pública.

## Spoilers

Se admiten dos formas:

```markdown
Texto ||oculto hasta entrar con el cursor||.
```

````markdown
```spoiler
# Markdown oculto

También se renderizan **énfasis**, enlaces y el resto del cuerpo.
```
````

El fence acepta dos nombres, `spoiler` y `spoiler-block`, que son exactamente el mismo bloque: el
largo por parecido con el plugin de Obsidian, el corto por escribirlo menos. La lista vive en
`lzy.render-markdown.spoilers.block_languages` y de ahí la leen tanto el render como la cadena de
formateo, así que añadir un nombre es añadirlo una vez.

Fuera del cursor, el inline se sustituye por `󰈉 SPOILER` y el bloque por
`󰈉 SPOILER · N líneas`. Al entrar en el inline desaparece el indicador y queda su contenido sin
delimitadores. En un bloque, el indicador permanece como cabecera y al entrar en una línea de su
cuerpo aparece debajo el Markdown revelado; al salir vuelve a quedar una sola línea. El bloque
registra sus nombres como una inyección del parser Markdown: al revelarlo no se presenta como
código, sino con headings, énfasis y enlaces renderizados. El alias se registra normalizado
(`spoiler_block`), que es la forma en la que Tree-sitter busca el lenguaje de una inyección: pasa
el nombre a minúsculas y cambia los `-` por `_` antes de resolverlo.

La detección inline es deliberadamente conservadora: no admite saltos de línea, contenido vacío,
anidamiento ni delimitadores incompletos. Tampoco actúa dentro de código inline, enlaces, imágenes,
autolinks, texto escapado o tablas. Los fences normales permanecen como código.

## Tags

Un `#tag` se pinta como un chip: fondo rojo `#6D3434` —el rojo del H2 bajado un 30 %, para que se
lea como el mismo color sin confundirse con la banda de un heading— y texto `#FFF0F4` en negrita.
El chip incluye la almohadilla y va con prioridad 4099, por encima de la banda de heading (4096),
del código inline contextual (4097) y de las cursivas (4098), así que un tag dentro de un heading
se sigue leyendo. En TTY pura el rojo oscuro no existe: ahí el chip usa el rojo del H2 con el texto
invertido.

Lo que se marca es exactamente lo que `sabunv.nvim.tags` reconoce, que es lo mismo que indexan y
renombran Marksman y obsidian-ls: si algo sale con chip, es un tag de verdad para el índice.
La única resta son los code spans —`` `#include <stdio.h>` `` es código citado, no una etiqueta—;
dentro de un fence no hace falta restar nada, porque su cuerpo es otro árbol y el handler inline no
lo ve. Los tags del frontmatter viven en el árbol YAML y hoy no reciben chip.

## Bloques de código que no se ven

Con los delimitadores ocultos, un fence sin cuerpo desaparecía entero: el plugin le pone
`conceal_lines` a sus dos líneas de ``` y, sin contenido que pintar, no quedaba ni una fila en
pantalla. Un fence sin cierre era igual de silencioso: su apertura se ocultaba y el texto de detrás
se pintaba como código sin ninguna pista.

Los dos casos son trampas de edición, y encima falsean lo que entiende cualquier cosa que lea el
documento —el parser empareja los ``` de otra manera, así que hasta la copia inteligente de un
bloque de más abajo se lleva texto de fuera—. Hay un tercer caso que no es un error pero se pierde
igual: la cabecera del plugin se dibuja a partir del nombre del lenguaje, así que un fence sin
lenguaje no recibe ninguna y su apertura se oculta como cualquier otro borde; el cuerpo queda
flotando sobre el fondo del código, sin nada que diga dónde empieza. Los tres se marcan en vez de
ocultarse:

| Caso                                       | Vista                                     |
| ------------------------------------------ | ----------------------------------------- |
| ` ``` ` + ` ``` ` sin cuerpo               | dos filas ámbar, `▲ bloque de código vacío` |
| ` ```lua ` + ` ``` ` sin cuerpo            | igual, con el lenguaje: `▲ lua · …`       |
| ` ``` ` + ` ``` ` con el cuerpo en blanco  | igual: un cuerpo de solo espacios no es cuerpo |
| ` ```sh ` sin cierre                       | fila roja, `▲ sh · bloque de código sin cerrar` |
| ` ``` ` con cuerpo, sin lenguaje           | fila gris, cabecera ` texto plano `       |

La detección mira los hijos del nodo: sin `code_fence_content` está vacío, con un solo
`fenced_code_block_delimiter` nunca se cerró, y sin `language` en el `info_string` es texto plano.

Lo de "vacío" hay que medirlo con cuidado, porque un salto de línea suelto sí produce un
`code_fence_content`: lo que cuenta es si alguna fila del cuerpo tiene algo que no sea espacio. Y
"fila del cuerpo" no es la línea entera. Dentro de una cita las filas llevan delante los `>` que la
continúan, y la última llega solo hasta donde arranca el ``` de cierre. Así que se mira cada fila a
partir de la columna donde empieza el fence, y la última recortada donde acaba el cuerpo: lo de
delante es prefijo de la cita, lo de detrás es el propio cierre. Un `>` escrito ya dentro del
bloque cae detrás de esa columna, así que sigue contando como contenido y el bloque no es vacío.

En las filas rescatadas se descartan las marcas del plugin que las dejaban invisibles (su
`conceal_lines` y su etiqueta de lenguaje) y se ponen banda y etiqueta propias. La banda se queda
en todos los modos y también con el cursor encima; la etiqueta, que sí tapa el texto real, se
aparta con el cursor en la línea para poder editar los ``` . Un bloque vacío rescata sus dos
delimitadores; uno sin cerrar solo el suyo, porque el resto ya se ve de más; y uno sin lenguaje
solo la apertura, porque su cierre se oculta igual que el de cualquier bloque con lenguaje. La
cabecera de texto plano va en gris neutro a propósito: no es un aviso, es el nombre que le faltaba
al bloque, y no debe competir con el ámbar ni con el rojo. Un bloque normal no se toca.

## Contrato visual

La configuración efectiva del plugin es la fuente de los iconos. Con sus defaults actuales:

| Fuente                                  | Vista renderizada aproximada                  | Celdas |
| --------------------------------------- | --------------------------------------------- | -----: |
| `[[other_a]]`                           | `󱗖 other_a`                                   |      9 |
| `[blabla](other_a)`                     | `󰌹 blabla`                                    |      8 |
| `[texto][label]`                        | `󰌹 texto`                                     |      7 |
| `[label][]` con definición              | `󰌹 label`                                     |      7 |
| `[label]` con definición                | `󰌹 label`                                     |      7 |
| `[missing]` sin definición              | `missing`                                     |      7 |
| `[label]: enlace.md "description"`      | `󰌹 label (description)`                       |     21 |
| `[label]: enlace.md`                    | `󰌹 label`                                     |      7 |

Los dos iconos de la tabla ocupan dos celdas: el glifo ocupa una y el espacio posterior otra.
`[texto][label]` ya lo trata render-markdown.nvim; la extensión no añade un segundo icono. Las
formas colapsada y abreviada solo reciben icono si la definición existe en el buffer.
En una definición, el destino sigue existiendo para navegación y rename, pero queda completamente
oculto. El título opcional se inyecta sin sus delimitadores como descripción entre paréntesis.

## Semántica de referencias

Las cuatro piezas comparten el mismo identificador normalizado:

```markdown
[label]: enlace.md "description"

[texto][label]
[label][]
[label]
```

Dentro de un vault, el adaptador de Obsidian permite:

- navegar desde cualquiera de los usos al destino de la definición;
- renombrar `label` en la definición y todos sus usos mediante rename LSP;
- renombrar por separado el texto visible de `[texto][label]`;
- renombrar o convertir por separado el destino de la definición;
- renombrar localmente la descripción sin cambiar sus comillas o paréntesis;
- completar destinos locales e identificadores definidos;
- mostrar con `K` metadatos y un extracto de la nota desde cualquiera de sus usos;
- conservar el título opcional, los destinos entre `<...>` y los fragments.

## Medición y formateadores

`hzsr.md.visible_width()` incluye por defecto el icono que render-markdown muestra. Si recibe
`bufnr`, utiliza la configuración efectiva de ese buffer y solo considera referencias abreviadas
o colapsadas que tengan definición. `markdown_wrap` pasa su buffer a esta función.

La cadena actual sigue siendo:

```text
markdown_callouts → markdown_frontmatter_prepare → markdown_spoilers_prepare → prettier
→ markdown_spoilers_restore → markdown_frontmatter_restore → markdown_reference_definitions
→ markdown_wrap → markdown_tabs
```

`markdown_callouts` protege la sintaxis antes de Prettier. El par de pasadas de frontmatter
sustituye temporalmente un bloque YAML/TOML inicial por un marcador válido y lo restaura byte por
byte, de modo que Prettier formatea el cuerpo sin reescribir la sangría de las propiedades. Después,
`markdown_spoilers_prepare` cambia temporalmente solo los fences estructurales de spoiler por una
inyección Markdown marcada; así Prettier formatea su cuerpo. Cada nombre lleva su propio marcador
—`spoiler` y `spoiler-block` no comparten uno— para que la pasada de vuelta devuelva el que había
escrito y no el otro. También sustituye cada spoiler inline
por un token atómico de nueve celdas —el ancho exacto de `󰈉 SPOILER`— para impedir que Prettier
parta su contenido oculto por el ancho bruto. La
pasada inmediatamente posterior restaura tanto los fences como el texto inline exacto. El escáner
respeta fences exteriores, código inline, escapes y tablas, por lo que los ejemplos literales no se
transforman.
`markdown_reference_definitions` vuelve a una sola línea las definiciones que Prettier expande por
su ancho bruto: no se admite una gramática propia multilínea. `markdown_wrap` corrige el cálculo
de ancho de la prosa y `markdown_tabs` normaliza la sangría al final. La pasada de definiciones es
idempotente y no modifica las que ya estaban en una línea.

`markdown_wrap` reenvuelve tanto los párrafos como los ítems de lista, que sufrían el mismo
problema: un ítem con un wiki-link largo saltaba de línea aunque su vista cupiera de sobra. Cada
ítem se mide por el ancho visible de su contenido y sus líneas de continuación se alinean bajo el
prefijo (sangría + marcador y, si la hay, la casilla de tarea, igual que Prettier), así que las
listas anidadas y ordenadas conservan su nivel. Un párrafo suelto conserva su sangría y la
descuenta del ancho. El resto —fences, cabeceras, blockquotes, tablas, reglas, definiciones y
HTML— se pasa intacto, y también cualquier lista que contenga algo que no sea prosa.

`hzsr.md.visible_width()` mide `||contenido||` como el ancho en celdas de `󰈉 SPOILER`, y el
tokenizador lo conserva como una unidad aunque contenga espacios. Esta medida es estable: no cambia
cuando el cursor revela temporalmente el contenido. Los bloques `spoiler` quedan fuera del wrapping
exterior y su cuerpo se formatea independientemente como Markdown embebido.

## Pruebas

`spec/render_markdown_spec.lua` inspecciona los extmarks reales. Reconstruye por línea el ancho de
pantalla a partir de los conceals de Tree-sitter, los conceals del plugin y `virt_text` inline, y
lo compara con `hzsr.md.visible_width()`. También verifica una decisión de salto de línea donde
contar solo la label produciría un resultado distinto.

`spec/conform_markdown_spec.lua` fija el orden semántico de la cadena y comprueba que la salida
multilínea de Prettier se colapsa de forma idempotente. `spec/spoilers_spec.lua` cubre extmarks,
revelado contextual, falsos positivos, inyección Markdown, ancho exacto y wrapping; el spec de
Conform comprueba además la transformación reversible de los fences, con los dos nombres y su
marcador propio.

`spec/markdown_tags_and_fences_spec.lua` cubre las dos marcas propias sobre extmarks reales: qué
tags reciben chip y cuáles no (code spans, destinos de enlace, `#123`, `#ff00ff`), y que un fence
vacío o sin cerrar recupera sus filas con banda y etiqueta —con lenguaje cuando lo hay—, que el
bloque normal sigue intacto y que la etiqueta se aparta con el cursor encima sin llevarse la banda.
Fija también los tres casos que se añadieron después: un cuerpo de solo blancos cuenta como vacío,
los `>` de una cita no cuentan como cuerpo pero un `>` escrito dentro del bloque sí, y un fence sin
lenguaje recibe su cabecera gris sin rescatar el cierre. Como el fondo del propio plugin también
llega al final de la línea, esas comprobaciones buscan la banda por su grupo, no la primera que
haya en la fila.
