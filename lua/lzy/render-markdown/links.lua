-- Renderizado que render-markdown.nvim no cubre para referencias CommonMark.

local M = {}

local definition_query =
  vim.treesitter.query.parse("markdown", "(link_reference_definition) @definition")
local usage_query = vim.treesitter.query.parse(
  "markdown_inline",
  [[
    (collapsed_reference_link) @collapsed
    (shortcut_link) @shortcut
  ]]
)
local definition_cache = {}

---@param bufnr integer
---@return render.md.buf.Config
local function buffer_config(bufnr)
  return require("render-markdown.state").get(bufnr)
end

---@param config render.md.buf.Config
---@return render.md.mark.Text
local function hyperlink_icon(config)
  return { config.link.hyperlink, config.link.highlight }
end

---@param config render.md.buf.Config
---@param row integer
---@param col integer
---@param icon render.md.mark.Text
---@return render.md.Mark
local function icon_mark(config, row, col, icon)
  return {
    modes = config.link.render_modes,
    conceal = "link",
    start_row = row,
    start_col = col,
    opts = {
      priority = 9000,
      hl_mode = "combine",
      virt_text = { icon },
      virt_text_pos = "inline",
    },
  }
end

---@param config render.md.buf.Config
---@param row integer
---@param start_col integer
---@param end_col integer
---@return render.md.Mark
local function hide_mark(config, row, start_col, end_col)
  return {
    modes = config.link.render_modes,
    conceal = true,
    start_row = row,
    start_col = start_col,
    opts = {
      end_row = row,
      end_col = end_col,
      conceal = "",
    },
  }
end

---@param node TSNode|nil
---@param bufnr integer
---@return string|nil
local function description(node, bufnr)
  if not node then
    return nil
  end
  local value = vim.treesitter.get_node_text(node, bufnr)
  local opening, closing = value:sub(1, 1), value:sub(-1)
  if (opening == '"' and closing == '"')
    or (opening == "'" and closing == "'")
    or (opening == "(" and closing == ")")
  then
    value = value:sub(2, -2)
  end
  value = vim.trim(value):gsub("%s+", " "):gsub("\\([%p])", "%1")
  return value ~= "" and value or nil
end

---@param config render.md.buf.Config
---@param node TSNode
---@param label TSNode
---@param bufnr integer
---@param marks render.md.Mark[]
local function hide_definition(config, node, label, bufnr, marks)
  local label_row, _, _, label_end = label:range()
  local _, _, node_end_row, node_end_col = node:range()
  local lines = vim.api.nvim_buf_get_lines(bufnr, label_row, node_end_row + 1, false)

  for row = label_row, node_end_row do
    local start_col = row == label_row and label_end - 1 or 0
    local end_col = row == node_end_row and node_end_col or #(lines[row - label_row + 1] or "")
    if end_col > start_col then
      marks[#marks + 1] = hide_mark(config, row, start_col, end_col)
    end
  end
end

---@param node TSNode
---@return table<string, TSNode>
local function named_children(node)
  local children = {}
  for child in node:iter_children() do
    if child:named() then
      children[child:type()] = child
    end
  end
  return children
end

---@param value string
---@return string
local function normalize_label(value)
  value = value:gsub("^%[", ""):gsub("%]$", "")
  value = value:gsub("\\([%p])", "%1")
  return vim.trim(value):gsub("%s+", " "):lower()
end

---@param bufnr integer
---@return table<string, true>
local function definition_ids(bufnr)
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local cached = definition_cache[bufnr]
  if cached and cached.tick == tick then
    return cached.ids
  end

  local ids = {}
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
  if not ok or not parser then
    return ids
  end

  parser:parse(true)
  for _, tree in ipairs(parser:trees()) do
    for _, node in definition_query:iter_captures(tree:root(), bufnr) do
      local children = named_children(node)
      local label = children.link_label
      if label then
        ids[normalize_label(vim.treesitter.get_node_text(label, bufnr))] = true
      end
    end
  end
  definition_cache[bufnr] = { tick = tick, ids = ids }
  return ids
end

---@param bufnr integer
---@param label string
---@return boolean
function M.has_definition(bufnr, label)
  return definition_ids(bufnr)[normalize_label(label)] == true
end

---@param node TSNode
---@param bufnr integer
---@return boolean
local function is_wikilink_shortcut(node, bufnr)
  local row, start_col, _, end_col = node:range()
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  return line:sub(start_col, start_col) == "[" and line:sub(end_col + 1, end_col + 1) == "]"
end

---@param node TSNode
---@param bufnr integer
---@return string
local function usage_label(node, bufnr)
  local children = named_children(node)
  local text = children.link_text and vim.treesitter.get_node_text(children.link_text, bufnr)
    or vim.treesitter.get_node_text(node, bufnr)
  return normalize_label(text)
end

---@param ctx render.md.handler.Context
---@param marks render.md.Mark[]
function M.render_inline(ctx, marks)
  local config = buffer_config(ctx.buf)
  if not config.link.enabled then
    return
  end
  local ids

  for id, node in usage_query:iter_captures(ctx.root, ctx.buf) do
    local capture = usage_query.captures[id]
    if capture == "collapsed" or not is_wikilink_shortcut(node, ctx.buf) then
      -- `[x]` solo es un enlace CommonMark si existe una definición. La forma
      -- `[x][]` no es ambigua sintácticamente, pero se valida igual para que el
      -- icono represente un enlace real y no markup roto.
      ids = ids or definition_ids(ctx.buf)
      if ids[usage_label(node, ctx.buf)] then
        local row, col = node:range()
        marks[#marks + 1] = icon_mark(config, row, col, hyperlink_icon(config))
      end
    end
  end
end

---@param ctx render.md.handler.Context
---@return render.md.Mark[]
function M.parse_markdown(ctx)
  local marks = {}
  local config = buffer_config(ctx.buf)
  if not config.link.enabled then
    return marks
  end

  for _, node in definition_query:iter_captures(ctx.root, ctx.buf) do
    local children = named_children(node)
    local label = children.link_label
    local destination = children.link_destination

    if label and destination then
      local label_row, label_start, _, label_end = label:range()
      local icon = hyperlink_icon(config)
      config:set_link_text(vim.treesitter.get_node_text(destination, ctx.buf), icon)
      marks[#marks + 1] = icon_mark(config, label_row, label_start, icon)
      marks[#marks + 1] = hide_mark(config, label_row, label_start, label_start + 1)
      hide_definition(config, node, label, ctx.buf, marks)

      local title = description(children.link_title, ctx.buf)
      if title then
        marks[#marks + 1] = {
          modes = config.link.render_modes,
          conceal = "link",
          start_row = label_row,
          start_col = label_end - 1,
          opts = {
            priority = 9000,
            hl_mode = "combine",
            virt_text = { { " (" .. title .. ")", config.link.highlight_title } },
            virt_text_pos = "inline",
          },
        }
      end
    end
  end

  return marks
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Enlace-imagen: `[![alt](img)](url)`
-- ─────────────────────────────────────────────────────────────────────────────
--
-- El patrón de los badges. Es una sola cosa —una imagen que además enlaza—,
-- pero para tree-sitter son dos nodos anidados: el `inline_link` y, dentro de
-- su texto, la `image`. render-markdown.nvim pinta un icono por nodo, así que
-- salían dos pegados, como si fueran dos enlaces distintos. Se deja uno solo, y
-- es el de imagen: la etiqueta que se ve es la imagen, no un texto.
--
-- `hzsr.md` mide con este mismo criterio (ver `image_end` en `parse_link`), que
-- es lo que hace que los formateadores no destrocen la línea.

---@param node render.md.Node
---@return render.md.Node|nil image la imagen que ocupa TODO el texto del enlace
local function whole_label_image(node)
  local text = node:child "link_text"
  if not text then
    return nil
  end
  local image = text:child "image"
  if
    image
    and image.start_row == text.start_row
    and image.start_col == text.start_col
    and image.end_row == text.end_row
    and image.end_col == text.end_col
  then
    return image
  end
end

---@param node render.md.Node
---@return boolean
local function is_labelling_image(node)
  local link = node:parent "inline_link"
  local image = link and whole_label_image(link)
  return image ~= nil and image.start_col == node.start_col and image.start_row == node.start_row
end

--- Un icono por enlace-imagen, no dos.
---@diagnostic disable: invisible
function M.patch_linked_images()
  local Render = require "render-markdown.render.inline.link"
  if Render.__nyabsidian_linked_image then
    return
  end
  local original = Render.setup
  Render.setup = function(self)
    -- La imagen calla: el icono lo pone el enlace que la envuelve, y así queda
    -- al principio de la construcción entera y no a mitad.
    if self.node.type == "image" and is_labelling_image(self.node) then
      return false
    end
    local enabled = original(self)
    if enabled and self.node.type == "inline_link" and whole_label_image(self.node) then
      -- Salvo que el destino tenga icono propio configurado, que manda.
      if self.data.icon[1] == self.config.hyperlink then
        self.data.icon[1] = self.config.image
      end
    end
    return enabled
  end
  ---@diagnostic disable-next-line: inject-field
  Render.__nyabsidian_linked_image = true
end
---@diagnostic enable: invisible

M.whole_label_image = whole_label_image

---@param kind "wiki"|"link"|"image"|"email"
---@param bufnr integer|nil
---@param destination string|nil
---@return integer
function M.icon_width(kind, bufnr, destination)
  local config
  if bufnr then
    local ok, resolved = pcall(buffer_config, bufnr)
    if ok then
      config = resolved
    end
  end

  local icon
  if config then
    if not config.link.enabled or kind == "wiki" and not config.link.wiki.enabled then
      return 0
    end
    if kind == "wiki" then
      local text = { config.link.wiki.icon, config.link.wiki.highlight }
      if destination then
        config:set_link_text(destination, text)
      end
      icon = text[1]
    elseif kind == "image" then
      icon = config.link.image
    elseif kind == "email" then
      icon = config.link.email
    else
      local text = hyperlink_icon(config)
      if destination then
        config:set_link_text(destination, text)
      end
      icon = text[1]
    end
  else
    local defaults = require("render-markdown").default.link
    icon = kind == "wiki" and defaults.wiki.icon
      or kind == "image" and defaults.image
      or kind == "email" and defaults.email
      or defaults.hyperlink
  end

  return vim.fn.strdisplaywidth(icon)
end

return M
