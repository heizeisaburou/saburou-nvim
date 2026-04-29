local M = {}

M.opts = {}

function M.setup()
  ---@diagnostic disable-next-line
  require("mason").setup(M.opts)
end

return M
