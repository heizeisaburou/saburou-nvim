return {
    -- --------------------------------------------------------------------------
    -- Plenary
    -- --------------------------------------------------------------------------
    {
        -- Libería estándar para Lua dentro de nvim. Aporta utilidades que muchos plugins necesitan
        -- plenary.path → manejo de rutas tipo Path:new("file.txt"):exists()
        -- plenary.job → ejecutar procesos async sin dolor
        -- plenary.async/await → corrutinas fáciles
        -- plenary.scandir → listar archivos/carpetas
        -- plenary.reload → recargar módulos Lua sin reiniciar Neovim
        -- plenary.window → helpers para ventanas flotantes
        -- plenary.test_harness → framework de tests
        -- .. etc
        "nvim-lua/plenary.nvim",
        lazy = false,
    },
    -- --------------------------------------------------------------------------
    -- LSP
    -- --------------------------------------------------------------------------
    {
        -- Una manera de ver las sobrecargas de funciones (los keybinds están definidos en lsp.overloads)
        "Issafalcon/lsp-overloads.nvim",
        lazy = false,
        dependencies = { "nvim-lspconfig" },
        config = function()
            require("lsp-overloads").setup()
        end,
    },
    {
        -- Cambiar rutas de archivos en imports, etc. al renombrar archivos mediate lsp
        "antosha417/nvim-lsp-file-operations",
        dependencies = {
            "nvim-lspconfig",
            "nvim-lua/plenary.nvim",
            "nvim-tree/nvim-tree.lua", -- o el que uses (puedes comentar este si usas otro)
            -- "nvim-neo-tree/neo-tree.nvim",
            -- "simonmclean/triptych.nvim"
        },
        config = function()
            require("configs.lsp.file-operations").config()
        end,
    },
    {
        -- Instalador de servidores LSP
        "williamboman/mason-lspconfig.nvim",
        event = "VeryLazy",
        dependencies = { "nvim-lspconfig" },
        config = function()
            require "configs.lsp.mason"
        end,
    },
    {
        -- Muestra los errores cómodamente separados por líneas
        -- (por defecto desactivado, togglear con <leader>lt)
        "maan2003/lsp_lines.nvim",
        dependencies = { "nvim-lspconfig" },
        lazy = false,
        config = function()
            require "configs.lsp.lines"
        end,
    },
    {
        -- CORE
        "neovim/nvim-lspconfig",
        event = { "BufReadPre", "BufNewFile" },
        config = function()
            require("configs.lsp.config").setup()
            -- vim.diagnostic.config { update_in_insert = true } -- actualizar durante inserción
        end,
    },
    -- --------------------------------------------------------------------------
    -- Conform
    -- --------------------------------------------------------------------------
    {
        -- Formateo
        "stevearc/conform.nvim",
        -- event = 'BufWritePre', -- uncomment for format on save
        opts = require "configs.conform",
    },
    -- --------------------------------------------------------------------------
    -- Treesitter
    -- --------------------------------------------------------------------------
    {
        -- Treesitter (configuración por defecto + servidores para que muestre bien los colores ahí donde no lo hace el LSP)
        "nvim-treesitter/nvim-treesitter",
        event = { "BufReadPre", "BufNewFile" },
        opts = require "configs.treesitter",
    },
    -- --------------------------------------------------------------------------
    -- Navegadores
    -- --------------------------------------------------------------------------
    {
        -- File Explorer (explorador de archivos)
        "nvim-tree/nvim-tree.lua",
        cmd = { "NvimTreeToggle", "NvimTreeFocus" },
        config = function()
            require("configs.nvimtree").setup()
        end,
    },
    {
        -- Aerial Nvim (árbol de símbolos)
        "stevearc/aerial.nvim",
        lazy = false,
        config = function()
            require "configs.aerial"
        end,
        -- opts = require "configs.aerial",
        -- Optional dependencies
        dependencies = {
            "nvim-treesitter/nvim-treesitter",
            "nvim-tree/nvim-web-devicons",
        },
    },
    -- --------------------------------------------------------------------------
    -- GIT
    -- --------------------------------------------------------------------------
    -- {
    --   -- Github Copilot (autocompletado con IA) [Falta $ T_T]
    --   "github/copilot.vim",
    --   lazy = false,
    --   config = function()
    --     -- Cargar cualquier configuración extra de Copilot
    --     require "configs.copilot" -- aquí se llama a tu copilot.lua
    --   end,
    -- },
    {
        "akinsho/git-conflict.nvim",
        event = "BufReadPre",
        config = function()
            require("configs.gitconflicts").setup()
        end,
    },
    {
        -- Viene por defecto solo lo importamos para recordar personalizarlo
        -- en un futuo.
        "lewis6991/gitsigns.nvim",
    },
    -- ------------------------------------------------------
    -- Depuración: Plugins para el debugging.
    -- ------------------------------------------------------
    -- Plugin para depuración - UI (hace tiempo que no lo usamos)
    {
        "rcarriga/nvim-dap-ui",
        dependencies = "mfussenegger/nvim-dap",
        event = "VeryLazy",
        config = function()
            local dap = require "dap"
            local dapui = require "dapui"
            dapui.setup()
            dap.listeners.after.event_initialized["dapui_config"] = function()
                dapui.open()
            end
            dap.listeners.before.event_terminated["dapui_config"] = function()
                dapui.close()
            end
            dap.listeners.before.event_exited["dapui_config"] = function()
                dapui.close()
            end
        end,
    },
    -- Plugin para depuración - Instalador de adaptadores de depuración
    {
        "jay-babu/mason-nvim-dap.nvim",
        event = "VeryLazy",
        dependencies = {
            "williamboman/mason.nvim",
            "mfussenegger/nvim-dap",
            "nvim-neotest/nvim-nio",
        },
        opts = {
            handlers = {},
            -- ensure_installed = {
            --
            -- }
        },
    },
    -- --------------------------------------------------------------------------------
    -- Overwrites de config
    -- --------------------------------------------------------------------------------
    {
        -- Oficial pero sobre-escribimos algunos de sus keybinds
        "hrsh7th/nvim-cmp",
        opts = require "configs.nvimcmp",
    },
    {
        "ziontee113/color-picker.nvim",
        lazy = false,
        config = function()
            require "configs.colorpicker"
        end,
    },
    {
        "folke/which-key.nvim",
        -- Lo obligamos a cargar rápidamente (para poder ver las combinaciones de teclas)
        event = "VeryLazy",
        keys = nil,
    },
    -- --------------------------------------------------------------------------
    -- Pestañas
    -- --------------------------------------------------------------------------
    -- -- TODO: en un futuro plantear la posibilidad de no utilizarlo ya que el
    -- -- sistema de pestañas original es mucho mejor (si ignoramos la dificultad
    -- -- para realizar ciertas acciones sobre las pestañas)
    -- {
    --     "romgrk/barbar.nvim",
    --     dependencies = {
    --         "lewis6991/gitsigns.nvim", -- OPTIONAL: for git status
    --         "nvim-tree/nvim-web-devicons", -- OPTIONAL: for file icons
    --     },
    --     init = function()
    --         vim.g.barbar_auto_setup = false
    --     end,
    --     opts = {},
    --     -- Esta opción es importante, la versión 2.0.0 debe llegar pronto pero quitar
    --     -- este parámetro ha provocado errores difíciles de encontrar en la 1.9.1
    --     version = "^v1.0.0", -- optional: only update when a new 1.x version is released
    --     lazy = false,
    --     config = function()
    --         require("configs.barbar").setup()
    --     end,
    -- },
    -- --------------------------------------------------------------------------
    -- Sin Categorizar
    -- --------------------------------------------------------------------------
    {
        -- Plugin para mover el cursor entre palabras en camelCase o snake_case
        "bkad/camelcasemotion",
        lazy = false,
    },
    {
        -- Plugin para resaltado (todo, etc))
        "folke/todo-comments.nvim",
        lazy = false,
        opts = require "configs.todocomments",
    },
    {
        "luukvbaal/statuscol.nvim",
        -- enabled = true,
        lazy = false,
        -- event = "BufReadPost",
        config = function()
            require("configs.statuscol").setup()
        end,
    },
    -- --------------------------------------------------------------------------------
    -- Plugins a desactivar
    -- --------------------------------------------------------------------------------
    {
        -- Desactivamos nvim-autopairs (cerrar llaves automáticamente)
        "windwp/nvim-autopairs",
        enabled = false,
    },
}
