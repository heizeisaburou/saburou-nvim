-- Copia inteligente: qué copiar depende de qué hay bajo el cursor.
--
-- Orden de prioridad (el más específico gana):
--   1. Código: el contenido sin delimitadores, tanto inline (`` `x` `` ->
--      `x`) como de bloque (fence o sangrado -> su cuerpo, sin las líneas
--      de ``` y sin la sangría del fence). El salto de línea final lo
--      decides tú: si dejas una última línea en blanco dentro del fence,
--      el texto copiado termina en `\n`; si no, termina sin salto.
--      Va primero a propósito: dentro de código no hay enlaces ni negritas
--      que copiar, solo texto literal, y el parseo de enlaces es por línea
--      (`` `[[x]]` `` se vería como un enlace de verdad).
--   2. Enlace: el componente exacto que se está hovereando (label, target/
--      nota, url, descripción, id de referencia...), ya sin llaves ni
--      paréntesis alrededor -- reusa lzy.obsidian.links.cursor_context(),
--      que ya distingue esto para hover/rename/follow.
--   3. Negrita/cursiva/negrita-cursiva/tachado: el contenido sin los
--      delimitadores (`***hola***` -> `hola`, en cualquier combinación de
--      `*`/`_`; `~hola~` y `~~hola~~` -> `hola`, tachado simple o doble).
--   4. Línea de heading: `[[NombreDeNota#anchor]]`, listo para pegar --
--      mismo criterio de desambiguación de nombre que "Más corto seguro"
--      en NyabsidianConvertLink, mismo algoritmo de slug que usan los
--      enlaces `#anchor` del resto del plugin.
--
-- Si nada de esto aplica (cursor sobre texto plano), copia un enlace a la
-- nota actual entera (`[[NombreDeNota]]`, sin anchor) -- la tecla nunca
-- queda "vacía": ese enlace casi siempre es útil igual. Si ni eso se
-- puede armar (buffer sin nombre, fuera de un vault), ahí sí no copia
-- nada y avisa.

local M = {}

local function default_notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Nyabsidian" })
end

---@param text string
local function default_copy(text)
  -- Igual que un yank normal, pero characterwise: no agrega salto de
  -- línea (mismo criterio que yank_path en link_actions.lua).
  vim.fn.setreg("0", text, "v")
  vim.fn.setreg('"', text, "v")
end

M.notify = default_notify
M.copy = default_copy

---@param text string
---@return string
local function strip_emphasis_markup(text)
  local ch = text:sub(1, 1)
  if ch ~= "*" and ch ~= "_" and ch ~= "~" then
    return text
  end
  local n = 0
  while text:sub(n + 1, n + 1) == ch do
    n = n + 1
  end
  if n > 0 and text:sub(-n) == ch:rep(n) and #text > n * 2 then
    return text:sub(n + 1, -n - 1)
  end
  return text
end

-- Nodo bajo el cursor. `descend` baja a los árboles inyectados: hace falta
-- para lo que vive en markdown_inline (emphasis, code_span) y estorba para
-- lo que vive en el árbol de `markdown` (los bloques de código, cuyo cuerpo
-- es otro árbol inyectado si el fence declara lenguaje).
--
---@param bufnr integer
---@param row0 integer 0-based
---@param col integer 0-based
---@param descend boolean
---@return TSNode|?
local function node_at(bufnr, row0, col, descend)
  local ok, node = pcall(vim.treesitter.get_node, {
    bufnr = bufnr,
    pos = { row0, col },
    ignore_injections = not descend,
  })
  if not ok then
    return nil
  end
  return node
end

--- Primer ancestro (el propio nodo cuenta) cuyo tipo esté en `types`.
---@param node TSNode|?
---@param types table<string, true>
---@return TSNode|?
local function ancestor(node, types)
  local n = node
  while n do
    if types[n:type()] then
      return n
    end
    n = n:parent()
  end
  return nil
end

--- Contenido de un code span (`` `x` ``, ``` ``con ` dentro`` ```) sin sus
--- backticks.
---@param bufnr integer
---@param row0 integer 0-based
---@param col integer 0-based
---@return string|?
local function inline_code_at_cursor(bufnr, row0, col)
  local span = ancestor(node_at(bufnr, row0, col, true), { code_span = true })
  if not span then
    return nil
  end

  local ok, raw = pcall(vim.treesitter.get_node_text, span, bufnr)
  if not ok or type(raw) ~= "string" then
    return nil
  end

  local ticks = raw:match "^`+"
  if not ticks or #raw <= #ticks * 2 or raw:sub(-#ticks) ~= ticks then
    return nil
  end

  local inner = raw:sub(#ticks + 1, -#ticks - 1)

  -- CommonMark: el espacio de cortesía de cada lado no es contenido
  -- (`` ` `x` ` `` -> "`x`"), salvo que el contenido sean solo espacios.
  if inner:sub(1, 1) == " " and inner:sub(-1) == " " and inner:match "[^ ]" then
    inner = inner:sub(2, -2)
  end

  return inner ~= "" and inner or nil
end

--- Sangría común de las líneas con contenido.
---@param lines string[]
---@return integer
local function common_indent(lines)
  local indent
  for _, line in ipairs(lines) do
    if line:match "%S" then
      local lead = #(line:match "^[ \t]*")
      if not indent or lead < indent then
        indent = lead
      end
    end
  end
  return indent or 0
end

--- Cuerpo de un bloque de código (fence o sangrado) bajo el cursor, sin los
--- delimitadores y sin la sangría del propio bloque. El cursor vale en
--- cualquier parte del bloque, líneas de ``` y `info string` incluidas.
---
--- El salto de línea final lo decide el contenido: dentro de un fence, la
--- última línea en blanco es tuya (el fence la admite), así que si la dejas
--- el texto copiado termina en `\n` y si no, no. Lo único que se descuenta
--- siempre es el salto estructural que precede al cierre.
---@param bufnr integer
---@param row0 integer 0-based
---@param col integer 0-based
---@return string|?
local function block_code_at_cursor(bufnr, row0, col)
  local block = ancestor(
    node_at(bufnr, row0, col, false),
    { fenced_code_block = true, indented_code_block = true }
  )
  if not block then
    return nil
  end

  local content, fence_indent = block, nil
  if block:type() == "fenced_code_block" then
    content = nil
    for child in block:iter_children() do
      if child:type() == "code_fence_content" then
        content = child
        break
      end
    end
    if not content then
      return nil -- fence vacío
    end
    -- El cuerpo arrastra la sangría del propio fence (p. ej. un bloque
    -- dentro de un ítem de lista); esa no es del código. La primera línea
    -- ya viene sin ella: el nodo empieza en su columna.
    fence_indent = select(2, block:range())
  end

  local ok, raw = pcall(vim.treesitter.get_node_text, content, bufnr)
  if not ok or type(raw) ~= "string" then
    return nil
  end

  local lines = vim.split(raw, "\n", { plain = true })
  local first = fence_indent and 2 or 1
  local indent = fence_indent or common_indent(lines)

  for index = first, #lines do
    local lead = #(lines[index]:match "^[ \t]*")
    lines[index] = lines[index]:sub(math.min(lead, indent) + 1)
  end

  if fence_indent then
    -- El cuerpo termina siempre en el salto de línea que precede al cierre
    -- (y con la sangría suelta de esa línea, que el nodo se lleva puesta):
    -- eso es estructura, se va. Lo que quede detrás ya es del usuario, así
    -- que una última línea en blanco dentro del fence deja el `\n` final.
    if #lines > 0 and not lines[#lines]:match "%S" then
      table.remove(lines)
    end
  else
    -- Un bloque sangrado no tiene forma de expresar esa última línea: sus
    -- líneas en blanco del final son la separación con lo que viene
    -- después, no contenido.
    while #lines > 0 and not lines[#lines]:match "%S" do
      table.remove(lines)
    end
  end

  local text = table.concat(lines, "\n")
  return text:match "%S" and text or nil
end

---@param bufnr integer
---@param row0 integer 0-based
---@param col integer 0-based
---@return string|? text
---@return string|? kind "formato" (negrita/cursiva) o "tachado" (`~x~`/`~~x~~`)
local function emphasis_at_cursor(bufnr, row0, col)
  -- markdown_inline (donde viven emphasis/strong_emphasis/strikethrough) es
  -- un árbol inyectado dentro del árbol de `markdown`; get_node() no baja ahí
  -- solo porque sí, hay que pedirlo explícitamente.
  local node = node_at(bufnr, row0, col, true)
  if not node then
    return nil
  end

  -- El nodo MÁS EXTERNO de negrita/cursiva/tachado que contiene el cursor:
  -- para `***hola***` (negrita+cursiva anidadas) o `~~hola~~` (tachado de
  -- doble tilde, que el grammar anida igual que las emphasis) queremos el
  -- span completo, no solo la capa interna.
  local outer, outer_type
  local n = node
  while n do
    local t = n:type()
    if t == "emphasis" or t == "strong_emphasis" or t == "strikethrough" then
      outer, outer_type = n, t
    end
    n = n:parent()
  end
  if not outer then
    return nil
  end

  local ok_text, raw = pcall(vim.treesitter.get_node_text, outer, bufnr)
  if not ok_text or not raw or raw == "" then
    return nil
  end
  local kind = outer_type == "strikethrough" and "tachado" or "formato"
  return strip_emphasis_markup(raw), kind
end

---@param path string ruta de la nota (obsidian.Path o string, se hace tostring)
---@return string|? name basename sin extensión, desambiguado contra el vault
local function note_target_name(path)
  local root = rawget(_G, "Obsidian") and Obsidian.dir and tostring(Obsidian.dir)
  if not root then
    return nil
  end
  local ok_la, link_actions = pcall(require, "lzy.obsidian.link_actions")
  if not ok_la or not link_actions.shortest_note_target then
    return nil
  end
  local ok_name, note_name = pcall(link_actions.shortest_note_target, tostring(path), root)
  if not ok_name or not note_name then
    return nil
  end
  return note_name:gsub("%.md$", "")
end

---@param bufnr integer
---@param row0 integer 0-based
---@return string|?
local function heading_link_at_cursor(bufnr, row0)
  local ok_headings, headings = pcall(require, "lzy.obsidian.headings")
  if not ok_headings then
    return nil
  end
  local ok_decl, decl = pcall(headings.declaration_at, bufnr, row0)
  if not ok_decl or not decl or not decl.note or not decl.note.path then
    return nil
  end

  local note_name = note_target_name(decl.note.path)
  if not note_name then
    return nil
  end

  local anchor = headings.anchor_segment(decl.text)
  if not anchor or anchor == "" then
    return nil
  end
  return ("[[%s#%s]]"):format(note_name, anchor)
end

--- Enlace a la nota actual entera (sin anchor). Fallback cuando no hay
--- nada más específico bajo el cursor -- a pedido del usuario, la tecla
--- nunca queda "vacía": si no hay nada que copiar puntualmente, copia el
--- enlace a la nota donde está parado, que casi siempre es útil igual.
---@param bufnr integer
---@return string|?
local function self_note_link(bufnr)
  local path = vim.api.nvim_buf_get_name(bufnr)
  if path == "" then
    return nil
  end
  local note_name = note_target_name(path)
  if not note_name then
    return nil
  end
  return ("[[%s]]"):format(note_name)
end

---@param opts { bufnr?: integer, notify?: fun(msg: string, level?: integer), copy?: fun(text: string) }|?
function M.smart_copy(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local notify = opts.notify or M.notify
  local copy = opts.copy or M.copy

  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local row0 = row - 1

  local function finish(text, what)
    copy(text)
    -- Un bloque entero en la notificación no se lee; basta con saber qué se
    -- copió y cuánto.
    local first = text:match "^[^\n]*"
    local breaks = select(2, text:gsub("\n", ""))
    -- Un `\n` final cierra la última línea, no abre otra.
    local count = breaks + (text:sub(-1) == "\n" and 0 or 1)
    local shown = breaks > 0 and ("%s… (%d líneas)"):format(first, count) or text
    notify(("Copiado (%s): %s"):format(what, shown))
  end

  -- 1. Código bajo el cursor: inline primero, que es lo más específico.
  --    Va antes que los enlaces porque dentro de código no hay enlaces que
  --    seguir, solo texto literal.
  local inline_code = inline_code_at_cursor(bufnr, row0, col)
  if inline_code then
    return finish(inline_code, "código")
  end

  local block_code = block_code_at_cursor(bufnr, row0, col)
  if block_code then
    return finish(block_code, "bloque de código")
  end

  -- 2. Enlace bajo el cursor.
  local ok_links, links = pcall(require, "lzy.obsidian.links")
  if ok_links and links.cursor_context then
    local ok_ctx, ctx = pcall(links.cursor_context)
    if ok_ctx and ctx and ctx.component and ctx.component.text and ctx.component.text ~= "" then
      return finish(ctx.component.text, "enlace")
    end
  end

  -- 3. Negrita/cursiva/negrita-cursiva/tachado bajo el cursor.
  local emphasis_text, emphasis_kind = emphasis_at_cursor(bufnr, row0, col)
  if emphasis_text then
    return finish(emphasis_text, emphasis_kind)
  end

  -- 4. Línea de heading.
  local heading_link = heading_link_at_cursor(bufnr, row0)
  if heading_link then
    return finish(heading_link, "header")
  end

  -- 5. Nada bajo el cursor: en vez de dejar la tecla "vacía", copiar un
  --    enlace a la nota actual entera.
  local self_link = self_note_link(bufnr)
  if self_link then
    copy(self_link)
    return notify(("Nada que copiar en esta posición: copiando enlace a esta nota -> %s"):format(self_link))
  end

  notify("Nada que copiar en esta posición", vim.log.levels.WARN)
end

return M
