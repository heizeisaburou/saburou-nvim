-- hzsr.enum

local M = {}

---Devuelve `true` si `value` coincide con alguno de los valores de `enum`.
---
---Pensado para validar enums definidos como tablas de constantes:
---
---```lua
---local mode = {
---  AUTO = "auto",
---  ASK = "ask",
---}
---
---M.one_of("auto", mode) -- true
---M.one_of("foo", mode)  -- false
---```
---
---No valida contra las claves del enum, sino contra sus valores.
---
---@param value any Valor a comprobar.
---@param enum table Tabla enum-like cuyos valores son las opciones válidas.
---@return boolean
function M.one_of(value, enum)
  vim.validate("enum", enum, "table")

  for _, enum_value in pairs(enum) do
    if value == enum_value then
      return true
    end
  end

  return false
end

return M
