local M = {}

-- local actions = require "diffview.actions"

M.opts = {
  view = {
    merge_tool = {
      layout = "diff3_mixed",
      disable_diagnostics = true,
      winbar_info = true,
    },
  },
  -- keymaps = {
  --   view = {
  --     { "n", "<leader>gco", actions.conflict_choose "ours", { desc = "Git conflicts: Ours" } },
  --     { "n", "<leader>gct", actions.conflict_choose "theirs", { desc = "Git conflicts: Theirs" } },
  --     { "n", "<leader>gcb", actions.conflict_choose "all", { desc = "Git conflicts: Both" } },
  --     { "n", "<leader>gc0", actions.conflict_choose "none", { desc = "Git conflicts: None" } },
  --     { "n", "<leader>gcp", actions.prev_conflict, { desc = "Git conflicts: Prev conflict" } },
  --     { "n", "<leader>gcn", actions.next_conflict, { desc = "Git conflicts: Next conflict" } },
  --   },
  -- },
}

function M.toggle()
  if require("diffview.lib").get_current_view() then
    vim.cmd.DiffviewClose()
  else
    vim.cmd.DiffviewOpen()
  end
end

function M.setup()
  require("diffview").setup(M.opts)
  vim.keymap.set("n", "<leader>gc", M.toggle, {
    noremap = true,
    silent = true,
    desc = "Git conflicts: Toggle Diffview",
  })
end

return M
