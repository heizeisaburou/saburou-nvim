-- hzsr.sys.executable

local M = {}

---@param names string|string[]
---@return string?
function M.find(names)
  names = type(names) == "string" and { names } or names
  vim.validate("names", names, "table")

  for index, name in ipairs(names) do
    vim.validate(("names[%d]"):format(index), name, "string")

    local path = vim.fn.exepath(name)
    if path ~= "" then
      return path
    end
  end

  return nil
end

---Resuelve el primer ejecutable disponible y conserva el primer nombre como
---fallback para que el consumidor pueda informar de que no está instalado.
---@param names string|string[]
---@return string
function M.resolve(names)
  local list = type(names) == "string" and { names } or names
  vim.validate("names", list, "table")

  if #list == 0 then
    error "names debe contener al menos un ejecutable"
  end

  return M.find(list) or list[1]
end

return M
