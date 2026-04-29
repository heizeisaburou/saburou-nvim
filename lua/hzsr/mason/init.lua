-- hzsr.mason.init

local M = {}

local nvchad = require "hzsr.mason.nvchad"

M.get_pkgs = function()
  return nvchad.get_pkgs()
end

M.install_all = function()
  return nvchad.install_all()
end

return M
