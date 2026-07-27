local M = {}
_G.sabunv = M

M.VERSION = "v0.1.0-alpha.4"
M.NVIM_VERSION = "0.12+"

M.ctx = require "sabunv.ctx"
M.edt = require "sabunv.edt"
M.indent = require "sabunv.indent"
M.moonfly = require "sabunv.moonfly"
M.nvim = require "sabunv.nvim"
M.util = require "sabunv.util"
M.terminal = require "sabunv.terminal"
M.restart = require "sabunv.restart"

return M
