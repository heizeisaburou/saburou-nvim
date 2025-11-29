-- Creamos una tabla para exportar nuestras funciones
local M = {}

-- Definimos la función de configuración que será llamada desde on_attach
function M.setup(client, bufnr)
    -- Solo ejecutar si el servidor LSP soporta signatureHelp
    if client.server_capabilities.signatureHelpProvider then
        -- Keybind para abrir el popup manualmente con Alt+s
        vim.api.nvim_buf_set_keymap(
            bufnr,
            "n",
            "<C-2>",
            ":LspOverloadsSignature<CR>",
            { noremap = true, silent = true }
        )

        -- Keybind en insert mode
        vim.api.nvim_buf_set_keymap(
            bufnr,
            "i",
            "<C-2>",
            "<cmd>LspOverloadsSignature<CR>",
            { noremap = true, silent = true }
        )

        -- Keybind toggle con Shift+H en modo normal
        vim.api.nvim_buf_set_keymap(
            bufnr,
            "n",
            "<A-h>",
            ":LspOverloadsToggle<CR>",
            { noremap = true, silent = true }
        )

        -- Cargar y configurar lsp-overloads
        require("lsp-overloads").setup(client, {
            ui = {
                border = "single",
                height = nil,
                width = nil,
                wrap = true,
                wrap_at = nil,
                max_width = nil,
                max_height = nil,
                close_events = { "CursorMoved", "BufHidden", "InsertLeave" },
                focusable = true,
                focus = false,
                offset_x = 0,
                offset_y = 0,
                floating_window_above_cur_line = false,
                silent = true,
                highlight = {
                    italic = true,
                    bold = true,
                    fg = "#ffffff",
                    -- agrega aquí cualquier otro highlight explícitamente
                },
            },
            keymaps = {
                previous_signature = "<C-j>",
                next_signature = "<C-k>",
                previous_parameter = "<C-h>",
                next_parameter = "<C-l>",
                close_signature = "<C-2>",
            },
            display_automatically = false,
        })
    end
end

-- Devolvemos la tabla para que pueda ser usada con require()
return M
