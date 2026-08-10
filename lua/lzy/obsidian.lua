-- lzy/l_obsidian

local M = {}

--- Workspace dinámico: el vault es SIEMPRE el directorio actual, sin importar
--- si es un vault real de Obsidian o no. Así el rename de notas y el arreglo
--- de enlaces funciona en cualquier proyecto sin hardcodear rutas.
---
--- Limitación conocida: el workspace se fija al cargar el plugin; si se cambia
--- de cwd en runtime haría falta recargar (hooks futuros).
local function make_opts()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
  return {
    legacy_commands = false,
    workspaces = {
      {
        name = "Workspace",
        path = cwd,
      },
    },
  }
end

M.opts = make_opts

function M.setup()
  require("obsidian").setup(M.opts())
end

return M
