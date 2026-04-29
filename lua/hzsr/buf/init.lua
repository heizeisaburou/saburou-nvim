-- hzsr.buf

local M = {}

--- Normaliza un buffer opcional.
---
--- @param bufnr? integer `nil`|`0`|`-1` => buffer actual.
--- @param validate? boolean? lanza excepción si el buffer es inválido. Por defecto: `true`
--- @return integer `-1` => buffer inválido
function M.resolve(bufnr, validate)
  vim.validate("bufnr", bufnr, "number", true)
  vim.validate("validate", validate, "boolean", true)

  if bufnr == nil or bufnr == 0 or bufnr == -1 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  validate = validate ~= nil and validate or true
  if validate and not vim.api.nvim_buf_is_valid(bufnr) then
    hzsr.err.Error
      .new("hzsr.buf.resolve", "INVALID_BUFFER", "el buffer indicado no es válido", { bufnr = bufnr })
      :raise()
  end

  return bufnr
end

-- hzsr.buf

---Indica si un buffer opcional es válido.
---
---`nil`, `0` y `-1` se resuelven como buffer actual.
---
---@param bufnr? integer
---@return boolean valid
function M.is_valid(bufnr)
  vim.validate("bufnr", bufnr, "number", true)

  if bufnr == nil or bufnr == 0 or bufnr == -1 then
    bufnr = vim.api.nvim_get_current_buf()
  end

  return vim.api.nvim_buf_is_valid(bufnr)
end

-- Elimina o descarga un buffer opcional.
--
--- @param bufnr? integer `nil`|`0`|`-1` => buffer actual.
--- @param force? boolean Fuerza eliminación; ignora cambios pendientes.
--- @param unload? boolean Descargar el en lugar de eliminarlo.
function M.delete(bufnr, force, unload)
  bufnr = M.resolve(bufnr)

  vim.validate("force", force, "boolean", true)
  vim.validate("unload", unload, "boolean", true)

  opts = { force = force or false, unload = unload or false }

  vim.api.nvim_buf_delete(bufnr, opts)
end

-- Genera una etiqueta basada en el nombre del buffer.
--
--- @param bufnr? integer
function M.gen_label(bufnr)
  local target = M.resolve(bufnr)
  local name = vim.api.nvim_buf_get_name(target)

  if name == "" then
    return "[No Name]"
  end
  return vim.fn.fnamemodify(name, ":t")
end

-- Cambia en todas las ventanas visibles el buffer `from_buf` por `to_buf`.
--
--- @param from_bufnr integer
--- @param to_bufnr integer
function M.replace_in_windows(from_bufnr, to_bufnr)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == from_bufnr then
      vim.api.nvim_win_set_buf(win, to_bufnr)
    end
  end
end

local function resolve_filter(filter)
  if type(filter) == "function" then
    return filter
  end

  if filter == "valid" then
    return hzsr.buf.filter.valid
  end

  if filter == "normal" then
    return hzsr.buf.filter.normal
  end

  if filter == "modified" then
    return hzsr.buf.filter.modified
  end

  if filter == "visible" then
    return hzsr.buf.filter.visible
  end

  error(("unknown buffer filter: %q"):format(filter))
end

-- Devuelve una lista de buffers en el mejor orden disponible.
-- Combina varias fuentes con esta prioridad: tabs, MRU y, por último,
-- el orden base de Neovim. Los duplicados se eliminan preservando la
-- primera aparición.
--
-- `filters` puede ser:
--   - `nil`: no filtra
--   - un string: resuelve a un filtro básico
--   - una función: se aplica directamente
--   - una lista de strings y/o funciones
--
-- `union` controla cómo se combinan varios filtros:
--   - `"and"`: todos deben pasar
--   - `"or"`: basta con que pase uno
--   - `nil`: se aplican uno a uno, en orden
--- @param filters? hzsr.buf.filter_str|hzsr.buf.filter_fn|hzsr.buf.filter_str[]|hzsr.buf.filter_fn[]
--- @param union? "and"|"or"
--- @return integer[]
function M.get_all(filters, union)
  vim.validate("union", union, function(v)
    return v == nil or v == "and" or v == "or"
  end, '"and", "or", or nil')

  vim.validate("filters", filters, function(v)
    if v == nil then
      return true
    end

    if type(v) == "string" or type(v) == "function" then
      return true
    end

    if type(v) == "table" then
      for i, item in ipairs(v) do
        local t = type(item)
        if t ~= "string" and t ~= "function" then
          return false, ("filters[%d] must be a string or function"):format(i)
        end
      end
      return true
    end

    return false
  end, "nil, string, function, or list of strings/functions")

  local buffers = hzsr.buf.source.adapter()

  if filters == nil then
    return buffers
  end

  local resolved

  if type(filters) == "string" or type(filters) == "function" then
    resolved = { resolve_filter(filters) }
  else
    resolved = vim.iter(filters):map(resolve_filter):totable()
  end

  if #resolved == 0 then
    return buffers
  end

  if union == "and" then
    return hzsr.buf.filter.apply(buffers, hzsr.buf.filter.gen.all(table.unpack(resolved)))
  end

  if union == "or" then
    return hzsr.buf.filter.apply(buffers, hzsr.buf.filter.gen.any(table.unpack(resolved)))
  end

  for _, filter in ipairs(resolved) do
    buffers = hzsr.buf.filter.apply(buffers, filter)
  end

  return buffers
end

--- @param src_bufnr? integer Buffer origen. Si es `nil`, se utiliza el buffer actual.
--- @param dst_bufnr integer Buffer destino.
function M.copy_to_other(src_bufnr, dst_bufnr)
  local target = M.resolve(src_bufnr)

  if target == dst_bufnr then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(target, 0, -1, false)
  vim.api.nvim_buf_set_lines(dst_bufnr, 0, -1, false, lines)
  vim.bo[dst_bufnr].modified = true
end

-- Reemplaza `src_buf` por `dst_buf` en todas las ventanas donde `src_buf` esté visible.
--
-- No modifica buffers; solo cambia qué buffer muestra cada ventana afectada.
--
--- @param src_bufnr? integer Buffer origen.
--- @param dst_bufnr integer Buffer destino.
function M.replace_containing_windows(src_bufnr, dst_bufnr)
  local target = M.resolve(src_bufnr)

  if target == dst_bufnr then
    return
  end

  for _, win in ipairs(vim.fn.win_findbuf(target)) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_set_buf(win, dst_bufnr)
    end
  end
end

--- @param src_bufnr? integer Buffer origen. Si es `nil`, se utiliza el buffer actual.
--- @param dst_bufnr integer Buffer destino ya existente.
--- @param opts? hzsr.buf.merge_into_existing.opts
function M.merge_into_existing(src_bufnr, dst_bufnr, opts)
  local target = M.resolve(src_bufnr)
  opts = opts or {}

  if target == dst_bufnr then
    return
  end

  M.copy_to_other(target, dst_bufnr)

  local replace_windows = opts.replace_windows
  if replace_windows == nil then
    replace_windows = true
  end

  if replace_windows then
    M.replace_containing_windows(target, dst_bufnr)
  end

  if vim.api.nvim_buf_is_valid(target) then
    vim.cmd("bwipeout! " .. target)
  end
end

-- Renombra el buffer para que pase a representar `path`.
-- No escribe el archivo en disco; solo cambia el nombre del buffer.
--
-- Reglas:
--   - `path` se normaliza a path absoluto con `hzsr.sys.path.resolve`.
--   - No resuelve symlinks.
--   - Si el buffer ya representa ese path, no hace nada y devuelve `true`.
--
--- @param bufnr integer
--- @param path string
--- @return boolean ok
--- @return string? msg
function M.rename_to_path(bufnr, path)
  vim.validate("bufnr", bufnr, "number")
  vim.validate("path", path, "string")

  local target = M.resolve(bufnr)
  local resolved_path = hzsr.sys.path.resolve(path)

  local current_name = vim.api.nvim_buf_get_name(target)
  local current_path = current_name ~= "" and hzsr.sys.path.resolve(current_name) or ""

  if current_path == resolved_path then
    return true
  end

  local ok, err = pcall(vim.api.nvim_buf_set_name, target, resolved_path)
  if not ok then
    return false, tostring(err)
  end

  return true
end

---Comprueba si un buffer está visible en alguna ventana de la pestaña actual.
---
---@param bufnr integer
---@return boolean
function M.is_visible(bufnr)
  bufnr = M.resolve(bufnr)

  for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(winid) and vim.api.nvim_win_get_buf(winid) == bufnr then
      return true
    end
  end

  return false
end

---Busca un buffer de reemplazo para mostrar al cerrar el buffer actual.
---
---@param current integer
---@return integer?
function M.get_replacement(current)
  current = M.resolve(current)

  local fallback = nil

  for _, bufnr in ipairs(M.get_all "normal") do
    if bufnr ~= current then
      fallback = fallback or bufnr

      if not M.is_visible(bufnr) then
        return bufnr
      end
    end
  end

  return fallback
end

M.source = require "hzsr.buf.source"
M.filter = require "hzsr.buf.filter"
M.write = require "hzsr.buf.write"

return M
