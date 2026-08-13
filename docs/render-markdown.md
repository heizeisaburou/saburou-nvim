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
├── cursor.lua  # cursor contextual de H1
├── inline.lua  # extensiones del handler markdown_inline
├── links.lua   # definiciones, referencias, iconos y ancho de icono
└── spoilers.lua # spoilers inline, bloques e inyección Markdown
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

Fuera del cursor, el inline se sustituye por `󰈉 SPOILER` y el bloque por
`󰈉 SPOILER · N líneas`. Al entrar en el inline desaparece el indicador y queda su contenido sin
delimitadores. En un bloque, el indicador permanece como cabecera y al entrar en una línea de su
cuerpo aparece debajo el Markdown revelado; al salir vuelve a quedar una sola línea. El bloque
registra `spoiler` como una inyección del parser Markdown: al revelarlo no se presenta como código,
sino con headings, énfasis y enlaces renderizados.

La detección inline es deliberadamente conservadora: no admite saltos de línea, contenido vacío,
anidamiento ni delimitadores incompletos. Tampoco actúa dentro de código inline, enlaces, imágenes,
autolinks, texto escapado o tablas. Los fences normales permanecen como código.

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
markdown_callouts → markdown_spoilers_prepare → prettier → markdown_spoilers_restore
→ markdown_reference_definitions → markdown_wrap → markdown_tabs
```

`markdown_callouts` protege la sintaxis antes de Prettier. Después,
`markdown_spoilers_prepare` cambia temporalmente solo los fences estructurales `spoiler` por una
inyección Markdown marcada; así Prettier formatea su cuerpo. También sustituye cada spoiler inline
por un token atómico de nueve celdas —el ancho exacto de `󰈉 SPOILER`— para impedir que Prettier
parta su contenido oculto por el ancho bruto. La
pasada inmediatamente posterior restaura tanto los fences como el texto inline exacto. El escáner
respeta fences exteriores, código inline, escapes y tablas, por lo que los ejemplos literales no se
transforman.
`markdown_reference_definitions` vuelve a una sola línea las definiciones que Prettier expande por
su ancho bruto: no se admite una gramática propia multilínea. `markdown_wrap` corrige el cálculo
de ancho de la prosa y `markdown_tabs` normaliza la sangría al final. La pasada de definiciones es
idempotente y no modifica las que ya estaban en una línea.

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
Conform comprueba además la transformación reversible de los fences.
