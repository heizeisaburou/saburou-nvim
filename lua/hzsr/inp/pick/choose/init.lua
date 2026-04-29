-- hzsr.inp.pick.choose

local M = {}

M.detail = require "hzsr.inp.pick.choose.detail"
M.sync = require("hzsr.inp.pick.choose.sync").choose
M.async = require("hzsr.inp.pick.choose.async").choose
M.adapter = require("hzsr.inp.pick.choose.adapter").choose
M.snacks = require "hzsr.inp.pick.choose.snacks"

return M
