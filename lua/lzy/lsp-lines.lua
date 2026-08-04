-- lzy.l_lsplines

local M = {}

--- Inicializa `lsp_lines.nvim` y sincroniza el estado inicial de los diagnósticos.
---
--- Este módulo permite alternar entre dos modos de visualización:
---   - `virtual_lines = true`: diagnósticos en líneas virtuales
---   - `virtual_text = true`: diagnósticos inline clásicos
---
--- Al iniciar, se conserva el valor actual de `virtual_lines` y se fuerza
--- `virtual_text` al estado opuesto, para que ambos modos no queden activos a la vez.
function M.setup()
  require("lsp_lines").setup()
  local virtual_lines_enabled = vim.diagnostic.config().virtual_lines or false
  vim.diagnostic.config {
    virtual_lines = virtual_lines_enabled,
    virtual_text = not virtual_lines_enabled,
  }
end

--- Registra mappings buffer-local relacionados con la visualización de diagnósticos.
---@type LspOnAttach
function M.on_attach(client, bufnr)
  local map = vim.keymap.set
  local opts = sabunv.util.mapping.lsp.bwith(bufnr)

  map("n", "<leader>lv", function()
    local virtual_lines_enabled = vim.diagnostic.config().virtual_lines or false
    virtual_lines_enabled = not virtual_lines_enabled

    vim.diagnostic.config {
      virtual_lines = virtual_lines_enabled,
      virtual_text = not virtual_lines_enabled,
    }
    vim.notify("virtual_lines = " .. tostring(virtual_lines_enabled), vim.log.levels.INFO)
  end, opts "virtual_lines")
end

return M
