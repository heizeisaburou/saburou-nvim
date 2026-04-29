-- lzy.l_dap-ui

local M = {}

-- PENDIENTE

function M.setup()
  local dap = require "dap"
  local dapui = require "dapui"

  dapui.setup()

  dap.listeners.after.event_initialized["dapui_config"] = function()
    dapui.open()
  end
  dap.listeners.before.event_terminated["dapui_config"] = function()
    dapui.close()
  end
  dap.listeners.before.event_exited["dapui_config"] = function()
    dapui.close()
  end

  local map = vim.keymap.set
  local noremap_silent = { noremap = true, silent = true }
  local function opts(desc)
    return vim.tbl_extend("force", noremap_silent, { desc = desc })
  end

  map("n", "<leader>ad", function()
    dap.run_last()
  end, opts "Dap: Run last")
  map("n", "<leader>ab", "<cmd> DapToggleBreakpoint <CR>", opts "Dap: Run other")
  map("n", "<leader>ar", "<cmd> DapContinue <CR>", opts "Dap: Continue")
end

return M
