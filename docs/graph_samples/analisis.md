# Análisis de los lenguajes de grafos

## D2

### Puntos fuertes

- Sin estilo ya queda bien: colores, fuente, márgenes y cajas de clase salen solos, y la variante con estilo apenas cambia.
- Sintaxis corta y legible: `nombre: etiqueta {shape: …}` para los nodos y `a -> b: etiqueta` para las aristas.
- Forma de clase propia (`shape: class`), con visibilidad, tipos y retornos alineados en columnas.
- Forma de persona (`shape: person`) y contenedores anidados, que bastan para imitar bien los casos de uso.
- Trae tres motores de layout (dagre, ELK y TALA) y se elige por diagrama.
- En Neovim tiene parser de Tree-sitter: uno externo ([ravsii/tree-sitter-d2](https://github.com/ravsii/tree-sitter-d2)) con el commit fijado, porque no está en el catálogo de nvim-treesitter. Con él, los bloques ` ```d2 ` de un markdown también se colorean. Sin instalarlo, resalta un `syntax/d2.vim` propio.
- En Neovim tiene formatter: `d2 fmt` vía Conform, que además valida, porque si el archivo no parsea el formateo falla con la línea del error.

### Puntos flojos

- No tiene diagrama de casos de uso nativo: hay que montarlo con personas, óvalos y un contenedor.
- Los métodos con parámetros variádicos (`...UnitID`) tienen que ir entre comillas, o el parser falla.
- En las clases, los métodos sin retorno salen con un `void`, que en Go no existe.
- El rombo de composición no se ve en el PNG, aunque se declare con `source-arrowhead`.
- Cada motor de layout da resultados muy distintos: el flujo salía enredado con ELK y limpio con dagre, así que hay que probar.
- En Neovim no tiene LSP (no existe ningún servidor de D2): los errores no se ven hasta formatear o renderizar.
- En Neovim no tiene linter.

### Dificultad de uso

**Nota: 2/10.** Lo que sale por defecto ya sirve: en `sin_estilo/` no hay ni un color y se ve bien. Lo único que pide trabajo es elegir motor de layout (el flujo quedaba enredado con ELK) y montar los casos de uso con personas y óvalos.

- **¿Hay que meter mano por una buena razón?** Casi siempre. Los casos de uso se imitan porque D2 no los tiene, y el motor de layout se elige porque cada diagrama pide uno. El único rodeo sin justificación es entrecomillar los variádicos.
- **¿Se puede automatizar?** Sí, y es lo más limpio de los cuatro. Una plantilla `estilo.d2` se importa con `...@estilo` y define `classes` reutilizables: un nodo hereda el color con `class: error` y una relación la línea discontinua con `class: dependencia`. Comprobado en `con_plantilla/`. El tema y el motor también se pueden pasar sin tocar el archivo (`D2_THEME`, `D2_LAYOUT` o `--theme`), y eso también lo he probado.
- **¿Cuánto hay que escribir?** Una línea de import arriba, más `class: nombre` sólo en los nodos que se quieran destacar.
- **¿Merece la pena?** No hay mucho que pagar: sin plantilla ya es el que mejor queda, y con ella lo sigue siendo.

### Anotaciones

Nada destacable.

## DOT (Graphviz)

### Puntos fuertes

- Es el más maduro y el que más se encuentra en otras herramientas.
- El flujo sale correcto sin ajustes, y las vueltas del bucle quedan mejor sin retoques de layout que con ellos.
- Las tablas HTML en las etiquetas dan control total sobre el contenido de cada nodo.
- En Neovim tiene LSP: `dotls`, que se instala con Mason.
- En Neovim tiene parser de Tree-sitter (`dot`), y con él se colorean también los bloques ` ```dot ` de un markdown.

### Puntos flojos

- Sin estilo queda austero: fuente serif y todo en blanco y negro.
- No sabe qué es una clase: cada clase es una tabla HTML escrita a mano, que es lo más largo de escribir de los cuatro.
- No tiene actores ni casos de uso: los actores son cajas con `«actor»`.
- La forma por defecto de un nodo es la elipse, así que en el flujo hay que declarar `shape=box`.
- `graph` es palabra reservada y no distingue mayúsculas: un nodo llamado `Graph` tiene que ir entre comillas.
- En Neovim no tiene formatter: no existe ninguno.
- En Neovim no tiene linter.

### Dificultad de uso

**Nota: 6/10.** Sin estilo es correcto pero en blanco y negro con fuente serif, y hay que meter mano en la estructura de casi todo: tablas HTML para las clases, `shape=box` para los pasos de un flujo y cajas `«actor»` para los actores.

- **¿Hay que meter mano por una buena razón?** En parte. Las tablas y los actores suplen lo que DOT no sabe dibujar, y eso es inevitable. La fuente serif y la elipse por defecto son malos valores por defecto que hay que corregir siempre.
- **¿Se puede automatizar?** A medias. El lenguaje no tiene `include`, pero `dot` acepta atributos globales por línea de comandos (`-G`, `-N`, `-E`), y en `con_plantilla/` van en `estilo.args`: fuente, relleno y color de aristas para todos los diagramas sin tocarlos. Dentro de un archivo, `node [...]` y `edge [...]` se heredan en los subgrafos. Lo que no llega a ninguna plantilla es el interior de las tablas HTML: el color de la cabecera de cada clase va escrito celda a celda.
- **¿Cuánto hay que escribir?** Para el aspecto general, nada en el diagrama. Para las clases, todo a mano y repetido en cada tabla.
- **¿Merece la pena?** Con la plantilla, flujo y casos de uso quedan dignos, por debajo de D2 y PlantUML. Las clases siguen siendo lo más largo de escribir de los cuatro.

### Anotaciones

`dotls` sólo arranca dentro de un repositorio git (`root_markers = { '.git' }`).

## Mermaid

### Puntos fuertes

- Sin estilo trae un tema con colores y queda presentable.
- `classDiagram` es nativo y su sintaxis es la más cercana a escribir código.
- Se renderiza dentro de los markdown de GitHub y de muchas otras herramientas, sin generar imagen.
- En Neovim tiene parser de Tree-sitter (`mermaid`), y también resalta los bloques ` ```mermaid ` dentro de un markdown.

### Puntos flojos

- Para generar una imagen hace falta `mmdc`, que dibuja con un navegador headless: el paquete arrastra `chromium`.
- Los nodos círculo (`((Autor))`) salen enormes, incluso en un diagrama de dos nodos.
- No tiene diagrama de casos de uso: hay que imitarlo con un `flowchart`.
- En los rombos, el texto se parte en líneas muy cortas, salvo que se suba `wrappingWidth`.
- En `classDiagram`, los retornos con paréntesis (`(Entry, bool)`) se pegan al método sin los `:`.
- Una línea `%%` vacía en un comentario rompe el parser.
- Con el tema `base`, `fontFamily: sans-serif` acaba en una fuente serif.
- En Neovim no tiene LSP ni formatter.
- En Neovim no tiene linter.

### Dificultad de uso

**Nota: 4/10.** Sin estilo trae un tema con color y queda presentable, pero hay que ajustar cosas que no son de estilo: el ancho de texto en los rombos y la forma de los actores, porque los círculos salen enormes.

- **¿Hay que meter mano por una buena razón?** Poco. Los casos de uso se imitan porque no existen, pero el ancho de texto y el tamaño de los círculos son defectos del renderizado, y `fontFamily: sans-serif` acaba en serif.
- **¿Se puede automatizar?** Sí, con un límite. `mmdc -c config.json` aplica tema, paleta y `wrappingWidth` a todos los diagramas sin tocarlos: comprobado en `con_plantilla/`. Pero los colores por nodo (`classDef`) se declaran en cada diagrama, y los círculos siguen enormes porque son forma, no estilo. Ojo: GitHub no lee `config.json`, así que donde Mermaid más se usa, en el markdown, la configuración tiene que ir en el frontmatter de cada bloque.
- **¿Cuánto hay que escribir?** Con `mmdc`, nada en el diagrama. Para verse igual en GitHub, unas quince líneas de frontmatter repetidas en cada diagrama.
- **¿Merece la pena?** Clases y flujo quedan bien, casi a la altura de D2. Los casos de uso son los más pobres de los cuatro.

### Anotaciones

`mmdc` saca el PNG con fondo transparente salvo que se le pase `-b white`.

## PlantUML

### Puntos fuertes

- Es el único con los tres diagramas nativos, casos de uso incluidos, con monigotes, `«include»` y `«extend»`.
- El diagrama de actividad tiene estructuras de control de verdad (`if`, `while`, `repeat`), así que el bucle anidado sale exacto.
- Sin estilo tiene el aspecto UML clásico y es correcto.
- Con unas pocas líneas de `skinparam` cambia mucho de aspecto.
- En Neovim tiene LSP: `plantuml_lsp`, con diagnósticos y autocompletado. Para diagnosticar usa el propio binario `plantuml`.

### Puntos flojos

- Sin estilo se ve anticuado: gris, con sombras y con el círculo de la «C» en cada clase.
- Necesita Java.
- Un color en una acción (`#color:texto;`) justo después de `endwhile` da error de sintaxis; hay que usar estereotipos y `<style>`.
- El color de fuente del bloque `class` no se aplica al nombre de la clase.
- Los mensajes de error sólo dan el número de línea, sin decir qué falla.
- En Neovim el LSP no viene con Mason ni con paquete de Arch: hay que compilarlo con `go install`.
- En Neovim no tiene formatter: no existe ninguno.
- En Neovim no tiene linter.
- En Neovim no tiene parser de Tree-sitter: el resaltado es un `syntax/plantuml.vim` propio de esta configuración. Ninguna gramática de terceros es usable (probadas tres, todas fallan con diagramas corrientes), así que no se puede hacer lo de D2.
- En Neovim, los bloques ` ```plantuml ` de un markdown salen sin color: la inyección necesita un parser de Tree-sitter.

### Dificultad de uso

**Nota: 3/10.** Por estructura es el que menos mano pide: los tres diagramas son nativos y el bucle anidado se escribe con `while` y `if`. Pero sin estilo se ve anticuado, gris, con sombras y con la «C» de cada clase, y casi siempre apetece cambiarlo.

- **¿Hay que meter mano por una buena razón?** Por estructura, nunca. Por aspecto, sí: el aspecto por defecto es un mal punto de partida, no una limitación del lenguaje.
- **¿Se puede automatizar?** Sí, y es donde más rinde. `plantuml -config estilo.puml` aplica un archivo de `skinparam` a todos los diagramas sin tocarlos (comprobado en `con_plantilla/`), y también se puede hacer con `!include` dentro del diagrama. Los `skinparam` van por tipo de elemento (`class`, `actor`, `usecase`, `activity`), así que una línea vale para todos los de ese tipo. Hay temas de serie con `!theme`, pero no los he probado.
- **¿Cuánto hay que escribir?** Con la plantilla, nada en el diagrama. Sin ella, unas veinte líneas arriba del todo.
- **¿Merece la pena?** Sí: con la plantilla queda a la altura de D2, y es el que mejor dibuja los casos de uso.

### Anotaciones

Por defecto el PNG sale pequeño; hace falta `-Sdpi=200` para que se lea bien.

## Comparativa de dificultad de uso

| Lenguaje | Nota | Plantilla externa | Herencia de estilos | Una vez pagado el precio |
| --- | --- | --- | --- | --- |
| D2 | 2/10 | Sí: `...@estilo`, o `D2_THEME` y `D2_LAYOUT` | Sí, con `classes` | El mejor, con o sin plantilla |
| PlantUML | 3/10 | Sí: `-config` o `!include` | Por tipo de elemento (`skinparam`) | A la altura de D2; el mejor en casos de uso |
| Mermaid | 4/10 | Con `mmdc -c`; en GitHub no, va en el frontmatter de cada diagrama | Tema global; `classDef` por diagrama | Bien en clases y flujo; flojo en casos de uso |
| DOT | 6/10 | Sólo por línea de comandos (`-G`, `-N`, `-E`) | `node`/`edge` por defecto, en subgrafos; no dentro de tablas HTML | Digno, por debajo del resto; clases muy largas |

Las tres variantes de cada lenguaje están en su carpeta: `sin_estilo/`, `con_estilo/` (ajustado a mano en cada diagrama) y `con_plantilla/` (una plantilla compartida y los diagramas de `sin_estilo/` casi sin tocar).
