-- hzsr.inp.ask.snacks

local M = {}

M.async = require("hzsr.inp.ask.snacks.async").ask
M.sync = require("hzsr.inp.ask.snacks.sync").ask

return M
