-- lzy/l_regedit

local M = {}

M.opts = {
  sync_unnamed = false, -- restaurar clipboard anterior al entrar y salir de la ventana
  command_name = "RegEdit",
  keys = {
    open = "<leader>re",
    clear = "<leader>c",
  },
}

function M.setup()
  -- Thank you lucas for creating this plugin
  
  local regedit = require "reg-edit"
  regedit.setup(M.opts)

  map = vim.keymap.set
  map("n", "<leader>re", "<cmd>RegEdit<CR>", { desc = "Reg-edit: modificar registros" })
  map("n", "<leader>rr", function() regedit.sync_unnamed_from_yank() end, { desc = "Reg-edit: modificar registros" })
end

return M
