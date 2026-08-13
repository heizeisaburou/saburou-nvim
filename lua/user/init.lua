-- sabunv.config

local M = {}

function M.setup()
  sabunv.terminal.setup(require "user.terminal")
  require "user.opts"
  require "user.cfg"
end

return M
