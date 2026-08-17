-- Spoilers contextuales para Markdown.

local M = {}

M.inline_text = "󰈉 SPOILER"

local excluded_query = vim.treesitter.query.parse(
  "markdown_inline",
  [[
    [
      (code_span)
      (email_autolink)
      (full_reference_link)
      (collapsed_reference_link)
      (shortcut_link)
      (image)
      (inline_link)
      (uri_autolink)
    ] @excluded
  ]]
)

local table_cache = {}

---@class lzy.render_markdown.SpoilerRange
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field end_col integer

---@class lzy.render_markdown.SpoilerBlock
---@field node TSNode
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field end_col integer
---@field opening_end_col integer
---@field closing_row integer
---@field closing_end_col integer
---@field content_lines integer

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

---@param ranges lzy.render_markdown.SpoilerRange[]
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

---@param node TSNode
---@param bufnr integer
---@return boolean
local function is_spoiler_block(node, bufnr)
  if node:type() ~= "fenced_code_block" then
    return false
  end
  for child in node:iter_children() do
    if child:type() == "info_string" then
      return vim.trim(vim.treesitter.get_node_text(child, bufnr)) == "spoiler"
    end
  end
  return false
end

---@param node TSNode
---@param bufnr integer
---@param result lzy.render_markdown.SpoilerBlock[]
local function collect_blocks(node, bufnr, result)
  if is_spoiler_block(node, bufnr) then
    local delimiters = {}
    for child in node:iter_children() do
      if child:type() == "fenced_code_block_delimiter" then
        delimiters[#delimiters + 1] = child
      end
    end
    if #delimiters >= 2 then
      local start_row, start_col, end_row, end_col = node:range()
      local opening_line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
      local opening_end_col = #(opening_line or "")
      local closing_row, _, _, closing_end_col = delimiters[#delimiters]:range()
      result[#result + 1] = {
        node = node,
        start_row = start_row,
        start_col = start_col,
        end_row = end_row,
        end_col = end_col,
        opening_end_col = opening_end_col,
        closing_row = closing_row,
        closing_end_col = closing_end_col,
        content_lines = math.max(0, closing_row - start_row - 1),
      }
    end
    return
  end
  for child in node:iter_children() do
    collect_blocks(child, bufnr, result)
  end
end

---@param ctx render.md.handler.Context
---@return lzy.render_markdown.SpoilerBlock[]
local function blocks(ctx)
  local result = {}
  collect_blocks(ctx.root, ctx.buf, result)
  return result
end

---@param bufnr integer
---@return table<integer, true>
local function table_rows(bufnr)
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  local cached = table_cache[bufnr]
  if cached and cached.tick == tick then
    return cached.rows
  end

  local rows = {}
  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, "markdown")
  if ok and parser then
    parser:parse(true)
    parser:for_each_tree(function(tree, language_tree)
      if language_tree:lang() ~= "markdown" then
        return
      end
      local function walk(node)
        if node:type() == "pipe_table" then
          local start_row, _, end_row, end_col = node:range()
          local last = end_col == 0 and end_row - 1 or end_row
          for row = start_row, last do
            rows[row] = true
          end
          return
        end
        for child in node:iter_children() do
          walk(child)
        end
      end
      walk(tree:root())
    end)
  end
  table_cache[bufnr] = { tick = tick, rows = rows }
  return rows
end

---@param ctx render.md.handler.Context
---@return lzy.render_markdown.SpoilerRange[]
local function protected_ranges(ctx)
  local result = {}
  for _, node in excluded_query:iter_captures(ctx.root, ctx.buf) do
    local start_row, start_col, end_row, end_col = node:range()
    result[#result + 1] = {
      start_row = start_row,
      start_col = start_col,
      end_row = end_row,
      end_col = end_col,
    }
  end
  return result
end

---@param row integer
---@param start_col integer
---@param end_col integer
---@return render.md.Mark
local function delimiter_mark(row, start_col, end_col)
  return {
    conceal = false,
    start_row = row,
    start_col = start_col,
    opts = {
      end_row = row,
      end_col = end_col,
      conceal = "",
      priority = 9501,
    },
  }
end

---@param ctx render.md.handler.Context
---@param marks render.md.Mark[]
function M.render_inline(ctx, marks)
  local protected = protected_ranges(ctx)
  local excluded_rows = table_rows(ctx.buf)
  local start_row, start_col, end_row, end_col = ctx.root:range()
  local last_row = end_row > start_row and end_col == 0 and end_row - 1 or end_row
  local lines = vim.api.nvim_buf_get_lines(ctx.buf, start_row, last_row + 1, false)

  for offset, line in ipairs(lines) do
    local row = start_row + offset - 1
    if not excluded_rows[row] then
      local region_start = row == start_row and start_col or 0
      local region_end = row == end_row and end_col or #line
      local search_from = region_start + 1

      while search_from <= region_end - 3 do
        local open = line:find("||", search_from, true)
        if not open or open - 1 >= region_end then
          break
        end
        local open_col = open - 1
        local valid_open = not is_escaped(line, open_col)
          and not overlaps(protected, row, open_col, open_col + 2)
        local close = valid_open and line:find("||", open + 2, true) or nil

        while close do
          local close_col = close - 1
          if
            not is_escaped(line, close_col)
            and not overlaps(protected, row, close_col, close_col + 2)
          then
            break
          end
          close = line:find("||", close + 2, true)
        end

        if valid_open and close and close > open + 2 then
          local close_col = close - 1
          local candidate_end = close_col + 2
          if not overlaps(protected, row, open_col, candidate_end) then
            marks[#marks + 1] = {
              conceal = true,
              start_row = row,
              start_col = open_col,
              opts = {
                end_row = row,
                end_col = candidate_end,
                conceal = "",
                virt_text = { { M.inline_text, "RenderMarkdownSpoiler" } },
                virt_text_pos = "inline",
                priority = 9500,
              },
            }
            marks[#marks + 1] = delimiter_mark(row, open_col, open_col + 2)
            marks[#marks + 1] = delimiter_mark(row, close_col, candidate_end)
            search_from = candidate_end + 1
          else
            search_from = open + 2
          end
        else
          search_from = open + 2
        end
      end
    end
  end
end

---@param block lzy.render_markdown.SpoilerBlock
---@return string
local function block_text(block)
  local suffix = block.content_lines == 1 and "línea" or "líneas"
  return ("󰈉 SPOILER · %d %s"):format(block.content_lines, suffix)
end

---@param block lzy.render_markdown.SpoilerBlock
---@return render.md.Mark[]
local function block_marks(block)
  return {
    {
      conceal = true,
      start_row = block.start_row + 1,
      start_col = 0,
      opts = {
        end_row = block.closing_row,
        end_col = block.closing_end_col,
        conceal_lines = "",
        priority = 9600,
      },
    },
    {
      conceal = false,
      start_row = block.start_row,
      start_col = block.start_col,
      opts = {
        end_row = block.start_row,
        end_col = block.start_col,
        virt_text = { { block_text(block), "RenderMarkdownSpoiler" } },
        virt_text_pos = "inline",
        priority = 9601,
      },
    },
    delimiter_mark(block.start_row, block.start_col, block.opening_end_col),
    delimiter_mark(block.closing_row, block.start_col, block.closing_end_col),
  }
end

---@param mark render.md.Mark
---@param block lzy.render_markdown.SpoilerBlock
---@return boolean
local function mark_overlaps_block(mark, block)
  local mark_end = mark.opts.end_row or mark.start_row
  return mark.start_row < block.end_row and mark_end >= block.start_row
end

---@param ctx render.md.handler.Context
---@return render.md.Mark[]
function M.parse_markdown(ctx)
  local found = blocks(ctx)
  local marks = require("render-markdown.handler.markdown").parse(ctx)

  if #found > 0 then
    marks = vim.tbl_filter(function(mark)
      for _, block in ipairs(found) do
        if mark_overlaps_block(mark, block) then
          return false
        end
      end
      return true
    end, marks)
  end

  -- Los fences vacíos o sin cerrar se rescatan aquí por lo mismo que los
  -- spoilers: hay que quitar antes las marcas del plugin que dejan esas filas
  -- invisibles (ver lzy.render-markdown.code).
  local code = require "lzy.render-markdown.code"
  local code_marks, hidden_rows = code.parse_markdown(ctx)
  if next(hidden_rows) then
    marks = vim.tbl_filter(function(mark)
      return not code.hides_row(mark, hidden_rows)
    end, marks)
  end

  vim.list_extend(marks, require("lzy.render-markdown.links").parse_markdown(ctx))
  for _, block in ipairs(found) do
    vim.list_extend(marks, block_marks(block))
  end
  vim.list_extend(marks, code_marks)
  return marks
end

---@return integer
function M.inline_width()
  return vim.fn.strdisplaywidth(M.inline_text)
end

function M.setup()
  vim.treesitter.language.register("markdown", "spoiler")
  local group = vim.api.nvim_create_augroup("SabunvMarkdownSpoilers", { clear = true })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      table_cache[args.buf] = nil
    end,
  })
end

M.blocks = blocks
M.block_text = block_text

return M
