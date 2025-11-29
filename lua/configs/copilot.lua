local map = vim.keymap.set
local noremap_silent = { noremap = true, silent = true }

-- Colorear las sugerencias de Copilot
vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*", -- se aplica a cualquier colorscheme
    callback = function()
        vim.api.nvim_set_hl(0, "CopilotSuggestion", {
            fg = "#f5c0d0", -- color de la sugerencia
            ctermfg = 8,
            force = true,
        })
    end,
})

-- Copilot
-- pedir sugerencia (mismo keybind pero esto lo arregla) <C-]> (cancelar sugerencia)
map("i", "<A-\\>", "<Plug>(copilot-suggest)", noremap_silent)
-- Aceptar linea entera ()
map("i", "<A-Up>", "<Plug>(copilot-accept-line)", noremap_silent)
-- Otros keybinds:  Basicamente son Alt + Arriba/Derecha y Alt + '[' o ']'.
