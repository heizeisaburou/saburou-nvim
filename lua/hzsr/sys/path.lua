-- hzsr.sys.path

local M = {}

-- Convierte `path` en una ruta absoluta y normalizada.
--
-- No requiere que la ruta exista.
-- Resuelve componentes como `.` y `..`, pero no resuelve symlinks.
--
--- @param path string
--- @return string
function M.resolve(path)
  vim.validate("path", path, "string")

  return vim.fn.fnamemodify(path, ":p")
end

-- Devuelve el directorio padre de `path`.
--
-- No requiere que la ruta exista.
--
--- @param path string
--- @return string
function M.dirname(path)
  vim.validate("path", path, "string")

  return vim.fn.fnamemodify(path, ":h")
end

-- Devuelve el nombre final de `path`.
--
-- No requiere que la ruta exista.
--
---@param path string
---@return string
function M.basename(path)
  vim.validate("path", path, "string")

  return vim.fn.fnamemodify(path, ":t")
end

-- Normaliza separadores de ruta al estilo del sistema operativo.
--
-- En Windows convierte `/` a `\`.
-- En Unix no modifica la ruta.
--
---@param path string
---@return string
function M.normalize(path)
  vim.validate("path", path, "string")

  local sysname = vim.uv.os_uname().sysname:lower()
  local iswin = not not (sysname:find "windows" or sysname:find "mingw")

  if iswin then
    return path:gsub("/", "\\")
  end

  return path
end

-- Devuelve el separador de entradas en la variable de entorno PATH.
--
-- Windows: `;` · Unix: `:`
--
---@return string
function M.env_path_sep()
  local sysname = vim.uv.os_uname().sysname:lower()
  local iswin = not not (sysname:find "windows" or sysname:find "mingw")

  return iswin and ";" or ":"
end

-- Comprueba si `entry` ya está en `vim.env.PATH`.
--
-- En Windows normaliza slashes e ignora mayúsculas para evitar falsos negativos.
--
---@param entry string
---@return boolean
function M.in_env_path(entry)
  vim.validate("entry", entry, "string")

  local sysname = vim.uv.os_uname().sysname:lower()
  local iswin = not not (sysname:find "windows" or sysname:find "mingw")
  local sep = iswin and ";" or ":"

  if iswin then
    local norm = entry:lower():gsub("[/\\]", "\\")
    for _, e in ipairs(vim.split(vim.env.PATH or "", sep, { plain = true })) do
      if e:lower():gsub("[/\\]", "\\") == norm then
        return true
      end
    end
    return false
  end

  return (vim.env.PATH or ""):find(vim.pesc(entry), 1, true) ~= nil
end

-- Antepone `entry` a `vim.env.PATH` si no está ya presente.
--
-- Usa el separador correcto para el SO actual.
--
---@param entry string
function M.prepend_env_path(entry)
  vim.validate("entry", entry, "string")

  if not M.in_env_path(entry) then
    vim.env.PATH = entry .. M.env_path_sep() .. (vim.env.PATH or "")
  end
end

return M
