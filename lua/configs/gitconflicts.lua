local map = vim.keymap.set

local M = {}

M.opts = {
    default_mappings = false,
    disable_diagnostics = true,
}

function M.set_mappings()
    map(
        "n",
        "<leader>gco",
        "<Plug>(git-conflict-ours)",
        { desc = "Git conflict: ours", noremap = true, silent = true }
    )
    map(
        "n",
        "<leader>gct",
        "<Plug>(git-conflict-theirs)",
        { desc = "Git conflict: theirs", noremap = true, silent = true }
    )
    map(
        "n",
        "<leader>gcb",
        "<Plug>(git-conflict-both)",
        { desc = "Git conflict: both", noremap = true, silent = true }
    )
    map(
        "n",
        "<leader>gc0",
        "<Plug>(git-conflict-none)",
        { desc = "Git conflict: none", noremap = true, silent = true }
    )
    map(
        "n",
        "<leader>gcp",
        "<Plug>(git-conflict-prev-conflict)",
        { desc = "Prev conflict", noremap = true, silent = true }
    )
    map(
        "n",
        "<leader>gcn",
        "<Plug>(git-conflict-next-conflict)",
        { desc = "Next conflict", noremap = true, silent = true }
    )
end

function M.setup()
    local plugin = require "git-conflict"
    plugin.setup(opts)
    M.set_mappings()
end

return M
