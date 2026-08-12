-- Acciones locales sobre el enlace bajo el cursor.
--
-- No cambian la política persistente del vault: convierten una sola referencia
-- a una representación elegida por el usuario o copian la identidad absoluta
-- que resuelve el mismo motor usado por apertura y rename.

local M = {}

local uv = vim.uv or vim.loop

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

---@param path string|table
---@param real boolean|?
---@return string
local function normalize(path, real)
  path = vim.fs.normalize(tostring(path))
  return real == false and path or vim.fs.normalize(uv.fs_realpath(path) or path)
end

---@param path string
---@param root string
---@return boolean
local function inside(path, root)
  path, root = normalize(path, false), normalize(root, false)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

---@param path string
---@param from_dir string
---@return string
local function relative_path(path, from_dir)
  path, from_dir = normalize(path, false), normalize(from_dir, false)
  local target, source = {}, {}
  for part in path:gmatch "[^/]+" do
    target[#target + 1] = part
  end
  for part in from_dir:gmatch "[^/]+" do
    source[#source + 1] = part
  end

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

---@param path string
---@param from_dir string
---@return string
local function explicit_relative_path(path, from_dir)
  local target = relative_path(path, from_dir)
  return vim.startswith(target, ".") and target or "./" .. target
end

---@param bufnr integer
---@return { bufnr: integer, source_path: string, source_dir: string, root: string }|?
local function context(bufnr)
  local source_path = vim.api.nvim_buf_get_name(bufnr)
  if source_path == "" then
    return nil
  end
  source_path = normalize(source_path)
  local workspace = require("obsidian.api").find_workspace(source_path)
  if not workspace then
    return nil
  end
  local root = normalize(workspace.root)
  return {
    bufnr = bufnr,
    source_path = source_path,
    source_dir = vim.fs.dirname(source_path),
    root = root,
  }
end

---@param bufnr integer
---@return table|?
local function cursor_ref(bufnr)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  for _, ref in ipairs(require("lzy.obsidian.attachments").parse_refs(line, row - 1)) do
    if ref.range.start_col <= col and col < ref.range.end_col then
      return ref
    end
  end
end

---@param path string
---@return boolean
local function is_note_path(path)
  local ext = path:match "%.([^./]+)$"
  return ext ~= nil and NOTE_EXTENSIONS[ext:lower()] == true
end

---@param path string
---@return string|?
local function existing_note(path)
  local names = { path }
  if not path:match "%.([^./]+)$" then
    names = { path .. ".md", path .. ".qmd", path .. ".base" }
  end
  for _, name in ipairs(names) do
    local stat = uv.fs_stat(name)
    if stat and stat.type == "file" and is_note_path(name) then
      return normalize(name)
    end
  end
end

---@param paths string[]
---@return string[]
local function unique_paths(paths)
  local seen, out = {}, {}
  for _, path in ipairs(paths) do
    path = normalize(path)
    if not seen[path] then
      seen[path] = true
      out[#out + 1] = path
    end
  end
  table.sort(out)
  return out
end

---@param paths string[]
---@param prompt string
---@param select? function
---@param callback fun(path: string|?)
local function choose_path(paths, prompt, select, callback)
  if #paths == 0 then
    return callback(nil)
  elseif #paths == 1 then
    return callback(paths[1])
  end
  (select or vim.ui.select)(paths, {
    prompt = prompt,
    format_item = function(path)
      return path
    end,
  }, callback)
end

---@param target string
---@param ctx table
---@param opts table
---@param callback fun(path: string|?, err: string|?)
local function resolve_note(target, ctx, opts, callback)
  local util = require "obsidian.util"
  target = vim.uri_decode(target) or target
  target = util.unescape_single_backslash(target)
  if target == "" then
    return callback(is_note_path(ctx.source_path) and ctx.source_path or nil)
  end

  local direct
  local is_uri, scheme = util.is_uri(target)
  if is_uri then
    if scheme ~= "file" then
      return callback(nil, "el enlace es una URI externa, no una nota local")
    end
    local ok, path = pcall(vim.uri_to_fname, target)
    direct = ok and path or nil
  elseif vim.fn.isabsolutepath(target) == 1 then
    direct = target
  elseif vim.startswith(target, "./") or vim.startswith(target, "../") then
    direct = vim.fs.joinpath(ctx.source_dir, target)
  elseif target:find("/", 1, true) then
    direct = vim.fs.joinpath(ctx.root, target)
  end

  if direct then
    local path = existing_note(normalize(direct, false))
    if path then
      return callback(path)
    end
    if is_uri or vim.fn.isabsolutepath(target) == 1 or vim.startswith(target, ".") then
      return callback(nil, ("no existe la nota '%s'"):format(direct))
    end
  end

  require("obsidian.search").resolve_note_async(target, function(notes)
    local paths = {}
    for _, note in ipairs(notes) do
      local path = note.path and tostring(note.path) or nil
      if path and existing_note(path) then
        paths[#paths + 1] = path
      end
    end
    paths = unique_paths(paths)
    choose_path(paths, "Elige la nota", opts.select, function(path)
      callback(path, path and nil or ("no se pudo resolver la nota '%s'"):format(target))
    end)
  end, { notes = { max_lines = 200 } })
end

---@param opts table|?
---@param callback fun(result: table|?, err: string|?)
local function resolve_cursor(opts, callback)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local ctx = context(bufnr)
  if not ctx then
    return callback(nil, "el buffer no pertenece a un vault")
  end
  local ref = cursor_ref(bufnr)
  if not ref then
    return callback(nil, "no hay un enlace bajo el cursor")
  end

  local attachments = require "lzy.obsidian.attachments"
  local target = attachments.strip_fragments(ref.target)
  if attachments.is_target(ref.target, { bufnr = bufnr }) then
    local resolved = attachments.resolve(ref.target, { bufnr = bufnr })
    if resolved.status == "missing" then
      return callback(nil, resolved.reason)
    end
    return callback {
      kind = "attachment",
      path = resolved.path,
      internal = not resolved.external,
      target = target,
      ref = ref,
      context = ctx,
    }
  end

  resolve_note(target, ctx, opts, function(path, err)
    if not path then
      return callback(nil, err)
    end
    callback {
      kind = "note",
      path = path,
      internal = inside(path, ctx.root),
      target = target,
      ref = ref,
      context = ctx,
    }
  end)
end

---@param path string
---@param root string
---@return string
local function shortest_note_target(path, root)
  local basename = vim.fs.basename(path)
  local ext = basename:match "%.([^./]+)$"
  local candidate = ext and ext:lower() == "md" and basename:sub(1, -4) or basename
  local wanted = normalize(path)
  local matches = {}
  local Note = require "obsidian.note"

  for current in require("obsidian.api").dir(root) do
    if is_note_path(current) then
      local note = Note.from_file(current, { max_lines = 200 })
      if note then
        for _, id in ipairs(note:reference_ids { lowercase = true }) do
          if id == candidate:lower() then
            matches[normalize(current)] = true
            break
          end
        end
      end
    end
  end
  if vim.tbl_count(matches) == 1 and matches[wanted] then
    return basename
  end
  return assert(vim.fs.relpath(root, path))
end

---@param target string
---@param kind string
---@param uri boolean|?
---@return string
local function render_target(target, kind, uri)
  if kind == "markdown" and not uri then
    return require("obsidian.util").urlencode(target, { keep_path_sep = true })
  end
  return target
end

---@param target string
---@param ref_kind string
---@param internal boolean
---@return string
local function render_note_target(target, ref_kind, internal)
  if internal and ref_kind == "wiki" and target:lower():sub(-3) == ".md" then
    target = target:sub(1, -4)
  end
  return render_target(target, ref_kind)
end

---@param resolved table
---@return table[]
local function format_choices(resolved)
  local path, ctx, ref = resolved.path, resolved.context, resolved.ref
  local choices = {}
  local function add(id, label, target, uri)
    choices[#choices + 1] = {
      id = id,
      label = label,
      target = render_target(target, ref.kind, uri),
    }
  end
  local function add_note(id, label, target)
    choices[#choices + 1] = {
      id = id,
      label = label,
      target = render_note_target(target, ref.kind, resolved.internal),
    }
  end

  if resolved.kind == "attachment" then
    if resolved.internal then
      local shortest = require("lzy.obsidian.attachments").format_target(path, {
        source_path = ctx.source_path,
        root = ctx.root,
        old_path = path,
        old_target = vim.fs.basename(path),
        format = "shortest",
        policy = { vault = "simplify", external = "preserve" },
      })
      add("shortest", "Más corto seguro", shortest)
      add("vault", "Desde la raíz del vault", assert(vim.fs.relpath(ctx.root, path)))
    end
    add("relative", "Relativo a la nota", explicit_relative_path(path, ctx.source_dir))
    add("absolute", "Absoluto del sistema", normalize(path, false))
    add("file_uri", "URI file://", vim.uri_from_fname(path), true)
  elseif resolved.internal then
    local has_fragment = #resolved.target < #ref.target
    local shortest = normalize(path) == normalize(ctx.source_path) and has_fragment and ""
      or shortest_note_target(path, ctx.root)
    add_note("shortest", "Más corto seguro", shortest)
    add_note("vault", "Desde la raíz del vault", assert(vim.fs.relpath(ctx.root, path)))
    add_note("relative", "Relativo a la nota", explicit_relative_path(path, ctx.source_dir))
  else
    add_note("relative", "Relativo a la nota", explicit_relative_path(path, ctx.source_dir))
    add_note("absolute", "Absoluto del sistema", normalize(path, false))
  end
  return choices
end

---@param msg string
---@param level integer|?
local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Nyabsidian" })
end

---@param path string
local function yank_path(path)
  -- Igual que un yank normal, pero characterwise: el path no adquiere un
  -- salto de línea. `clipboard=unnamed[plus]` sigue siendo quien decide si el
  -- registro sin nombre se sincroniza además con el sistema.
  vim.fn.setreg("0", path, "v")
  vim.fn.setreg('"', path, "v")
end

---@param opts { bufnr?: integer, select?: function, copy?: fun(path: string), notify?: function }|?
function M.copy_path(opts)
  opts = opts or {}
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
  local ref = cursor_ref(bufnr)
  if not ref then
    local ctx = context(bufnr)
    if not ctx or not is_note_path(ctx.source_path) then
      return (opts.notify or notify)(
        "No hay una nota o adjunto que copiar",
        vim.log.levels.ERROR
      )
    end
    local path = normalize(ctx.source_path)
    if opts.copy then
      opts.copy(path)
    else
      yank_path(path)
    end
    return (opts.notify or notify)("Path absoluto copiado: " .. path)
  end

  resolve_cursor(opts, function(result, err)
    if not result then
      return (opts.notify or notify)("No se pudo copiar el path: " .. err, vim.log.levels.ERROR)
    end
    if opts.copy then
      opts.copy(result.path)
    else
      yank_path(result.path)
    end
    (opts.notify or notify)("Path absoluto copiado: " .. result.path)
  end)
end

---@param opts { bufnr?: integer, select?: function, notify?: function }|?
function M.convert_link(opts)
  opts = opts or {}
  resolve_cursor(opts, function(result, err)
    if not result then
      return (opts.notify or notify)(
        "No se pudo convertir el enlace: " .. err,
        vim.log.levels.ERROR
      )
    end
    local choices = format_choices(result)
    local select = opts.select or vim.ui.select
    select(choices, {
      prompt = "Formato del enlace",
      format_item = function(item)
        local current = item.target == result.target and "  (actual)" or ""
        return ("%s: %s%s"):format(item.label, item.target, current)
      end,
    }, function(choice)
      if not choice then
        return
      end
      local ref = result.ref
      local start_col = ref.target_range.start_col
      local end_col = start_col + #result.target
      vim.api.nvim_buf_set_text(
        result.context.bufnr,
        ref.range.start_row,
        start_col,
        ref.range.start_row,
        end_col,
        { choice.target }
      )
      local notify_user = opts.notify or notify
      notify_user(("Enlace convertido a: %s"):format(choice.label))
    end)
  end)
end

-- API pequeña para pruebas.
M.resolve_cursor = resolve_cursor
M.format_choices = format_choices

return M
