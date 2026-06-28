--- lzy/l_lspconfig
---
--- Capa propia de configuración LSP.
---
--- Centraliza:
---   - servidores gestionados y deshabilitados
---   - configuraciones específicas por servidor
---   - capabilities compartidas
---   - callbacks `on_init` / `on_attach`
---   - keymaps LSP
---   - comandos LSP
---   - registro mediante `vim.lsp.config(...)`
---   - activación mediante `vim.lsp.enable(...)`
---
--- Futuro:
---   Añadir estado persistente para activar/desactivar servidores en runtime:
---
---     :LspServerEnable lua_ls
---     :LspServerDisable ruff
---     :LspServerToggle vtsls
---
---   Posible archivo:
---
---     stdpath("state") .. "/lzy/lsp_servers.json"

local M = {}

-- =============================================================================
-- Servers
-- =============================================================================

--- Servidores gestionados por esta capa.
---
--- Esta tabla no instala servidores.
M.servers = {
  -- "ansiblels",
  "bashls",
  "basedpyright",
  "clangd",
  "cssls",
  "gopls",
  "html",
  "lua_ls",
  "marksman",
  "neocmake",
  "ruff",
  "rust_analyzer",
  "vtsls",
  -- "expert",
  "elixirls",
  "qmlls",
  "texlab",
}

--- Servidores deshabilitados para esta capa.
---
--- No desinstala nada ni impide que otro módulo los configure.
M.disable = { "deno" }

-- =============================================================================
-- Server configs
-- =============================================================================

--- Configuración específica por servidor.
---
---@type table<string, vim.lsp.Config>
M.config = {
  ansiblels = {
    settings = {
      ansible = {
        enable = true,
        disableProgressNotifications = false,
        builtin = {
          isWithYamllint = false,
          ansibleVersion = "",
          ansibleLintVersion = "",
          yamllintVersion = "",
          force = false,
        },
        ansible = {
          useFullyQualifiedCollectionNames = true,
        },
        python = {
          interpreterPath = "",
        },
        validation = {
          enabled = true,
          lint = {
            enabled = true,
            arguments = "",
          },
        },
        completion = {
          provideRedirectModules = true,
          provideModuleOptionAliases = true,
        },
        ansibleDoc = {
          path = "ansible-doc",
          enableSplitRight = true,
        },
        ansibleNavigator = {
          path = "ansible-navigator",
        },
        dev = {
          serverPath = "",
        },
        ansibleServer = {
          trace = {
            server = "off",
          },
        },
      },
    },
  },

  bashls = {},

  basedpyright = {
    settings = {
      basedpyright = {
        -- https://docs.basedpyright.com/#/configuration
        typeCheckingMode = "standard",
      },
    },
  },

  clangd = {
    cmd = {
      "clangd",
      "--offset-encoding=utf-16",
    },
  },

  cssls = {},

  gopls = {},

  html = {},

  ---@type lspconfig.settings.lua_ls
  lua_ls = {
    -- TIP: Para configurar lua-language-server para la configuración de Neovim, puedes generar un .luarc.json con:
    --   :Luarc [NVIM_APPNAME]
    settings = {
      Lua = {
        hover = {
          previewFields = 0, -- o más; default 50
          enumsLimit = 0, -- default 5
        },
      },
    },
  },

  marksman = {
    cmd = { "marksman", "server" },
    root_markers = { ".marksman.toml", ".git" },
    filetypes = { "markdown", "markdown.mdx" },
  },

  neocmake = {},

  ruff = {},

  rust_analyzer = {
    -- settings = {
    --   ["rust-analyzer"] = {
    --     rustfmt = {
    --       extraArgs = { "+nightly" },
    --     },
    --   },
    -- },
    settings = {
      ["rust-analyzer"] = {
        lens = {
          enable = true,
        },
      },
    },
  },

  qmlls = {
    -- cmd = {
    --   "/usr/lib/qt6/bin/qmlls",
    --   "--no-cmake-calls",
    --   "-I",
    --   "/usr/lib/qt6/qml",
    --   "-I",
    --   "/usr/bin",
    -- },
    filetypes = { "qml", "qmljs" },
    root_markers = { ".qmlls.ini", "shell.qml", ".git" },
  },
  vtsls = {},
}

-- =============================================================================
-- Mapping opts
-- =============================================================================

---@param desc? string
---@param opts? sabunv.util.mapping.opts
---@return table
local function lsp_global_opts(desc, opts)
  opts = vim.tbl_extend("force", { prefix = "LSP" }, opts or {})
  return sabunv.util.mapping.gen(desc, opts)
end

---@param bufnr integer
---@return sabunv.util.mapping.gen
local function make_lsp_buffer_opts(bufnr)
  return function(desc, opts)
    opts = vim.tbl_extend("force", { prefix = "LSP" }, opts or {})
    return sabunv.util.mapping.bgen(bufnr, desc, opts)
  end
end

-- =============================================================================
-- On attach mappings
-- =============================================================================

---@param _client vim.lsp.Client
---@param bufnr integer
local function setup_on_attach_mappings(_client, bufnr)
  local map = vim.keymap.set
  local opts = make_lsp_buffer_opts(bufnr)

  map("n", "<leader>lt", vim.lsp.buf.type_definition, opts "Go to type definition")
  map("n", "gD", vim.lsp.buf.declaration, opts "Go to declaration")
  map("n", "gd", vim.lsp.buf.definition, opts "Go to definition")

  map("n", "<leader>ld", function()
    vim.notify("  Showing line diagnostics ...", vim.log.levels.INFO)

    local _, float_win = vim.diagnostic.open_float {
      scope = "line",
    }

    if float_win then
      vim.api.nvim_set_current_win(float_win)
    end
  end, opts "Open line diagnostics")

  map("n", "<leader>ll", function()
    vim.diagnostic.setloclist {
      bufnr = bufnr,
      open = true,
    }
  end, opts "Diagnostics: open loclist")

  map("n", "<leader>lu", function()
    local cfg = vim.diagnostic.config() or {}
    local new = not cfg.update_in_insert

    vim.diagnostic.config { update_in_insert = new }
    vim.notify("update_in_insert = " .. tostring(new), vim.log.levels.INFO)
  end, opts "Toggle update_in_insert")
end

-- =============================================================================
-- Global mappings
-- =============================================================================

local function setup_global_mappings()
  local map = vim.keymap.set
  local opts = lsp_global_opts

  map("n", "<leader>li", function()
    vim.cmd "LspInfo"
  end, opts "Show info")

  map("n", "<leader>lr", function()
    vim.cmd "LspRestart"
  end, opts "Restart")

  map("n", "<leader>lR", function()
    vim.cmd "LspRestart!"
  end, opts "Restart force")

  map("n", "<leader>lL", function()
    vim.cmd "LspLog"
  end, opts "Open log")
end

-- =============================================================================
-- Callbacks
-- =============================================================================

---@type LspOnAttach
M.on_attach = function(client, bufnr)
  if client.name == "ruff" then
    client.server_capabilities.hoverProvider = false
  end

  -- require("hzsr.lsp_signature_help").on_attach(client, bufnr)
  local ok, lzy_lsplines = pcall(require, "lzy.l_lsp-lines")
  if ok and lzy_lsplines then
    lzy_lsplines.on_attach(client, bufnr)
  end

  setup_on_attach_mappings(client, bufnr)
end

---@type fun(client: vim.lsp.Client, init_result: table?)
M.on_init = function(client, _)
  if client:supports_method "textDocument/semanticTokens" then
    client.server_capabilities.semanticTokensProvider = nil
  end
end

-- =============================================================================
-- Capabilities
-- =============================================================================

---@return lsp.ClientCapabilities
local function make_capabilities()
  local capabilities = vim.lsp.protocol.make_client_capabilities()

  if capabilities.workspace then
    capabilities.workspace.didChangeWatchedFiles = nil
  end

  local extra_capabilities = {
    -- general = {
    --     positionEncodings = { "utf-16" },
    -- },
    textDocument = {
      completion = {
        completionItem = {
          documentationFormat = { "markdown", "plaintext" },
          snippetSupport = true,
          preselectSupport = true,
          insertReplaceSupport = true,
          labelDetailsSupport = true,
          deprecatedSupport = true,
          commitCharactersSupport = true,
          tagSupport = { valueSet = { 1 } },
          resolveSupport = {
            properties = {
              "documentation",
              "detail",
              "additionalTextEdits",
            },
          },
        },
      },
    },
  }

  return vim.tbl_deep_extend("force", capabilities, extra_capabilities)
end

M.capabilities = make_capabilities()

-- =============================================================================
-- Server helpers
-- =============================================================================

---@param cfg? vim.lsp.Config
---@return vim.lsp.Config
local function extend_server_config(cfg)
  local base = {
    capabilities = M.capabilities,
    on_init = M.on_init,
  }

  return vim.tbl_deep_extend("force", base, cfg or {})
end

---@param name string
---@return boolean
local function is_managed_server(name)
  return vim.tbl_contains(M.servers, name)
end

---@param name string
---@return boolean
local function is_disabled_server(name)
  return vim.tbl_contains(M.disable, name)
end

---@param name string
---@return boolean
local function is_enabled_server(name)
  return is_managed_server(name) and not is_disabled_server(name)
end

---@param name string
local function configure_server(name)
  local cfg = extend_server_config(M.config[name])
  vim.lsp.config(name, cfg)
end

---@param name string
local function enable_server(name)
  if not is_managed_server(name) then
    vim.notify(("LSP server is not managed by this config: %s"):format(name), vim.log.levels.WARN)
    return
  end

  if is_disabled_server(name) then
    vim.notify(("LSP server is disabled by M.disable: %s"):format(name), vim.log.levels.WARN)
    return
  end

  configure_server(name)
  vim.lsp.enable(name)
end

---@param name string
---@param force? boolean
local function disable_server(name, force)
  vim.lsp.enable(name, false)

  if force then
    vim.iter(vim.lsp.get_clients { name = name }):each(function(client)
      client:stop(true)
    end)
  end
end

local function enable_all_servers()
  for _, name in ipairs(M.servers) do
    if is_enabled_server(name) then
      enable_server(name)
    end
  end
end

-- =============================================================================
-- Completion helpers
-- =============================================================================

---@param arg string
---@return string[]
local function complete_managed_servers(arg)
  return vim
    .iter(M.servers)
    :filter(function(name)
      return name:sub(1, #arg) == arg
    end)
    :totable()
end

---@param arg string
---@return string[]
local function complete_active_clients(arg)
  return vim
    .iter(vim.lsp.get_clients())
    :map(function(client)
      return client.name
    end)
    :filter(function(name)
      return name:sub(1, #arg) == arg
    end)
    :totable()
end

-- =============================================================================
-- Commands
-- =============================================================================

local function create_lsp_commands()
  vim.api.nvim_create_user_command("LspInfo", function()
    vim.cmd "checkhealth vim.lsp"
  end, {
    force = true,
    desc = "Show LSP health/info",
  })

  vim.api.nvim_create_user_command("LspLog", function()
    vim.cmd(("tabnew %s"):format(vim.lsp.log.get_filename()))
  end, {
    force = true,
    desc = "Open LSP log",
  })

  vim.api.nvim_create_user_command("LspStart", function(info)
    local servers = info.fargs

    if #servers == 0 then
      enable_all_servers()
      return
    end

    for _, name in ipairs(servers) do
      enable_server(name)
    end
  end, {
    force = true,
    nargs = "*",
    complete = complete_managed_servers,
    desc = "Enable managed LSP server(s)",
  })

  vim.api.nvim_create_user_command("LspStop", function(info)
    local servers = info.fargs

    if #servers == 0 then
      servers = vim
        .iter(vim.lsp.get_clients { bufnr = 0 })
        :map(function(client)
          return client.name
        end)
        :totable()
    end

    for _, name in ipairs(servers) do
      disable_server(name, info.bang)
    end
  end, {
    force = true,
    nargs = "*",
    bang = true,
    complete = complete_active_clients,
    desc = "Disable/stop LSP server(s)",
  })

  vim.api.nvim_create_user_command("LspRestart", function(info)
    local servers = info.fargs

    if #servers == 0 then
      servers = vim
        .iter(vim.lsp.get_clients { bufnr = 0 })
        :map(function(client)
          return client.name
        end)
        :totable()
    end

    for _, name in ipairs(servers) do
      disable_server(name, info.bang)
    end

    vim.defer_fn(function()
      for _, name in ipairs(servers) do
        enable_server(name)
      end
    end, 500)
  end, {
    force = true,
    nargs = "*",
    bang = true,
    complete = complete_active_clients,
    desc = "Restart LSP server(s)",
  })
end

-- Hotfix qmlls: Pesé a que se generan los diagnosticos al volver al modo normal no se renderizan en las lineas;
--   - El contador de warnings, etc se actualiza, y puedes listar todos los
--     diagnosticos, pero no se muestran en el documento.
--   - Con vim.diagnostic.show() los obligamos a salir
--
-- Protecciones
-- - `update_in_insert`: en este modo el hotfix no es necesario
local function qmlls_diags_hotfix_with_autocmd()
  vim.api.nvim_create_autocmd("ModeChanged", {
    group = vim.api.nvim_create_augroup("lzy_qmlls_diagnostic_refresh", { clear = true }),
    callback = function(args)
      local ft = vim.bo[args.buf].filetype
      if ft ~= "qml" and ft ~= "qmljs" then
        return
      end

      local has_qmlls = #vim.lsp.get_clients { bufnr = args.buf, name = "qmlls" } > 0
      if not has_qmlls then
        return
      end

      local cfg = vim.diagnostic.config() or {}
      if cfg.update_in_insert then
        return
      end

      vim.diagnostic.show(nil, args.buf)
    end,
  })
end

-- =============================================================================
-- Setup
-- =============================================================================

---@return nil
M.setup = function()
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("lzy_lsp_attach", { clear = true }),
    callback = function(args)
      local client = assert(vim.lsp.get_client_by_id(args.data.client_id))
      M.on_attach(client, args.buf)
    end,
  })

  create_lsp_commands()
  setup_global_mappings()
  enable_all_servers()
  qmlls_diags_hotfix_with_autocmd()
end

return M
