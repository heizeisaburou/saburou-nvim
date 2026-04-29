-- hzsr.err.Error

--- @class hzsr.err.BoundFactory
--- @field new fun(code?: string, message?: string, data?: any): hzsr.err.Error

--- @class hzsr.err.Error
--- @field cname string
--- @field namespace string
--- @field code string
--- @field message string
--- @field data any
local Error = {}

Error.__index = Error
Error.__hzsr_err_base = true
Error.cname = "hzsr.err.Error"

--- @param value any
--- @return string
local function normalize_string(value)
  if value == nil then
    return ""
  end

  return tostring(value)
end

--- @param value string
--- @return boolean
local function is_empty(value)
  return value == ""
end

--- @param name string
--- @param value string
local function validate_no_colon(name, value)
  if value:find(":", 1, true) then
    error(string.format("%s must not contain ':'", name), 3)
  end
end

-- Formatea este error a string.
--
-- Reglas:
--   - namespace, code y message se unen en orden con ":".
--   - sólo se incluyen si no son "".
--   - si no hay encabezado, se usa "error".
--   - si hay data, se añade en una nueva línea con `vim.inspect`.
--
--- @return string
function Error:format()
  local parts = {}

  if not is_empty(self.namespace) then
    parts[#parts + 1] = self.namespace
  end

  if not is_empty(self.code) then
    parts[#parts + 1] = self.code
  end

  if not is_empty(self.message) then
    parts[#parts + 1] = self.message
  end

  local head = (#parts > 0) and table.concat(parts, ":") or "error"

  if self.data == nil then
    return head
  end

  return head .. "\n" .. vim.inspect(self.data)
end

function Error:__tostring()
  return self:format()
end

-- Lanza este error como objeto estructurado.
--
-- Conserva namespace, code, message y data para que pueda detectarse con
-- `Error.instanceof()` / `Error.matches()` desde un `pcall`.
--
--- @param level? integer
function Error:raise(level)
  error(self, level or 2)
end

-- Lanza este error como string formateado.
--
-- Pierde la estructura del error. Úsalo solo en bordes donde quieras
-- compatibilidad con flujos que esperan errores string.
--
--- @param level? integer
function Error:sraise(level)
  error(self:format(), level or 2)
end

-- Crea un objeto de error.
--
-- Convención:
--   - cname, namespace, code y message nunca son nil.
--   - namespace y code no pueden contener ":".
--   - data se conserva tal cual.
--
--- @param namespace? string
--- @param code? string
--- @param message? string
--- @param data? any
--- @return hzsr.err.Error
function Error.new(namespace, code, message, data)
  vim.validate("namespace", namespace, "string", true)
  vim.validate("code", code, "string", true)
  vim.validate("message", message, "string", true)

  namespace = normalize_string(namespace)
  code = normalize_string(code)
  message = normalize_string(message)

  if not is_empty(namespace) then
    validate_no_colon("namespace", namespace)
  end

  if not is_empty(code) then
    validate_no_colon("code", code)
  end

  return setmetatable({
    cname = Error.cname,
    namespace = namespace,
    code = code,
    message = message,
    data = data,
  }, Error)
end

-- Devuelve `true` si `value` es una instancia de una clase de error
-- compatible con hzsr.
--
-- Reglas:
--   - `value` debe ser una tabla.
--   - La metatable de `value` debe existir y ser una tabla.
--   - La metatable debe declarar `__hzsr_err_base = true`.
--   - No exige que la metatable sea exactamente `Error`, así que permite
--     subclases/herencia siempre que la clase derivada mantenga esa marca.
--
--- @param value any Valor a comprobar.
--- @return boolean
function Error.instanceof(value)
  if type(value) ~= "table" then
    return false
  end

  local mt = getmetatable(value)
  return type(mt) == "table" and mt.__hzsr_err_base == true
end

-- Devuelve `true` si `value` es un error compatible y además coincide
-- con el `namespace` y/o `code` indicados.
--
-- Reglas:
--   - Si `value` no es un error válido, devuelve `false`.
--   - Si `namespace` es `nil` o "", no se filtra por namespace.
--   - Si `code` es `nil` o "", no se filtra por code.
--   - Si ambos filtros están vacíos, el resultado equivale a comprobar
--     simplemente que `value` es un error válido.
--
--- @param value any Valor a comprobar.
--- @param namespace? string Namespace esperado. Si es `nil` o "", no se filtra por namespace.
--- @param code? string Code esperado. Si es `nil` o "", no se filtra por code.
--- @return boolean
function Error.matches(value, namespace, code)
  if not Error.instanceof(value) then
    return false
  end

  namespace = normalize_string(namespace)
  code = normalize_string(code)

  if namespace ~= "" and value.namespace ~= namespace then
    return false
  end

  if code ~= "" and value.code ~= code then
    return false
  end

  return true
end

-- Devuelve `true` si `value` es una string de error formateada por `Error:format()`
-- y además coincide con el `namespace` y/o `code` indicados.
--
-- Reglas:
--   - Si `value` no es string, devuelve `false`.
--   - Si `namespace` es `nil` o "", no se filtra por namespace.
--   - Si `code` es `nil` o "", no se filtra por code.
--   - Sólo comprueba la cabecera de la primera línea; ignora `data`.
--   - Soporta prefijos de Lua tipo "file.lua:123: ".
--
--- @param value any Valor a comprobar.
--- @param namespace? string Namespace esperado. Si es `nil` o "", no se filtra por namespace.
--- @param code? string Code esperado. Si es `nil` o "", no se filtra por code.
--- @return boolean
function Error.smatches(value, namespace, code)
  if type(value) ~= "string" then
    return false
  end

  namespace = normalize_string(namespace)
  code = normalize_string(code)

  local first_line = value:match "([^\n]*)" or value

  -- Lua suele prefijar los errores con "ruta:línea: ".
  -- Eliminamos ese prefijo si existe para quedarnos con el mensaje real.
  first_line = first_line:gsub("^.-:%d+:%s*", "", 1)

  local parsed_namespace, parsed_code = first_line:match "^([^:]+):([^:]+):"

  if parsed_namespace ~= nil and parsed_code ~= nil then
    if namespace ~= "" and parsed_namespace ~= namespace then
      return false
    end

    if code ~= "" and parsed_code ~= code then
      return false
    end

    return true
  end

  return false
end

-- Crea un constructor/helper ligado a un namespace por defecto.
--
--- @param default_namespace? string
--- @return hzsr.err.BoundFactory
function Error.bind(default_namespace)
  local namespace = normalize_string(default_namespace)

  if namespace ~= "" then
    validate_no_colon("default_namespace", namespace)
  end

  return {
    new = function(code, message, data)
      return Error.new(namespace, code, message, data)
    end,
  }
end

return Error
