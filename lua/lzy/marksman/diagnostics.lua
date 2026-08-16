-- Enlaces que no existen bajo NUESTRO criterio, fuera de un vault.
--
-- El servidor ya diagnostica enlaces rotos, pero su criterio y el nuestro no
-- coinciden, y el desajuste va en las dos direcciones:
--
--   * Él marca cosas que sí resolvemos (indexa por título y por nombre exacto,
--     nosotros perdonamos caja, escapes y guiones). Eso lo filtra
--     `lzy.marksman.publish_diagnostics`.
--   * Y **no** marca cosas que no resolvemos: para él `[[una-nota]]` es válido
--     si el H1 de alguna nota dice `# Una nota`, aunque no exista ningún
--     fichero que se llame así. Para nosotros la identidad es el nombre del
--     fichero, así que ese enlace no lleva a ninguna parte -- y sin este
--     módulo no lo avisaba nadie: dejaba de seguirse, en silencio.
--
-- Namespace propio, para no pelearse con los suyos.

local M = {}

local NS = vim.api.nvim_create_namespace "marksman-links"
local DEBOUNCE_MS = 250
local timers = {}

---@param path string
---@return boolean
local function is_external(path)
  return path:match "^[%a][%w+.-]*:" ~= nil and path:match "^%a:[/\\]" == nil
end

---@param bufnr integer
---@return vim.Diagnostic[]
local function collect(bufnr)
  local workspace = require "lzy.marksman.workspace"
  local parser = require "lzy.marksman.parser"

  local root = workspace.root(bufnr)
  local source_path = vim.api.nvim_buf_get_name(bufnr)
  if not root or source_path == "" then
    return {}
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local excluded = parser.excluded_rows(lines)
  local out = {}

  for idx, line in ipairs(lines) do
    if not excluded[idx - 1] then
      local definition = parser.definition(line, idx - 1)
      local refs = definition and { definition } or parser.links(line, idx - 1)
      for _, ref in ipairs(refs) do
        local target = ref.path
        if
          target
          and target ~= ""
          and ref.path_range
          and not is_external(target)
          and not target:match "^#"
        then
          local ok, matches = pcall(workspace.resolve, target, {
            source_path = source_path,
            root = root,
          })
          -- La ambigüedad también es nuestra: la del servidor se filtra entera
          -- (ver lzy.marksman.resolvable_elsewhere) porque él la mide contra los
          -- títulos y nosotros contra los nombres. Una sola voz.
          local message
          if ok and #matches == 0 then
            message = ("No existe ninguna nota '%s'"):format(target)
          elseif ok and #matches > 1 then
            message = ("'%s' es ambiguo: %d notas responden a ese nombre"):format(
              target,
              #matches
            )
          end
          if message then
            out[#out + 1] = {
              lnum = ref.range.start_row,
              col = ref.path_range.start_col,
              end_lnum = ref.range.start_row,
              end_col = ref.path_range.end_col,
              severity = vim.diagnostic.severity.WARN,
              source = "marksman-nyabsidian",
              message = message,
            }
          end
        end
      end
    end
  end

  return out
end

---@param bufnr integer
local function refresh(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  -- Dentro de un vault manda lzy.obsidian.diagnostics; aquí sólo markdown
  -- suelto, que es donde vive marksman.
  local ok_vault, attachments = pcall(require, "lzy.obsidian.attachments")
  if ok_vault and attachments.in_vault(bufnr) then
    return vim.diagnostic.set(NS, bufnr, {})
  end

  local ok, diagnostics = pcall(collect, bufnr)
  vim.diagnostic.set(NS, bufnr, ok and diagnostics or {})
end

---@param bufnr integer
function M.schedule(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  local existing = timers[bufnr]
  if existing then
    existing:stop()
    existing:close()
  end
  local timer = (vim.uv or vim.loop).new_timer()
  timers[bufnr] = timer
  timer:start(
    DEBOUNCE_MS,
    0,
    vim.schedule_wrap(function()
      timers[bufnr] = nil
      refresh(bufnr)
    end)
  )
end

---@param bufnr integer
function M.clear(bufnr)
  local timer = timers[bufnr]
  if timer then
    timer:stop()
    timer:close()
    timers[bufnr] = nil
  end
  if vim.api.nvim_buf_is_valid(bufnr) then
    vim.diagnostic.set(NS, bufnr, {})
  end
end

local installed = false

function M.setup()
  if installed then
    return
  end
  installed = true

  local group = vim.api.nvim_create_augroup("marksman_diagnostics", { clear = true })
  local pattern = { "*.md", "*.markdown", "*.mdx" }

  -- Sin debounce y por separado: la caché de ficheros tiene que quedar
  -- invalidada ANTES de que corra el refresh, sea cual sea el orden en que se
  -- registren los autocmds.
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = pattern,
    callback = function()
      pcall(require("lzy.marksman.workspace").invalidate_files)
    end,
  })

  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave", "TextChanged" }, {
    group = group,
    pattern = pattern,
    callback = function(ev)
      M.schedule(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    pattern = pattern,
    callback = function(ev)
      M.clear(ev.buf)
    end,
  })
end

-- API pequeña para pruebas.
M.refresh = refresh
M.collect = collect

return M
