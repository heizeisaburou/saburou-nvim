---@class Servers
local M = {}

M.to_install = {
    "lua_ls", -- lua-language-server (Mason: lua-language-server)
    "html", -- vscode-css-language-server (Mason: html-lsp)
    "cssls", -- vscode-html-language-server (Mason: css-lsp)
    "bashls",
    "basedpyright",
    "vtsls", -- [!] deno genera conflictos. Si vtsls falla probablemente esté instalado; prueba ":MasonUninstall deno" (y reinicia)
    "marksman",
    "ruff",
    "clangd",
    "rust_analyzer",
    "gopls",
    "ansiblels",
    "jinja_lsp", -- Bug importante con python: deja de funcionar K si en filetypes pones python, jinja_lsp no muere en LspRestart y se crean nuevas instancias.
}

---Tabla usada para facilitar la implementación de ejecutar una vez dentro de los cb
---de configuraciones.
---@type table<string, boolean>
local executed = {}
for _, server in ipairs(M.to_install) do
    executed[server] = false
end

---@class LspServerConfig
---@field settings table
---@field cmd string[]|nil
---@field root_dir fun(bufnr:number):string|nil
---@field on_attach fun(client:any, bufnr:number)|nil
-- ...

---@alias ServerFactory fun():LspServerConfig|nil

---@type table<string, ServerFactory>
M.configs = {}

M.configs.lua_ls = function()
    local config = {
        settings = {
            Lua = {
                runtime = { version = "LuaJIT" },
                diagnostics = {
                    enable = true,
                    globals = { "vim", "describe", "it", "before_each", "after_each" },
                },
                workspace = {
                    library = {
                        vim.fn.expand "$VIMRUNTIME/lua",
                        vim.fn.expand "$VIMRUNTIME/lua/vim/lsp",
                        vim.fn.stdpath "data" .. "/lazy/lazy.nvim/lua",
                        vim.fn.stdpath "data" .. "/lazy/NvChad/lua",
                        vim.fn.stdpath "data" .. "/lazy/ui/lua",
                        vim.fn.stdpath "data" .. "/lazy/ui/nvchad_types", -- Tipos
                        vim.fn.stdpath "data" .. "/lazy/base46/lua",
                        vim.fn.stdpath "data" .. "/lazy/nvim-treesitter/lua",
                        vim.fn.stdpath "data" .. "/lazy/gitsigns.nvim/lua",
                        vim.fn.stdpath "data" .. "/lazy/plenary.nvim/lua", -- Debug (etc)
                        vim.fn.stdpath "data" .. "/lazy/statuscol.nvim/lua",
                        "${3rd}/luv/library",
                        "${3rd}/busted/library",
                        vim.fn.expand "~/.config/nvim/lua",
                        --- Agrega aquí los tuyos
                    },
                    maxPreload = 100000,
                    preloadFileSize = 10000,
                },
            },
        },
    }
    return config
end

M.configs.ansiblels = function()
    if not executed.ansiblels then
        vim.filetype.add {
            extension = {
                ansible = "yaml.ansible",
                html = "ansible",
            },
        }
        executed.ansiblels = true
    end

    local config = {
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
                    interpreterPath = "", -- usa el Python por defecto del entorno
                },
                validation = {
                    enabled = true, -- activa validación con ansible-lint o syntax-check
                    lint = {
                        enabled = true,
                        arguments = "", -- sin flags extra
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
    }
    return config
end

M.configs.jinja_lsp = function()
    if not executed.jinja_lsp then
        vim.filetype.add {
            extension = {
                jinja = "jinja",
                jinja2 = "jinja",
                j2 = "jinja",
                py = "python",
            },
        }
        executed.jinja_lsp = true
    end
    local config = {
        -- filetypes = { "jinja", "rust", "python" },
        -- bugueado para python. solución provisional -> dejar solo jinja
        filetypes = { "jinja" },
    }
    return config
end

M.configs.bashls = function()
    if not executed.bashls then
        vim.filetype.add {
            extension = {
                zsh = "bash",
            },
        }
        executed.bashls = true
    end

    local config = {
        settings = {
            cmd = { "bash-language-server", "start" },
            filetypes = { "bash", "sh" },
            bashIde = {
                globPattern = "**/*@(.sh|.inc|.bash|.command|.zsh|.zshrc)",
            },
        },

        -- root_dir = function(bufnr, on_dir)
        --   -- Notar que esta función debe indicar el root o nil a on_dir
        --   local fname = vim.api.nvim_buf_get_name(bufnr)
        --   local basename = vim.fn.fnamemodify(fname, ":t")
        --   local root = nil
        --
        --   if basename == "PKGBUILD" then
        --     local parent = vim.fn.fnamemodify(fname, ":h") -- directorio donde está PKGBUILD
        --     local src_dir = table.concat({ parent, "src" }, "/")
        --     if vim.fn.isdirectory(src_dir) == 1 then
        --       root = src_dir -- usamos src como root
        --     else
        --       root = nil -- no hay src, fallback a root por defecto
        --     end
        --   end
        --   -- si no encontramos src/, usamos root_pattern por defecto
        --   if not root then
        --     root = util.root_pattern(".git", ".hg", ".bzr", ".svn")(fname) or vim.fs.dirname(fname)
        --   end
        --   if on_dir then
        --     on_dir(root)
        --   end
        -- end, -- end root_dir
    }
    return config
end

M.configs.basedpyright = function()
    local config = {
        settings = {
            basedpyright = {
                -- https://docs.basedpyright.com/#/configuration
                typeCheckingMode = "standard",
            },
        },
    }
    return config
end

M.configs.clangd = function()
    local config = {
        cmd = {
            "clangd",
            "--offset-encoding=utf-16",
        },
    }
    return config
end

M.configs.rust_analyzer = function()
    local config = {
        settings = {
            ["rust-analyzer"] = {
                rustfmt = {
                    extraArgs = { "+nightly" },
                },
            },
        },
    }
    return config
end

M.configs.html = function()
    local config = {
        cmd = { "vscode-html-language-server", "--stdio" },
        filetypes = { "jinja", "jinja2", "j2" },
        init_options = {
            configurationSection = { "html", "css", "javascript" },
            embeddedLanguages = {
                css = true,
                javascript = true,
            },
            provideFormatter = true,
        },
        settings = {
            html = {
                format = {
                    enable = true,
                },
            },
        },
    }
    return config
end

return M
