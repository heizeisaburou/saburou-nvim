-- hzsr.buf.source.mru

local M = {}

---@return integer[]
function M.mru_nav()
  return require("mru_nav").get_buffer_history()
end

---@return integer[]
function M.adapter()
  local nvim_buffers = hzsr.buf.source.nvim.adapter()

  local ok, mru_nav = pcall(require, "mru_nav")
  if not ok or not mru_nav then
    return nvim_buffers
  end

  local buffers = M.mru_nav()

  vim.list_extend(buffers, nvim_buffers)

  return vim.iter(buffers):unique():totable()
end

return M
