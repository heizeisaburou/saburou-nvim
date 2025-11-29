local lsp_lines = require "lsp_lines"
lsp_lines.setup()

local virtual_lines_enabled = vim.diagnostic.config().virtual_lines or false
vim.diagnostic.config {
    virtual_lines = virtual_lines_enabled,
    virtual_text = not virtual_lines_enabled,
}
