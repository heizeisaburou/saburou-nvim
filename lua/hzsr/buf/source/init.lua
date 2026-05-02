-- hzsr.buf.source

local M = {}

M.nvim = require "hzsr.buf.source.nvim"
M.mru = require "hzsr.buf.source.mru"
M.btabs = require "hzsr.buf.source.btabs"
M.adapter = require("hzsr.buf.source.adapter").adapter

return M
