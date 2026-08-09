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
  local regedit = require "reg-edit"
  regedit.setup(M.opts)

  local map = vim.keymap.set

  -- Permite modificar el registros, incluyendo las macros grabadas.
  map("n", "<leader>re", "<cmd>RegEdit<CR>", { desc = "Reg-edit: modificar registros" })

  -- sync_unnamed manual. Esta es una funcionalidad cuyo origen es un bug de la primera versión
  -- del plugin. El efecto producido es que restaura lo que había en el clipboard antes de
  -- sobreescribirlo utilizando por ejemplo `dd` (eliminar linea) y funciona incluso tras varias
  -- sobreescrituras de este tipo.
  map("n", "<leader>rr", function()
    regedit.sync_unnamed_from_yank()
  end, { desc = "Reg-edit: restaurar copia" })
end

return M
