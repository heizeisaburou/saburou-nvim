-- hzsr.edt.io.close

local M = {}

M.detail = require "hzsr.edt.io.close.detail"

M.close = require("hzsr.edt.io.close.close").close
M.close_multi = require("hzsr.edt.io.close.close_multi").close_multi
M.close_all = require("hzsr.edt.io.close.close_all").close_all

return M
