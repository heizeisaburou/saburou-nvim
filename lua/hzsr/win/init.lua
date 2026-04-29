-- hzsr.win

local M = {}

-- Normaliza una ventana opcional.
--
--- @param winid? integer `nil`|`0`|`-1` => ventana actual.
--- @param validate? boolean? lanza excepción si la ventana es inválida. Por defecto: `true`
function M.resolve(winid, validate)
  vim.validate("winid", winid, "number", true)
  vim.validate("validate", validate, "boolean", true)

  if winid == nil or winid == 0 or winid == -1 then
    winid = vim.api.nvim_get_current_win()
  end

  validate = validate ~= nil and validate or true
  if validate and not vim.api.nvim_win_is_valid(winid) then
    hzsr.err.Error
      .new("hzsr.win.resolve", "INVALID_WINDOW", "el window indicado no es válido", { winid = winid })
      :raise()
  end

  return winid
end

---Indica si una ventana opcional es válida.
---
---`nil`, `0` y `-1` se resuelven como ventana actual.
---
---@param winid? integer
---@return boolean valid
function M.is_valid(winid)
  vim.validate("winid", winid, "number", true)

  if winid == nil or winid == 0 or winid == -1 then
    winid = vim.api.nvim_get_current_win()
  end

  return vim.api.nvim_win_is_valid(winid)
end

-- Cierra una ventana opcional.
--
--- @param winid? integer `nil`|`0`|`-1` => ventana actual.
function M.close(winid, force)
  winid = M.resolve(winid)

  vim.api.nvim_win_close(winid, force)
end

M.hl = require "hzsr.win.hl"

return M
