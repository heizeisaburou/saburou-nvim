local default_opts = require "nvchad.configs.cmp"

---@diagnostic disable-next-line: different-requires
local cmp = require "cmp"
local luasnip = require "luasnip"
local leave_key = "<C-q>"

local custom_opts = {
    -- No preseleccionamos automáticamente
    preselect = cmp.PreselectMode.None,
    completion = { completeopt = "menu,menuone,noselect" },
    mapping = {
        [leave_key] = function()
            -- Si CMP está abierto, cerrarlo
            if cmp.visible() then
                cmp.close()
            else
                -- Default leave_key behavior
                vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(leave_key, true, true, true), "n", true)
            end
        end,
        ["<C-p>"] = cmp.mapping.select_prev_item(),
        ["<C-n>"] = cmp.mapping.select_next_item(),
        ["<C-Space>"] = cmp.mapping.complete(),
        -- No reemplazar el comportamiento por defecto de <C-d> (opuesto: <C-t>)
        ["<C-d>"] = function()
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<C-d>", true, true, true), "n", true)
        end,
        -- No reemplazar el comportamiento por defecto de <C-e> (opuesto: <>)
        ["<C-e>"] = function()
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<End>", true, true, true), "n", true)
        end,
        -- Cambiamos teclas de scroll de d/f a f/g
        ["<C-f>"] = cmp.mapping.scroll_docs(-4),
        ["<C-g>"] = cmp.mapping.scroll_docs(4),
        -- Ajuste: No entramos a la selección con Enter
        ["<CR>"] = cmp.mapping.confirm {
            behavior = cmp.ConfirmBehavior.Insert,
            select = false,
        },
        -- Fix de <Tab> para que no seleccione sugerencias dentro de los snippets
        ["<Tab>"] = cmp.mapping(function(fallback)
            if luasnip.in_snippet() then
                luasnip.jump(1)
            else
                -- (Permitir TAB (siempre puedes cancelar con CTRL+Q)
                if cmp.visible() then
                    cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then
                    luasnip.expand_or_jump()
                else
                    fallback()
                end
                -- fallback()
            end
        end, { "i", "s" }),
        -- same fix (but for shift+Tab)
        ["<S-Tab>"] = cmp.mapping(function(fallback)
            if luasnip.in_snippet() then
                luasnip.jump(-1)
            else
                -- (Permitir TAB (siempre puedes cancelar con CTRL+Q)
                if cmp.visible() then
                    cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                    luasnip.jump(-1)
                else
                    fallback()
                end
                -- fallback()
            end
        end, { "i", "s" }),
    },
}

return vim.tbl_deep_extend("force", default_opts, custom_opts)
