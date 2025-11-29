local M = {}

function M.resizeTree()
    local percentage = 17
    local min_width = 25
    local ratio = percentage / 100
    local width = math.floor(vim.go.columns * ratio)
    if width < min_width then
        width = min_width
    end
    vim.cmd("tabdo NvimTreeResize " .. width)
end

M.setup = function()
    local api = require "nvim-tree.api"
    local opts = require "nvchad.configs.nvimtree" -- default ones

    opts.view = { relativenumber = true }
    opts.on_attach = function(bufnr)
        api.config.mappings.default_on_attach(bufnr)

        local lefty = function()
            local node = api.tree.get_node_under_cursor()
            if node and node.nodes and node.open then
                api.node.open.edit()
            else
                api.node.navigate.parent()
            end
        end

        local righty = function()
            local node = api.tree.get_node_under_cursor()
            if node and node.nodes and not node.open then
                api.node.open.edit()
            end
        end

        local mapping_opts = { buffer = bufnr }
        local map = vim.keymap.set
        map("n", "h", lefty, mapping_opts)
        map("n", "<Left>", lefty, mapping_opts)
        map("n", "l", righty, mapping_opts)
        map("n", "<Right>", righty, mapping_opts)
    end

    require("nvim-tree").setup(opts)

    vim.api.nvim_create_autocmd({ "VimResized" }, {
        desc = "Resize nvim-tree if nvim window got resized",
        group = vim.api.nvim_create_augroup("NvimTreeResize", { clear = true }),
        callback = M.resizeTree,
    })
    M.resizeTree() -- First Resize
end

return M
