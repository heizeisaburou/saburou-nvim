-- sabunv.moonfly.tty

local M = {}
local cursor_namespace = vim.api.nvim_create_namespace "sabunv-tty-cursor"
local cursor_buffer = nil

local CURSOR_HIGHLIGHT = "SabunvTTYCursor"
local INSERT_CURSOR_HIGHLIGHT = "SabunvTTYInsertCursor"
local CURSOR_ON_H2_HIGHLIGHT = "SabunvTTYCursorOnH2"
local INSERT_CURSOR_ON_H2_HIGHLIGHT = "SabunvTTYInsertCursorOnH2"
local MARKDOWN_FILETYPES = { markdown = true, quarto = true, ["markdown.mdx"] = true, opencode_output = true }

M.colors = {
  h2 = {
    fg = "black",
    bg = "red",
    ctermfg = 15,
    ctermbg = 1,
  },
  cursor = {
    -- El bloque físico invierte el fondo: cian termina viéndose rojo.
    fg = "white",
    bg = "cyan",
    ctermfg = 15,
    ctermbg = 14,
    nocombine = true,
  },
  insert_cursor = {
    -- La barra de inserción no invierte la celda completa.
    fg = "white",
    bg = "red",
    ctermfg = 15,
    ctermbg = 1,
    nocombine = true,
  },
  cursor_on_h2 = {
    -- Contraste inverso sobre el fondo rojo de H2.
    fg = "red",
    bg = "black",
    ctermfg = 1,
    ctermbg = 0,
    nocombine = true,
  },
  insert_cursor_on_h2 = {
    fg = "red",
    bg = "white",
    ctermfg = 1,
    ctermbg = 15,
    nocombine = true,
  },
}

local function cursor_highlight(bufnr, line)
  local is_insert = vim.api.nvim_get_mode().mode:sub(1, 1) == "i"
  local is_h2 = MARKDOWN_FILETYPES[vim.bo[bufnr].filetype] and line:match "^%s*##%s+"

  if is_h2 then
    return is_insert and INSERT_CURSOR_ON_H2_HIGHLIGHT or CURSOR_ON_H2_HIGHLIGHT
  end

  return is_insert and INSERT_CURSOR_HIGHLIGHT or CURSOR_HIGHLIGHT
end

---@return boolean
function M.is_pure()
  local term = (vim.env.TERM or ""):lower()
  local colorterm = (vim.env.COLORTERM or ""):lower()
  local session_type = (vim.env.XDG_SESSION_TYPE or ""):lower()
  local tty = vim.fn.system("tty 2>/dev/null"):gsub("%s+", "")

  if term == "linux" or term == "vt100" or term == "vt220" or term == "dumb" then
    return true
  end

  if session_type == "tty" and colorterm == "" then
    return true
  end

  return tty:match "^/dev/tty%d+$" ~= nil
end

local function clear_cursor()
  if cursor_buffer and vim.api.nvim_buf_is_valid(cursor_buffer) then
    vim.api.nvim_buf_clear_namespace(cursor_buffer, cursor_namespace, 0, -1)
  end
  cursor_buffer = nil
end

local function update_cursor()
  clear_cursor()

  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_win_get_buf(winid)
  if vim.bo[bufnr].buftype ~= "" then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(winid)
  if cursor[1] < 1 then
    return
  end

  local row = cursor[1] - 1
  local col = cursor[2]
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local char = vim.fn.strcharpart(line:sub(col + 1), 0, 1)
  local highlight = cursor_highlight(bufnr, line)

  if char == "" or char == "\t" then
    char = " "
  end

  cursor_buffer = bufnr
  vim.api.nvim_buf_set_extmark(bufnr, cursor_namespace, row, col, {
    ephemeral = false,
    priority = 65535,
    virt_text = { { char, highlight } },
    virt_text_pos = "overlay",
    hl_mode = "replace",
  })
end

function M.setup_cursor()
  if not M.is_pure() then
    clear_cursor()
    return
  end

  vim.api.nvim_set_hl(0, CURSOR_HIGHLIGHT, M.colors.cursor)
  vim.api.nvim_set_hl(0, INSERT_CURSOR_HIGHLIGHT, M.colors.insert_cursor)
  vim.api.nvim_set_hl(0, CURSOR_ON_H2_HIGHLIGHT, M.colors.cursor_on_h2)
  vim.api.nvim_set_hl(0, INSERT_CURSOR_ON_H2_HIGHLIGHT, M.colors.insert_cursor_on_h2)

  local group = vim.api.nvim_create_augroup("SabunvTTYCursor", { clear = true })
  vim.api.nvim_create_autocmd({
    "BufEnter",
    "CursorMoved",
    "CursorMovedI",
    "ModeChanged",
    "TextChanged",
    "TextChangedI",
    "WinEnter",
  }, {
    group = group,
    callback = update_cursor,
  })
  vim.api.nvim_create_autocmd({ "BufLeave", "WinLeave" }, {
    group = group,
    callback = clear_cursor,
  })

  update_cursor()
end

return M
