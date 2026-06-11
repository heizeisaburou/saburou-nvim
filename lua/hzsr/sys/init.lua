-- hzsr.sys

local M = {}

-- Can't use `has('win32')` because the `nvim -ll` test runner doesn't support `vim.fn` yet.
-- [Note] Extracted from vim.fs
M.sysname = vim.uv.os_uname().sysname:lower()
M.iswin = not not (M.sysname:find "windows" or M.sysname:find "mingw")
M.os_sep = M.iswin and "\\" or "/"
M.env_path_sep = M.iswin and ";" or ":"

M.path = require "hzsr.sys.path"
M.fs = require "hzsr.sys.fs"

return M
