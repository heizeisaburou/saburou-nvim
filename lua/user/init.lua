-- sabunv.config

local M = {}

function M.setup()
  sabunv.terminal.setup(require "user.terminal")
  require "user.opts"
  sabunv.wrap.setup(require "user.wrap")
  require "user.cfg"
end

return M
