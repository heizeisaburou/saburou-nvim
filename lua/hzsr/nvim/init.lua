-- hzsr.nvim

local M = {}

-- -----------------------------------------------------------------------------

---@return string?
function M.appname()
  return vim.env.NVIM_APPNAME
end

---@return string
function M.normalize_appname()
  return M.appname() or "nvim"
end

---@return string
function M.runtimedir()
  return vim.env.VIMRUNTIME
end

---@param nvim_appname? string Custom NVIM_APPNAME
---@return string
function M.configdir(nvim_appname)
  local appname = nvim_appname or M.normalize_appname()
  return vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath "config"), appname)
end

---@param nvim_appname? string Custom NVIM_APPNAME
---@return string
function M.statedir(nvim_appname)
  local appname = nvim_appname or M.normalize_appname()
  return vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath "state"), appname)
end

---@param nvim_appname? string Custom NVIM_APPNAME
---@return string
function M.datadir(nvim_appname)
  local appname = nvim_appname or M.normalize_appname()
  return vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath "data"), appname)
end

-- -----------------------------------------------------------------------------

M.rmdir = {}

-- Funciones para eliminar directorios de Neovim.
--
-- Por seguridad, no se ofrece `configdir` como directorio a eliminar.

---Elimina el directorio de estado de Neovim.
---
---Equivale a `rmdir`: solo funciona si el directorio está vacío.
---
---@return boolean ok
---@return string? err
function M.state()
  return hzsr.sys.fs.rmdir(hzsr.nvim.statedir())
end

---Elimina el directorio de datos de Neovim.
---
---Equivale a `rmdir`: solo funciona si el directorio está vacío.
---
---@return boolean ok
---@return string? err
function M.data()
  return hzsr.sys.fs.rmdir(hzsr.nvim.datadir())
end

-- -----------------------------------------------------------------------------

M.error = {}

function M.error.is_keyboard_interrupt(err)
  return tostring(err):lower():match "keyboard%s*interrupt" ~= nil
end

-- Captura cosas como:
-- Vim(write):E13: ...
-- Vim:E212: ...
-- E37: ...
---@param err string
function M.error.filter_code(err)
  return err:match "Vim%([^)]*%):(E%d+):" or err:match ":(E%d+):" or err:match "(E%d+)"
end

-- -----------------------------------------------------------------------------

M.luarc = require "hzsr.nvim.luarc"

return M
