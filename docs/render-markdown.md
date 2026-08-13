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
└── links.lua   # definiciones, referencias, iconos y ancho de icono
```

`require("lzy.render-markdown")` conserva la misma API pública.

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
markdown_callouts → prettier → markdown_reference_definitions → markdown_wrap → markdown_tabs
```

`markdown_callouts` protege la sintaxis antes de Prettier. Después,
`markdown_reference_definitions` vuelve a una sola línea las definiciones que Prettier expande por
su ancho bruto: no se admite una gramática propia multilínea. `markdown_wrap` corrige el cálculo
de ancho de la prosa y `markdown_tabs` normaliza la sangría al final. La pasada de definiciones es
idempotente y no modifica las que ya estaban en una línea.

## Pruebas

`spec/render_markdown_spec.lua` inspecciona los extmarks reales. Reconstruye por línea el ancho de
pantalla a partir de los conceals de Tree-sitter, los conceals del plugin y `virt_text` inline, y
lo compara con `hzsr.md.visible_width()`. También verifica una decisión de salto de línea donde
contar solo la label produciría un resultado distinto.

`spec/conform_markdown_spec.lua` fija el orden semántico de la cadena y comprueba que la salida
multilínea de Prettier se colapsa de forma idempotente.
