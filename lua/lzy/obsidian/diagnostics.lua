-- Diagnóstico de "nota inexistente" junto al enlace.
--
-- obsidian-ls (el LSP embebido de obsidian.nvim) no publica diagnósticos:
-- quien marcaba los `[[NAME]]` rotos era marksman, y la conmutación
-- marksman <-> obsidian-ls (ver init.lua) lo desconecta dentro del vault
-- porque ahí sobra para todo lo demás (definition/hover/completion/rename).
-- Sin marksman en el buffer, ese "esta nota no existe" dejó de verse.
--
-- Este módulo repone solo eso, sin depender de qué LSP esté activo: escanea
-- los mismos refs que follow_link/rename (lzy.obsidian.attachments), resuelve
-- cada target con el mismo motor (lzy.obsidian.notes) y marca con
-- vim.diagnostic los que no tienen nota. Nada de colores custom por ahora.

local M = {}

local NS = vim.api.nvim_create_namespace "nyabsidian.diagnostics"
local DEBOUNCE_MS = 400

---@type table<integer, uv.uv_timer_t>
local timers = {}
---@type table<integer, integer>
local generations = {}

--- Igual que `vim.b[bufnr].obsidian_buffer`, pero sin depender de que el
--- FileType/BufEnter de obsidian.nvim ya haya corrido: consulta el mismo
--- workspace lookup que usa link_actions.lua, así que también funciona nada
--- más abrir el buffer (o en tests que no montan el pipeline de filetype).
---@param bufnr integer
---@return boolean
local function in_vault(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" then
    return false
  end
  local ok, ws = pcall(require("obsidian.api").find_workspace, name)
  return ok and ws ~= nil
end

---@param bufnr integer
---@return { range: table, target: string }[]
local function note_refs(bufnr)
  local attachments = require "lzy.obsidian.attachments"
  local util = require "obsidian.util"
  local out = {}

  for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    for _, ref in ipairs(attachments.parse_refs(line, row - 1)) do
      if
        (ref.kind == "wiki" or ref.kind == "markdown")
        and not util.is_uri(ref.target)
        and not attachments.is_target(ref.target, { bufnr = bufnr })
      then
        local target = vim.uri_decode(ref.target) or ref.target
        target = util.unescape_single_backslash(target)
        target = attachments.strip_fragments(target)
        if target ~= "" then
          out[#out + 1] = { range = ref.range, target_range = ref.target_range, target = target }
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
  if not in_vault(bufnr) then
    return vim.diagnostic.set(NS, bufnr, {})
  end

  local ok, refs = pcall(note_refs, bufnr)
  if not ok or #refs == 0 then
    return vim.diagnostic.set(NS, bufnr, {})
  end

  local gen = (generations[bufnr] or 0) + 1
  generations[bufnr] = gen

  ---@type table<string, table[]>
  local by_target = {}
  for _, ref in ipairs(refs) do
    local list = by_target[ref.target]
    if not list then
      list = {}
      by_target[ref.target] = list
    end
    list[#list + 1] = { range = ref.range, target_range = ref.target_range }
  end

  local pending = 0
  for _ in pairs(by_target) do
    pending = pending + 1
  end

  local diagnostics = {}
  local function finish()
    pending = pending - 1
    if pending > 0 then
      return
    end
    if not vim.api.nvim_buf_is_valid(bufnr) or generations[bufnr] ~= gen then
      return
    end
    vim.diagnostic.set(NS, bufnr, diagnostics)
  end

  local notes = require "lzy.obsidian.notes"
  for target, locations in pairs(by_target) do
    local resolve_ok = pcall(notes.resolve_async, target, function(found)
      if #found == 0 then
        for _, loc in ipairs(locations) do
          diagnostics[#diagnostics + 1] = {
            lnum = loc.range.start_row,
            col = loc.target_range.start_col,
            end_lnum = loc.range.end_row,
            end_col = loc.target_range.end_col,
            severity = vim.diagnostic.severity.WARN,
            source = "nyabsidian",
            message = ("La nota '%s' no existe todavía"):format(target),
          }
        end
      end
      finish()
    end)
    if not resolve_ok then
      finish()
    end
  end
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
  generations[bufnr] = (generations[bufnr] or 0) + 1
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

  local group = vim.api.nvim_create_augroup("nyabsidian_diagnostics", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "InsertLeave", "TextChanged" }, {
    group = group,
    pattern = { "*.md", "*.markdown", "*.qmd", "*.mdx" },
    callback = function(ev)
      M.schedule(ev.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufUnload", {
    group = group,
    pattern = { "*.md", "*.markdown", "*.qmd", "*.mdx" },
    callback = function(ev)
      M.clear(ev.buf)
    end,
  })
end

-- API pequeña para pruebas.
M.refresh = refresh

return M
