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

-- ---------------------------------------------------------------------------
-- Herramientas externas que Mason no instala
-- ---------------------------------------------------------------------------
-- Esta configuración es pública: el criterio no es "qué tengo yo instalado"
-- sino "qué le pasa a quien la clona". `:MasonInstallAll` se salta en silencio
-- todo lo que no tenga mapping en Mason (`hzsr/mason/nvchad/init.lua`), así que
-- una herramienta ausente no puede fallar en silencio: hay que decir qué falta,
-- qué deja de funcionar y cómo se instala.
--
-- Pero tampoco puede repetirse en cada guardado. De ahí las dos propiedades de
-- `M.external`: resolución memoizada (una vez por sesión, no una vez por
-- formateo) y aviso con `vim.notify_once`.
--
-- Algunas de estas herramientas se instalan fuera del `PATH` (Julia deja sus
-- Pkg Apps en `~/.julia/bin`, que no añade al `PATH`), por lo que `paths`
-- permite declarar directorios de fallback donde buscarlas.

---@class hzsr.sys.executable.ExternalSpec
---@field bin string Ejecutable tal y como se busca en el `PATH`.
---@field label? string Nombre para el aviso, si no coincide con `bin`.
---@field paths? string[] Directorios de fallback; admiten `~`.
---@field why? string Qué deja de funcionar sin la herramienta.
---@field how? string Cómo se instala, ya redactado como frase.

---@class hzsr.sys.executable.External
---@field command fun(): string Ruta resuelta, o `bin` si no se encuentra.
---@field available fun(): boolean `false` (avisando una vez) si no está.

---@param spec hzsr.sys.executable.ExternalSpec
---@return string
local function missing_message(spec)
  local message = ("%s no está instalado"):format(spec.label or spec.bin)

  if spec.why then
    message = message .. ": " .. spec.why
  end

  message = message .. "."

  if spec.how then
    message = message .. " " .. spec.how
  end

  return message
end

---Declara una herramienta externa que Mason no instala.
---
---Busca el ejecutable en el `PATH` y, si no está, en los directorios de
---`paths`. Resuelve una sola vez por sesión y avisa una sola vez si falta,
---sin bloquear la operación que la pedía.
---@param spec hzsr.sys.executable.ExternalSpec
---@return hzsr.sys.executable.External
function M.external(spec)
  vim.validate("spec", spec, "table")
  vim.validate("spec.bin", spec.bin, "string")
  vim.validate("spec.paths", spec.paths, "table", true)

  -- nil mientras no se haya resuelto; luego la ruta encontrada o `false`.
  local resolved

  local function resolve()
    if resolved == nil then
      resolved = M.find(spec.bin) or false

      if not resolved then
        for _, dir in ipairs(spec.paths or {}) do
          local candidate = vim.fs.normalize(vim.fs.joinpath(dir, spec.bin))

          if vim.fn.executable(candidate) == 1 then
            resolved = candidate
            break
          end
        end
      end
    end

    return resolved
  end

  return {
    command = function()
      return resolve() or spec.bin
    end,
    available = function()
      if resolve() then
        return true
      end

      vim.notify_once(missing_message(spec), vim.log.levels.WARN)
      return false
    end,
  }
end

return M
