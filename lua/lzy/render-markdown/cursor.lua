-- Cursor y headings contextuales de render-markdown.

local M = {}

local namespace = vim.api.nvim_create_namespace "sabunv-markdown-h1-cursor"
local windows = {}
local has_highlight = false
local file_types = {}

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

function M.update_highlight()
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

  has_highlight = not vim.tbl_isempty(cursor)
  vim.api.nvim_set_hl(namespace, "Cursor", cursor)
  vim.api.nvim_set_hl(namespace, "CursorIM", cursor)
end

---@param winid integer
local function restore(winid)
  local previous = windows[winid]
  if previous == nil then
    return
  end

  windows[winid] = nil
  if vim.api.nvim_win_is_valid(winid) then
    local active = vim.api.nvim_get_hl_ns({ winid = winid })
    if active == namespace then
      vim.api.nvim_win_set_hl_ns(winid, previous)
    end
  end
end

local function update()
  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local row = vim.api.nvim_win_get_cursor(winid)[1] - 1
  local is_markdown = vim.tbl_contains(file_types, vim.bo[bufnr].filetype)

  if not has_highlight or not is_markdown or not is_h1_row(bufnr, row) then
    restore(winid)
    return
  end

  local active = vim.api.nvim_get_hl_ns({ winid = winid })
  if windows[winid] ~= nil and active ~= namespace then
    windows[winid] = nil
  end

  if windows[winid] == nil then
    -- No sustituir namespaces especiales de ventanas de plugins.
    if active ~= -1 and active ~= 0 then
      return
    end
    windows[winid] = active
  end

  vim.api.nvim_win_set_hl_ns(winid, namespace)
end

---@param opts render.md.UserConfig
function M.setup(opts)
  file_types = opts.file_types or {}
  local group = vim.api.nvim_create_augroup("SabunvMarkdownH1Cursor", { clear = true })

  vim.api.nvim_create_autocmd(
    { "BufEnter", "CursorMoved", "CursorMovedI", "ModeChanged", "WinEnter" },
    {
      group = group,
      callback = update,
    }
  )

  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    group = group,
    callback = function()
      restore(vim.api.nvim_get_current_win())
    end,
  })

  vim.api.nvim_create_autocmd("WinClosed", {
    group = group,
    callback = function(args)
      windows[tonumber(args.match)] = nil
    end,
  })

  update()
end

M.heading_level = heading_level

return M
