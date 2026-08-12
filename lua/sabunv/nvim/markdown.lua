-- sabunv.nvim.markdown — resolución de enlaces y adjuntos en notas markdown.

-- Por qué existe: obsidian.nvim resuelve los adjuntos con una predicción
-- `attachments.folder` (p.ej. "assets"), que falla con rutas reales del vault
-- (subcarpetas, relativo con ../, nombres de carpeta distintos). Este módulo
-- resuelve la ruta real en el disco: relativa a la nota → relativa a la raíz →
-- búsqueda vault-wide por basename (como hace la app Obsidian). Es agnóstico
-- del plugin (sirve igual en buffers marksman o markdown.mdx).

local M = {}

local MEDIA_EXTENSIONS = {
  "avif", "bmp", "gif", "jpg", "jpeg", "png", "svg", "webp",
  "flac", "m4a", "mp3", "ogg", "wav", "webm", "3gp",
  "mkv", "mov", "mp4", "ogv",
  "pdf", "canvas",
}
local MEDIA_SET = {}
for _, ext in ipairs(MEDIA_EXTENSIONS) do
  MEDIA_SET[ext] = true
end

--- ¿El target es un adjunto (no una nota ni una URL)?
--- Usa la lista del plugin cuando está cargado; si no, la propia.
---@param target string
---@return boolean
local function is_attachment_path(target)
  local ok, obsidian = pcall(require, "obsidian")
  if ok and obsidian.api and obsidian.api.is_attachment_path then
    return obsidian.api.is_attachment_path(target)
  end
  local ext = target:match "%.([^%.]+)$"
  return ext ~= nil and MEDIA_SET[ext] ~= nil
end

--- ¿Es un vault (marker .obsidian o .nyabsidian) en este directorio?
---@param dir string
---@return boolean
local function is_vault_dir(dir)
  local obsidian = vim.uv.fs_stat(vim.fs.joinpath(dir, ".obsidian"))
  if obsidian and obsidian.type == "directory" then
    return true
  end
  local nyabsidian = vim.uv.fs_stat(vim.fs.joinpath(dir, ".nyabsidian"))
  return nyabsidian ~= nil and nyabsidian.type == "file"
end

--- Raíz del vault (marker .obsidian/.nyabsidian subiendo parents) o, si no,
--- del proyecto marksman (.marksman.toml/.git). Solo para buffers con nombre.
---@param bufnr integer
---@return string|? root
---@return boolean is_vault true si es un vault real (permite búsqueda vault-wide)
function M.root_of(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name ~= "" then
    local dir = vim.fs.dirname(name)
    while dir do
      if is_vault_dir(dir) then
        return vim.fs.normalize(dir), true
      end
      local parent = vim.fs.dirname(dir)
      if parent == dir then
        break
      end
      dir = parent
    end
  end

  local root = vim.fs.root(bufnr, { ".marksman.toml", ".git" })
  if root then
    return vim.fs.normalize(root), false
  end
  return nil, false
end

--- Resuelve el target de un enlace a la ruta real en disco, o nil.
--- Devuelve como segundo valor la lista de candidatos cuando la búsqueda
--- vault-wide es ambigua (varias coincidencias de basename).
---
---@param target string
---@param opts { bufnr?: integer, vault?: boolean }|? vault=false desactiva la
---  búsqueda vault-wide (útil cuando el llamador no quiere ambigüedad).
---@return string|? path
---@return string[]|? candidates
function M.resolve(target, opts)
  opts = opts or {}
  local bufnr = opts.bufnr or 0

  target = vim.fn.expand(vim.trim(target))
  if target == "" then
    return nil
  end

  -- URI (http, https, ...): no es un archivo local; se devuelve tal cual.
  if target:match "^[%a][%w%+%.%-]*://" then
    return target
  end

  -- Absoluto (o ya resuelto relativo al cwd).
  if vim.fn.isabsolutepath(target) == 1 then
    local s = vim.uv.fs_stat(target)
    if s and s.type == "file" then
      return target
    end
    return nil
  end

  local note_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
  local root, is_vault = M.root_of(bufnr)

  -- Relativo a la nota (permite ../ hacia niveles superiores).
  local p = vim.fs.normalize(vim.fs.joinpath(note_dir, target))
  local s = vim.uv.fs_stat(p)
  if s and s.type == "file" then
    return p
  end

  -- Relativo a la raíz del vault o del proyecto marksman.
  if root then
    p = vim.fs.normalize(vim.fs.joinpath(root, target))
    s = vim.uv.fs_stat(p)
    if s and s.type == "file" then
      return p
    end
  end

  -- Búsqueda vault-wide por basename, como la app Obsidian. Solo en vaults
  -- reales (en un proyecto marksman toda la carpeta sería candidata).
  if is_vault and opts.vault ~= false then
    local base = target:gsub("/+$", ""):match "([^/\\]+)$"
    if base then
      -- limit = math.huge: el default de vim.fs.find es 1 (primera
      -- coincidencia); aquí se necesitan todas para detectar ambigüedad.
      local matches = vim.fs.find({ base }, { path = root, type = "file", limit = math.huge })
      if #matches == 1 then
        return matches[1]
      elseif #matches > 1 then
        return nil, matches
      end
    end
  end

  return nil
end

--- Abre un enlace/adjunto de forma fiel a Obsidian:
--- URI → vim.ui.open; adjunto resuelto → vim.ui.open; ambigüedad vault-wide →
--- vim.ui.select con los candidatos.
---@param target string
---@param opts { bufnr?: integer }|?
---@return boolean handled true si se ha lanzado apertura o picker
function M.open(target, opts)
  opts = opts or {}
  local bufnr = opts.bufnr or 0

  if target:match "^[%a][%w%+%.%-]*://" then
    vim.ui.open(target)
    return true
  end

  local resolved, candidates = M.resolve(target, { bufnr = bufnr })
  if resolved then
    vim.ui.open(resolved)
    return true
  end

  if candidates and #candidates > 0 then
    vim.ui.select(candidates, {
      prompt = ("Abrir '%s': hay varias coincidencias"):format(vim.fs.basename(target)),
    }, function(choice)
      if choice then
        vim.ui.open(choice)
      end
    end)
    return true
  end

  return false
end

--- Target del enlace (wiki, markdown o autolink) que contiene la posición.
--- Devuelve el target tal cual (sin label `|x`, sin `!`); nil si no hay enlace.
---@param bufnr integer
---@param row integer 1-based
---@param col integer 0-based
---@return string|? target
function M.ref_target(bufnr, row, col)
  row = row or (vim.api.nvim_win_get_cursor(0))[1]
  col = col or (vim.api.nvim_win_get_cursor(0))[2]

  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
  if not line then
    return nil
  end

  -- Wiki: [[Algo]] / ![[x.png]] / [[x|label]]
  for start_col, inner, end_col in line:gmatch "()%[%[([^%[%]]*)%]%]()" do
    if start_col - 1 <= col and col < end_col - 1 then
      return inner:match "^([^|]+)" or inner
    end
  end

  -- Markdown: [label](target) / ![alt](x.png)
  for start_col, target, end_col in line:gmatch "()%[[^%]]*%]%(([^()%s]+)%)()" do
    if start_col - 1 <= col and col < end_col - 1 then
      return target
    end
  end

  -- Autolink: <https://...>
  for start_col, inner, end_col in line:gmatch "()<([^<>%s]+)>()" do
    if start_col - 1 <= col and col < end_col - 1 then
      if inner:match "^[%a][%w%+%.%-]*://" then
        return inner
      end
    end
  end

  return nil
end

return M
