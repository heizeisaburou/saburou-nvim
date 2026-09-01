-- hzsr.win.wrap

-- Ajuste de línea por ventana y buffer.
--
-- `wrap` es una opción de ventana, así que ponerla a secas se queda pegada a la
-- ventana: el siguiente archivo que abras ahí saldría ajustado aunque no tenga
-- nada que ver. Todo lo de aquí usa la forma ligada al buffer
-- (`vim.wo[win][buf]`), que da las dos propiedades que se quieren:
--
--   - el mismo archivo en dos splits puede ir ajustado en uno y no en el otro;
--   - abrir otro archivo en la misma ventana no hereda el ajuste.
--
-- Nunca se toca el valor global.

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
  -- `vim.wo[winid][bufnr]` sólo admite 0 como buffer, así que hay que estar en
  -- la ventana para que ese 0 sea el suyo.
  vim.api.nvim_win_call(winid, function()
    vim.wo[0][0].wrap = enabled

    -- Al desactivar no se tocan: sin `wrap` no hacen nada, y devolverlas a su
    -- valor anterior obligaría a recordarlo por ventana para nada.
    if enabled then
      for name, value in pairs(companions) do
        vim.wo[0][0][name] = value
      end
    end
  end)
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
