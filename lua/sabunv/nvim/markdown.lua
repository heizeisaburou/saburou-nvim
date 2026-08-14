-- sabunv.nvim.markdown — resolución de enlaces y adjuntos en notas markdown.

-- Por qué existe: obsidian.nvim resuelve los adjuntos con una predicción
-- `attachments.folder` (p.ej. "assets"), que falla con rutas reales del vault
-- (subcarpetas, relativo con ../, nombres de carpeta distintos). Este módulo
-- resuelve la ruta real en el disco. Fuera de un vault usa las coordenadas de
-- Marksman (`/` raíz, `./` local, destino desnudo potencialmente ambiguo); el
-- ftplugin delega los vaults al resolvedor específico de Nyabsidian.

local M = {}

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
--- Devuelve como segundo valor la lista de candidatos cuando un destino
--- desnudo es ambiguo en el workspace.
---
---@param target string
---@param opts { bufnr?: integer }|?
---@return string|? path
---@return string[]|? candidates
function M.resolve(target, opts)
  opts = opts or {}
  local bufnr = opts.bufnr or 0

  target = vim.trim(target)
  if target == "" then
    return nil
  end

  -- URI (http, https, ...): no es un archivo local; se devuelve tal cual.
  if target:match "^[%a][%w%+%.%-]*://" then
    return target
  end
  local source_path = vim.api.nvim_buf_get_name(bufnr)
  local root = M.root_of(bufnr)
  if not root or source_path == "" then
    return nil
  end

  local matches = require("lzy.marksman.workspace").resolve(target, {
    source_path = source_path,
    root = root,
    all_files = true,
  })
  if #matches == 1 then
    return matches[1]
  elseif #matches > 1 then
    return nil, matches
  end
  return nil
end

--- Abre un enlace/adjunto de Markdown general:
--- URI → vim.ui.open; path textual → Neovim; binario → aplicación del sistema;
--- ambigüedad de workspace →
--- vim.ui.select con los candidatos.
---@param target string
---@param opts { bufnr?: integer }|?
---@return boolean handled true si se ha lanzado apertura o picker
function M.open(target, opts)
  opts = opts or {}
  local bufnr = opts.bufnr or 0
  local opener = require "sabunv.nvim.file_opener"

  if target:match "^[%a][%w%+%.%-]*://" then
    opener.open_external(target, { title = "Markdown" })
    return true
  end

  local resolved, candidates = M.resolve(target, { bufnr = bufnr })
  if resolved then
    opener.open_path(resolved, { title = "Markdown" })
    return true
  end

  if candidates and #candidates > 0 then
    vim.ui.select(candidates, {
      prompt = ("Abrir '%s': hay varias coincidencias"):format(vim.fs.basename(target)),
    }, function(choice)
      if choice then
        opener.open_path(choice, { title = "Markdown" })
      end
    end)
    return true
  end

  return false
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Rename de adjuntos (fiel a la app Obsidian)
-- ─────────────────────────────────────────────────────────────────────────────

local SCAN_EXTS = { md = true, canvas = true, mdown = true, qmd = true, markdown = true }

--- Ruta de `path` relativa a `from_dir`, bajando con `..` cuando hace falta.
--- vim.fs.relpath (nvim 0.12) solo calcula rutas bajo el base y devuelve nil
--- si el target está fuera (el soporte de `..` llegó en 0.13).
---@param path string
---@param from_dir string
---@return string
local function rel_path(path, from_dir)
  path = vim.fs.normalize(path)
  from_dir = vim.fs.normalize(from_dir)
  local function parts(p)
    local out = {}
    for comp in p:gmatch "[^/]+" do
      out[#out + 1] = comp
    end
    return out
  end
  local p, f = parts(path), parts(from_dir)
  local i = 1
  while p[i] and f[i] and p[i] == f[i] do
    i = i + 1
  end
  local out = {}
  for _ = i, #f do
    out[#out + 1] = ".."
  end
  for j = i, #p do
    out[#out + 1] = p[j]
  end
  if #out == 0 then
    return "."
  end
  return table.concat(out, "/")
end

--- Candidatos de reemplazo (texto viejo → texto nuevo) con los que un archivo
--- puede referenciar a un adjunto, ordenados del más específico al más corto.
---@param note_path string
---@param old_path string
---@param new_path string
---@param root string|?
---@return table[]
local function rename_segments(note_path, old_path, new_path, root)
  local segs = {}
  local function add(old_str, new_str)
    if not old_str or not new_str or old_str == "" then
      return
    end
    for _, s in ipairs(segs) do
      if s.old == old_str then
        return
      end
    end
    table.insert(segs, { old = old_str, new = new_str, bare = not old_str:find "/" })
  end
  local function add_pair(old_str, new_str)
    if not old_str or not new_str or old_str == "" then
      return
    end
    add(old_str, new_str)
    -- Variante urlencoded para enlaces markdown con %20, %C3%A1, ...
    local ok, util = pcall(require, "obsidian.util")
    if ok and util.urlencode then
      local eo = util.urlencode(old_str)
      if eo ~= old_str then
        add(eo, util.urlencode(new_str))
      end
    end
  end

  -- Relativa a la nota (y relativa a la raíz cuando la nota está en la raíz).
  local note_dir = vim.fs.dirname(note_path)
  add_pair(rel_path(old_path, note_dir), rel_path(new_path, note_dir))
  -- Relativa a la raíz del vault.
  if root then
    local rel = rel_path(old_path, root)
    if rel and not vim.startswith(rel, "..") then
      add_pair(rel, rel_path(new_path, root))
      add_pair("./" .. rel, "./" .. rel_path(new_path, root))
    end
  end
  -- Basename: wiki [[x]], embeds y markdown ](x).
  add_pair(vim.fs.basename(old_path), vim.fs.basename(new_path))

  table.sort(segs, function(a, b)
    return #a.old > #b.old
  end)
  return segs
end

--- ¿La ocurrencia (st, ed) de un segmento en `line` forma parte de un enlace?
--- Las rutas relativas valen si no están pegadas a más caracteres de ruta; el
--- basename pelado solo dentro de [[...]] (wiki/embed) o tras "](" (markdown),
--- para no tocar menciones en prosa.
---@param line string
---@param st integer
---@param ed integer
---@param seg table
---@return boolean
local function plausible_link(line, st, ed, seg)
  if not seg.bare then
    local prev = line:sub(st - 1, st - 1)
    local next = line:sub(ed + 1, ed + 1)
    if prev:match "[%w_%.%/%\\%-]" or next:match "[%w_%.%/%\\%-]" then
      return false
    end
    return true
  end
  if line:sub(1, st - 1):match "%[%[[^%]]*$" and line:find("]]", ed + 1, true) then
    return true
  end
  return line:sub(st - 2, st - 1) == "]("
end

--- Renombra un adjunto (imagen/audio/pdf/...) de forma fiel a Obsidian: mueve
--- el archivo en disco y construye un WorkspaceEdit que actualiza los enlaces
--- del vault completo (wiki [[x]], embeds, markdown relativos, canvas). La
--- extensión se conserva si el nombre nuevo no la trae (foto → foto.png).
---
--- Uso: solo la resuelve el parche del LSP (`Obsidian rename` con el cursor
--- sobre un adjunto); el plugin no renombra lo que no es una nota .md.
---
---@param target string target del enlace bajo el cursor (parse_link/ref_target)
---@param new_name string nombre nuevo (basename)
---@param opts { bufnr?: integer }|?
---@return lsp.WorkspaceEdit|? edit nil si no se puede renombrar
---@return string|? err motivo del fallo
function M.rename_attachment(target, new_name, opts)
  opts = opts or {}
  local bufnr = opts.bufnr or 0

  new_name = vim.trim(new_name)
  if new_name == "" or new_name == "." or new_name == ".." or new_name:find "[/\\]" then
    return nil, ("nombre inválido: '%s'"):format(new_name)
  end

  local old = M.resolve(target, { bufnr = bufnr })
  if not old then
    return nil, ("no se encuentra el adjunto '%s'"):format(target)
  end
  if type(old) == "table" then
    return nil, ("'%s' es ambiguo (%d coincidencias en el vault)"):format(target, #old)
  end

  local ext = vim.fn.fnamemodify(old, ":e")
  local new_base = new_name
  if vim.fn.fnamemodify(new_name, ":e") == "" and ext ~= "" then
    new_base = new_base .. "." .. ext
  end
  local new_path = vim.fs.normalize(vim.fs.joinpath(vim.fs.dirname(old), new_base))

  if new_path == old then
    return nil, ("el adjunto ya se llama '%s'"):format(new_base)
  end
  if vim.uv.fs_stat(new_path) then
    return nil, ("ya existe: %s"):format(new_path)
  end

  -- Archivos del vault que pueden referenciar al adjunto.
  local root = M.root_of(bufnr)
  local files = {}
  local function walk(dir)
    local ok_iter, iter = pcall(vim.fs.dir, dir)
    if not ok_iter then
      return
    end
    for name in iter do
      local p = vim.fs.joinpath(dir, name)
      local s = vim.uv.fs_stat(p)
      if s then
        if s.type == "directory" then
          if not vim.startswith(name, ".") then
            walk(p)
          end
        elseif s.type == "file" then
          local ext2 = p:match "%.([^%.]+)$"
          if ext2 and SCAN_EXTS[ext2:lower()] then
            files[#files + 1] = p
          end
        end
      end
    end
  end
  walk(root or vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)))

  local has_nvim_0_12 = vim.fn.has "nvim-0.12.0" == 1
  local documentChanges = {}

  for _, file in ipairs(files) do
    local segs = rename_segments(file, old, new_path, root)
    local fh = io.open(file, "rb")
    if fh then
      local content = fh:read "*a"
      fh:close()

      local edits = {}
      local line_no = 0
      for raw in (content .. "\n"):gmatch("(.-)\n") do
        local line = raw:gsub("\r$", "")
        line_no = line_no + 1
        local n = 1
        while n <= #line do
          -- Primera ocurrencia más cercana entre todos los segmentos; a igual
          -- posición gana el más largo (la ruta más específica).
          local best
          for _, seg in ipairs(segs) do
            local st, ed = line:find(seg.old, n, true)
            if st and (not best or st < best.st or (st == best.st and #seg.old > #best.seg.old)) then
              best = { st = st, ed = ed, seg = seg }
            end
          end
          if not best then
            break
          end
          if plausible_link(line, best.st, best.ed, best.seg) then
            edits[#edits + 1] = {
              range = {
                start = { line = line_no - 1, character = best.st - 1 },
                ["end"] = { line = line_no - 1, character = best.ed },
              },
              newText = best.seg.new,
            }
            n = best.ed + 1
          else
            n = best.st + 1
          end
        end
      end

      if #edits > 0 then
        documentChanges[#documentChanges + 1] = {
          textDocument = {
            uri = vim.uri_from_fname(file),
            version = has_nvim_0_12 and vim.NIL or nil,
          },
          edits = edits,
        }
      end
    end
  end

  documentChanges[#documentChanges + 1] = {
    kind = "rename",
    oldUri = vim.uri_from_fname(old),
    newUri = vim.uri_from_fname(new_path),
    options = {},
  }

  return { documentChanges = documentChanges }, nil
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

  -- Referencias CommonMark: tanto la declaración como sus tres formas de uso
  -- comparten el destino declarado. El parser mantiene id, path, fragment y
  -- descripción como componentes separados.
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local ok_parser, parser = pcall(require, "lzy.marksman.parser")
  if ok_parser then
    local ref = parser.at(lines, row - 1, col)
    if ref then
      if ref.kind == "reference_definition" then
        return ref.raw_target
      elseif ref.kind == "reference_use" and ref.definition then
        return ref.definition.raw_target
      end
    end
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
