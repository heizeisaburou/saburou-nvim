-- Identidad, apertura y refactor de adjuntos dentro de un vault Obsidian.
-- Este módulo no conoce Marksman ni usa `attachments.folder` para resolver
-- enlaces existentes: esa opción sólo gobierna dónde se añaden archivos.

local M = {}

local uv = vim.uv or vim.loop
local HAS_NVIM_012 = vim.fn.has "nvim-0.12.0" == 1

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

local REFERENCE_EXTENSIONS = vim.tbl_extend("force", {}, NOTE_EXTENSIONS, { canvas = true })

local DEFAULT_PATH_POLICY = { vault = "preserve", external = "preserve" }
local workspace_path_policies = {}

---@param path string|table Acepta también `obsidian.Path` mediante su `__tostring`.
---@param real boolean|?
---@return string
local function normalize(path, real)
  path = vim.fs.normalize(tostring(path))
  return real == false and path or vim.fs.normalize(uv.fs_realpath(path) or path)
end

---@param path string
---@return boolean
local function is_file(path)
  local stat = uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

---@param path string
---@param root string|table
---@return boolean
local function inside(path, root)
  path, root = normalize(path, false), normalize(root, false)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

---@param dir string
---@return boolean
local function has_vault_marker(dir)
  local obsidian = uv.fs_stat(vim.fs.joinpath(dir, ".obsidian"))
  local nyabsidian = uv.fs_stat(vim.fs.joinpath(dir, ".nyabsidian"))
  return obsidian ~= nil and obsidian.type == "directory"
    or nyabsidian ~= nil and nyabsidian.type == "file"
end

---@param path string
---@param from_dir string
---@return string
local function relative_path(path, from_dir)
  path, from_dir = normalize(path, false), normalize(from_dir, false)
  local function parts(value)
    local out = {}
    for part in value:gmatch "[^/]+" do
      out[#out + 1] = part
    end
    return out
  end

  local target, source = parts(path), parts(from_dir)
  local idx = 1
  while target[idx] and source[idx] and target[idx] == source[idx] do
    idx = idx + 1
  end

  local out = {}
  for _ = idx, #source do
    out[#out + 1] = ".."
  end
  for current = idx, #target do
    out[#out + 1] = target[current]
  end
  return #out == 0 and "." or table.concat(out, "/")
end

---@param opts { bufnr?: integer, source_path?: string, root?: string }|?
---@return { bufnr: integer, source_path: string, source_dir: string, root: string }|?
local function context(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local source_path = opts.source_path or vim.api.nvim_buf_get_name(bufnr)
  if source_path == "" then
    return nil
  end
  source_path = normalize(source_path)

  local root = opts.root
  if not root then
    if not rawget(_G, "Obsidian") then
      return nil
    end
    local ok_api, api = pcall(require, "obsidian.api")
    if not ok_api then
      return nil
    end
    local workspace = api.find_workspace(source_path)
    root = workspace and tostring(workspace.root) or nil
  end
  if not root then
    return nil
  end
  root = normalize(root)
  if not inside(source_path, root) then
    return nil
  end

  return {
    bufnr = bufnr,
    source_path = source_path,
    source_dir = vim.fs.dirname(source_path),
    root = root,
  }
end

---@param bufnr integer|?
---@return boolean
function M.in_vault(bufnr)
  return context { bufnr = bufnr or vim.api.nvim_get_current_buf() } ~= nil
end

---@class nyabsidian.AttachmentPathPolicy
---@field vault "preserve"|"simplify"
---@field external "preserve"|"absolute"

---@param root string|table
---@param nyabsidian table|nil Contenido de la clave propia `nyabsidian`.
---@return boolean ok
---@return string|? err
function M.configure(root, nyabsidian)
  root = normalize(root)
  workspace_path_policies[root] = vim.deepcopy(DEFAULT_PATH_POLICY)
  if nyabsidian ~= nil and type(nyabsidian) ~= "table" then
    return false, "nyabsidian debe ser una tabla"
  end
  nyabsidian = nyabsidian or {}
  for key in pairs(nyabsidian) do
    if key ~= "attachment_paths" then
      return false, ("nyabsidian.%s no es una opción reconocida"):format(key)
    end
  end

  local configured = nyabsidian.attachment_paths or {}
  if type(configured) ~= "table" then
    return false, "nyabsidian.attachment_paths debe ser una tabla"
  end
  for key in pairs(configured) do
    if key ~= "vault" and key ~= "external" then
      return false, ("nyabsidian.attachment_paths.%s no es una opción reconocida"):format(key)
    end
  end
  if
    configured.vault ~= nil
    and configured.vault ~= "preserve"
    and configured.vault ~= "simplify"
  then
    return false, "nyabsidian.attachment_paths.vault debe ser 'preserve' o 'simplify'"
  end
  if
    configured.external ~= nil
    and configured.external ~= "preserve"
    and configured.external ~= "absolute"
  then
    return false, "nyabsidian.attachment_paths.external debe ser 'preserve' o 'absolute'"
  end

  workspace_path_policies[root] = vim.tbl_extend("force", {}, DEFAULT_PATH_POLICY, configured)
  return true
end

---@param root string|table
---@return nyabsidian.AttachmentPathPolicy
function M.path_policy(root)
  return workspace_path_policies[normalize(root)] or DEFAULT_PATH_POLICY
end

---@param dir string
---@param root string
---@param callback fun(path: string)
---@param opts { raw?: boolean }|? `raw = true` salta el `uv.fs_realpath()` por
---archivo que hace `normalize()` (una syscall cada uno) y solo aplica
---`vim.fs.normalize()` (puro manejo de strings, sin tocar disco). Para
---adjuntos importa tener la ruta real (symlinks resueltos, para dedupear
---identidad de archivo); para indexar contenido de notas (lzy.obsidian.
---notes) no hace falta -- y en un vault
---de ~1600 archivos, esa syscall de más terminó siendo la mayoría del
---tiempo real (perfilado con jit.p: ~76% del tiempo en normalize()/fs.*).
local function walk_files(dir, root, callback, opts)
  local ok, iterator = pcall(vim.fs.dir, dir)
  if not ok then
    return
  end

  local ignore = require "obsidian.ignore"
  for name, kind in iterator do
    local path = vim.fs.joinpath(dir, name)
    if kind == "directory" then
      local relative = vim.fs.relpath(root, path) or path
      if
        not vim.startswith(name, ".")
        and not has_vault_marker(path)
        and not ignore.is_ignored_dir(relative)
      then
        walk_files(path, root, callback, opts)
      end
    elseif kind == "file" and not vim.startswith(name, ".") and not ignore.is_ignored(path) then
      callback((opts and opts.raw) and vim.fs.normalize(path) or normalize(path))
    end
  end
end

---@class nyabsidian.AttachmentIndex
---@field by_basename table<string, string[]>
---@field references string[]
---@field files string[]

---@param root string
---@return nyabsidian.AttachmentIndex
local function build_index(root)
  local index = { by_basename = {}, references = {}, files = {} }
  walk_files(root, root, function(path)
    local basename = vim.fs.basename(path):lower()
    index.by_basename[basename] = index.by_basename[basename] or {}
    index.by_basename[basename][#index.by_basename[basename] + 1] = path
    index.files[#index.files + 1] = path

    local ext = path:match "%.([^./]+)$"
    if ext and REFERENCE_EXTENSIONS[ext:lower()] then
      index.references[#index.references + 1] = path
    end
  end)
  return index
end

---@param root string
---@param basename string
---@param opts { exclude?: string, include?: string, index?: nyabsidian.AttachmentIndex }|?
---@return string[]
local function basename_matches(root, basename, opts)
  opts = opts or {}
  basename = basename:lower()
  local exclude = opts.exclude and normalize(opts.exclude, false) or nil
  local found, matches = {}, {}
  local function collect(path)
    if
      vim.fs.basename(path):lower() == basename
      and normalize(path, false) ~= exclude
      and not found[path]
    then
      found[path] = true
      matches[#matches + 1] = path
    end
  end
  if opts.index then
    for _, path in ipairs(opts.index.by_basename[basename] or {}) do
      collect(path)
    end
  else
    walk_files(root, root, collect)
  end
  if opts.include and inside(opts.include, root) then
    collect(normalize(opts.include, false))
  end
  return matches
end

---@param candidates string[]
---@param source_dir string
---@return string[]
local function best_match_order(candidates, source_dir)
  local indexed = {}
  for position, path in ipairs(candidates) do
    indexed[#indexed + 1] = {
      path = path,
      local_to_source = inside(path, source_dir),
      position = position,
    }
  end
  table.sort(indexed, function(a, b)
    if a.local_to_source ~= b.local_to_source then
      return a.local_to_source
    elseif #a.path ~= #b.path then
      return #a.path < #b.path
    end
    -- JavaScript sort es estable: ante paths de igual longitud la app conserva
    -- el orden de indexación del vault.
    return a.position < b.position
  end)
  return vim.tbl_map(function(item)
    return item.path
  end, indexed)
end

--- Expuestos para que otros módulos (lzy.obsidian.notes) puedan construir
--- su propio índice de un
--- solo recorrido del vault sin reimplementar las reglas de ignorados
--- (`.obsidian`/`.nyabsidian` como límite, `obsidian.ignore`, dotfiles).
M.walk_files = walk_files
M.NOTE_EXTENSIONS = NOTE_EXTENSIONS
-- `M.is_target`/`M.resolve` reconstruyen este índice completo del vault
-- (con una syscall de realpath por archivo, vía walk_files) cada vez que
-- se les llama SIN `opts.index`. Expuesto para que callers que preguntan
-- por muchos targets seguidos (diagnostics.lua) construyan uno solo y lo
-- reusen -- mismo patrón que ya usa M.rename() internamente.
M.build_index = build_index

---@param location string
---@return string
function M.strip_fragments(location)
  local util = require "obsidian.util"
  location = util.strip_block_links(location)
  location = util.strip_anchor_links(location)
  return location
end

---@param target string
---@return string|? path
local function file_uri(target)
  if target:match "^file://" then
    local ok, path = pcall(vim.uri_to_fname, target)
    return ok and path or nil
  end
end

---@class nyabsidian.AttachmentResolved
---@field status "resolved"
---@field path string
---@field root string
---@field source_path string
---@field external boolean
---@field candidates string[]|? Candidatos ya ordenados como la app.

---@class nyabsidian.AttachmentMissing
---@field status "missing"
---@field target string
---@field reason string
---@field root string|?
---@field source_path string|?

---@param target string
---@param opts { bufnr?: integer, source_path?: string, root?: string, format?: string, index?: nyabsidian.AttachmentIndex }|?
---@return nyabsidian.AttachmentResolved|nyabsidian.AttachmentMissing
function M.resolve(target, opts)
  opts = opts or {}
  local ctx = context(opts)
  target = M.strip_fragments(target or "")
  target = vim.uri_decode(target) or target
  target = require("obsidian.util").unescape_single_backslash(target)

  if not ctx then
    return { status = "missing", target = target, reason = "el buffer no pertenece a un vault" }
  end
  if target == "" then
    return {
      status = "missing",
      target = target,
      reason = "el enlace no contiene un archivo",
      root = ctx.root,
      source_path = ctx.source_path,
    }
  end

  local is_uri, scheme = require("obsidian.util").is_uri(target)
  if is_uri and scheme ~= "file" then
    return {
      status = "missing",
      target = target,
      reason = "el target es una URI externa, no un adjunto local",
      root = ctx.root,
      source_path = ctx.source_path,
    }
  end

  local index = opts.index
  local explicit_file = file_uri(target)
  local candidate
  if explicit_file then
    candidate = normalize(explicit_file, false)
  elseif vim.fn.isabsolutepath(target) == 1 then
    candidate = normalize(target, false)
  elseif vim.startswith(target, "./") or vim.startswith(target, "../") then
    candidate = normalize(vim.fs.joinpath(ctx.source_dir, target), false)
  end

  if candidate then
    if is_file(candidate) then
      candidate = normalize(candidate)
      return {
        status = "resolved",
        path = candidate,
        root = ctx.root,
        source_path = ctx.source_path,
        external = not inside(candidate, ctx.root),
      }
    end
    if inside(candidate, ctx.root) then
      index = index or build_index(ctx.root)
      for _, path in ipairs(index.files) do
        if normalize(path, false):lower() == candidate:lower() then
          return {
            status = "resolved",
            path = path,
            root = ctx.root,
            source_path = ctx.source_path,
            external = false,
          }
        end
      end
    end
    return {
      status = "missing",
      target = target,
      reason = ("no existe '%s'"):format(candidate),
      root = ctx.root,
      source_path = ctx.source_path,
    }
  end

  -- Reimplementa MetadataCache.getLinkpathDest() de la app instalada:
  -- lookup case-insensitive por basename, exacto primero, luego sufijo de path;
  -- candidatos bajo la carpeta origen antes que el resto y, dentro de cada
  -- grupo, el path más corto. getFirstLinkpathDest() toma el primero.
  index = index or build_index(ctx.root)
  local matches = basename_matches(ctx.root, vim.fs.basename(target), { index = index })
  if #matches == 0 then
    return {
      status = "missing",
      target = target,
      reason = ("no se encuentra '%s' en el vault"):format(target),
      root = ctx.root,
      source_path = ctx.source_path,
    }
  end

  local normalized_target = target:gsub("\\", "/"):gsub("^/", ""):lower()
  local exact
  for _, path in ipairs(matches) do
    local relative = assert(vim.fs.relpath(ctx.root, path)):lower()
    if relative == normalized_target then
      exact = path
      break
    end
  end
  if exact then
    return {
      status = "resolved",
      path = exact,
      root = ctx.root,
      source_path = ctx.source_path,
      external = false,
      candidates = matches,
    }
  end

  local suffix_matches = {}
  for _, path in ipairs(matches) do
    local relative = assert(vim.fs.relpath(ctx.root, path)):lower()
    if
      not target:find("/", 1, true) or relative:sub(-#normalized_target) == normalized_target
    then
      suffix_matches[#suffix_matches + 1] = path
    end
  end
  local ordered = best_match_order(suffix_matches, ctx.source_dir)
  if #ordered > 0 then
    return {
      status = "resolved",
      path = ordered[1],
      candidates = ordered,
      root = ctx.root,
      source_path = ctx.source_path,
      external = false,
    }
  end
  return {
    status = "missing",
    target = target,
    reason = ("no se encuentra '%s' en el vault"):format(target),
    root = ctx.root,
    source_path = ctx.source_path,
  }
end

--- Obsidian permite que plugins enlacen tipos nuevos. Una extensión no-nota
--- basta; un archivo sin extensión entra cuando existe de verdad. `[[nota]]`
--- no se roba porque el fichero físico habitual es `nota.md`, no `nota`.
---@param location string
---@param opts { bufnr?: integer, source_path?: string, root?: string }|?
---@return boolean
function M.is_target(location, opts)
  local util = require "obsidian.util"
  location = M.strip_fragments(location or "")
  if location == "" or util.is_uri(location) and not location:match "^file://" then
    return false
  end
  if not context(opts) then
    return false
  end

  local ext = location:match "%.([^./\\]+)$"
  if ext and NOTE_EXTENSIONS[ext:lower()] then
    return false -- extensión de nota explícita (.md/.qmd/...): nunca adjunto.
  end
  if ext then
    -- Extensión no reconocida como nota (.com, .exe, .pdf...): la mayoría
    -- de las veces sí es un adjunto real, pero el texto de un `[[Título]]`
    -- puede coincidir con algo que PARECE una extensión sin serlo --
    -- p.ej. `[[COMMAND.COM]]` apuntando a una nota real de verdad llamada
    -- "COMMAND.COM.md". Antes esto se daba por adjunto sin comprobar
    -- nada, así que un link así ni generaba diagnóstico de "no existe" NI
    -- dejaba que la acción inteligente ofreciera crear la nota -- se
    -- perdía en el limbo. Mismo criterio que
    -- ya usa la rama sin extensión de acá abajo: si existe como nota,
    -- gana la nota; si no, pero existe como archivo real con esa
    -- extensión literal, es un adjunto; si no existe ninguna de las dos,
    -- lo tratamos como nota (rota/por crear) en vez de tragárnoslo en
    -- silencio como adjunto fantasma.
    if M.resolve(location .. ".md", opts).status == "resolved" then
      return false
    end
    return M.resolve(location, opts).status == "resolved"
  end
  -- La app añade `.md` antes de considerar un target sin extensión. Dejamos
  -- que el flujo de notas gane cuando existe; un archivo extensionless solo
  -- es adjunto cuando no colisiona con una nota real.
  if M.resolve(location .. ".md", opts).status == "resolved" then
    return false
  end
  local result = M.resolve(location, opts)
  return result.status == "resolved"
end

---El destino de un `](...)` cuyo contenido empieza en `from`.
---@param line string
---@param from integer índice 1-based del primer carácter del destino
---@return string|nil target
---@return integer|nil start 1-based
---@return integer|nil finish 1-based, último carácter del destino
---@return integer|nil close 1-based, el `)` que cierra
local function inline_destination(line, from)
  local escaped = false
  if line:sub(from, from) == "<" then
    for idx = from + 1, #line do
      local char = line:sub(idx, idx)
      if char == ">" and not escaped then
        local close = line:find(")", idx + 1, true)
        return line:sub(from + 1, idx - 1), from + 1, idx - 1, close
      end
      escaped = char == "\\" and not escaped
    end
    return nil
  end

  local depth, idx = 0, from
  while idx <= #line do
    local char = line:sub(idx, idx)
    if not escaped then
      if char == "(" then
        depth = depth + 1
      elseif char == ")" then
        if depth == 0 then
          break
        end
        depth = depth - 1
      elseif char:match "%s" then
        break -- a partir de aquí empieza el título
      end
    end
    escaped = char == "\\" and not escaped
    idx = idx + 1
  end

  if idx == from then
    return nil
  end
  local close = line:find(")", idx, true)
  return line:sub(from, idx - 1), from, idx - 1, close
end

---Los enlaces que envuelven una imagen: `[![alt](img)](url)`, el patrón de los
---badges. A la vista es una sola cosa —y así se pinta, con un icono, ver
---lzy.render-markdown.links— pero son dos destinos: la imagen, que es el
---adjunto, y el enlace que la envuelve. obsidian.nvim solo devuelve la imagen,
---así que el destino de fuera quedaba invisible para follow, convert y las
---reescrituras de rename.
---@param line string
---@param row integer
---@param refs table[] los refs ya encontrados; se añaden al final
local function add_linked_images(line, row, refs)
  -- Los de fuera van después a propósito: donde los dos se solapan manda la
  -- imagen, que es lo que se está viendo.
  for index = 1, #refs do
    local ref = refs[index]
    if
      ref.kind == "markdown"
      and ref.embed
      and ref.range.start_row == ref.range.end_row
      and ref.range.start_col >= 1
      and line:sub(ref.range.start_col, ref.range.start_col) == "["
      and line:sub(ref.range.end_col + 1, ref.range.end_col + 2) == "]("
    then
      local target, start, finish, close = inline_destination(line, ref.range.end_col + 3)
      if target and close then
        refs[#refs + 1] = {
          kind = "markdown",
          embed = false,
          raw = line:sub(ref.range.start_col, close),
          range = {
            start_row = row,
            start_col = ref.range.start_col - 1,
            end_row = row,
            end_col = close,
          },
          target = require("obsidian.util").unescape_single_backslash(target),
          raw_target = target,
          target_range = { start_col = start - 1, end_col = finish },
          -- La etiqueta de este enlace es la imagen entera; su texto
          -- alternativo es lo único legible que hay.
          label = ref.raw:match "^!%[(.-)%]" or "",
          -- Dónde está el destino de esa imagen: la única parte de la
          -- construcción donde manda ella y no el enlace. Ver `cursor_linked_image`.
          image_target_range = ref.target_range,
        }
      end
    end
  end
end

---@param line string
---@param row integer|?
---@return table[] refs
function M.parse_refs(line, row)
  row = row or 0
  local refs = {}

  -- CommonMark reference definition: `[id]: destination "optional title"`.
  -- obsidian.nvim no la incluye en parse.refs, aunque Tree-sitter sí la
  -- reconoce. Conservamos rangos separados para que rename, follow y las
  -- reescrituras de adjuntos no confundan el identificador con el destino.
  local indent = line:match "^( *)" or ""
  if #indent <= 3 and line:sub(#indent + 1, #indent + 1) == "[" then
    local opening = #indent + 1
    local closing, escaped = nil, false
    for idx = opening + 1, #line do
      local char = line:sub(idx, idx)
      if char == "]" and not escaped then
        closing = idx
        break
      end
      if char == "\\" and not escaped then
        escaped = true
      else
        escaped = false
      end
    end

    local label = closing and line:sub(opening + 1, closing - 1) or ""
    if
      closing
      and label ~= ""
      and vim.trim(label) ~= ""
      and label:sub(1, 1) ~= "^"
      and line:sub(closing + 1, closing + 1) == ":"
    then
      local token_start = closing + 2
      while line:sub(token_start, token_start):match "[ \t]" do
        token_start = token_start + 1
      end

      local target_start, target_end, token_end
      if line:sub(token_start, token_start) == "<" then
        escaped = false
        for idx = token_start + 1, #line do
          local char = line:sub(idx, idx)
          if char == ">" and not escaped then
            target_start, target_end, token_end = token_start + 1, idx - 1, idx
            break
          end
          if char == "\\" and not escaped then
            escaped = true
          else
            escaped = false
          end
        end
      elseif token_start <= #line then
        local depth, idx = 0, token_start
        escaped = false
        while idx <= #line do
          local char = line:sub(idx, idx)
          if not escaped and char:match "[ \t]" and depth == 0 then
            break
          elseif not escaped and char == "(" then
            depth = depth + 1
          elseif not escaped and char == ")" then
            if depth == 0 then
              break
            end
            depth = depth - 1
          end
          if char == "\\" and not escaped then
            escaped = true
          else
            escaped = false
          end
          idx = idx + 1
        end
        if idx > token_start and depth == 0 then
          target_start, target_end, token_end = token_start, idx - 1, idx - 1
        end
      end

      if target_start and target_end and target_start <= target_end then
        local target = line:sub(target_start, target_end)
        local title, title_range, title_delimiter
        local title_start = token_end + 1
        while line:sub(title_start, title_start):match "[ \t]" do
          title_start = title_start + 1
        end
        local title_opening = line:sub(title_start, title_start)
        local closing_delimiter = title_opening == "(" and ")" or title_opening
        if title_opening == '"' or title_opening == "'" or title_opening == "(" then
          local escaped_title = false
          for idx = title_start + 1, #line do
            local char = line:sub(idx, idx)
            if char == closing_delimiter and not escaped_title then
              if line:sub(idx + 1):match "^%s*$" then
                title = line:sub(title_start + 1, idx - 1)
                title_range = { start_col = title_start, end_col = idx - 1 }
                title_delimiter = title_opening
              end
              break
            end
            if char == "\\" and not escaped_title then
              escaped_title = true
            else
              escaped_title = false
            end
          end
        end
        refs[#refs + 1] = {
          kind = "reference",
          raw = line:sub(opening, token_end),
          range = {
            start_row = row,
            start_col = opening - 1,
            end_row = row,
            end_col = token_end,
          },
          label = label,
          label_range = { start_col = opening, end_col = closing - 1 },
          target = target,
          raw_target = target,
          target_range = { start_col = target_start - 1, end_col = target_end },
          title = title,
          title_range = title_range,
          title_delimiter = title_delimiter,
          embed = false,
        }
      end
    end
  end

  for _, parsed in ipairs(require("obsidian.parse.refs").extract(line, { row = row })) do
    local raw = parsed.raw
    local target, target_start
    if parsed.kind == "wiki" then
      local opening = parsed.embed and 4 or 3 -- 1-based char tras ![[ / [[
      local body = raw:sub(opening, -3)
      local pipe
      for idx = 1, #body do
        if body:sub(idx, idx) == "|" and body:sub(idx - 1, idx - 1) ~= "\\" then
          pipe = idx
          break
        end
      end
      local raw_target = pipe and body:sub(1, pipe - 1) or body
      target = require("obsidian.util").unescape_single_backslash(raw_target)
      target_start = parsed.range.start_col + opening - 1
    elseif parsed.kind == "markdown" then
      local _, paren = raw:find("](", 1, true)
      if paren then
        local body_start = paren + 1
        if raw:sub(body_start, body_start) == "<" then
          local close = raw:find(">", body_start + 1, true)
          if close then
            target = raw:sub(body_start + 1, close - 1)
            target_start = parsed.range.start_col + body_start
          end
        else
          local finish = raw:find("%s", body_start) or #raw
          target = raw:sub(body_start, finish - 1)
          target_start = parsed.range.start_col + body_start - 1
        end
      end
    end

    if target and target_start then
      refs[#refs + 1] = vim.tbl_extend("force", parsed, {
        target = target,
        target_range = {
          start_col = target_start,
          end_col = target_start + #target,
        },
      })
    end
  end

  add_linked_images(line, row, refs)
  return refs
end

---@param bufnr integer|?
---@return table|?
function M.cursor_ref(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not context { bufnr = bufnr } then
    return nil
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  for _, ref in ipairs(M.parse_refs(line, row - 1)) do
    if
      ref.range.start_col <= col
      and col < ref.range.end_col
      and M.is_target(ref.target, { bufnr = bufnr })
    then
      return ref
    end
  end
end

---El enlace exterior de un enlace-imagen (`[![alt](img)](url)`, el patrón de
---los badges) cuando el cursor está sobre él.
---
---A la vista es una sola cosa, pero son dos destinos solapados, y manda el de
---fuera: la imagen es la etiqueta en la que se hace clic, no el destino —es lo
---que significa la sintaxis y lo que hace cualquier renderizador—. La imagen
---sigue siendo alcanzable en el único sitio donde se la pide a propósito: su
---propio destino.
---@param bufnr integer|?
---@return table|nil
function M.cursor_linked_image(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not context { bufnr = bufnr } then
    return nil
  end
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  for _, ref in ipairs(M.parse_refs(line, row - 1)) do
    local image = ref.image_target_range
    if image and ref.range.start_col <= col and col < ref.range.end_col then
      if image.start_col <= col and col < image.end_col then
        return nil -- sobre el destino de la imagen: se pide la imagen
      end
      return ref
    end
  end
end

---@param path string
---@return boolean
function M.is_text(path)
  return require("sabunv.nvim.file_opener").is_text(path)
end

---@param path string
---@param opts { schedule?: boolean }|?
function M.open_path(path, opts)
  opts = vim.tbl_extend("keep", opts or {}, { title = "Nyabsidian" })
  return require("sabunv.nvim.file_opener").open_path(path, opts)
end

---@param location string
---@param opts { bufnr?: integer, callback?: function, notify?: function }|?
---@return boolean handled
function M.follow(location, opts)
  opts = opts or {}
  if not M.is_target(location, opts) then
    return false
  end

  local result = M.resolve(location, opts)
  local callback = opts.callback or function() end
  local notify = opts.notify
    or function(msg, level)
      vim.notify(msg, level, { title = "Nyabsidian" })
    end
  if result.status == "missing" then
    notify(result.reason, vim.log.levels.ERROR)
    callback(nil, {})
    return true
  end

  M.open_path(result.path)
  callback(nil, {})
  return true
end

---@param bufnr integer|?
---@return boolean handled
function M.open_under_cursor(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not M.in_vault(bufnr) then
    return false
  end
  -- Un enlace-imagen manda sobre la imagen que le hace de etiqueta: ver
  -- cursor_linked_image. obsidian.nvim solo ve la imagen, así que sin esto `gx`
  -- sobre un badge abría el SVG en vez del enlace.
  local badge = M.cursor_linked_image(bufnr)
  local ref = badge or M.cursor_ref(bufnr) or require("lzy.obsidian.links").cursor_ref(bufnr)
  local target = ref and (ref.raw_target or ref.target) or nil
  if target and M.is_target(target, { bufnr = bufnr }) then
    return M.follow(target, { bufnr = bufnr })
  end

  -- `gx` también conserva el flujo de URLs del vault sin caer en el módulo
  -- antiguo de Marksman. `cursor_link()` incluye nuestro parche de <https://>.
  local location
  if badge then
    location = badge.target
  else
    local link = require("obsidian.api").cursor_link()
    location = link and require("obsidian.util").parse_link(link) or nil
  end
  if location then
    local is_uri, scheme = require("obsidian.util").is_uri(location)
    if is_uri and scheme ~= "file" then
      vim.ui.open(location)
      return true
    end
  end
  return false
end

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

---@param root string
---@return string[]
local function reference_files(root, index)
  if index then
    return index.references
  end
  local paths = {}
  walk_files(root, root, function(path)
    local ext = path:match "%.([^./]+)$"
    if ext and REFERENCE_EXTENSIONS[ext:lower()] then
      paths[#paths + 1] = path
    end
  end)
  table.sort(paths)
  return paths
end

---@param line string
---@param row integer
---@return table[]
local function canvas_refs(line, row)
  local refs, search = {}, 1
  while true do
    local start, finish = line:find('"file"%s*:%s*"', search)
    if not start then
      break
    end
    local value_start = finish + 1
    local idx, escaped = value_start, false
    while idx <= #line do
      local char = line:sub(idx, idx)
      if char == '"' and not escaped then
        break
      end
      if char == "\\" and not escaped then
        escaped = true
      else
        escaped = false
      end
      idx = idx + 1
    end
    if idx > #line then
      break
    end
    local encoded = line:sub(value_start, idx - 1)
    local ok_decode, target = pcall(vim.json.decode, '"' .. encoded .. '"')
    if ok_decode and type(target) == "string" then
      refs[#refs + 1] = {
        target = target,
        kind = "canvas",
        range = { start_row = row, start_col = start - 1, end_col = idx },
        target_range = { start_col = value_start - 1, end_col = idx - 1 },
      }
    end
    search = idx + 1
  end
  return refs
end

---@param target string
---@return "file_uri"|"absolute"|"note_relative"|"vault_relative"|"basename" form
---@return string decoded
local function target_form(target)
  target = M.strip_fragments(target or "")
  local decoded = vim.uri_decode(target) or target
  decoded = require("obsidian.util").unescape_single_backslash(decoded)
  if target:match "^file://" then
    return "file_uri", decoded
  elseif vim.fn.isabsolutepath(decoded) == 1 then
    return "absolute", decoded
  elseif vim.startswith(decoded, "./") or vim.startswith(decoded, "../") then
    return "note_relative", decoded
  elseif decoded:find("/", 1, true) then
    return "vault_relative", decoded
  end
  return "basename", decoded
end

---@param path string
---@param source_path string
---@param original string
---@return string
local function note_relative_target(path, source_path, original)
  local target = relative_path(path, vim.fs.dirname(source_path))
  if vim.startswith(original, "./") and not vim.startswith(target, ".") then
    return "./" .. target
  end
  return target
end

---@param new_path string
---@param opts { source_path: string, root: string, old_path: string, format?: string, index?: nyabsidian.AttachmentIndex }
---@return string
local function simplified_vault_target(new_path, opts)
  local obsidian = rawget(_G, "Obsidian")
  local format = opts.format
    or obsidian and obsidian.opts.link and obsidian.opts.link.format
    or "shortest"
  if format == "relative" then
    return relative_path(new_path, vim.fs.dirname(opts.source_path))
  elseif format == "absolute" then
    return assert(vim.fs.relpath(opts.root, new_path))
  end

  local basename = vim.fs.basename(new_path)
  local matches = basename_matches(opts.root, basename, {
    exclude = opts.old_path,
    include = new_path,
    index = opts.index,
  })
  if #matches == 1 then
    return basename
  end
  return assert(vim.fs.relpath(opts.root, new_path))
end

---@param new_path string
---@param opts { source_path: string, root: string, old_path: string, old_target?: string, format?: string, index?: nyabsidian.AttachmentIndex, policy?: nyabsidian.AttachmentPathPolicy }
---@return string
function M.format_target(new_path, opts)
  local new_inside = inside(new_path, opts.root)
  local policy = opts.policy or M.path_policy(opts.root)
  if new_inside and policy.vault == "simplify" then
    return simplified_vault_target(new_path, opts)
  elseif not new_inside and policy.external == "absolute" then
    return normalize(new_path, false)
  end

  local form, original = target_form(opts.old_target or vim.fs.basename(opts.old_path))
  if form == "file_uri" then
    return vim.uri_from_fname(new_path)
  elseif form == "absolute" then
    return normalize(new_path, false)
  elseif form == "note_relative" then
    return note_relative_target(new_path, opts.source_path, original)
  elseif new_inside and form == "vault_relative" then
    return assert(vim.fs.relpath(opts.root, new_path))
  elseif new_inside then
    -- Un basename se conserva mientras siga siendo seguro. Si el nuevo nombre
    -- colisiona, se amplía lo mínimo necesario para no cambiar de identidad.
    return simplified_vault_target(
      new_path,
      vim.tbl_extend("force", {}, opts, { format = "shortest" })
    )
  end
  -- Basename/vault-relative no pueden representar un archivo externo. El
  -- fallback absoluto conserva identidad sin fabricar una cadena de `../`.
  return normalize(new_path, false)
end

---@param target string
---@param resolved_path string
---@param opts { bufnr?: integer, source_path?: string, root?: string }|?
---@return string
function M.rename_placeholder(target, resolved_path, opts)
  local ctx = assert(context(opts), "el buffer no pertenece a un vault")
  local form, original = target_form(target)
  if form == "file_uri" then
    return vim.uri_from_fname(resolved_path)
  elseif form == "absolute" then
    return normalize(resolved_path, false)
  elseif form == "note_relative" then
    return note_relative_target(resolved_path, ctx.source_path, original)
  end
  return inside(resolved_path, ctx.root) and assert(vim.fs.relpath(ctx.root, resolved_path))
    or normalize(resolved_path, false)
end

---@param target string
---@param kind string
---@return string
local function encode_target(target, kind)
  if kind == "markdown" or kind == "reference" then
    -- `vim.uri_from_fname()` ya devuelve una URI codificada. Volver a pasarla
    -- por urlencode convertiría `file:///...` en `file%3A///...` y `%20` en
    -- `%2520`.
    if target:match "^file://" then
      return target
    end
    return require("obsidian.util").urlencode(target, { keep_path_sep = true })
  elseif kind == "canvas" then
    return vim.json.encode(target):sub(2, -2)
  end
  return target
end

---@param old_path string
---@param new_name string
---@param opts { bufnr?: integer, source_path?: string, root?: string }|?
---@return string|? destination
---@return string|? err
function M.destination(old_path, new_name, opts)
  local ctx = context(opts)
  if not ctx then
    return nil, "el buffer no pertenece a un vault"
  end
  if type(new_name) ~= "string" or new_name == "" then
    return nil, "el destino no puede estar vacío"
  elseif new_name ~= vim.trim(new_name) then
    return nil, "el destino no puede empezar ni terminar con espacios"
  elseif new_name:find("\\", 1, true) then
    return nil, "usa '/' como separador de directorios"
  elseif new_name:find "[%z\r\n]" then
    return nil, "el destino no puede contener NUL ni saltos de línea"
  elseif require("obsidian.util").contains_invalid_characters(new_name) then
    return nil, "el destino no puede contener '#', '^', '[', ']' ni '|'"
  elseif new_name:sub(-1) == "/" then
    return nil, "el destino debe terminar en un nombre de archivo"
  end

  local explicit_uri = file_uri(new_name)
  local destination
  if explicit_uri then
    destination = normalize(explicit_uri, false)
  elseif vim.fn.isabsolutepath(new_name) == 1 then
    destination = normalize(new_name, false)
  elseif vim.startswith(new_name, "./") or vim.startswith(new_name, "../") then
    destination = normalize(vim.fs.joinpath(ctx.source_dir, new_name), false)
  else
    -- El placeholder del rename siempre representa una ubicación desde la
    -- raíz del vault. Mantener esa misma gramática después de editarlo evita
    -- que borrar `attachments/` conserve silenciosamente la carpeta antigua.
    destination = normalize(vim.fs.joinpath(ctx.root, new_name), false)
    if not inside(destination, ctx.root) then
      return nil, "un destino relativo al vault no puede escapar de su raíz"
    end
  end

  local basename = vim.fs.basename(destination)
  if basename == "" or basename == "." or basename == ".." then
    return nil, "el destino final no es un nombre de archivo válido"
  end
  local old_ext = vim.fn.fnamemodify(old_path, ":e")
  if vim.fn.fnamemodify(basename, ":e") == "" and old_ext ~= "" then
    destination = destination .. "." .. old_ext
  end
  if normalize(destination, false) == normalize(old_path, false) then
    return nil, "el origen y el destino son el mismo archivo"
  elseif uv.fs_stat(destination) then
    return nil, ("ya existe: %s"):format(destination)
  end
  return destination
end

---@param old_path string Ruta ya elegida de forma inequívoca.
---@param new_name string Basename o path explícito.
---@param opts { bufnr?: integer, source_path?: string, root?: string, notify?: function }|?
---@return lsp.WorkspaceEdit|? edit
---@return string|? err
function M.rename(old_path, new_name, opts)
  opts = opts or {}
  local ctx = context(opts)
  if not ctx then
    return nil, "el buffer no pertenece a un vault"
  end
  old_path = normalize(old_path)
  if not is_file(old_path) then
    return nil, ("no existe el adjunto '%s'"):format(old_path)
  end

  local new_path, destination_error = M.destination(old_path, new_name, opts)
  if not new_path then
    return nil, destination_error
  end

  local index = build_index(ctx.root)
  local document_changes = {}
  for _, source_path in ipairs(reference_files(ctx.root, index)) do
    local ext = source_path:match("%.([^./]+)$"):lower()
    local edits = {}
    for row, line in ipairs(read_lines(source_path)) do
      local refs = ext == "canvas" and canvas_refs(line, row - 1) or M.parse_refs(line, row - 1)
      for _, ref in ipairs(refs) do
        local result = M.resolve(ref.target, {
          source_path = source_path,
          root = ctx.root,
          index = index,
        })
        local points_to_old = result.status == "resolved" and normalize(result.path) == old_path
        if points_to_old then
          local target = M.format_target(new_path, {
            source_path = source_path,
            root = ctx.root,
            old_path = old_path,
            old_target = ref.target,
            index = index,
          })
          local old_target = ref.target
          local old_file = M.strip_fragments(old_target)
          target = target .. old_target:sub(#old_file + 1)
          edits[#edits + 1] = {
            range = {
              start = { line = row - 1, character = ref.target_range.start_col },
              ["end"] = { line = row - 1, character = ref.target_range.end_col },
            },
            newText = encode_target(target, ref.kind),
          }
        end
      end
    end

    if #edits > 0 then
      table.sort(edits, function(a, b)
        if a.range.start.line == b.range.start.line then
          return a.range.start.character > b.range.start.character
        end
        return a.range.start.line > b.range.start.line
      end)
      document_changes[#document_changes + 1] = {
        textDocument = {
          uri = vim.uri_from_fname(source_path),
          version = HAS_NVIM_012 and vim.NIL or nil,
        },
        edits = edits,
      }
    end
  end

  local parent = vim.fs.dirname(new_path)
  if vim.fn.isdirectory(parent) ~= 1 then
    local ok_mkdir, mkdir_error = pcall(vim.fn.mkdir, parent, "p")
    if not ok_mkdir or vim.fn.isdirectory(parent) ~= 1 then
      return nil, ("no se pudo crear '%s': %s"):format(parent, tostring(mkdir_error))
    end
  end

  document_changes[#document_changes + 1] = {
    kind = "rename",
    oldUri = vim.uri_from_fname(old_path),
    newUri = vim.uri_from_fname(new_path),
    options = { overwrite = false, ignoreIfExists = false },
  }

  return { documentChanges = document_changes }
end

return M
