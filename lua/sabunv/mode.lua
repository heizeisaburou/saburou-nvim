-- sabunv.mode

local M = {}

function M.capture()
  return {
    mode = vim.api.nvim_get_mode().mode,
    win = vim.api.nvim_get_current_win(),
  }
end

function M.restore(context)
  if not context then
    return
  end

  vim.schedule(function()
    if not vim.api.nvim_win_is_valid(context.win) or vim.api.nvim_get_current_win() ~= context.win then
      return
    end

    local mode = context.mode:sub(1, 1)

    if mode == "i" or mode == "t" then
      vim.cmd "startinsert"
    elseif mode == "R" then
      vim.cmd "startreplace"
    else
      vim.cmd "stopinsert"
    end
  end)
end

return M
