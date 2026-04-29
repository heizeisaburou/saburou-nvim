-- hzsr.sys.fs

local M = {}

-- Devuelve la ruta real del sistema de archivos.
--
-- Resuelve symlinks y normaliza la ruta, pero requiere que exista.
-- Si la ruta no existe o no puede resolverse, devuelve `nil`.
--
--- @param path string
--- @return string?
function M.realpath(path)
  vim.validate("path", path, "string")

  return vim.uv.fs_realpath(path)
end

-- Devuelve `true` si `path` existe en el sistema de archivos.
--
--- @param path string
--- @return boolean
function M.exists(path)
  vim.validate("path", path, "string")

  return vim.uv.fs_stat(path) ~= nil
end

-- Devuelve `true` si `path` existe y es un archivo regular.
--
--- @param path string
--- @return boolean
function M.is_file(path)
  vim.validate("path", path, "string")

  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

-- Devuelve `true` si `path` existe y es un directorio.
--
--- @param path string
--- @return boolean
function M.is_dir(path)
  vim.validate("path", path, "string")

  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

-- Elimina un directorio vacío.
--
-- Equivale a `rmdir`: falla si el directorio no existe, no es un directorio,
-- o no está vacío.
--
--- @param path string
--- @return boolean ok
--- @return string? err
function M.rmdir(path)
  vim.validate("path", path, "string")

  local ok, err = vim.uv.fs_rmdir(path)

  if ok then
    return true
  end

  return false, err
end

return M
