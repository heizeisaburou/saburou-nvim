-- hzsr.buf.source.adapter

local M = {}

--Devuelve una lista de buffers en el mejor orden disponible.
--Combina varias fuentes con esta prioridad: tabs, MRU y, por último,
--el orden base de Neovim. Los duplicados se eliminan preservando la
--primera aparición.
---@return integer[]
function M.adapter()
  local combined = {}

  -- orden basado en tabs > mru > nvim
  vim.list_extend(combined, hzsr.buf.source.btabs.adapter())
  vim.list_extend(combined, hzsr.buf.source.mru.adapter())
  vim.list_extend(combined, hzsr.buf.source.nvim.adapter())

  return vim.iter(combined):unique():totable()
end

return M
