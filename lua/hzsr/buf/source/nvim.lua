-- hzsr.buf.source.nvim

local M = {}

---@return integer[]
function M.adapter()
  return vim.api.nvim_list_bufs()
end

return M
