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
  -- Descomenta si trabajas con SQL: da diagnósticos donde `sqls` no llega.
  --   - Fuera por defecto porque `sqlfluff` necesita Python (Python es una 
  --     dependencia circunstancial de la configuración)
  --   - Conform lo tiene fuera por lo mismo (ver lzy.conform).
  -- sql = { "sqlfluff" },

  -- Descomenta para revisar la calidad de las reglas Suricata/Snort. No
  -- sustituye a `suricata_language_server`, que es quien dice si la firma
  -- compila: esto opina sobre estilo y sobre lo que le falta a la firma para
  -- ser útil en producción. Ver language-dependencies.md.
  -- hog = { "suricata_check" },
}

-- suricata-check no está en Mason ni en el catálogo de nvim-lint, y su forma
-- recomendada de instalación es un virtualenv, que no queda en el `PATH`. Se
-- resuelve con el mismo helper que las herramientas externas de Conform, y se
-- memoiza aquí para no rehacer la búsqueda en cada linteo.
local bin
local function suricata_check_bin()
  bin = bin
    or require("hzsr.sys.executable").external {
      bin = "suricata-check",
      paths = { "~/.venv/suricata-check/bin", "~/.venv/sls/bin" },
      why = "las reglas Suricata se quedan sin revisión de calidad",
      how = "Instálalo con `python3 -m venv ~/.venv/suricata-check && "
        .. "~/.venv/suricata-check/bin/pip install suricata-check`.",
    }

  return bin
end

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

  -- suricata-check no lee stdin: hay que pasarle una ruta. Sin archivo en
  -- disco no hay nada que revisar. `available()` avisa una vez si falta el
  -- binario y devuelve false, así que no se ejecuta a ciegas.
  suricata_check = function(bufnr)
    return vim.api.nvim_buf_get_name(bufnr) ~= ""
      and suricata_check_bin().available()
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

  -- suricata-check no lo trae nvim-lint, así que se define entero. Detalles que
  -- no son opcionales, todos comprobados ejecutando la herramienta:
  --
  --   - No lee stdin: se le pasa la ruta con `-r`, de ahí `stdin = false`.
  --   - `-o` es obligatorio en la práctica. Su valor por defecto es `.`, y
  --     escribe ahí tres archivos (`suricata-check.jsonl`, `.log` y
  --     `-fast.log`); sin redirigirlo ensucia el directorio de reglas en cada
  --     guardado. Se mandan a la caché de Neovim.
  --   - Con la severidad por defecto (INFO) devuelve ~50 avisos por un fichero
  --     de cinco reglas, casi todos sugerencias de metadatos. `WARNING` deja lo
  --     accionable; para verlo todo, bajar a INFO aquí.
  --   - Colorea siempre, ignorando `NO_COLOR`, así que el parser quita ANSI.
  --   - Sale con 0 haya o no hallazgos.
  local cache = vim.fs.joinpath(vim.fn.stdpath "cache", "suricata-check")

  lint.linters.suricata_check = {
    cmd = function()
      return suricata_check_bin().command()
    end,
    stdin = false,
    append_fname = false,
    stream = "stdout",
    ignore_exitcode = true,
    args = {
      "-r",
      function()
        return vim.api.nvim_buf_get_name(0)
      end,
      "-o",
      function()
        vim.fn.mkdir(cache, "p")
        return cache
      end,
      "--log-level",
      "ERROR",
      "--issue-severity",
      "WARNING",
    },
    parser = function(output, bufnr)
      local severities = {
        ERROR = vim.diagnostic.severity.ERROR,
        WARNING = vim.diagnostic.severity.WARN,
        INFO = vim.diagnostic.severity.INFO,
        DEBUG = vim.diagnostic.severity.HINT,
      }
      local last = vim.api.nvim_buf_line_count(bufnr)
      local diagnostics = {}

      for line in vim.gsplit(output or "", "\n") do
        -- La herramienta colorea aunque no escriba a un tty.
        local clean = line:gsub("\27%[[%d;]*m", "")
        local code, level, first, final, message =
          clean:match "^%[(%w+)%]%s+%((%u+)%)%s+Lines%s+(%d+)%-(%d+),%s+sid%s+%S+:%s+(.+)$"

        if code then
          -- Las líneas vienen 1-indexadas y pueden apuntar fuera del buffer si
          -- el archivo cambió entre el guardado y el parseo.
          local lnum = math.min(tonumber(first) - 1, last - 1)
          local end_lnum = math.min(tonumber(final) - 1, last - 1)

          diagnostics[#diagnostics + 1] = {
            lnum = math.max(lnum, 0),
            end_lnum = math.max(end_lnum, 0),
            col = 0,
            end_col = 0,
            severity = severities[level] or vim.diagnostic.severity.INFO,
            source = "suricata-check",
            code = code,
            message = message,
          }
        end
      end

      return diagnostics
    end,
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
