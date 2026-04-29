-- hzsr.buf.filter

-- Predicados y generadores de predicados para filtrar buffers.
--
-- Este módulo no obtiene buffers ni decide su orden; solo ofrece utilidades para quedarnos
-- con los que cumplen ciertas condiciones.
--
-- Hay dos grupos de funciones:
--
-- - Predicados directos:
--   Reciben un buffer y devuelven `true` o `false`.
--   - `valid(buf)`   -- Neovim conoce el buffer.
--   - `loaded(buf)`  -- El buffer está cargado en memoria.
--   - `listed(buf)`  -- El buffer está cargado y listado.
--   - `normal(buf)`  -- El buffer es normal de edición.
--   - `modified(buf)`
--   - `visible(buf)`
--
-- - Generadores de predicados (`gen`):
--   Devuelven un nuevo filtro. Por eso pueden requerir parámetros adicionales para
--   configurarlo antes de usarlo.
--   - `gen.all(...)`
--   - `gen.any(...)`
--   - `gen.not_(pred)`
--   - `gen.visible_in(wins)`
local M = {}
M.gen = {}

-- Aplica un predicado a una lista de buffers.
---@param buffers integer[]
---@param pred fun(buf: integer): boolean
---@return integer[]
function M.apply(buffers, pred)
  return vim.iter(buffers):filter(pred):totable()
end

-- Comprueba si Neovim conoce este buffer.
--
-- Un buffer válido no tiene por qué estar cargado ni listado.
---@param buf integer
---@return boolean
function M.valid(buf)
  return vim.api.nvim_buf_is_valid(buf)
end

-- Comprueba si el buffer está cargado en memoria.
--
-- `nvim_buf_is_loaded()` devuelve `false` si el buffer no es válido.
---@param buf integer
---@return boolean
function M.loaded(buf)
  return vim.api.nvim_buf_is_loaded(buf)
end

-- Comprueba si el buffer está cargado y listado.
--
-- Usamos `loaded()` antes de leer opciones del buffer para evitar acceder a
-- `vim.bo[buf]` sobre buffers descargados o inválidos.
---@param buf integer
---@return boolean
function M.listed(buf)
  return M.loaded(buf) and vim.bo[buf].buflisted
end

-- Comprueba si un buffer es normal de edición.
--
-- Normal aquí significa:
--   - cargado
--   - listado
--   - `buftype == ""`
---@param buf integer
---@return boolean
function M.normal(buf)
  return M.listed(buf) and vim.bo[buf].buftype == ""
end

-- Comprueba si un buffer está modificado.
---@param buf integer
---@return boolean
function M.modified(buf)
  return M.loaded(buf) and vim.bo[buf].modified
end

-- Comprueba si un buffer está visible en alguna ventana de la pestaña actual.
---@param buf integer
---@return boolean
function M.visible(buf)
  if not M.valid(buf) then
    return false
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
      return true
    end
  end

  return false
end

-- Combina varios predicados con lógica AND.
--
-- Devuelve un nuevo predicado que solo pasa si todos los predicados dados devuelven `true`.
---@param ... fun(buf: integer): boolean
---@return fun(buf: integer): boolean
function M.gen.all(...)
  local preds = { ... }

  return function(buf)
    for _, pred in ipairs(preds) do
      if not pred(buf) then
        return false
      end
    end

    return true
  end
end

-- Combina varios predicados con lógica OR.
--
-- Devuelve un nuevo predicado que pasa si al menos uno de los predicados dados
-- devuelve `true`.
---@param ... fun(buf: integer): boolean
---@return fun(buf: integer): boolean
function M.gen.any(...)
  local preds = { ... }

  return function(buf)
    for _, pred in ipairs(preds) do
      if pred(buf) then
        return true
      end
    end

    return false
  end
end

-- Niega un predicado.
--
-- Devuelve un nuevo predicado que invierte el resultado del original.
---@param pred fun(buf: integer): boolean
---@return fun(buf: integer): boolean
function M.gen.not_(pred)
  return function(buf)
    return not pred(buf)
  end
end

-- Crea un predicado que comprueba si un buffer está visible en unas ventanas dadas.
---@param wins integer[]
---@return fun(buf: integer): boolean
function M.gen.visible_in(wins)
  return function(buf)
    if not M.valid(buf) then
      return false
    end

    for _, win in ipairs(wins) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
        return true
      end
    end

    return false
  end
end

return M
