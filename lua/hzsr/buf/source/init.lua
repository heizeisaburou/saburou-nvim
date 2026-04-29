-- hzsr.buf.source

local M = {}

M.nvim = require "hzsr.buf.source.nvim"
M.mru = require "hzsr.buf.source.mru"
M.tabs = require "hzsr.buf.source.tabs"
M.adapter = require("hzsr.buf.source.adapter").adapter

return M
