-- hzsr.edt.edit

local M = {}

-- =============================================================================
-- Cut
-- =============================================================================

M.cut = {}

---@param opts hzsr.edt.DeleteLineOpts?
function M.cut.delete_line(opts)
  local defaults = {
    copy = true,
    copy_indent = true,
    insert = true,
    keep_indent = true,
    winid = 0,
    row = nil,
  }

  local iopts = vim.tbl_extend("force", defaults, opts or {})

  local winid = iopts.winid
  local bufnr = vim.api.nvim_win_get_buf(winid)

  local row = iopts.row or vim.api.nvim_win_get_cursor(winid)[1]

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  local indent = line:match "^%s*" or ""

  if iopts.copy then
    local content_to_copy = iopts.copy_indent and line or line:sub(#indent + 1)
    vim.fn.setreg("+", content_to_copy)
  end

  vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { "" })

  if iopts.keep_indent then
    vim.api.nvim_buf_set_text(bufnr, row - 1, 0, row - 1, 0, { indent })
  end

  vim.api.nvim_win_set_cursor(winid, { row, iopts.keep_indent and #indent or 0 })

  if iopts.insert then
    vim.api.nvim_feedkeys("a", "n", false)
  end
end

---@param winid integer?
---@param over_lines boolean?
---@param cur_row integer?
---@param cur_col integer?
---@return integer? row
---@return integer? start
---@return integer? count
function M.cut.find_word(winid, over_lines, cur_row, cur_col)
  winid = winid or 0
  local bufnr = vim.api.nvim_win_get_buf(winid)

  if not cur_row or not cur_col then
    cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(winid))
  end

  local line_count = vim.api.nvim_buf_line_count(bufnr)

  local start_idx, count, line
  local row = cur_row
  local ln_start = cur_row - 1
  local ln_end = over_lines and line_count - 1 or ln_start

  for ln = ln_start, ln_end do
    line = vim.api.nvim_buf_get_lines(bufnr, ln, ln + 1, false)[1]

    if line then
      local s, e = line:find "%w+"

      while s and e and e < (ln == ln_start and cur_col + 1 or 0) do
        s, e = line:find("%w+", e + 1)
      end

      if s and e then
        start_idx = s
        count = e - s + 1
        row = ln + 1
        break
      end
    end
  end

  return row, start_idx, count
end

---@param opts hzsr.edt.DeleteWordOpts?
function M.cut.delete_word(opts)
  local defaults = {
    copy = true,
    insert = true,
    winid = 0,
    row = nil,
    col = nil,
  }

  local iopts = vim.tbl_extend("force", defaults, opts or {})

  local winid = iopts.winid
  local bufnr = vim.api.nvim_win_get_buf(winid)

  local cur_row, cur_col
  if iopts.row ~= nil and iopts.col ~= nil then
    cur_row = iopts.row
    cur_col = iopts.col
  else
    cur_row, cur_col = unpack(vim.api.nvim_win_get_cursor(winid))
  end

  local row, start_idx, count = M.cut.find_word(winid, true, cur_row, cur_col)
  if not row or not start_idx or not count then
    return
  end

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  local word = line:sub(start_idx, start_idx + count - 1)

  if iopts.copy then
    vim.fn.setreg("+", word)
  end

  local new_line = line:sub(1, start_idx - 1) .. line:sub(start_idx + count)
  vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })

  vim.api.nvim_win_set_cursor(winid, { row, start_idx - 1 })

  if iopts.insert then
    vim.api.nvim_feedkeys("a", "n", false)
  end
end

---@param opts hzsr.edt.DeleteToLineEndOpts?
function M.cut.delete_up_to_line_end(opts)
  local defaults = {
    copy = true,
    insert = true,
  }

  local iopts = vim.tbl_extend("force", defaults, opts or {})

  local winid = 0
  local bufnr = vim.api.nvim_win_get_buf(winid)

  local row, col = unpack(vim.api.nvim_win_get_cursor(winid))
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]

  if not line then
    return
  end

  local text_to_delete = line:sub(col + 1)

  if iopts.copy then
    vim.fn.setreg("+", text_to_delete)
  end

  local new_line = line:sub(1, col)
  vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })

  vim.api.nvim_win_set_cursor(winid, { row, col })

  if iopts.insert then
    vim.api.nvim_feedkeys("a", "n", false)
  end
end

-- =============================================================================
-- Append line suffix
-- =============================================================================

-- Créditos: CarlosHPlata (GitHub), por la idea original del keymap:
-- añadir puntuación al final de la línea conservando la posición del cursor.
M.append_line_suffix = {}

---@class hzsr.edt.edit.append_line_suffix.opts
---@field allow_dups? boolean
---@field strip? boolean

---@class hzsr.edt.edit.append_line_suffix.opts.internal
---@field allow_dups boolean
---@field strip boolean

---@type hzsr.edt.edit.append_line_suffix.opts.internal
M.append_line_suffix.defaults = {
  allow_dups = false,
  strip = true,
}

---@param suffix string
---@param opts? hzsr.edt.edit.append_line_suffix.opts
---@return fun()
function M.append_line_suffix.gen(suffix, opts)
  vim.validate("suffix", suffix, "string")
  vim.validate("opts", opts, "table", true)

  ---@type hzsr.edt.edit.append_line_suffix.opts.internal
  local int = vim.tbl_extend("force", M.append_line_suffix.defaults, opts or {})

  vim.validate("opts.allow_dups", int.allow_dups, "boolean")
  vim.validate("opts.strip", int.strip, "boolean")

  return function()
    local win = 0
    local bufnr = 0

    local cursor = vim.api.nvim_win_get_cursor(win)
    local row = cursor[1]
    local col = cursor[2]

    local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
    local new_line = int.strip and line:gsub("%s+$", "") or line

    if int.allow_dups or new_line:sub(-#suffix) ~= suffix then
      new_line = new_line .. suffix
    end

    vim.api.nvim_buf_set_lines(bufnr, row - 1, row, false, { new_line })

    local new_col = math.min(col, #new_line)
    vim.api.nvim_win_set_cursor(win, { row, new_col })
  end
end

return M
