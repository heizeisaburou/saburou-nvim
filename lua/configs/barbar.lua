local map = vim.keymap.set
local noremap_silent = { noremap = true, silent = true }

local M = {}

M.opts = {}

function M.set_mappings()
    -- Re-order to previous/next con Barbar
    map("n", "<A-,>", "<Cmd>BufferMovePrevious<CR>", noremap_silent)
    map("n", "<A-.>", "<Cmd>BufferMoveNext<CR>", noremap_silent)

    -- Move to previous/next
    map("n", "<S-Tab>", "<Cmd>BufferPrevious<CR>", noremap_silent)
    map("n", "<Tab>", "<Cmd>BufferNext<CR>", noremap_silent)

    -- Goto buffer in position...
    map("n", "<A-1>", "<Cmd>BufferGoto1<CR>", noremap_silent)
    map("n", "<A-2>", "<Cmd>BufferGoto2<CR>", noremap_silent)
    map("n", "<A-3>", "<Cmd>BufferGoto3<CR>", noremap_silent)
    map("n", "<A-4>", "<Cmd>BufferGoto4<CR>", noremap_silent)
    map("n", "<A-5>", "<Cmd>BufferGoto5<CR>", noremap_silent)
    map("n", "<A-6>", "<Cmd>BufferGoto6<CR>", noremap_silent)
    map("n", "<A-7>", "<Cmd>BufferGoto7<CR>", noremap_silent)
    map("n", "<A-8>", "<Cmd>BufferGoto8<CR>", noremap_silent)
    map("n", "<A-9>", "<Cmd>BufferGoto9<CR>", noremap_silent)
    map("n", "<A-10>", "<Cmd>BufferGoto10<CR>", noremap_silent)

    -- Pin/unpin buffer
    map("n", "<A-p>", "<Cmd>BufferPin<CR>", noremap_silent)

    -- Goto previous buffer
    map("n", "<A-Tab>", function()
        vim.notify("Going to previous buffer", vim.log.levels.INFO)
        local prev_buf = vim.fn.bufnr "#"
        if prev_buf == -1 or (not vim.api.nvim_buf_is_loaded(prev_buf)) then
            vim.notify("No previous buffer", vim.log.levels.INFO)
            return
        end
        require("nvchad.tabufline").goto_buf(prev_buf)
    end, noremap_silent)
end

function M.setup()
    local barbar = require "barbar"
    barbar.setup(M.opts)
    M.set_mappings()
end

return M
