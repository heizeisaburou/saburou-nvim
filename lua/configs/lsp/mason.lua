local Servers = require "configs.lsp.servers"

-- Mason-lspconfig setup
require("mason-lspconfig").setup {
    ensure_installed = Servers.to_install,
    automatic_installation = false,
}
