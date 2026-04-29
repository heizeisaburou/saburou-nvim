-- lzy.l_git-blame

-- Pendiente: Configurar en condiciones
-- Nota: Se togglea con <leader>gb

local M = {}

M.opts = {
  enabled = false, -- if you want to enable the plugin
  message_template = " <summary> • <date> • <author> • <<sha>>", -- template for the blame message, check the Message template section for more options
  date_format = "%m-%d-%Y %H:%M:%S", -- template for the date, check Date format section for more options
  virtual_text_column = 1, -- virtual text start column, check Start virtual text at column section for more options
}

function M.setup()
  require("gitblame").setup(M.opts)

  local map = vim.keymap.set

  map("n", "<leader>gb", function()
    vim.cmd "GitBlameToggle"
  end, { desc = "git-blame: toggle" })
end

return M
