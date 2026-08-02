-- hzsr.nvim

local M = {}

-- -----------------------------------------------------------------------------

---@return string?
function M.appname()
  local appname = vim.env.NVIM_APPNAME
  return appname ~= "" and appname or nil
end

---@return string
function M.normalize_appname()
  return M.appname() or "nvim"
end

---@return string
function M.runtimedir()
  return vim.env.VIMRUNTIME or ""
end

---@param path string
---@param current_appname string
---@param target_appname string
---@return string
function M.retarget_stdpath(path, current_appname, target_appname)
  vim.validate("path", path, "string")
  vim.validate("current_appname", current_appname, "string")
  vim.validate("target_appname", target_appname, "string")

  local current_parts = vim.split(current_appname:gsub("\\", "/"), "/", {
    plain = true,
    trimempty = true,
  })

  if #current_parts == 0 then
    error "current_appname no puede estar vacío"
  end

  local current_leaf = current_parts[#current_parts]
  local path_leaf = vim.fs.basename(path)
  local suffix = ""

  if path_leaf == current_leaf .. "-data" then
    suffix = "-data"
  elseif path_leaf ~= current_leaf then
    error(("stdpath '%s' no corresponde a NVIM_APPNAME='%s'"):format(path, current_appname))
  end

  local root = path
  for _ = 1, #current_parts do
    root = vim.fs.dirname(root)
  end

  local target_parts = vim.split(target_appname:gsub("\\", "/"), "/", {
    plain = true,
    trimempty = true,
  })

  if #target_parts == 0 then
    error "target_appname no puede estar vacío"
  end

  target_parts[#target_parts] = target_parts[#target_parts] .. suffix

  local target = root
  for _, part in ipairs(target_parts) do
    target = vim.fs.joinpath(target, part)
  end

  return target
end

---@param kind "config"|"data"|"state"
---@param nvim_appname? string
---@return string
local function stdpath_for_app(kind, nvim_appname)
  local current_appname = M.normalize_appname()
  local current_path = vim.fn.stdpath(kind)

  if not nvim_appname or nvim_appname == current_appname then
    return current_path
  end

  return M.retarget_stdpath(current_path, current_appname, nvim_appname)
end

---@param nvim_appname? string Custom NVIM_APPNAME
---@return string
function M.configdir(nvim_appname)
  return stdpath_for_app("config", nvim_appname)
end

---@param nvim_appname? string Custom NVIM_APPNAME
---@return string
function M.statedir(nvim_appname)
  return stdpath_for_app("state", nvim_appname)
end

---@param nvim_appname? string Custom NVIM_APPNAME
---@return string
function M.datadir(nvim_appname)
  return stdpath_for_app("data", nvim_appname)
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
