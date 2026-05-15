-- lzy/plg

return {
  -- ---------------------------------------------------------------------------
  -- Core
  -- ---------------------------------------------------------------------------
  -- --- [ plenary ] -----------------------------------------------------------
  -- Libería estándar para Lua dentro de nvim.
  {
    "nvim-lua/plenary.nvim",
  },
  -- --- [ snacks ] ------------------------------------------------------------
  {
    "folke/snacks.nvim",
    priority = 1000,
    lazy = false,
    config = function()
      require("lzy.l_snacks").setup()
    end,
  },
  -- --- [ mru-nav ] -----------------------------------------------------------
  {
    "mjacobs/mru-nav.nvim",
    cmd = { "MruFile", "MruBuffer", "MruClearFiles" },
    lazy = false,
    config = function()
      require("lzy.l_mru-nav").setup()
    end,
  },
  -- --- [ mason ] -------------------------------------------------------------
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    init = function()
      require("lzy.l_mason").init_setup()
    end,
    config = function()
      require("lzy.l_mason").setup()
    end,
  },
  -- --- [ telescope ] ---------------------------------------------------------
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    cmd = "Telescope",
    config = function()
      return require("lzy.l_telescope").setup(true)
    end,
  },
  -- ---------------------------------------------------------------------------
  -- Code
  -- ---------------------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPre", "BufNewFile" },
    branch = "main",
    opts = require("lzy.l_treesitter").opts,
    config = function()
      require("lzy.l_treesitter").setup()
    end,
  },
  --- [ lspconfig ] ------------------------------------------------------------
  {
    "neovim/nvim-lspconfig",
    -- event = "VeryLazy",
    lazy = false,
    config = function()
      require("lzy.l_lspconfig").setup()
    end,
  },
  -- --- [ conform ] -----------------------------------------------------------
  -- Plugin para formatear código, requiere instalar un montón de servidores que
  -- tienen parámetros distintos, así que puede ser algo tedioso de configurar
  -- cada servidor. Sin embargo, yo ofrezco una configuración para cada servidor.
  {
    "stevearc/conform.nvim",
    event = "VeryLazy",
    config = function()
      require("lzy.l_conform").setup()
    end,
  },
  -- --- [ lsp_lines ] ---------------------------------------------------------
  -- Muestra los errores cómodamente separados por líneas
  {
    "maan2003/lsp_lines.nvim",
    dependencies = { "nvim-lspconfig" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("lzy.l_lsp-lines").setup()
    end,
  },
  -- --- [ workspaces ] --------------------------------------------------------
  -- Sistema de workspaces
  {
    "natecraddock/workspaces.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    event = "VeryLazy",
    config = function()
      require("lzy.l_workspaces").setup()
    end,
  },
  {
    -- Plugin que resalta los matches TODO, NOTE, etc.
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    keys = require("lzy.l_todo-comments").keys,
    config = function()
      require("lzy.l_todo-comments").setup()
    end,
  },

  -- --- [ dap-ui ] ------------------------------------------------------------
  {
    -- Plugin para depuración - UI
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
    },
    event = "VeryLazy",
    config = function()
      require("lzy.l_dap-ui").setup()
    end,
  },
  -- --- [ mason-dap ] ---------------------------------------------------------
  -- Instalador de adaptadores de depuración
  {
    "jay-babu/mason-nvim-dap.nvim",
    event = "VeryLazy",
    dependencies = {
      "williamboman/mason.nvim",
      "mfussenegger/nvim-dap",
      "nvim-neotest/nvim-nio",
    },
    config = function()
      require("lzy.l_mason-dap").setup()
    end,
  },
  -- --- [ gitsings ] -----------------------------------------------------------
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = function()
      return require "lzy.l_gitsigns"
    end,
  },
  -- --- [ git-conflict ] ------------------------------------------------------
  {
    "akinsho/git-conflict.nvim",
    event = "BufReadPre",
    config = function()
      require("lzy.l_git-conflict").setup()
    end,
  },
  {
    "f-person/git-blame.nvim",
    -- load the plugin at startup
    event = "VeryLazy",
    -- Because of the keys part, you will be lazy loading this plugin.
    -- The plugin will only load once one of the keys is used.
    -- If you want to load the plugin at startup, add something like event = "VeryLazy",
    -- or lazy = false. One of both options will work.
    config = function()
      require("lzy.l_git-blame").setup()
    end,
  },
  {
    "MeanderingProgrammer/render-markdown.nvim",
    -- event = { "BufReadPre", "BufNewFile" },
    lazy = false,
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
    config = function()
      require("lzy.l_render-markdown").setup()
    end,
  },
  -- ---------------------------------------------------------------------------
  -- AI
  -- ---------------------------------------------------------------------------
  --- [ copilot ] --------------------------------------------------------------
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    keys = require("lzy.l_copilot").keys,
    config = function()
      require("lzy.l_copilot").setup()
    end,
  },
  --- [ codex ] ----------------------------------------------------------------
  {
    "kkrampis/codex.nvim",
    lazy = true,
    cmd = { "Codex", "CodexToggle" }, -- Optional: Load only on command execution
    keys = require("lzy.l_codex").keys,
    config = function()
      require("lzy.l_codex").setup()
    end,
  },
  --- [ claude ] ---------------------------------------------------------------
  {
    "greggh/claude-code.nvim",
    keys = require("lzy.l_claude").keys,
    dependencies = {
      "nvim-lua/plenary.nvim", -- Required for git operations
    },
    config = function()
      require("lzy.l_claude").setup()
    end,
  },
  -- ---------------------------------------------------------------------------
  -- UI
  -- ---------------------------------------------------------------------------
  -- --- [ volt ] --------------------------------------------------------------
  {
    "nvzone/volt",
    config = function()
      if sabunv and sabunv.moonfly and sabunv.moonfly.volt_highlights then
        sabunv.moonfly.apply()
      end
    end,
  },

  {
    "nvzone/menu",
    dependencies = { "nvzone/volt" },
  },
  { "nvzone/minty", cmd = { "Huefy", "Shades" } },
  -- --- [ camelcasemotion ] ---------------------------------------------------
  -- Plugin para mover el cursor entre palabras en camelCase o snake_case
  {
    "bkad/camelcasemotion",
    event = "VeryLazy",
    config = function()
      require("lzy.l_camelcasemotion").setup()
    end,
  },
  -- --- [ cmp ] ---------------------------------------------------------------
  -- Note: Algunos de los plugins se integran aquí por dependencia fuerte,
  -- integridad o simplicidad.
  {
    "hrsh7th/nvim-cmp",
    event = { "InsertEnter", "VeryLazy" },
    dependencies = {
      {
        -- --- └─ [ LuaSnip ] --------------------------------------------------
        "L3MON4D3/LuaSnip",
        dependencies = "rafamadriz/friendly-snippets",
        config = function()
          require("lzy.l_luasnip").setup()
        end,
      },

      -- --- └─ [ auotpairs ] --------------------------------------------------
      -- cerrar automáticamente llaves como p.ej. ()[]{}
      -- [TIP] Activalo si te gusta.
      -- {
      --   "windwp/nvim-autopairs",
      --   config = function()
      --     require("lzy.l_autopairs").setup()
      --   end,
      -- },

      -- --- └─ [ cmp.plugins ] ------------------------------------------------
      {
        "saadparwaiz1/cmp_luasnip",
        "hrsh7th/cmp-nvim-lua",
        "hrsh7th/cmp-nvim-lsp",
        "hrsh7th/cmp-buffer",
        "https://codeberg.org/FelipeLema/cmp-async-path.git",
      },
    },
    config = function()
      require("lzy.l_cmp").setup()
    end,
  },
  -- --- [ which-key ] ---------------------------------------------------------
  {
    -- TODO: poner nuestros grupos de teclas
    "folke/which-key.nvim",
    event = "VeryLazy",
    keys = { "<leader>", "<c-w>", '"', "'", "`", "c", "v", "g", "l" },
    cmd = "WhichKey",
    opts = {},
  },
  --- [ nvim-tree ] ------------------------------------------------------------
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    event = "VeryLazy",
    config = function()
      require("lzy.l_nvim-tree").setup()
    end,
  },
  {
    -- Aerial Nvim (árbol de símbolos)
    "stevearc/aerial.nvim",
    event = "VeryLazy",
    config = function()
      require("lzy.l_aerial").setup()
    end,
    -- Optional dependencies
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons",
    },
  },
  -- --- [ lualine ] -----------------------------------------------------------
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    lazy = false,
    config = function()
      sabunv.moonfly.setup.lualine()
      require("lzy.l_lualine").setup()
    end,
  },
  -- --- [ statuscol ] ---------------------------------------------------------
  {
    "luukvbaal/statuscol.nvim",
    lazy = false,
    config = function()
      require("lzy.l_statuscol").setup()
    end,
  },
  -- --- [ bufferline ] --------------------------------------------------------
  {
    "akinsho/bufferline.nvim",
    version = "*",
    dependencies = "nvim-tree/nvim-web-devicons",
    event = "VeryLazy",
    config = function()
      sabunv.moonfly.setup.bufferline()
      require("lzy.l_bufferline").setup(true)
    end,
  },
  -- ---------------------------------------------------------------------------
  -- Theme
  -- ---------------------------------------------------------------------------
  --- [ moonfly ] --------------------------------------------------------------
  {
    "bluz71/vim-moonfly-colors",
    name = "moonfly",
    lazy = false,
    priority = 1000,
    config = function()
      sabunv.moonfly.core_setup()
      sabunv.moonfly.setup.moonfly()
    end,
  },
  -- ---------------------------------------------------------------------------
  -- Editor
  -- ---------------------------------------------------------------------------
  -- TODO: Mover cosas de otras secciones a esta en un futuro
  {
    "lsproule/reg-edit",
    lazy = false,
    commit = "158ff192a5182e2d9d257f79fd7cc924bb8a7e7f",
    config = function ()
      require("lzy.l_reg-edit").setup()
    end
  }
}
