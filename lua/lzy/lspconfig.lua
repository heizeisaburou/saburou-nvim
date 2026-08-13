--- lzy/l_lspconfig
---
--- Capa propia de configuración LSP.
---
--- Centraliza:
---   - servidores gestionados y deshabilitados
---   - configuraciones específicas por servidor
---   - factories para configuraciones que dependen del sistema en runtime
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
---
--- Fuera por ahora:
--- "expert", -- alternativa a elixirls; por investigar

M.servers = {
  "lua_ls",
  "marksman", -- markdown
  --
  --
  --
  -- "ansiblels", -- Ansible (yaml.ansible; detectado en opts.lua)
  -- "basedpyright", -- python
  -- "bashls",
  -- "clangd", -- C, C++
  -- "clojure_lsp",
  -- "csharp_ls",
  -- "cssls", -- .css
  -- "dartls",
  -- "djls", -- Django templates
  -- "elixirls",
  -- "fsautocomplete", -- F#
  "gopls", -- golang
  -- "hls", -- Haskell
  -- "html", -- .html
  -- "jdtls", -- Java
  -- "jinja_lsp", -- Jinja (.jinja/.jinja2/.j2)
  -- "jsonls", -- .json
  -- "kotlin_language_server",
  -- "metals", -- scala
  -- "neocmake", -- cmake
  -- "ocamllsp", -- camellito
  -- "phpactor", -- php
  -- "pug", -- Pug (.pug/.jade)
  -- "qmlls", -- qml
  -- "ruby_lsp",
  -- "ruff", -- Linter y formateador adicional para python
  -- "rust_analyzer",
  -- "shopify_theme_ls", -- Liquid (Shopify)
  -- "sourcekit", -- swift
  -- "svelte",
  -- "taplo", -- .toml
  -- "texlab", -- latex
  -- "tinymist", -- Typst
  -- "twiggy_language_server", -- Twig (.twig)
  -- "vtsls", -- TypeScript, JavaScript
  -- "vue_ls", -- Vue (framework de javascript)
  -- "yamlls", -- .yaml
  -- "zls", -- zig
  -- -- WORKING [Poner abajo hasta terminar]
  -- "shuck",
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
---@alias lzy.lsp.ConfigFactory fun(name: string): vim.lsp.Config?
---@type table<string, vim.lsp.Config|lzy.lsp.ConfigFactory>
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

  clojure_lsp = {},

  csharp_ls = {},

  cssls = {},

  dartls = {},

  djls = {
    -- django-language-server también anuncia `html` y `python`, pero el LSP de
    -- HTML y `basedpyright` ya gestionan esos filetypes. Restringido a
    -- templates para evitar clientes duplicados.
    filetypes = { "htmldjango" },
  },

  jinja_lsp = {
    -- El server anuncia filetypes de Python además de `jinja`; restringido
    -- para no duplicar a basedpyright.
    filetypes = { "jinja" },
    -- Sin `lang` el server no carga configuración y no ofrece completado
    -- (11 snippets: for/if/set/with/include/import...). Se pasa por settings en
    -- lugar de exigir un `jinja-lsp.toml` en el proyecto.
    settings = {
      ["jinja-lsp"] = {
        lang = "python",
      },
    },
  },

  fsautocomplete = {},

  gopls = {},

  hls = {
    -- Mantiene alineado el proveedor LSP con el formateador de Conform.
    settings = {
      haskell = {
        formattingProvider = "fourmolu",
      },
    },
  },

  html = {},

  jdtls = {},

  jsonls = {},

  kotlin_language_server = function()
    local java_home = hzsr.sys.java.resolve_home {
      env = { "KOTLIN_LSP_JAVA_HOME", "JAVA_HOME", "JDK_HOME" },
      versions = { 21, 17 },
      require_jdk = true,
    }
    local storage_path = vim.fs.joinpath(vim.fn.stdpath "cache", "kotlin-language-server")

    -- nvim-lspconfig usa la raíz Gradle/Maven como storagePath. En scripts
    -- .kts sueltos esa raíz puede ser nil y `{}` termina serializado como `[]`,
    -- pero kotlin-language-server exige que initializationOptions sea un objeto.
    vim.fn.mkdir(storage_path, "p")

    local config = {
      init_options = { storagePath = storage_path },
    }

    if not java_home then
      vim.notify_once(
        "kotlin-language-server necesita Java 21 o 17. "
          .. "Instala un JDK compatible o define KOTLIN_LSP_JAVA_HOME.",
        vim.log.levels.WARN
      )
      return config
    end

    -- El launcher de Mason respeta JAVA_HOME tanto en Unix como en Windows.
    config.cmd_env = { JAVA_HOME = java_home }
    return config
  end,

  ---@type lspconfig.settings.lua_ls
  lua_ls = {
    -- TIP: Para configurar lua-language-server para la configuración de Neovim, puedes generar un .luarc.json con:
    --   :Luarc [NVIM_APPNAME]
    settings = {
      Lua = {
        hover = {
          -- Permite mostrar más elementos al hacer hover (Shift+k)
          -- 0, -1 -> No desactivan el límite sino que muestran literalmente 0 elementos
          previewFields = 1000, -- default 50
          enumsLimit = 1000, -- default 5
        },
      },
    },
  },

  marksman = {
    cmd = { "marksman", "server" },
    -- marksman sobra cuando obsidian.nvim gestiona el buffer (obsidian-ls):
    -- resuelve enlaces wiki complejos ("~ > .zshrc") que marksman no puede.
    -- root_dir devuelve nil para notas de vault (.obsidian/.nyabsidian) y
    -- workspace_required impide arrancar sin root. El root_markers vacío
    -- anula el de nvim-lspconfig: con ".git" arrancaría igual en vaults.
    workspace_required = true,
    root_markers = {},
    root_dir = function(bufnr, on_dir)
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name == "" then
        on_dir(nil)
        return
      end
      local in_vault = #vim.fs.find({ ".obsidian", ".nyabsidian" }, {
        upward = true,
        path = vim.fs.dirname(name),
      }) > 0
      if in_vault then
        on_dir(nil)
        return
      end
      on_dir(vim.fs.root(bufnr, { ".marksman.toml", ".git" }))
    end,
    filetypes = { "markdown", "markdown.mdx" },
  },

  metals = {},

  neocmake = {},

  pug = {
    -- pug-lsp (opa-oz) v0.1.0: release "under heavy development". El binario de
    -- Mason no responde al handshake LSP (imprime un TODO y sale), por lo que el
    -- cliente se inicia pero nunca llega a attach. Se mantiene registrado para
    -- poder verificar en el futuro cuando el proyecto publique releases nuevas.
    filetypes = { "pug" },
  },

  ocamllsp = function()
    local ocamlformat_bin =
      vim.fs.joinpath(vim.fn.stdpath "data", "mason", "packages", "ocamlformat", "bin")

    if not hzsr.sys.fs.is_dir(ocamlformat_bin) then
      return {}
    end

    local current_path = vim.env.PATH or ""
    local path = current_path == "" and ocamlformat_bin
      or (ocamlformat_bin .. hzsr.sys.path_list_sep .. current_path)

    -- El paquete de Mason contiene ocamlformat-rpc, pero su receipt sólo
    -- enlaza `ocamlformat` en mason/bin. Ocamllsp busca el RPC mediante PATH.
    return { cmd_env = { PATH = path } }
  end,

  ruff = {},

  ruby_lsp = function()
    local bundle_path = vim.fs.joinpath(vim.fn.stdpath "data", "ruby-lsp", "bundle")
    vim.fn.mkdir(bundle_path, "p")

    -- Ruby LSP detecta RuboCop, Standard o Syntax Tree desde el bundle del
    -- proyecto. Con el Ruby del sistema, Bundler intentaría escribir las gemas
    -- del bundle compuesto en `/usr/lib`; BUNDLE_PATH las mantiene en el data
    -- dir del usuario. La función `cmd` de nvim-lspconfig gestiona el cwd por
    -- proyecto, pero no reenvía cmd_env, así que se replica aquí con `env`.
    return {
      cmd = function(dispatchers, config)
        return vim.lsp.rpc.start({ "ruby-lsp" }, dispatchers, {
          cwd = config and (config.cmd_cwd or config.root_dir),
          env = { BUNDLE_PATH = bundle_path },
        })
      end,
      init_options = {
        formatter = "auto",
      },
    }
  end,

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

  sourcekit = {
    -- sourcekit-lsp también anuncia C/C++/Objective-C, pero clangd ya gestiona
    -- esos filetypes en esta configuración. Evita dos clientes simultáneos.
    filetypes = { "swift" },
  },

  taplo = {},

  tinymist = {
    -- El default de nvim-lspconfig usa root_markers `.git`, que deja sin
    -- attach los .typ sueltos (p. ej. el smoke test no es un repo git).
    root_dir = function(bufnr, on_dir)
      on_dir(vim.fn.getcwd())
    end,
    single_file_support = true,
    -- El formateo lo gestiona Conform vía `typstyle`; se desactiva el propio
    -- de tinymist para no duplicar. `exportPdf`/preview no se activan.
    settings = {
      formatterMode = "disable",
    },
  },

  yamlls = {},

  zls = {},

  qmlls = {
    -- Mason ofrece qmlls también en Windows. Si se usa el Qt del sistema,
    -- algunas distribuciones publican el ejecutable como qmlls6.
    cmd = { hzsr.sys.executable.resolve { "qmlls", "qmlls6" } },
    filetypes = { "qml", "qmljs" },
    root_markers = { ".qmlls.ini", "shell.qml", ".git" },
  },
  vtsls = {
    -- Volar (vue-language-server) v3 funciona en hybrid mode obligatorio: solo
    -- gestiona HTML/template. El TypeScript de los <script> de .vue lo delega
    -- a vtsls mediante el plugin `@vue/typescript-plugin`, que ya viene dentro
    -- del paquete de Mason de vue-language-server.
    settings = {
      vtsls = {
        tsserver = {
          globalPlugins = {
            {
              name = "@vue/typescript-plugin",
              location = vim.fs.joinpath(
                vim.fn.stdpath "data",
                "mason",
                "packages",
                "vue-language-server",
                "node_modules",
                "@vue",
                "language-server"
              ),
              languages = { "vue" },
              configNamespace = "typescript",
            },
          },
        },
      },
    },
    -- Sin `vue` en filetypes, vtsls nunca se adjunta a un .vue y el script
    -- SFC se queda sin TS (diagnósticos, goto definition, hover).
    filetypes = {
      "typescript",
      "javascript",
      "javascriptreact",
      "typescriptreact",
      "vue",
    },
  },
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
  local native_gx = vim.fn.maparg("gx", "n", false, true)

  if type(native_gx) == "table" and type(native_gx.callback) == "function" then
    map("n", "gx", native_gx.callback, opts "Open link under cursor")
  end

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
  require("lzy.lsp-lines").on_attach(client, bufnr)

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

-- A document-highlight response can arrive after its buffer has been wiped,
-- for example while nvim-tree is renaming files. Neovim's default handler
-- accesses the buffer without checking that it still exists.
local function setup_document_highlight_handler()
  vim.lsp.handlers["textDocument/documentHighlight"] = function(_, result, ctx)
    if not result or not vim.api.nvim_buf_is_valid(ctx.bufnr) then
      return
    end

    local client = vim.lsp.get_client_by_id(ctx.client_id)
    if not client then
      return
    end

    vim.lsp.util.buf_highlight_references(ctx.bufnr, result, client.offset_encoding)
  end
end

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
  local entry = M.config[name]
  local cfg

  -- Las factories se evalúan al activar/reiniciar el servidor. Esto permite
  -- detectar toolchains instalados después de arrancar la configuración base.
  if type(entry) == "function" then
    cfg = entry(name)
  else
    cfg = entry
  end

  if cfg ~= nil and type(cfg) ~= "table" then
    error(("M.config[%q] debe ser una tabla o una factory que devuelva una tabla"):format(name))
  end

  cfg = extend_server_config(cfg)

  -- Algunos servidores traen un `on_init` propio en nvim-lspconfig que no debe
  -- perderse (p. ej. `vue_ls`/`volar` registra el forwarding `tsserver/request`
  -- imprescindible en hybrid mode). Se encadena en lugar de sobrescribirlo.
  local existing = vim.lsp.config[name]
  local existing_on_init = existing and existing.on_init
  if existing_on_init and existing_on_init ~= cfg.on_init then
    local prev_on_init, cur_on_init = existing_on_init, cfg.on_init
    cfg.on_init = function(client, init_result)
      if prev_on_init then
        prev_on_init(client, init_result)
      end
      if cur_on_init then
        cur_on_init(client, init_result)
      end
    end
  end

  vim.lsp.config(name, cfg)
end

---@param name string
local function enable_server(name)
  if not is_managed_server(name) then
    vim.notify(
      ("LSP server is not managed by this config: %s"):format(name),
      vim.log.levels.WARN
    )
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
  setup_document_highlight_handler()

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
