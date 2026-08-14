---
id: marksman
aliases: []
tags: []
---

# Marksman — documento de trabajo

## Hechos comprobados

Probado con Marksman `2026-02-08`:

| Forma                    | Resolución de Marksman                                                       |
| ------------------------ | ---------------------------------------------------------------------------- |
| `[x](algo.md)`           | busca por nombre/path en el workspace; puede devolver varios homónimos        |
| `[x](./algo.md)`         | relativo exacto a la carpeta de la nota; no hace fallback                     |
| `[x](../algo.md)`        | relativo exacto en el padre                                                   |
| `[x](/algo.md)`          | path exacto desde la raíz del workspace                                       |
| `[x](/algo)`             | igual que el anterior; resuelve la extensión Markdown                         |
| `[x][id]`                | busca una definición `[id]: destino`; el identificador no contiene un path    |
| `[id]: destino "título"` | identifica y renombra `id`, pero no trata aún destino/título como símbolos LSP |

`algo.md` y `./algo.md` pueden coincidir si solo hay un candidato junto a la nota, pero no tienen
el mismo contrato. En una prueba con tres `duplicate.md`, el destino desnudo devolvió los tres;
`./duplicate.md` devolvió únicamente el vecino y `/duplicate.md` únicamente el de la raíz.
`./root-only.md` desde una subcarpeta quedó roto aunque `/root-only.md` funcionaba. No existe un
fallback de `./` a la raíz. `[[algo]]` es una extensión wiki, no Markdown estándar.

La raíz es la que el cliente entrega a Marksman (`.marksman.toml` o `.git` en esta configuración).
Por tanto, `/nota.md` solo puede funcionar como se espera si el LSP arrancó con la raíz correcta.

## Auditoría funcional de Marksman

La versión `2026-02-08` ya implementa:

- `gd` y hover renderizado para `[[nota]]` y `[texto](nota.md)`, incluidos fragmentos;
- completion de enlaces inline, que propone paths inequívocos desde la raíz (`/path/nota.md`);
- completion y rename global del identificador en `[texto][id]`, `[id][]`, `[id]` y `[id]: ...`;
- rename de headings iniciado en su declaración, actualizando enlaces inline y wiki.

No implementa todavía:

- `gd`, hover ni completion sobre el destino de `[id]: destino "título"`;
- hover de la nota desde los usos de una referencia (muestra la definición en crudo);
- rename independiente del destino, título o label visible;
- iniciar desde un fragment del enlace el rename del heading enlazado;
- incluir destinos de definiciones de referencia al actualizar un heading;
- renombrar/mover una nota y reescribir sus enlaces.

El adaptador Sabunv completa solo esas carencias y delega el resto en Marksman.

CommonMark define destinos, pero no un workspace ni un filesystem. GitHub, MkDocs u otro
consumidor pueden reescribirlos o dar una semántica propia a `/`; esa variación es real y está
fuera de la sintaxis Markdown.

## Qué configura `.marksman.toml`

- Configura extensiones, H1 como título, wikilinks, completado y code actions.
- La configuración del proyecto prevalece sobre la global de Marksman.
- No puede hacer `algo.md` root-relative, cambiar la base inline ni definir aliases de rutas.
- `completion.wiki.style` afecta a `[[wikilinks]]`, no a `[x](path.md)`.

Qué carpeta se entrega como root y si se permite arrancar sin ella son decisiones del cliente
LSP, no de `.marksman.toml`.

## Fronteras

| Capa                    | Decide                                                     |
| ----------------------- | ---------------------------------------------------------- |
| CommonMark              | sintaxis del destino; no define un workspace               |
| Cliente LSP             | root y si admite modo single-file                          |
| Marksman                | resolución observada de inline links y wikilinks           |
| `.marksman.toml`        | títulos, wikilinks, extensiones, completado y code actions |
| Adaptador Sabunv        | referencias, rename y políticas que Marksman no implemente |

## Contrato decidido

1. La resolución sigue a Marksman: `/` parte de la raíz; `./` y `../` son estrictamente relativos
   a la nota; un destino desnudo puede ser ambiguo y nunca se elige arbitrariamente.
2. `gx` usa el mismo sistema de coordenadas también para adjuntos. En particular, `/asset.png`
   parte de la raíz del proyecto y `./asset.png` de la carpeta de la nota.
3. No se introducen bases, aliases ni `.nyamarksman` propios.
4. El rename del componente nota mueve el archivo y actualiza sus enlaces; el componente fragment
   renombra únicamente el heading y sus referencias. Los fragmentos se reescriben en su forma
   canónica (`Nueva Sección` → `nueva-sección`) también en wikilinks. Labels, identificadores y
   títulos se mantienen como componentes independientes, igual que en `obsidian-ls`.
5. Los destinos de referencia tienen hover de la nota; los adjuntos no fabrican preview propia.
6. Después de resolver un adjunto, su contenido decide la apertura: texto dentro de Neovim y
   binario mediante `vim.ui.open()`. La extensión no participa en esa decisión.

## Implementación

- `K` usa el mismo preview propio para wikilinks, enlaces inline, definiciones y usos CommonMark.
  Así nunca entrega a Neovim el hover de ancho cero que Marksman devuelve para una nota vacía y
  nunca muestra el frontmatter como cuerpo. Una nota sin cuerpo muestra una tarjeta explícita de
  “Nota vacía”, con aliases y tags cuando existen.
- `gd` conserva la navegación nativa y añade navegación directa desde el identificador, destino o
  fragmento de `[id]: destino "título"`. Los usos `[texto][id]`, `[id][]` y `[id]` siguen yendo a
  la declaración. Si un inline, wiki o una declaración resuelve un adjunto, `gd` usa el mismo
  opener por contenido que `gx`.
- `<C-A-r>` distingue label visible, identificador de referencia, nota, heading, URL, título y
  tag. El rename de nota mueve el archivo y reescribe solo referencias inequívocas; el de heading
  delega en Marksman y completa los fragmentos de definiciones que el servidor omite. Renombrar
  un tag cambia también su frontmatter y toda su rama (`padre/hijo` conserva `/hijo`).
- El completado adicional actúa en destinos de definiciones, inline y wiki, incluidos los todavía
  incompletos `[[/` y `[texto](/`. `/`, `./` y `../` ya son intención suficiente para listar
  notas desde el primer carácter; la coordenada elegida se conserva en el resultado.
- `<leader>nb` abre siempre el picker de backlinks, incluso con cero o un resultado. El índice
  resuelve links inline, wiki y los usos CommonMark a través de su declaración; omite código,
  frontmatter, declaraciones sin usar y destinos ambiguos.
- `<leader>nf` sigue el destino final bajo el cursor. `<CR>` aplica la misma acción inteligente de
  Obsidian: sigue enlaces, permite elegir el tag o subtag y después muestra las notas de esa rama,
  pliega headings/frontmatter cuando el folding Markdown está activo o conmuta y crea checkboxes.
  El selector indica cuántas notas y apariciones contiene cada rama. Sin folding, Enter sobre un
  heading conserva su acción normal. `<leader>nx` deja disponible la acción de checkbox de forma
  explícita.
- El índice estructural usa Tree-sitter para excluir frontmatter, HTML y bloques de código, y
  reconoce headings ATX y Setext, Unicode y anchors duplicados.
- `gx` comparte con Nyabsidian un opener portable. Usa `file` cuando existe y un detector propio
  de firmas, BOM, NUL y bytes de control como fallback; por eso un `.mp4` textual se edita en
  Neovim y un PNG llamado `.txt` conserva la aplicación del sistema.

## Fuentes

[CommonMark](https://spec.commonmark.org/0.31.2/#links), [features de Marksman](https://github.com/artempyanykh/marksman/blob/main/docs/features.md), [configuración](https://github.com/artempyanykh/marksman/blob/main/docs/configuration.md) y [opciones actuales](https://github.com/artempyanykh/marksman/blob/main/Tests/default.marksman.toml).
