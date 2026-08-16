-- Llevar los enlaces ya escritos de un proyecto Markdown a su forma canónica.
--
-- El equivalente de `:NyabsidianRelink` fuera de un vault, y con una vuelta de
-- tuerca: aquí la forma canónica **la decide el proyecto**. `.marksman.toml`
-- puede pedir `file-stem` (`[[Mi nota]]`) o dejar el default `title-slug`
-- (`[[mi-nota]]`), así que la misma nota se escribe distinto según el proyecto
-- y este comando reescribe hacia lo que ese proyecto haya declarado. Ver
-- `lzy.marksman.workspace.canonical_target`.
--
-- Lo que NUNCA se toca: enlaces externos, y enlaces que no resuelven o que
-- resuelven a más de una cosa. En una pasada que reescribe ficheros, no saber
-- es razón para no tocar.

local M = {}

---@param path string
---@return string[]
local function read_lines(path)
  local bufnr = vim.fn.bufnr(path)
  if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or {}
end

---@param path string
---@return boolean
local function is_external(path)
  return path:match "^[%a][%w+.-]*:" ~= nil and path:match "^%a:[/\\]" == nil
end

--- Los refs con destino de un fichero, saltándose bloques de código.
---@param path string
---@return table[]
local function target_refs(path)
  local parser = require "lzy.marksman.parser"
  local lines = read_lines(path)
  local excluded = parser.excluded_rows(lines)
  local out = {}
  for idx, line in ipairs(lines) do
    if not excluded[idx - 1] then
      local definition = parser.definition(line, idx - 1)
      if definition then
        out[#out + 1] = definition
      else
        for _, ref in ipairs(parser.links(line, idx - 1)) do
          if ref.kind == "inline" or ref.kind == "wiki" then
            out[#out + 1] = ref
          end
        end
      end
    end
  end
  return out
end

---@class marksman.RelinkPlan
---@field changes table<string, lsp.TextEdit[]>
---@field count integer
---@field files integer

---@param opts { root: string }
---@return marksman.RelinkPlan|nil plan
---@return string|nil err
function M.plan(opts)
  local root = opts and opts.root and vim.fs.normalize(opts.root) or nil
  if not root then
    return nil, "no hay proyecto Marksman activo"
  end

  local workspace = require "lzy.marksman.workspace"
  local changes, count, files = {}, 0, 0

  for _, source_path in ipairs(workspace.files(root, { markdown = true })) do
    local edits = {}
    for _, ref in ipairs(target_refs(source_path)) do
      local written = ref.path
      if written and written ~= "" and not is_external(written) and ref.path_range then
        local matches = workspace.resolve(written, { source_path = source_path, root = root })
        if #matches == 1 then
          local canonical =
            workspace.canonical_target(matches[1], root, ref.kind, source_path)
          if canonical and canonical ~= written then
            edits[#edits + 1] = {
              range = {
                start = { line = ref.range.start_row, character = ref.path_range.start_col },
                ["end"] = { line = ref.range.start_row, character = ref.path_range.end_col },
              },
              newText = canonical,
            }
            count = count + 1
          end
        end
      end
    end

    if #edits > 0 then
      -- De atrás hacia adelante: si no, cada edición desplaza las columnas de
      -- las siguientes de su misma línea.
      table.sort(edits, function(a, b)
        if a.range.start.line == b.range.start.line then
          return a.range.start.character > b.range.start.character
        end
        return a.range.start.line > b.range.start.line
      end)
      changes[source_path] = edits
      files = files + 1
    end
  end

  return { changes = changes, count = count, files = files }
end

---@param plan marksman.RelinkPlan
---@return lsp.WorkspaceEdit
function M.workspace_edit(plan)
  local documentChanges = {}
  for path, edits in pairs(plan.changes) do
    documentChanges[#documentChanges + 1] = {
      textDocument = { uri = vim.uri_from_fname(path), version = vim.NIL },
      edits = edits,
    }
  end
  return { documentChanges = documentChanges }
end

---@param opts { bufnr?: integer, root?: string, notify?: fun(msg: string, level?: integer), confirm?: fun(prompt: string): boolean }|?
function M.run(opts)
  opts = opts or {}
  local notify = opts.notify
    or function(msg, level)
      vim.notify(msg, level or vim.log.levels.INFO, { title = "Marksman" })
    end

  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local root = opts.root or require("lzy.marksman.workspace").root(bufnr)
  if not root then
    return notify("Este buffer no pertenece a ningún proyecto", vim.log.levels.ERROR)
  end

  local plan, err = M.plan { root = root }
  if not plan then
    return notify(err or "no se pudo planificar", vim.log.levels.ERROR)
  end
  if plan.count == 0 then
    return notify "Los enlaces ya están en su forma canónica"
  end

  local style = require("lzy.marksman.workspace").wiki_style(root)
  local prompt = ("Reescribir %d enlace(s) en %d fichero(s)? (estilo wiki: %s)"):format(
    plan.count,
    plan.files,
    style
  )
  local accepted = opts.confirm and opts.confirm(prompt)
    or (not opts.confirm and vim.fn.confirm(prompt, "&Sí\n&No", 2) == 1)
  if not accepted then
    return notify("Sin cambios", vim.log.levels.WARN)
  end

  vim.lsp.util.apply_workspace_edit(M.workspace_edit(plan), "utf-8")
  vim.schedule(function()
    vim.cmd "silent! wall"
  end)
  notify(("Reescritos %d enlace(s) en %d fichero(s)"):format(plan.count, plan.files))
end

return M
