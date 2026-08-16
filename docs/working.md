# Working: dos bugs de la acción inteligente

## 1. Badge `[![alt](img)](url)` en `<CR>` (obsidian, `lua/lzy/obsidian/links.lua`)

Diagnóstico (confirmado con nvim --headless sobre el badge de PayPal del
README): `attachments.cursor_linked_image()` ya decide bien la prioridad
(imagen gana solo sobre su propio destino; el enlace exterior gana en el
resto), y `patch_action_follow` (`actions.follow_link`) ya la respeta.

El bug está en `patch_smart_action` / el propio `<CR>`:

- `obsidian.actions.smart_action` decide si hay enlace mirando solo el
  `api.cursor_link()` nativo, que no ve el enlace exterior de un badge
  (columna sobre `](https://paypal...)`) → cae a otra rama (checkbox) y
  no pasa nada.
- Cuando sí detecta algo (columnas sobre `Donate` o sobre la URL de la
  imagen), devuelve `<cmd>Obsidian follow_link<cr>`, que dispara
  `vim.lsp.buf.definition` → eso NO pasa por `actions.follow_link`
  parcheado, así que pierde la prioridad de `cursor_linked_image` y
  siempre resuelve al enlace nativo (la imagen).

Fix: en `patch_smart_action`, si `attachments.cursor_linked_image()`
detecta un badge bajo el cursor, despachar directo a
`require('obsidian.actions').follow_link()` (la versión parcheada) en
vez de dejar que seas `api.cursor_link()`/`:Obsidian follow_link` decidan.

## 2. Copia inteligente no actualiza el registro de nvim

`smart_copy.default_copy` / `link_actions.yank_path` ya hacen bien el
`setreg` (`"` y `0`); confirmado con test headless. `cfg.lua` tiene
`sync_clipboard = true`, que activa `clipboard=unnamedplus` -- eso alía
el registro `"` al `+` del sistema. Los binds `<leader>cs`/`<leader>cn`
(sync manual Neovim<->sistema) solo tienen sentido si de base NO están
sincronizados; con `unnamedplus` de fondo son redundantes y cualquier
selección de mouse/otra app puede pisar `"`/`+` por fuera del control de
nvim -- de ahí que ni `p` ni Ctrl+Shift+V reflejen lo recién copiado.

Fix: `sync_clipboard = false` (como recomienda el propio comentario del
archivo), dejando el sync system<->nvim solo a los binds explícitos.

## 3. Volver a nombres verbatim (revertir la slugificación) — HECHO

Decisión revertida: escribir enlaces en minúsculas-con-guiones en lugar de
conservar el nombre/heading original con sus espacios y mayúsculas.

Por qué se podía revertir barato: `headings.resolve` estandariza LOS DOS
lados al comparar, así que el slug nunca fue un requisito del motor, solo
la forma que elegíamos al escribir. Verificado: `#Installation on Linux`,
`#installation-on-linux` y `#INSTALLATION ON LINUX` resuelven al mismo
heading. Consecuencia: **cero migración**, los enlaces ya escritos siguen
resolviendo para siempre.

Los datos del vault real (1235 notas) daban la razón al cambio: 90% de los
nombres con mayúscula, 59% con espacios, y 89% de los anchors ya estaban en
verbatim. El slug era la convención minoritaria y cada rename la propagaba.

Cambios:
- `headings.anchor_text(name, kind)` nuevo: política de ESCRITURA. Wiki va
  verbatim; markdown percent-encodea siempre (un espacio corta el destino y
  deja medio enlace parseado -- ésta era la única trampa real). Un heading
  con `[`/`]`/`|`/`#` no es representable en `[[...]]`, así que ahí cae al
  anchor canónico.
- `headings.rename` y `smart_copy` pasan por ella (eran los 2 únicos puntos
  de escritura).
- `note_id_func` -> `new_note.verbatim_id`: `:Obsidian new` con "Mi Nota"
  da `Mi Nota.md`, no `mi-nota.md`. Colisiones -> "Mi Nota 2". Quita solo
  `#^[]|/\` (rompen enlace o fabrican carpetas). Esto alinea las dos
  puertas de creación: crear-desde-enlace ya era verbatim.

NO se tocó marksman a propósito: es un LSP CommonMark y GitHub/mdBook
renderizan `#my-header`; ahí el slug es la convención correcta para interop.
