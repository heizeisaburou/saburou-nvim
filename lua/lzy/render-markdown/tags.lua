-- Estilo de los tags (`#tag`) de Markdown.
--
-- Los tags no son un nodo del grammar, así que render-markdown.nvim no sabe
-- nada de ellos: los reconoce el mismo parser que usan Marksman y obsidian-ls
-- para indexarlos y renombrarlos (sabunv.nvim.tags). El estilo se pinta desde
-- aquí, sobre el árbol markdown_inline, para que lo que se ve coincide
-- exactamente con lo que esas dos ramas consideran un tag: si algo sale con
-- chip rojo, es un tag de verdad para el índice y para el rename.
--
-- Lo único que se descuenta son los code spans: un `#include` entre backticks
-- es código citado, no una etiqueta, y ahí el chip sería puro ruido. Dentro de
-- un bloque de código no hace falta descontar nada -- su cuerpo es otro árbol,
-- este handler no lo ve.

local M = {}

M.highlight = "RenderMarkdownTag"

-- La banda de los headings usa 4096, el código inline contextual 4097 y las
-- cursivas 4098: el chip va encima de todo eso para que un tag dentro de un
-- heading siga leyéndose.
M.priority = 4099

local excluded_query = vim.treesitter.query.parse(
  "markdown_inline",
  [[
    [
      (code_span)
      (email_autolink)
      (link_destination)
      (uri_autolink)
    ] @excluded
  ]]
)

---@param ctx render.md.handler.Context
---@return lzy.render_markdown.Range[]
local function excluded_ranges(ctx)
  local ranges = {}
  for _, node in excluded_query:iter_captures(ctx.root, ctx.buf) do
    local start_row, start_col, end_row, end_col = node:range()
    ranges[#ranges + 1] = {
      start_row = start_row,
      start_col = start_col,
      end_row = end_row,
      end_col = end_col,
    }
  end
  return ranges
end

---@param ranges lzy.render_markdown.Range[]
---@param row integer
---@param start_col integer
---@param end_col integer
---@return boolean
local function overlaps(ranges, row, start_col, end_col)
  for _, range in ipairs(ranges) do
    if row >= range.start_row and row <= range.end_row then
      local range_start = row == range.start_row and range.start_col or 0
      local range_end = row == range.end_row and range.end_col or math.huge

      if start_col < range_end and end_col > range_start then
        return true
      end
    end
  end

  return false
end

---@param ctx render.md.handler.Context
---@param marks render.md.Mark[]
function M.render_inline(ctx, marks)
  local tags = require "sabunv.nvim.tags"
  local excluded = excluded_ranges(ctx)

  local start_row, start_col, end_row, end_col = ctx.root:range()
  local last_row = end_row
  if end_row > start_row and end_col == 0 then
    last_row = end_row - 1
  end

  local lines = vim.api.nvim_buf_get_lines(ctx.buf, start_row, last_row + 1, false)
  for offset, line in ipairs(lines) do
    local row = start_row + offset - 1
    local region_start = row == start_row and start_col or 0
    local region_end = row == end_row and end_col or #line

    for _, tag in ipairs(tags.parse_line(line, row)) do
      local range = tag.range
      if
        range.start_col >= region_start
        and range.end_col <= region_end
        and not overlaps(excluded, row, range.start_col, range.end_col)
      then
        marks[#marks + 1] = {
          modes = { "i" },
          -- El chip es color, no un conceal: no estorba al editar la línea, así
          -- que se queda puesto también con el cursor encima.
          conceal = false,
          start_row = row,
          start_col = range.start_col,
          opts = {
            end_row = row,
            end_col = range.end_col,
            hl_group = M.highlight,
            priority = M.priority,
          },
        }
      end
    end
  end
end

return M
