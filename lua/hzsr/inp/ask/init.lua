-- hzsr.inp.ask

local M = {}

M.sync = require("hzsr.inp.ask.sync").ask
M.async = require("hzsr.inp.ask.async").ask
M.snacks = require "hzsr.inp.ask.snacks"
M.adapter = require("hzsr.inp.ask.adapter").ask

return M
