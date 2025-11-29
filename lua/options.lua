require "nvchad.options"

-- Cargar comandos
require("cmds").setup()

-- Desactivar visualización de carácteres especiales al final de linea (p.e. $)
-- Ajuste que fue necesario en un debian
vim.opt.list = false

-- Cursor personalizado (arregla cursor fijo al salir de nvim en TMUX)
local enter_cursor = "n-v-c:block,"
    .. "i-ci-ve:ver25,"
    .. "r-cr:hor20,"
    .. "o:hor50,"
    .. "a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor,"
    .. "sm:block-blinkwait175-blinkoff150-blinkon175"

local leave_cursor = "a:ver25-blinkwait700-blinkoff400-blinkon250"

--  -> Cursor al entrar
vim.opt.guicursor = enter_cursor
vim.api.nvim_create_autocmd({ "VimEnter", "VimResume" }, {
    pattern = "*",
    command = "lua vim.opt.guicursor = '" .. enter_cursor .. "'",
})
-- -> Cursor al salir
vim.api.nvim_create_autocmd("VimLeave", {
    pattern = "*",
    command = "lua vim.opt.guicursor = '" .. leave_cursor .. "'",
})
