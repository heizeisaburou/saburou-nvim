require "nvchad.mappings"
local Methods = require "methods"

-- --------------------------------------------------------------------------
-- START
-- --------------------------------------------------------------------------

local map = vim.keymap.set
local unmap = vim.keymap.del
local noremap_silent = { noremap = true, silent = true }

-- --------------------------------------------------------------------------
-- Reescribir | Eliminar mappings
-- --------------------------------------------------------------------------
unmap("n", "<leader>cm") -- git commits
map(
    "n",
    "<leader>gC",
    "<cmd>Telescope git_commits<CR>",
    { desc = "Git commits", noremap = true, silent = true }
)
unmap("n", "<leader>ch") -- cheatseet
map("n", "<leader>tc", "<cmd>NvCheatsheet<CR>", { desc = "Cheatsheet", noremap = true, silent = true })
unmap("n", "<leader>ds") -- vim.diagnostic.setloclist -- remapeado en lsp.config
unmap("n", "<leader>e") -- NvimTreeFocus
-- map("n", "<leader>???", "<cmd>NvimTreeFocus<CR>", { desc = "Focus Nvim Tree" }) -- No se que tecla ponerle pero tampoco me importa, estorba.

-- --------------------------------------------------------------------------
-- Recortes especiales
-- --------------------------------------------------------------------------
-- d — delete
-- D — delete (and copy)
-- e — enter
-- c — cut and enter

-- Descripciones de los comandos (alias)
local cuts_desc = {
    l = "Line",
    t = "Line (same indent)",
    w = "Word",
    e = "Up to Line End",
}

-- Opciones basadas en la categoría
local cuts_cat_opts = {
    d = { copy = false, insert = false },
    D = { insert = false },
    e = { copy = false },
    c = {},
}

-- Up to Line End → delete_to_line_end
for cat, cat_opts in pairs(cuts_cat_opts) do
    local keys = cat .. "e" -- p.e. de, De, ee, ce
    map("n", "<leader>" .. keys, function()
        Methods.delete_up_to_line_end(cat_opts)
    end, { noremap = true, silent = true, desc = cuts_desc.e })
end

-- Word
for cat, cat_opts in pairs(cuts_cat_opts) do
    local keys = cat .. "w" -- p.e. dw, Dw, ew, cw
    map("n", "<leader>" .. keys, function()
        Methods.delete_word(cat_opts)
    end, { noremap = true, silent = true, desc = cuts_desc.w })
end

-- End line

-- Line + Line (same_indent) → delete_line
-- Opciones específicas de los comandos l t
local cuts_dl_cmd_opts = {
    l = { copy_indent = false, keep_indent = false },
    t = { copy_indent = false },
}
for cat, cat_opts in pairs(cuts_cat_opts) do
    for cmd, cmd_opts in pairs(cuts_dl_cmd_opts) do
        local keys = cat .. cmd -- p.e. dt, el
        local opts = vim.tbl_extend("force", {}, cat_opts, cmd_opts)
        map("n", "<leader>" .. keys, function()
            Methods.delete_line(opts)
        end, { noremap = true, silent = true, desc = cuts_desc[cmd] })
    end
end

-- --------------------------------------------------------------------------
-- Ajustar teclas que modifican el clipboard
-- --------------------------------------------------------------------------
map({ "n", "x" }, "x", '"_x', noremap_silent)
map({ "n", "x" }, "X", "x", noremap_silent)

map("n", "X", '"_X', noremap_silent)
map("n", "D", "d", noremap_silent)
map("n", "d", '"_d', noremap_silent)
map("n", "s", '"_s', noremap_silent)
map("n", "S", '"_S', noremap_silent)
map("n", "C", '"_C', noremap_silent)

-- [Dinámicos para soportar luasnip]
local luasnip = require "luasnip"
local function map_visual_key(inside_snip, outside_snip)
    return function()
        if luasnip.in_snippet() then
            vim.api.nvim_feedkeys(inside_snip, "n", false)
        else
            vim.api.nvim_feedkeys(outside_snip, "n", false)
        end
    end
end
-- Mapeos
map("x", "p", map_visual_key("p", "P"), noremap_silent)
map("x", "P", map_visual_key("P", "p"), noremap_silent)
map("x", "d", map_visual_key("d", '"_d'), noremap_silent)
map("x", "D", map_visual_key("D", "d"), noremap_silent)
map("x", "s", map_visual_key("s", '"_s'), noremap_silent)
map("x", "S", map_visual_key("s", "s"), noremap_silent)

-- --------------------------------------------------------------------------
-- Terminal
-- --------------------------------------------------------------------------
-- Salir del modo terminal y volver a modo normal con Ctrl+Q
vim.api.nvim_set_keymap("t", "<C-q>", "<C-\\><C-n>", noremap_silent)

-- --------------------------------------------------------------------------
-- Normal
-- --------------------------------------------------------------------------
map("n", ";", ":", { desc = "CMD enter command mode" })

-- Agregar líneas en modo normal la tecla ñÑ
map("n", "ñ", ':call append(line("."), "")<CR>==', noremap_silent)
map("n", "Ñ", ':call append(line(".") - 1, "")<CR>==', noremap_silent)

-- --------------------------------------------------------------------------
-- Insert
-- --------------------------------------------------------------------------
-- Borrar con ctrl + x/s
map("i", "<C-x>", "<Del>", noremap_silent)
map("i", "<C-s>", "<BS>", noremap_silent)
-- Ponen una tabulación de verdad
map("i", "<S-Tab>", function()
    vim.notify("[!] Putting real \\t ...", vim.log.levels.INFO)
    vim.api.nvim_put({ "\t" }, "c", false, true)
end, noremap_silent)

-- --------------------------------------------------------------------------
-- Complex (mejor categorizar independientemente de lo que sean)
-- --------------------------------------------------------------------------
-- Mover entre palabras más natural (ver abajo Plugins -> Camelcase motion)
map({ "n", "x" }, "W", "W", noremap_silent)
map({ "n", "x" }, "w", "e", noremap_silent)
map({ "n", "x" }, "B", "gE", noremap_silent)

-- Alternativas a Home
map("n", "<leader>sa", "<Home>", { desc = "[Home]" })
map("i", "<C-a>", "<Home>", { desc = "[Home]" })
map("n", "<leader>sm", function()
    require("menu").open "default"
end, { desc = "NVChad's menu" })

-- --------------------------------------------------------------------------
-- Pestañas (cuándo no hay plugin)
-- --------------------------------------------------------------------------
-- romgrk/barbar.nvim
-- Re-order a través de Tabufline si Barbar no está activo
map("n", "<A-,>", function()
    require("nvchad.tabufline").move_buf(-1)
end, noremap_silent)

map("n", "<A-.>", function()
    require("nvchad.tabufline").move_buf(1)
end, noremap_silent)

-- Goto buffer in position ...
for i = 1, 9, 1 do
    map("n", string.format("<A-%s>", i), function()
        ---@type integer?
        local bufnr = vim.tbl_get(vim.t.bufs, i)
        if bufnr then
            vim.api.nvim_set_current_buf(bufnr)
        end
    end)
end

-- --------------------------------------------------------------------------
-- Plugins
-- --------------------------------------------------------------------------
-- bkad/camelcasemotion
-- usar con e E
map({ "n", "x" }, "e", "<Plug>CamelCaseMotion_w", noremap_silent)
map({ "n", "x" }, "E", "<Plug>CamelCaseMotion_b", noremap_silent)

-- DAP
map("n", "<leader>ad", '<cmd>lua require("dap").run_last()<CR>', noremap_silent)
map("n", "<leader>ab", "<cmd> DapToggleBreakpoint <CR>", noremap_silent)
map("n", "<leader>ar", "<cmd> DapContinue <CR>", noremap_silent)

map("n", "<RightMouse>", function()
    vim.cmd.exec '"normal! \\<RightMouse>"'
    local options = vim.bo.ft == "NvimTree" and "nvimtree" or "default"
    require("menu").open(options, { mouse = true })
end, {})
-- --------------------------------------------------------------------------
-- LSP
-- --------------------------------------------------------------------------
-- LspInfo
map("n", "<leader>li", function()
    vim.cmd "LspInfo"
end, { desc = "show LSP info" })

-- LspRestart
map("n", "<leader>lr", function()
    vim.notify("  Restarting LSP ...", vim.log.levels.INFO)
    vim.cmd "LspRestart"
end, { desc = "restart LSP" })

map("n", "<A-f>", function()
    require("conform").format { lsp_fallback = true }
end, { desc = "restart LSP" })

-- Diagnostics → loclist
map("n", "<leader>lL", function()
    vim.diagnostic.setloclist()
end, { desc = "diagnostics loclist" })
