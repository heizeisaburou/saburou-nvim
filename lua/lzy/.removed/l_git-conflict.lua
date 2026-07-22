local M = {}

M.opts = {
  default_mappings = false,
  disable_diagnostics = true,
}

function M.setup()
  require("git-conflict").setup(M.opts)

  local map = vim.keymap.set
  local noremap_silent = { noremap = true, silent = true }
  local function opts(desc)
    return vim.tbl_extend("force", noremap_silent, { desc = desc })
  end

  map("n", "<leader>gco", "<Plug>(git-conflict-ours)", opts "Git conflicts: Ours")
  map("n", "<leader>gct", "<Plug>(git-conflict-theirs)", opts "Git conflicts: Theirs")
  map("n", "<leader>gcb", "<Plug>(git-conflict-both)", opts "Git conflicts: Both")
  map("n", "<leader>gc0", "<Plug>(git-conflict-none)", opts "Git conflicts: None")
  map("n", "<leader>gcp", "<Plug>(git-conflict-prev-conflict)", opts "Git conflicts: Prev conflict")
  map("n", "<leader>gcn", "<Plug>(git-conflict-next-conflict)", opts "Git conflicts: Next conflict")
end

return M
