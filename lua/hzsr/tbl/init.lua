-- hzsr.tbl

local M = {}

M.lst = require "hzsr.tbl.lst"

-- -----------------------------------------------------------------------------

-- Devuelve una sublista de `lst` desde el índice `i` hasta `j`.
--
-- Reglas:
--   - `j` es opcional; si no se indica, se usa `#lst`.
--   - Sólo copia posiciones existentes/no nil.
--   - No modifica la lista original.
--
--- @generic T
--- @param lst T[]
--- @param i integer Índice inicial.
--- @param j? integer Índice final. Por defecto: `#lst`.
--- @return T[]
function M.select(lst, i, j)
  vim.validate("lst", lst, "table")
  vim.validate("i", i, "number")
  vim.validate("j", j, "number", true)

  hzsr.num.assert.integer("i", i)

  if j ~= nil then
    hzsr.num.assert.integer("j", j)
  end

  j = j or #lst

  local out = {}

  for k = i, j do
    if lst[k] ~= nil then
      out[#out + 1] = lst[k]
    end
  end

  return out
end

-- Devuelve `true` si `lst` contiene `value`.
--
--- @generic T
--- @param lst T[]
--- @param value T
--- @return boolean
function M.contains(lst, value)
  vim.validate("lst", lst, "table")

  for _, item in ipairs(lst) do
    if item == value then
      return true
    end
  end

  return false
end

-- Devuelve `true` si `lst` no contiene elementos.
--
--- @param lst any[]
--- @return boolean
function M.empty(lst)
  vim.validate("lst", lst, "table")

  return #lst == 0
end

-- Devuelve `true` si `lst` contiene al menos un elemento.
--
--- @param lst any[]
--- @return boolean
function M.not_empty(lst)
  vim.validate("lst", lst, "table")

  return #lst > 0
end

-- -----------------------------------------------------------------------------

M.assert = {}

-- Lanza error si `lst` está vacía.
--
--- @param name string
--- @param lst any[]
function M.assert.not_empty(name, lst)
  vim.validate("name", name, "string")
  vim.validate(name, lst, "table")

  if M.empty(lst) then
    error(("%s must not be empty"):format(name), 2)
  end
end

-- Lanza error si `lst` no es una lista.
--
--- @param name string
--- @param lst table
function M.assert.is_list(name, lst)
  vim.validate("name", name, "string")
  vim.validate(name, lst, "table")

  if not vim.islist(lst) then
    error(("%s must be a list, not a map"):format(name), 2)
  end
end

-- Lanza error si `lst` no es una lista de strings.
--
--- @param name string
--- @param lst table
function M.assert.of_str(name, lst)
  M.assert.is_list(name, lst)

  if not vim.iter(lst):all(function(value)
    return type(value) == "string"
  end) then
    error(("%s must be a list of strings"):format(name), 2)
  end
end

-- Lanza error si `lst` contiene duplicados.
--
--- @param name string
--- @param lst table
function M.assert.unique(name, lst)
  M.assert.is_list(name, lst)

  local unique = vim.list.unique(vim.deepcopy(lst))

  if not vim.deep_equal(lst, unique) then
    error(("%s must not have duplicates"):format(name), 2)
  end
end

return M
