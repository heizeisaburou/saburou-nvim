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
      require("lzy.snacks").setup()
    end,
  },
  -- --- [ mru-nav ] -----------------------------------------------------------
  {
    "mjacobs/mru-nav.nvim",
    commit = "581f9f1132b003ea4fc4241ff30158ee247305ac",
    cmd = { "MruFile", "MruBuffer", "MruClearFiles" },
    lazy = false,
    config = function()
      require("lzy.mru-nav").setup()
    end,
  },
  -- --- [ mason ] -------------------------------------------------------------
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate" },
    init = function()
      require("lzy.mason").init_setup()
    end,
    config = function()
      require("lzy.mason").setup()
    end,
  },
  -- --- [ telescope ] ---------------------------------------------------------
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    cmd = "Telescope",
    config = function()
      return require("lzy.telescope").setup(true)
    end,
  },
  -- ---------------------------------------------------------------------------
  -- Code
  -- ---------------------------------------------------------------------------
  {
    "nvim-treesitter/nvim-treesitter",
    event = { "BufReadPre", "BufNewFile" },
    branch = "main",
    opts = require("lzy.treesitter").opts,
    config = function()
      require("lzy.treesitter").setup()
    end,
  },
  --- [ lspconfig ] ------------------------------------------------------------
  {
    "neovim/nvim-lspconfig",
    -- event = "VeryLazy",
    lazy = false,
    config = function()
      require("lzy.lspconfig").setup()
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
      require("lzy.conform").setup()
    end,
  },
  -- --- [ nvim-lint ] ---------------------------------------------------------
  -- Capa de linting para lo que no cubre ningún LSP. El primer caso es SQL:
  -- sqls no publica diagnósticos (ni los anuncia), así que fuera de un
  -- proyecto PostgreSQL no habría ninguno.
  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("lzy.nvim-lint").setup()
    end,
  },
  -- --- [ lsp_lines ] ---------------------------------------------------------
  -- Muestra los errores cómodamente separados por líneas
  {
    "maan2003/lsp_lines.nvim",
    dependencies = { "nvim-lspconfig" },
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("lzy.lsp-lines").setup()
    end,
  },
  -- --- [ workspaces ] --------------------------------------------------------
  -- Sistema de workspaces
  {
    "natecraddock/workspaces.nvim",
    dependencies = { "nvim-telescope/telescope.nvim" },
    event = "VeryLazy",
    config = function()
      require("lzy.workspaces").setup()
    end,
  },
  {
    -- Plugin que resalta los matches TODO, NOTE, etc.
    "folke/todo-comments.nvim",
    event = "VeryLazy",
    keys = require("lzy.todo-comments").keys,
    config = function()
      require("lzy.todo-comments").setup()
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
      require("lzy.dap-ui").setup()
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
      require("lzy.mason-dap").setup()
    end,
  },
  -- --- [ gitsings ] -----------------------------------------------------------
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = function()
      return require "lzy.gitsigns"
    end,
  },
  -- --- [ diffview ] ----------------------------------------------------------
  {
    "sindrets/diffview.nvim",
    event = "BufReadPre",
    dependencies = { "nvim-lua/plenary.nvim" },
    -- Mismo motivo que `keys`: sin esta lista, en una sesión sin archivo
    -- abierto (`nvim` a secas) el plugin no se ha cargado y sus comandos
    -- todavía no existen. lazy.nvim crea un stub por cada nombre que lo carga
    -- y reenvía la llamada, así que `:Diffview<Tab>` completa desde el arranque
    -- y `:'<,'>DiffviewFileHistory` conserva el rango. Es la lista completa de
    -- `plugin/diffview.lua`.
    cmd = {
      "DiffviewOpen",
      "DiffviewFileHistory",
      "DiffviewClose",
      "DiffviewFocusFiles",
      "DiffviewToggleFiles",
      "DiffviewRefresh",
      "DiffviewLog",
    },
    keys = function()
      return require("lzy.diffview").keys
    end,
    config = function()
      require("lzy.diffview").setup()
    end,
  },
  -- --- [ git-blame ] ---------------------------------------------------------
  {
    "f-person/git-blame.nvim",
    -- load the plugin at startup
    event = "VeryLazy",
    -- Because of the keys part, you will be lazy loading this plugin.
    -- The plugin will only load once one of the keys is used.
    -- If you want to load the plugin at startup, add something like event = "VeryLazy",
    -- or lazy = false. One of both options will work.
    config = function()
      require("lzy.git-blame").setup()
    end,
  },
  -- --- [ nvim-web-devicons ] -------------------------------------------------
  {
    "nvim-tree/nvim-web-devicons",
    lazy = false,
    config = function()
      require("lzy.nvim-web-devicons").setup()
    end,
  },
  -- --- [ render-markdown ] ---------------------------------------------------
  {
    "MeanderingProgrammer/render-markdown.nvim",
    -- Nuestros handlers dependen de la API interna de esta revisión.
    commit = "f422cb5c6855f150e2ddcfaf44e7157b98b34f6a",
    lazy = false,
    dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
    config = function()
      require("lzy.render-markdown").setup()
    end,
    ft = { "markdown", "Avante", "copilot-chat", "opencode_output" },
  },
  -- ---------------------------------------------------------------------------
  -- AI
  -- ---------------------------------------------------------------------------
  --- [ copilot ] --------------------------------------------------------------
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    keys = require("lzy.copilot").keys,
    config = function()
      require("lzy.copilot").setup()
    end,
  },
  --- [ codex ] ----------------------------------------------------------------
  {
    "kkrampis/codex.nvim",
    commit = "4317788afc091d5e913109c55d5a04f32be4e14a",
    lazy = true,
    cmd = { "Codex", "CodexToggle" }, -- Optional: Load only on command execution
    keys = require("lzy.codex").keys,
    config = function()
      require("lzy.codex").setup()
    end,
  },
  --- [ claude ] ---------------------------------------------------------------
  {
    "greggh/claude-code.nvim",
    keys = require("lzy.claude").keys,
    dependencies = {
      "nvim-lua/plenary.nvim", -- Required for git operations
    },
    config = function()
      require("lzy.claude").setup()
    end,
  },
  --- [ opencode ] -------------------------------------------------------------
  {
    "sudo-tee/opencode.nvim",
    lazy = false,
    config = function()
      require("lzy.opencode").setup()
    end,
    dependencies = {
      "nvim-lua/plenary.nvim",
      {
        "MeanderingProgrammer/render-markdown.nvim",
      },
      -- Optional, for file mentions and commands completion, pick only one
      -- "saghen/blink.cmp",
      "hrsh7th/nvim-cmp",

      -- Optional, for file mentions picker, pick only one
      "folke/snacks.nvim",
      -- 'nvim-telescope/telescope.nvim',
      -- 'ibhagwan/fzf-lua',
      -- 'nvim_mini/mini.nvim',
    },
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
      require("lzy.camelcasemotion").setup()
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
          require("lzy.luasnip").setup()
        end,
      },

      -- --- └─ [ auotpairs ] --------------------------------------------------
      -- cerrar automáticamente llaves como p.ej. ()[]{}
      -- [TIP] Activalo si te gusta.
      -- {
      --   "windwp/nvim-autopairs",
      --   config = function()
      --     require("lzy.autopairs").setup()
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
      require("lzy.cmp").setup()
    end,
  },
  -- --- [ which-key ] ---------------------------------------------------------
  {
    -- TODO: poner nuestros grupos de teclas
    "folke/which-key.nvim",
    event = "VeryLazy",
    keys = { "<leader>", "<c-w>", '"', "'", "`", "c", "v", "g", "l", "n"},
    cmd = "WhichKey",
    opts = {},
  },
  --- [ nvim-tree ] ------------------------------------------------------------
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFocus" },
    event = "VeryLazy",
    config = function()
      require("lzy.nvim-tree").setup()
    end,
  },
  -- --- [ obsidian ] ----------------------------------------------------------
  -- Obsidian-style vault features: rename de notas actualizando [[enlaces]].
  -- Sin workspaces configurados: el directorio actual se trata como vault.
  {
    "obsidian-nvim/obsidian.nvim",
    -- Nyabsidian parchea comportamiento interno: actualizar sólo tras probarlo.
    commit = "69fe7c6bf61a5222b5061a9a9dfc5023f2ec0fdc",
    ft = { "markdown" },
    init = function()
      -- Comandos Nyabsidian* disponibles desde el arranque, sin esperar a
      -- abrir un .md. El plugin sigue cargando lazy con ft=markdown.
      require("lzy.obsidian.commands").setup()
    end,
    config = function()
      require("lzy.obsidian").setup()
    end,
  },
  {
    -- Aerial Nvim (árbol de símbolos)
    "stevearc/aerial.nvim",
    event = "VeryLazy",
    config = function()
      require("lzy.aerial").setup()
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
      require("lzy.lualine").setup()
    end,
  },
  -- --- [ statuscol ] ---------------------------------------------------------
  {
    "luukvbaal/statuscol.nvim",
    lazy = false,
    config = function()
      require("lzy.statuscol").setup()
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
      require("lzy.bufferline").setup(true)
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
    commit = "ee2763a804ad69c2c1afe70b153c6058cd02bb51",
    config = function()
      require("lzy.reg-edit").setup()
    end,
  },
}
