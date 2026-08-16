# working.md — completion de `[[enlaces`

Pendiente vivo. Se borra cuando no quede nada en "Falta".

## Mapa (para no perderse)

Dos motores completan destinos de enlace en markdown:

| motor | cuándo | dónde vive |
|---|---|---|
| marksman | proyecto normal con LSP marksman | `lua/lzy/marksman/completion.lua` |
| obsidian.nvim | vault (carpeta con `.nyabsidian`) | `lua/lzy/obsidian/completion.lua` + el plugin |

`lua/lzy/link_target.lua` es la parte común de los dos: qué significa lo que
tecleas al empezar el destino.

    /algo    → raíz del proyecto/vault; si ahí no existe, ruta absoluta del sistema
    ./algo   → relativo a la nota (igual ../algo)
    algo     → desnudo, lo resuelve el buscador de cada lado

---

## Problema A — `[[/` no ofrecía carpetas · **HECHO**

**Era.** Escribo `[[/` y no aparece `/docs` ni ninguna otra carpeta. Solo
archivos, así que no hay forma de bajar por el árbol sin acertar el nombre del
archivo a ciegas.

**Causa.** Ningún lado listaba directorios: marksman filtraba `kind == "file"`
y obsidian solo devuelve notas.

**Decisión tomada.** `/` es ambiguo a propósito: se ofrecen **las carpetas de
la raíz del proyecto y las de la raíz del sistema**, distinguidas por el
`detail` del item ("Carpeta del proyecto" / "Carpeta del vault" / "Carpeta del
sistema").

**Hecho.** `[[/` es navegación de rutas: abre el nivel, aceptas una carpeta,
abre el siguiente.

- `link_target.entries(query, root, { files })` — enumera lo que hay en el nivel
  tecleado, en las dos raíces. Las carpetas van con `/` final y primero (son el
  camino, no el destino).
- Lo consumen los dos lados: `marksman/completion.lua` (solo carpetas: las notas
  ya se las pone su índice de proyecto) y, vía el nuevo `wiki_target_context`,
  `obsidian/completion.lua` con `files = true` — el plugin busca notas por
  nombre y no entiende un destino que empieza por `/`, así que dentro de
  `[[/docs/` no ofrecía nada.
- La barra ahora dispara la lista. obsidian-ls declara `{ "[", "#", "^" }` como
  trigger characters; `/` no estaba y no es carácter de palabra, así que el
  cliente no pedía nada hasta la primera letra siguiente. `patch_trigger_
  characters` en `obsidian/completion.lua` la añade. En marksman ya estaba
  (`get_trigger_characters`).
- `marksman/workspace.lua:resolve` prueba la ruta absoluta del sistema cuando
  `/loquesea` no cuelga del proyecto — si no, la completion ofrecería enlaces
  que luego no abren.

## Problema B — `[[/d` ofrecía `(create)` y escribía `[[1786869003-VDUY|/do]]` · **HECHO**

**Era.** Escribo `[[/d`, sale `[[/do]] (create)`, la acepto, y en el buffer
queda `[[1786869003-VDUY|/do]]`.

**Causa, la cadena entera:**

1. obsidian.nvim siempre añade un item "crear nota nueva" con lo tecleado como
   nombre (`completion/sources/new.lua`). No le importa que sea una ruta a
   medias.
2. Para crear esa nota llama a `note_id_func`. El default es `zettel_id` →
   `1786869003-VDUY`. **El nombre que tecleas no es el id de la nota**, es solo
   la etiqueta.
3. Al escribir el enlace usa `builtin.wiki_link`: si la etiqueta ≠ id, produce
   `[[id|etiqueta]]`.

**Hecho.**

- `note_id_func = builtin.title_id` en `make_opts()` de
  `lua/lzy/obsidian/init.lua`: el id de una nota nueva es el slug del título, el
  archivo se llama igual y el enlace queda legible (`[[mis-notas]]`). Solo
  afecta a notas nuevas.
- El item `(create)` se retira entero cuando lo tecleado es una coordenada de
  ruta (`sanitize` en `obsidian/completion.lua`): `[[/docs` no pide crear una
  nota `/docs`.
- `drop_pathish_alias` se queda como red de seguridad para el resto de casos.

**Ojo, dos formas de crear nota conviven a propósito:**

- desde la completion → `title_id`, slug (`mis notas` → `mis-notas.md`).
- desde un enlace ya escrito, `lzy.obsidian.new_note` → `verbatim`, el archivo
  se llama exactamente como el enlace. Slugificar aquí rompería el `[[NAME]]`
  que lo pidió.

---

## Problema C — el enlace-imagen `[![alt](img)](url)` salía como dos enlaces · **HECHO**

**Era.** El patrón de los badges. Dos iconos pegados, como si hubiera dos
enlaces distintos, y los formateadores midiendo mal la línea.

**Causa.** Es una sola cosa a la vista, pero para tree-sitter son dos nodos
anidados: `inline_link > link_text > image`. Nadie lo trataba como una unidad:

- render-markdown.nvim pinta un icono por nodo → dos.
- `hzsr.md.parse_link` (lo que miden los formateadores) escaneaba la etiqueta
  carácter a carácter, así que el `]` de la imagen le cerraba el enlace de
  fuera. La línea del badge medía ~110 celdas en vez de 8, y `markdown_wrap`
  partía por donde no era.
- `obsidian.parse.refs` solo devuelve la imagen; el destino de fuera era
  invisible para follow, convert y las reescrituras de rename.

**Hecho.** Una cosa, un icono, y el icono es el de imagen — la etiqueta que se
ve es una imagen, no un texto.

- `patch_linked_images` en `lzy/render-markdown/links.lua`: la `image` interior
  calla y el `inline_link` que la envuelve pinta el icono de imagen. Si el
  destino tiene icono propio configurado (`link.custom`), ese manda.
- `hzsr/md/init.lua:parse_link` reconoce la imagen dentro de la etiqueta
  (`image_end`) y mide icono + alt, sin sumar además el icono de enlace. El
  spec de render compara el ancho medido con el ancho realmente renderizado.
- `attachments.parse_refs` añade el enlace exterior como segundo ref, con dónde
  está el destino de la imagen (`image_target_range`).
- `gx` (`attachments.open_under_cursor`) y la acción inteligente
  (`patch_action_follow`) preguntan antes por `cursor_linked_image`: **manda el
  enlace de fuera**. La imagen es la etiqueta en la que se hace clic, no el
  destino — es lo que significa la sintaxis y lo que hace cualquier
  renderizador. La imagen sigue alcanzable en el único sitio donde se la pide a
  propósito: encima de su propio destino.

Marksman no necesitaba nada: su parser ya ve el enlace exterior, y el destino
interior es una imagen, no una nota.

## Falta

- Navegación para `./` y `../`, no solo para `/`. Mismo `link_target.entries`,
  otra rama; no se hizo para no ensanchar el cambio.
- `entries` ignora los enlaces simbólicos (`vim.fs.dir` los devuelve como
  `link`, no como `directory`/`file`). Si en algún vault navegas por symlinks,
  esto es lo que hay que tocar.
- La resolución del lado obsidian (no marksman) no prueba la ruta absoluta del
  sistema. Si acabas usando enlaces `/ruta/del/sistema` dentro de un vault y no
  abren, es esto.

## Ya hecho antes (no rehacer)

- `lua/lzy/link_target.lua`: coordenadas, `is_explicit`, `needle`,
  `filter_text`, `encode`, `relative` — compartido por marksman y obsidian.
- `filter_text` arregló el "empezar por `/` no genera nada" (cmp puntuaba
  `/docs` contra `docs/api.md` → score 0 → item invisible).
- `is_explicit` salta el mínimo de caracteres cuando escribes una coordenada.

## Reglas de la casa

- No commitear sin okay explícito, cada tanda por separado.
- Tests: `nvim --headless -u NONE -c "lua dofile(vim.fn.expand('~/.config/hzsr12/lua/hzsr/test/init.lua')).run({'--plenary'})" -c "qa!"`
