-- hzsr.win.wrap

-- Ajuste de línea por ventana.
--
-- `wrap` es una opción de ventana, no de buffer: el mismo archivo abierto en
-- dos splits puede ir ajustado en uno y sin ajustar en el otro. Todo lo de aquí
-- trabaja sobre una ventana concreta, nunca sobre el global.

local M = {}

--- Opciones que solo tienen sentido con `wrap` activo, y su valor entonces.
---
--- `linebreak` es la importante: sin ella el ajuste parte por el carácter que
--- toque, a mitad de palabra. `breakindent` sangra la continuación a la altura
--- de la línea original, que es lo que hace legible una lista ajustada.
local companions = {
  linebreak = true,
  breakindent = true,
}

---@param winid integer
---@param enabled boolean
local function apply(winid, enabled)
  vim.api.nvim_set_option_value("wrap", enabled, { win = winid })

  -- Al desactivar no se tocan: sin `wrap` no hacen nada, y devolverlas a su
  -- valor anterior obligaría a recordarlo por ventana para nada.
  if enabled then
    for name, value in pairs(companions) do
      vim.api.nvim_set_option_value(name, value, { win = winid })
    end
  end
end

--- Estado del ajuste de línea de una ventana.
---@param winid? integer `nil`|`0`|`-1` => ventana actual.
---@return boolean
function M.enabled(winid)
  return vim.api.nvim_get_option_value("wrap", { win = hzsr.win.resolve(winid) })
end

--- Activa el ajuste de línea.
---@param winid? integer `nil`|`0`|`-1` => ventana actual.
function M.enable(winid)
  apply(hzsr.win.resolve(winid), true)
end

--- Desactiva el ajuste de línea.
---@param winid? integer `nil`|`0`|`-1` => ventana actual.
function M.disable(winid)
  apply(hzsr.win.resolve(winid), false)
end

--- Alterna el ajuste de línea.
---@param winid? integer `nil`|`0`|`-1` => ventana actual.
---@return boolean enabled Estado en el que queda.
function M.toggle(winid)
  winid = hzsr.win.resolve(winid)

  local enabled = not M.enabled(winid)
  apply(winid, enabled)

  return enabled
end

return M
