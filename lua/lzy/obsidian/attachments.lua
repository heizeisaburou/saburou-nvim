-- Adaptador Obsidian para adjuntos locales.
--
-- No decide cómo funcionan los enlaces de Marksman. Sólo traduce las
-- operaciones del LSP in-process de obsidian.nvim al resolver de archivos que
-- ya existe mientras ese resolver termina de independizarse.

local M = {}

local NOTE_EXTENSIONS = {
  md = true,
  markdown = true,
  mdown = true,
  mkdn = true,
  mkd = true,
  qmd = true,
  rmd = true,
  base = true,
}

---@param location string
---@return string
function M.strip_fragments(location)
  local util = require("obsidian.util")
  location = util.strip_block_links(location)
  location = util.strip_anchor_links(location)
  return location
end

--- Obsidian permite que plugins enlacen tipos nuevos. Por eso cualquier target
--- local con extensión que no sea una nota se considera adjunto, además de la
--- lista multimedia conocida por obsidian.nvim.
---@param location string
---@return boolean
function M.is_target(location)
  local util = require("obsidian.util")
  local api = require("obsidian.api")

  location = M.strip_fragments(location)
  if location == "" or util.is_uri(location) then
    return false
  end
  if api.is_attachment_path(location) then
    return true
  end

  local ext = location:match("%.([^./\\]+)$")
  return ext ~= nil and not NOTE_EXTENSIONS[ext:lower()]
end

--- Abre un adjunto si el resolver Obsidian encuentra uno. Devuelve false para
--- que el llamador pueda continuar con el handler upstream cuando no existe.
---@param location string
---@param opts { bufnr?: integer, callback?: function }|?
---@return boolean handled
function M.follow(location, opts)
  opts = opts or {}
  location = M.strip_fragments(location)
  if not M.is_target(location) then
    return false
  end

  local md = require("sabunv.nvim.markdown")
  local handled = md.open(location, { bufnr = opts.bufnr or vim.api.nvim_get_current_buf() })
  if handled and opts.callback then
    opts.callback(nil, {})
  end
  return handled
end

--- Construye el WorkspaceEdit de rename/move de un adjunto.
---@param location string
---@param new_name string
---@param opts { bufnr?: integer }|?
---@return lsp.WorkspaceEdit|? edit
---@return string|? err
function M.rename(location, new_name, opts)
  opts = opts or {}
  location = M.strip_fragments(location)
  if not M.is_target(location) then
    return nil, nil
  end
  return require("sabunv.nvim.markdown").rename_attachment(location, new_name, {
    bufnr = opts.bufnr or vim.api.nvim_get_current_buf(),
  })
end

return M
