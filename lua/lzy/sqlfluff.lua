-- lazy/l_sqlfluff

-- sqlfluff formatea y además hace de linter, pero necesita que el proyecto
-- declare su dialecto: sin él aborta. Esta config es pública, así que no puede
-- exigir esa disciplina a quien solo abre un `.sql` suelto.
--
-- Aquí vive el criterio compartido por las dos capas que lo usan: Conform
-- (formato, con `pg_format` de reserva) y nvim-lint (diagnósticos, que
-- sencillamente no se ejecutan donde no hay dialecto).
--
-- Lo que trae Conform de fábrica no basta: su lista de raíces incluye
-- `pyproject.toml`, `setup.cfg` y `tox.ini`, así que cualquier proyecto Python
-- con un `.sql` dentro activaría sqlfluff sin haberlo configurado nunca.

local M = {}

-- Archivos donde sqlfluff acepta su configuración, en el orden en que se
-- buscan hacia arriba desde el archivo.
M.configs = { ".sqlfluff", "pyproject.toml", "setup.cfg", "tox.ini", "pep8.ini" }

-- `true` si el archivo declara de verdad una configuración de sqlfluff. Un
-- `.sqlfluff` lo es por definición; el resto solo cuentan si traen la sección.
--
---@param path string
---@return boolean
local function declares(path)
  if vim.fs.basename(path) == ".sqlfluff" then
    return true
  end

  local ok, lines = pcall(vim.fn.readfile, path, "", 500)
  if not ok then
    return false
  end

  return vim.iter(lines):any(function(line)
    return line:find "^%s*%[tool%.sqlfluff" ~= nil or line:find "^%s*%[sqlfluff" ~= nil
  end)
end

--- `true` si algún ancestro de `dirname` declara el dialecto de sqlfluff.
---@param dirname string|nil
---@return boolean
function M.declared(dirname)
  if not dirname or dirname == "" then
    return false
  end

  for _, name in ipairs(M.configs) do
    local found = vim.fs.find(name, {
      upward = true,
      path = dirname,
      type = "file",
    })[1]

    if found and declares(found) then
      return true
    end
  end

  return false
end

return M
