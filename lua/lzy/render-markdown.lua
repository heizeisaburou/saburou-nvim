-- lzy.l_render-markdown

-- TODO Con el sistema de persistencia, recordar el estado en el que estabamos al
-- reiniciar

local M = {}

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------

---@type boolean
local is_setup = false

-- -----------------------------------------------------------------------------
-- Contextual rendering
-- -----------------------------------------------------------------------------

local inline_code_query = vim.treesitter.query.parse("markdown_inline", "(code_span) @code")
local inline_emphasis_query = vim.treesitter.query.parse(
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
local h1_cursor_namespace = vim.api.nvim_create_namespace "sabunv-markdown-h1-cursor"
local h1_cursor_windows = {}
local has_h1_cursor_highlight = false

---@class lzy.render_markdown.Range
---@field start_row integer
---@field start_col integer
---@field end_row integer
---@field end_col integer

---@param bufnr integer
---@param row integer
---@return integer?
local function heading_level(bufnr, row)
  local lines = vim.api.nvim_buf_get_lines(bufnr, row, row + 2, false)
  local marker = (lines[1] or ""):match "^%s*(#+)%s"

  if marker and #marker <= 6 then
    return #marker
  end

  local underline = lines[2] or ""
  if underline:match "^%s*=+%s*$" then
    return 1
  elseif underline:match "^%s*%-+%s*$" then
    return 2
  end
end

---@param bufnr integer
---@param row integer
---@return boolean
local function is_h1_row(bufnr, row)
  if heading_level(bufnr, row) == 1 then
    return true
  end

  if row == 0 then
    return false
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  return line:match "^%s*=+%s*$" ~= nil and heading_level(bufnr, row - 1) == 1
end

local function update_h1_cursor_highlight()
  local heading = vim.api.nvim_get_hl(0, {
    name = "@markup.heading.1.markdown",
    link = false,
  })
  local cursor = {}

  if heading.fg and heading.bg then
    cursor.fg = heading.bg
    cursor.bg = heading.fg
  end

  if heading.ctermfg and heading.ctermbg then
    cursor.ctermfg = heading.ctermbg
    cursor.ctermbg = heading.ctermfg
  end

  has_h1_cursor_highlight = not vim.tbl_isempty(cursor)
  vim.api.nvim_set_hl(h1_cursor_namespace, "Cursor", cursor)
  vim.api.nvim_set_hl(h1_cursor_namespace, "CursorIM", cursor)
end

---@param winid integer
local function restore_cursor_highlight(winid)
  local previous = h1_cursor_windows[winid]
  if previous == nil then
    return
  end

  h1_cursor_windows[winid] = nil
  if vim.api.nvim_win_is_valid(winid) then
    local active = vim.api.nvim_get_hl_ns { winid = winid }
    if active == h1_cursor_namespace then
      vim.api.nvim_win_set_hl_ns(winid, previous)
    end
  end
end

local function update_cursor_highlight()
  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local filetype = vim.bo[bufnr].filetype
  local row = vim.api.nvim_win_get_cursor(winid)[1] - 1
  local is_markdown = vim.tbl_contains(M.opts.file_types, filetype)

  if not has_h1_cursor_highlight or not is_markdown or not is_h1_row(bufnr, row) then
    restore_cursor_highlight(winid)
    return
  end

  local active = vim.api.nvim_get_hl_ns { winid = winid }
  if h1_cursor_windows[winid] ~= nil and active ~= h1_cursor_namespace then
    h1_cursor_windows[winid] = nil
  end

  if h1_cursor_windows[winid] == nil then
    local previous = active

    -- No sustituir namespaces especiales de ventanas de plugins.
    if previous ~= -1 and previous ~= 0 then
      return
    end

    h1_cursor_windows[winid] = previous
  end

  vim.api.nvim_win_set_hl_ns(winid, h1_cursor_namespace)
end

local function setup_h1_cursor()
  local group = vim.api.nvim_create_augroup("SabunvMarkdownH1Cursor", { clear = true })

  vim.api.nvim_create_autocmd({ "BufEnter", "CursorMoved", "CursorMovedI", "ModeChanged", "WinEnter" }, {
    group = group,
    callback = update_cursor_highlight,
  })

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    group = group,
    callback = function()
      restore_cursor_highlight(vim.api.nvim_get_current_win())
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      h1_cursor_windows[tonumber(args.match)] = nil
    end,
  })

  update_cursor_highlight()
end

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

  for _, node in inline_emphasis_query:iter_captures(ctx.root, ctx.buf) do
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
      local valid_boundaries = not previous:match("[%w_]") and not following:match("[%w_]")
      local valid_content = not content:match("^%s") and not content:match("%s$")
      local escaped = is_escaped(line, candidate_start) or is_escaped(line, close - 1)

      if
        valid_boundaries
        and valid_content
        and not escaped
        and not overlaps(protected, row, candidate_start, candidate_end)
      then
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
          -- Mantener la cursiva cuando anti-conceal muestra los delimitadores
          -- en la línea del cursor.
          conceal = false,
          start_row = row,
          start_col = candidate_start,
          opts = {
            end_row = row,
            end_col = candidate_end,
            hl_group = "@markup.italic.markdown_inline",
            priority = 101,
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
local function render_markdown_inline(ctx)
  local marks = {}

  -- tree-sitter-markdown-inline no reconoce algunos énfasis válidos con `_`,
  -- por ejemplo `_v1_`, cuando el contenido termina en un dígito.
  render_unparsed_underscore_emphasis(ctx, marks)

  for id, node in inline_code_query:iter_captures(ctx.root, ctx.buf) do
    if inline_code_query.captures[id] == "code" then
      local start_row, start_col, end_row, end_col = node:range()
      local level = heading_level(ctx.buf, start_row)

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
            -- Los fondos de heading usan la prioridad por defecto de Neovim
            -- (4096), por encima del 140 del código inline del plugin.
            priority = 4097,
          },
        }
      end
    end
  end

  return marks
end

-- -----------------------------------------------------------------------------
-- Base opts
-- -----------------------------------------------------------------------------

---@module 'render-markdown'
---@type render.md.UserConfig
M.opts = {
  enabled = true,
  file_types = { "markdown", "quarto", "markdown.mdx", "opencode_output" },

  completions = {
    lsp = {
      enabled = false,
    },
  },

  code = {
    render_modes = { "i" },
  },

  custom_handlers = {
    markdown_inline = {
      extends = true,
      parse = render_markdown_inline,
    },
  },
}

-- -----------------------------------------------------------------------------
-- Theme opts
-- -----------------------------------------------------------------------------

local function moonfly_config()
  if not sabunv or not sabunv.moonfly or not sabunv.moonfly.render_markdown then
    return {}
  end

  return sabunv.moonfly.render_markdown.config()
end

local function setup_moonfly()
  if not sabunv or not sabunv.moonfly or not sabunv.moonfly.setup then
    return
  end

  if not sabunv.moonfly.setup.render_markdown then
    return
  end

  sabunv.moonfly.setup.render_markdown()
end

local function build_opts()
  return vim.tbl_deep_extend("force", vim.deepcopy(M.opts), moonfly_config())
end

local function setup_plugin()
  require("render-markdown").setup(build_opts())

  local ok, render_markdown = pcall(require, "render-markdown")
  if ok then
    pcall(render_markdown.enable)
  end
end

-- -----------------------------------------------------------------------------
-- Keymaps
-- -----------------------------------------------------------------------------

local function setup_keymaps()
  local map = vim.keymap.set

  map("n", "<leader>mr", "<cmd>RenderMarkdown toggle<CR>", {
    desc = "Markdown: toggle render",
  })
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

---@return boolean
function M.is_setup()
  return is_setup
end

function M.resetup()
  setup_moonfly()
  update_h1_cursor_highlight()
  setup_plugin()
end

function M.setup()
  setup_moonfly()
  update_h1_cursor_highlight()
  setup_plugin()

  is_setup = true

  setup_keymaps()
  setup_h1_cursor()
end

return M
