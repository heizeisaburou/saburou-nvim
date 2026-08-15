-- lazy/l_lint

-- Capa de linting para lo que ningún LSP cubre.
--
-- El primer caso es SQL: `sqls` no publica diagnósticos ni anuncia
-- `diagnosticProvider`, así que fuera de un proyecto PostgreSQL —donde manda
-- `postgres_lsp`, que sí lintea— no habría ninguno. `sqlfluff` es linter
-- además de formateador y llena ese hueco.
--
-- `M.linters_by_ft` es la tabla que Mason lee para saber qué instalar
-- (`lua/hzsr/mason/nvchad/init.lua`), así que aquí va todo lo que deba estar
-- disponible. Que un linter se ejecute o no en un buffer concreto lo decide
-- `M.conditions`.

local M = {}

M.linters_by_ft = {
  sql = { "sqlfluff" },
}

-- Linters que solo tienen sentido en ciertos proyectos. Si la condición falla,
-- el linter no se ejecuta y no se publica nada: quedarse sin diagnósticos es
-- mejor que llenar el buffer de falsos positivos o del error de la propia
-- herramienta.
M.conditions = {
  -- sqlfluff aborta si el proyecto no declara dialecto. Mismo criterio que usa
  -- Conform para elegir entre sqlfluff y pg_format.
  sqlfluff = function(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    return name ~= "" and require("lzy.sqlfluff").declared(vim.fs.dirname(name))
  end,
}

--- Linters aplicables al buffer, ya filtrados por su condición.
---@param bufnr integer
---@return string[]
local function linters_for(bufnr)
  local names = {}

  for _, name in ipairs(M.linters_by_ft[vim.bo[bufnr].filetype] or {}) do
    local condition = M.conditions[name]
    if not condition or condition(bufnr) then
      names[#names + 1] = name
    end
  end

  return names
end

---@param bufnr integer
local function lint_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or vim.bo[bufnr].buftype ~= "" then
    return
  end

  local names = linters_for(bufnr)
  if #names == 0 then
    return
  end

  -- try_lint() trabaja siempre sobre el buffer actual; el autocmd puede llegar
  -- con otro en pantalla.
  vim.api.nvim_buf_call(bufnr, function()
    require("lint").try_lint(names)
  end)
end

function M.setup()
  local lint = require "lint"

  lint.linters_by_ft = M.linters_by_ft

  -- sqlfluff recibe el texto por stdin, así que por su cuenta buscaría la
  -- configuración desde el cwd de Neovim y no desde el árbol del archivo:
  -- abrir un `.sql` desde otro directorio se quedaría sin dialecto y sin
  -- diagnósticos. `--stdin-filename` le dice de dónde viene el texto.
  lint.linters.sqlfluff.args = {
    "lint",
    "--format=json",
    "--stdin-filename",
    function()
      local name = vim.api.nvim_buf_get_name(0)
      return name ~= "" and name or "stdin.sql"
    end,
    "-",
  }

  local group = vim.api.nvim_create_augroup("hzsr_lint", { clear = true })

  -- Al leer y al guardar. InsertLeave queda fuera a propósito: sqlfluff tarda
  -- cientos de milisegundos y no compensa lanzarlo en cada salida de inserción.
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost" }, {
    group = group,
    callback = function(event)
      lint_buffer(event.buf)
    end,
  })
end

return M
