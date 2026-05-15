-- lzy/l_regedit

local M = {}

M.opts = {
  command_name = "RegEdit",
  keys = {
    open = "<leader>re",
    clear = "<leader>c",
  },
}

function M.setup()
  local regedit = require "reg-edit"
  regedit.setup(M.opts)
end

return M
