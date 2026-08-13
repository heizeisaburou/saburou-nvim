-- Extensiones contextuales para el parser markdown_inline.

local M = {}

local code_query = vim.treesitter.query.parse("markdown_inline", "(code_span) @code")
local italic_query = vim.treesitter.query.parse("markdown_inline", "(emphasis) @italic")
local emphasis_query = vim.treesitter.query.parse(
  "markdown_inline",
  [[
    (emphasis) @parsed
    (strong_emphasis) @parsed

    [
      (code_span)
      (email_autolink)
      (link_destination)
      (uri_autolink)
    ] @excluded
  ]]
)

---@param bufnr integer
---@param row integer
---@return string?, integer?
local function heading_italic_highlight(bufnr, row)
  local level = require("lzy.render-markdown.cursor").heading_level(bufnr, row)
  if level then
    return "RenderMarkdownH" .. level .. "Italic", level
  end
end

---@param ctx render.md.handler.Context
---@param marks render.md.Mark[]
local function render_heading_italics(ctx, marks)
  for _, node in italic_query:iter_captures(ctx.root, ctx.buf) do
    local start_row, start_col, end_row, end_col = node:range()
    local highlight = heading_italic_highlight(ctx.buf, start_row)

    if highlight then
      marks[#marks + 1] = {
        modes = { "i" },
        conceal = false,
        start_row = start_row,
        start_col = start_col,
        opts = {
          end_row = end_row,
          end_col = end_col,
          hl_group = highlight,
          -- La banda del heading usa 4096 y el código inline contextual 4097.
          priority = 4098,
        },
      }
    end
  end
end

---@class lzy.render_markdown.Range
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field end_col integer

---@param line string
---@param col integer 0-indexed byte column
---@return boolean
local function is_escaped(line, col)
  local backslashes = 0
  local index = col

  while index > 0 and line:sub(index, index) == "\\" do
    backslashes = backslashes + 1
    index = index - 1
  end

  return backslashes % 2 == 1
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
local function render_unparsed_underscore_emphasis(ctx, marks)
  local protected = {} ---@type lzy.render_markdown.Range[]

  for _, node in emphasis_query:iter_captures(ctx.root, ctx.buf) do
    local start_row, start_col, end_row, end_col = node:range()
    protected[#protected + 1] = {
      start_row = start_row,
      start_col = start_col,
      end_row = end_row,
      end_col = end_col,
    }
  end

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
    local search_from = region_start + 1

    while search_from <= region_end do
      local open, close, content = line:find("_([^_]+)_", search_from)
      if not open or not close or close > region_end then
        break
      end

      local candidate_start = open - 1
      local candidate_end = close
      local previous = open > 1 and line:sub(open - 1, open - 1) or ""
      local following = line:sub(close + 1, close + 1)
      local valid_boundaries = not previous:match "[%w_]" and not following:match "[%w_]"
      local valid_content = not content:match "^%s" and not content:match "%s$"
      local escaped = is_escaped(line, candidate_start) or is_escaped(line, close - 1)

      if
        valid_boundaries
        and valid_content
        and not escaped
        and not overlaps(protected, row, candidate_start, candidate_end)
      then
        local highlight, level = heading_italic_highlight(ctx.buf, row)
        marks[#marks + 1] = {
          modes = { "i" },
          conceal = true,
          start_row = row,
          start_col = candidate_start,
          opts = {
            end_row = row,
            end_col = candidate_start + 1,
            conceal = "",
          },
        }
        marks[#marks + 1] = {
          modes = { "i" },
          -- Mantener la cursiva cuando anti-conceal muestra los delimitadores.
          conceal = false,
          start_row = row,
          start_col = candidate_start,
          opts = {
            end_row = row,
            end_col = candidate_end,
            hl_group = highlight or "@markup.italic.markdown_inline",
            priority = level and 4098 or 101,
          },
        }
        marks[#marks + 1] = {
          modes = { "i" },
          conceal = true,
          start_row = row,
          start_col = candidate_end - 1,
          opts = {
            end_row = row,
            end_col = candidate_end,
            conceal = "",
          },
        }
      end

      search_from = open + 1
    end
  end
end

---@param ctx render.md.handler.Context
---@return render.md.Mark[]
function M.parse(ctx)
  local marks = {}

  -- tree-sitter-markdown-inline no reconoce algunos énfasis válidos con `_`,
  -- por ejemplo `_v1_`, cuando el contenido termina en un dígito.
  render_unparsed_underscore_emphasis(ctx, marks)
  render_heading_italics(ctx, marks)
  require("lzy.render-markdown.links").render_inline(ctx, marks)
  require("lzy.render-markdown.spoilers").render_inline(ctx, marks)

  for id, node in code_query:iter_captures(ctx.root, ctx.buf) do
    if code_query.captures[id] == "code" then
      local start_row, start_col, end_row, end_col = node:range()
      local level = require("lzy.render-markdown.cursor").heading_level(ctx.buf, start_row)

      if level then
        marks[#marks + 1] = {
          modes = { "i" },
          conceal = "code_background",
          start_row = start_row,
          start_col = start_col,
          opts = {
            end_row = end_row,
            end_col = end_col,
            hl_group = "RenderMarkdownCodeInline",
            -- Los fondos de heading usan prioridad 4096, por encima del 140
            -- que usa el plugin para código inline.
            priority = 4097,
          },
        }
      end
    end
  end

  return marks
end

return M
