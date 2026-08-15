-- Copia inteligente: qué copiar depende de qué hay bajo el cursor.
--
-- Orden de prioridad (el más específico gana):
--   1. Enlace: el componente exacto que se está hovereando (label, target/
--      nota, url, descripción, id de referencia...), ya sin llaves ni
--      paréntesis alrededor -- reusa lzy.obsidian.links.cursor_context(),
--      que ya distingue esto para hover/rename/follow.
--   2. Negrita/cursiva/negrita-cursiva: el contenido sin los delimitadores
--      (`***hola***` -> `hola`, en cualquier combinación de `*`/`_`).
--   3. Línea de heading: `[[NombreDeNota#anchor]]`, listo para pegar --
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
  if ch ~= "*" and ch ~= "_" then
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

---@param bufnr integer
---@param row0 integer 0-based
---@param col integer 0-based
---@return string|?
local function emphasis_at_cursor(bufnr, row0, col)
  -- markdown_inline (donde viven emphasis/strong_emphasis) es un árbol
  -- inyectado dentro del árbol de `markdown`; get_node() no baja ahí solo
  -- porque sí, hay que pedirlo explícitamente.
  local ok, node =
    pcall(vim.treesitter.get_node, { bufnr = bufnr, pos = { row0, col }, ignore_injections = false })
  if not ok or not node then
    return nil
  end

  -- El nodo MÁS EXTERNO de negrita/cursiva que contiene el cursor: para
  -- `***hola***` (negrita+cursiva anidadas) queremos el span completo, no
  -- solo la capa interna.
  local outer
  local n = node
  while n do
    local t = n:type()
    if t == "emphasis" or t == "strong_emphasis" then
      outer = n
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
  return strip_emphasis_markup(raw)
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
    notify(("Copiado (%s): %s"):format(what, text))
  end

  -- 1. Enlace bajo el cursor.
  local ok_links, links = pcall(require, "lzy.obsidian.links")
  if ok_links and links.cursor_context then
    local ok_ctx, ctx = pcall(links.cursor_context)
    if ok_ctx and ctx and ctx.component and ctx.component.text and ctx.component.text ~= "" then
      return finish(ctx.component.text, "enlace")
    end
  end

  -- 2. Negrita/cursiva/negrita-cursiva bajo el cursor.
  local emphasis_text = emphasis_at_cursor(bufnr, row0, col)
  if emphasis_text then
    return finish(emphasis_text, "formato")
  end

  -- 3. Línea de heading.
  local heading_link = heading_link_at_cursor(bufnr, row0)
  if heading_link then
    return finish(heading_link, "header")
  end

  -- 4. Nada bajo el cursor: en vez de dejar la tecla "vacía", copiar un
  --    enlace a la nota actual entera.
  local self_link = self_note_link(bufnr)
  if self_link then
    copy(self_link)
    return notify(("Nada que copiar en esta posición: copiando enlace a esta nota -> %s"):format(self_link))
  end

  notify("Nada que copiar en esta posición", vim.log.levels.WARN)
end

return M
