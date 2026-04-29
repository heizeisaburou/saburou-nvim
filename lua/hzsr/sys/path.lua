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

return M
