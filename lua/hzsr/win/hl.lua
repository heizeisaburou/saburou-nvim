-- hzsr.win.hl

local M = {}

---@alias hzsr.win.hl.winhighlight string
---@alias hzsr.win.hl.entries table<string, string>

---@class hzsr.win.hl.str.module
M.str = {}

-- ---------------------------------------------------------------------------
-- string helpers
-- ---------------------------------------------------------------------------
-- Estas funciones NO acceden a Neovim.
-- Solo reciben strings `winhighlight` y devuelven strings nuevos.

---Normaliza un valor de `winhighlight`.
---
---@param winhighlight? string
---@return string winhighlight
function M.str.normalize(winhighlight)
  vim.validate("winhighlight", winhighlight, "string", true)

  return winhighlight or ""
end

---Comprueba si una cadena de `winhighlight` contiene exactamente `from:to`.
---
---@param winhighlight? string Valor de `winhighlight` a inspeccionar.
---@param from string Grupo de highlight original.
---@param to string Grupo de highlight destino.
---@return boolean found `true` si existe exactamente la entrada `from:to`.
function M.str.has_entry(winhighlight, from, to)
  vim.validate("winhighlight", winhighlight, "string", true)
  vim.validate("from", from, "string")
  vim.validate("to", to, "string")

  winhighlight = M.str.normalize(winhighlight)

  local expected = from .. ":" .. to

  for item in string.gmatch(winhighlight, "([^,]+)") do
    if item == expected then
      return true
    end
  end

  return false
end

---Añade o reemplaza una entrada `from:to` en una cadena de `winhighlight`.
---
---Si ya existe una entrada con el mismo grupo `from`, se reemplaza.
---El resto de entradas se conservan.
---
---@param winhighlight? string Valor base de `winhighlight`.
---@param from string Grupo de highlight original.
---@param to string Grupo de highlight destino.
---@return string winhighlight Nuevo valor de `winhighlight`.
function M.str.add_entry(winhighlight, from, to)
  vim.validate("winhighlight", winhighlight, "string", true)
  vim.validate("from", from, "string")
  vim.validate("to", to, "string")

  winhighlight = M.str.normalize(winhighlight)

  local entry = from .. ":" .. to
  local entries = {}

  for item in string.gmatch(winhighlight, "([^,]+)") do
    local lhs = item:match "^([^:]+):"

    if lhs ~= from then
      table.insert(entries, item)
    end
  end

  table.insert(entries, entry)

  return table.concat(entries, ",")
end

---Elimina una entrada por grupo origen `from`.
---
---Por ejemplo, si `winhighlight` contiene `Normal:DiffAdd`, pasar
---`from = "Normal"` eliminará esa entrada independientemente del destino.
---
---@param winhighlight? string Valor base de `winhighlight`.
---@param from string Grupo de highlight original.
---@return string winhighlight Nuevo valor de `winhighlight`.
function M.str.remove_entry(winhighlight, from)
  vim.validate("winhighlight", winhighlight, "string", true)
  vim.validate("from", from, "string")

  winhighlight = M.str.normalize(winhighlight)

  local entries = {}

  for item in string.gmatch(winhighlight, "([^,]+)") do
    local lhs = item:match "^([^:]+):"

    if lhs ~= from then
      table.insert(entries, item)
    end
  end

  return table.concat(entries, ",")
end

---Añade o reemplaza varias entradas en una cadena de `winhighlight`.
---
---@param winhighlight? string Valor base de `winhighlight`.
---@param entries hzsr.win.hl.entries Mapa `{ from = to }`.
---@return string winhighlight Nuevo valor de `winhighlight`.
function M.str.add_entries(winhighlight, entries)
  vim.validate("winhighlight", winhighlight, "string", true)
  vim.validate("entries", entries, "table")

  winhighlight = M.str.normalize(winhighlight)

  for from, to in pairs(entries) do
    vim.validate("from", from, "string")
    vim.validate("to", to, "string")

    winhighlight = M.str.add_entry(winhighlight, from, to)
  end

  return winhighlight
end

---Elimina varias entradas por grupo origen.
---
---@param winhighlight? string Valor base de `winhighlight`.
---@param groups string[] Lista de grupos origen a eliminar.
---@return string winhighlight Nuevo valor de `winhighlight`.
function M.str.remove_entries(winhighlight, groups)
  vim.validate("winhighlight", winhighlight, "string", true)
  vim.validate("groups", groups, "table")

  winhighlight = M.str.normalize(winhighlight)

  for index, from in ipairs(groups) do
    vim.validate(("groups[%d]"):format(index), from, "string")

    winhighlight = M.str.remove_entry(winhighlight, from)
  end

  return winhighlight
end

-- ---------------------------------------------------------------------------
-- window helpers
-- ---------------------------------------------------------------------------
-- Estas funciones SÍ acceden a Neovim.
-- Están sueltas en `hzsr.win.hl.*`.

---Obtiene el valor de `winhighlight` de una ventana.
---
---Si `winid` es `nil`, usa la ventana actual mediante `hzsr.win.resolve`.
---Devuelve siempre un string para ventanas válidas.
---
---@param winid? integer Identificador de ventana. Si es `nil`, se resuelve la ventana actual.
---@return string winhighlight Valor actual de `winhighlight`.
function M.get_winhighlight(winid)
  winid = hzsr.win.resolve(winid)

  return vim.wo[winid].winhighlight or ""
end

---Establece el valor de `winhighlight` de una ventana.
---
---Si `winhighlight` es `nil`, se establece como cadena vacía.
---
---@param winid? integer Identificador de ventana. Si es `nil`, se resuelve la ventana actual.
---@param winhighlight? string Nuevo valor de `winhighlight`.
function M.set_winhighlight(winid, winhighlight)
  vim.validate("winhighlight", winhighlight, "string", true)

  winid = hzsr.win.resolve(winid)

  vim.wo[winid].winhighlight = winhighlight or ""
end

---Limpia el `winhighlight` de una ventana.
---
---@param winid? integer Identificador de ventana. Si es `nil`, se resuelve la ventana actual.
function M.clear_winhighlight(winid)
  M.set_winhighlight(winid, "")
end

---Comprueba si una ventana tiene una entrada exacta `from:to` en `winhighlight`.
---
---@param winid? integer Identificador de ventana. Si es `nil`, se resuelve la ventana actual.
---@param from string Grupo de highlight original.
---@param to string Grupo de highlight destino.
---@return boolean found `true` si existe exactamente la entrada `from:to`.
function M.has_winhighlight_entry(winid, from, to)
  local winhighlight = M.get_winhighlight(winid)

  return M.str.has_entry(winhighlight, from, to)
end

---Añade o reemplaza una entrada `from:to` en el `winhighlight` de una ventana.
---
---@param winid? integer Identificador de ventana. Si es `nil`, se resuelve la ventana actual.
---@param from string Grupo de highlight original.
---@param to string Grupo de highlight destino.
---@return string winhighlight Nuevo valor aplicado.
function M.set_winhighlight_entry(winid, from, to)
  local winhighlight = M.get_winhighlight(winid)

  winhighlight = M.str.add_entry(winhighlight, from, to)

  M.set_winhighlight(winid, winhighlight)

  return winhighlight
end

---Elimina una entrada por grupo origen `from` del `winhighlight` de una ventana.
---
---@param winid? integer Identificador de ventana. Si es `nil`, se resuelve la ventana actual.
---@param from string Grupo de highlight original.
---@return string winhighlight Nuevo valor aplicado.
function M.unset_winhighlight_entry(winid, from)
  local winhighlight = M.get_winhighlight(winid)

  winhighlight = M.str.remove_entry(winhighlight, from)

  M.set_winhighlight(winid, winhighlight)

  return winhighlight
end

---Añade o reemplaza varias entradas en el `winhighlight` de una ventana.
---
---@param winid? integer Identificador de ventana. Si es `nil`, se resuelve la ventana actual.
---@param entries hzsr.win.hl.entries Mapa `{ from = to }`.
---@return string winhighlight Nuevo valor aplicado.
function M.set_winhighlight_entries(winid, entries)
  local winhighlight = M.get_winhighlight(winid)

  winhighlight = M.str.add_entries(winhighlight, entries)

  M.set_winhighlight(winid, winhighlight)

  return winhighlight
end

---Elimina varias entradas del `winhighlight` de una ventana por grupo origen.
---
---@param winid? integer Identificador de ventana. Si es `nil`, se resuelve la ventana actual.
---@param groups string[] Lista de grupos origen a eliminar.
---@return string winhighlight Nuevo valor aplicado.
function M.unset_winhighlight_entries(winid, groups)
  local winhighlight = M.get_winhighlight(winid)

  winhighlight = M.str.remove_entries(winhighlight, groups)

  M.set_winhighlight(winid, winhighlight)

  return winhighlight
end

return M
