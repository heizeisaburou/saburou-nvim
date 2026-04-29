-- hzsr.edt

local M = {}

M.edit = require "hzsr.edt.edit"
M.reveal = require "hzsr.edt.reveal"
M.io = require "hzsr.edt.io"

function M.go_previous_buffer()
  local prev_buf = vim.fn.bufnr "#"
  if prev_buf == -1 or (not vim.api.nvim_buf_is_loaded(prev_buf)) then
    vim.notify("No previous buffer", vim.log.levels.INFO)
    return
  end
  vim.cmd.buffer(prev_buf)
end

return M
