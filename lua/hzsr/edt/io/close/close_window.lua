-- hzsr.edt.io.close.close_window

local M = {}

local Detail = require "hzsr.edt.io.close.detail"

-- -----------------------------------------------------------------------------

---@class hzsr.edt.io.close_window.opts
---@field protect_last_normal? boolean

---@class hzsr.edt.io.close_window.opts.internal
---@field protect_last_normal boolean

-- -----------------------------------------------------------------------------

---@param winid integer?
---@param opts hzsr.edt.io.close_window.opts?
---@return integer
---@return hzsr.edt.io.close_window.opts.internal
local function parse_close_window_args(winid, opts)
  vim.validate("winid", winid, "number", true)
  vim.validate("opts", opts, "table", true)

  local target = hzsr.win.resolve(winid)

  opts = opts or {}

  vim.validate("opts.protect_last_normal", opts.protect_last_normal, "boolean", true)

  ---@type hzsr.edt.io.close_window.opts.internal
  local iopts = vim.tbl_extend("force", {
    protect_last_normal = true,
  }, opts)

  return target, iopts
end

-- -----------------------------------------------------------------------------

-- Comprueba si `winid` es la única ventana normal de la pestaña actual.
-- Una ventana es "normal" si su buffer es normal según `hzsr.buf.filter.normal`.
-- Si la ventana objetivo no es normal, retorna `false`: no hay nada que proteger.
---@param winid integer
---@return boolean
local function is_last_normal_window(winid)
  local target_buf = vim.api.nvim_win_get_buf(winid)

  if not hzsr.buf.filter.normal(target_buf) then
    return false
  end

  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if w ~= winid and vim.api.nvim_win_is_valid(w) then
      local buf = vim.api.nvim_win_get_buf(w)

      if hzsr.buf.filter.normal(buf) then
        return false
      end
    end
  end

  return true
end

-- -----------------------------------------------------------------------------

---Cierra una ventana sin tocar su buffer.
---
---Si `opts.protect_last_normal` es `true` y la ventana objetivo es la única
---ventana normal de la pestaña actual, no la cierra.
---
---@param winid integer?
---@param opts hzsr.edt.io.close_window.opts?
---@return integer? closed Winid cerrado, o `nil` si no se cerró nada.
function M.close_window(winid, opts)
  local w, o = parse_close_window_args(winid, opts)

  if o.protect_last_normal and is_last_normal_window(w) then
    return nil
  end

  local ok, err = Detail.close_window(w)

  if not ok then
    error(err)
  end

  -- Si la ventana sigue viva, fue el guardia de "última ventana" de Neovim.
  if vim.api.nvim_win_is_valid(w) then
    return nil
  end

  return w
end

-- -----------------------------------------------------------------------------

return M
