-- hzsr.edt.io.save

local M = {}

M.detail = require "hzsr.edt.io.save.detail"

M.save = require("hzsr.edt.io.save.save").save
M.save_multi = require("hzsr.edt.io.save.save_multi").save_multi
M.save_all = require("hzsr.edt.io.save.save_all").save_all

return M
