-- hzsr.edt.reveal.simple.Marker

---@class hzsr.edt.reveal.simple.Marker.opts
---@field hl? string Highlight destino usado en `winhighlight`. Por defecto: `"CurSearch"`.
---@field hl_groups? string[] Grupos de ventana que se remapearán.

---@class hzsr.edt.reveal.simple.Marker
---@field _winid integer Identificador de ventana de Neovim.
---@field _hl string Highlight destino usado para revelar la ventana.
---@field _hl_groups string[] Grupos de ventana que se remapearán.
---@field _original_winhighlight string Valor original de `winhighlight` antes de activar el marker.
local Marker = {}

Marker.__index = Marker

---@private
---@type string
Marker.__default_hl = "CurSearch"

---@private
---@type string[]
Marker.__default_hl_groups = {
  -- Window/base UI
  "Normal",
  "NormalNC",
  "SignColumn",
  "LineNr",
  "CursorLine",
  "CursorLineNr",
  "EndOfBuffer",
  "FoldColumn",
}

---@param opts? hzsr.edt.reveal.simple.Marker.opts
---@return string
---@return string[]
local function parse_opts(opts)
  vim.validate("opts", opts, "table", true)

  opts = opts or {}

  local int = vim.tbl_extend("force", {
    hl = Marker.__default_hl,
    hl_groups = Marker.__default_hl_groups,
  }, opts)

  vim.validate("opts.hl", int.hl, "string", true)
  vim.validate("opts.hl_groups", int.hl_groups, "table", true)

  int.hl = int.hl ~= "" and int.hl or Marker.__default_hl

  if int.hl_groups == nil or vim.tbl_isempty(int.hl_groups) then
    int.hl_groups = Marker.__default_hl_groups
  end

  for index, hl_group in ipairs(int.hl_groups) do
    vim.validate(("opts.hl_groups[%d]"):format(index), hl_group, "string")
  end

  return int.hl, int.hl_groups
end

---Crea un marker para una ventana concreta.
---
---@param winid integer Identificador de ventana válido.
---@param opts? hzsr.edt.reveal.simple.Marker.opts Opciones de highlight.
---@return hzsr.edt.reveal.simple.Marker marker Nueva instancia de marker.
function Marker.new(winid, opts)
  vim.validate("winid", winid, "number")

  local target = hzsr.win.resolve(winid)
  local hl, hl_groups = parse_opts(opts)

  ---@type hzsr.edt.reveal.simple.Marker
  local self = setmetatable({
    _winid = target,
    _hl = hl,
    _hl_groups = hl_groups,
    _original_winhighlight = hzsr.win.hl.get_winhighlight(target),
  }, Marker)

  return self
end

---@return integer
function Marker:get_win()
  return self._winid
end

---@return string
function Marker:get_hl()
  return self._hl
end

---@return string[]
function Marker:get_hl_groups()
  return self._hl_groups
end

---Activa el marker en la ventana asociada.
---
---@return boolean ok
function Marker:activate()
  if not self:is_valid() then
    return false
  end

  if self:is_active() then
    return true
  end

  self._original_winhighlight = hzsr.win.hl.get_winhighlight(self._winid)

  local entries = {}

  for _, hl_group in ipairs(self._hl_groups) do
    entries[hl_group] = self._hl
  end

  hzsr.win.hl.set_winhighlight(
    self._winid,
    hzsr.win.hl.str.add_entries(self._original_winhighlight, entries)
  )

  return true
end

---Desactiva el marker y restaura el `winhighlight` original.
---
---@return boolean ok
function Marker:deactivate()
  if not self:is_valid() then
    return false
  end

  if not self:is_active() then
    return true
  end

  hzsr.win.hl.set_winhighlight(self._winid, self._original_winhighlight)

  return true
end

---Indica si el marker está activo actualmente en la ventana.
---
---@return boolean active
function Marker:is_active()
  if not self:is_valid() then
    return false
  end

  local winhighlight = hzsr.win.hl.get_winhighlight(self._winid)

  for _, hl_group in ipairs(self._hl_groups) do
    if not hzsr.win.hl.str.has_entry(winhighlight, hl_group, self._hl) then
      return false
    end
  end

  return true
end

---Indica si la ventana asociada sigue existiendo.
---
---@return boolean valid
function Marker:is_valid()
  return hzsr.win.is_valid(self._winid)
end

return Marker
