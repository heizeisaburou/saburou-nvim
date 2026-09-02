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

  -- `explicit` marca las formas que nombran UN sitio concreto: si ahí no está,
  -- es un error y no tiene sentido seguir buscando por el vault.
  local direct, explicit
  local is_uri, scheme = util.is_uri(target)
  if is_uri then
    if scheme ~= "file" then
      return callback(nil, "el enlace es una URI externa, no una nota local")
    end
    local ok, path = pcall(vim.uri_to_fname, target)
    direct, explicit = ok and path or nil, true
  elseif vim.startswith(target, "./") or vim.startswith(target, "../") then
    direct, explicit = vim.fs.joinpath(ctx.source_dir, target), true
  elseif vim.startswith(target, "/") then
    -- La barra inicial es la raíz del VAULT, no la del sistema de archivos:
    -- `/docs/Nota` significa `<vault>/docs/Nota`, exactamente igual que
    -- `docs/Nota`. Resolverla contra la raíz del disco (lo que hacía
    -- `isabsolutepath` aquí) no encontraba nunca nada y dejaba a este
    -- resolutor discrepando de lzy.obsidian.notes, que sí la lee como raíz.
    -- Como ruta del sistema sólo se prueba si bajo el vault no hay nada, que
    -- es como se enlaza una nota de fuera.
    local from_root = vim.fs.joinpath(ctx.root, target:sub(2))
    direct = existing_note(normalize(from_root, false)) and from_root or target
  elseif vim.fn.isabsolutepath(target) == 1 then
    direct, explicit = target, true
  elseif target:find("/", 1, true) then
    direct = vim.fs.joinpath(ctx.root, target)
  end

  if direct then
    local path = existing_note(normalize(direct, false))
    if path then
      return callback(path)
    end
    if explicit then
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
--- Delegado en lzy.obsidian.coordinate: ahí vive el criterio único de
--- «coordenada más corta que sigue siendo inequívoca», compartido por notas y
--- adjuntos.
---
--- Antes esto recorría el vault entero llamando a `Note.from_file` por cada
--- nota, **una vez por enlace**, y en cuanto había un homónimo saltaba de golpe
--- a la ruta completa desde la raíz. Ahora consulta el índice cacheado y amplía
--- carpeta a carpeta.
---@param path string
---@param root string
---@return string
local function shortest_note_target(path, root)
  -- `fresh`: esto lo dispara una acción suelta del usuario (convertir enlace,
  -- copia inteligente), así que se paga una reconstrucción del índice antes que
  -- arriesgarse a escribir una coordenada ambigua con datos rancios.
  return require("lzy.obsidian.coordinate").minimal(path, { root = root, fresh = true })
end

-- Expuesto para lzy.obsidian.smart_copy.
M.shortest_note_target = shortest_note_target

---@param target string
---@param kind string
---@param uri boolean|?
---@return string
local function render_target(target, kind, uri)
  if (kind == "markdown" or kind == "reference") and not uri then
    return require("lzy.link_target").encode(target)
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
  -- Igual que un yank normal, pero characterwise: el path no adquiere un salto
  -- de línea. `'clipboard'` sigue siendo quien decide si además va al sistema
  -- (ver sabunv.util.clipboard.yank), que es lo que hace que `p` lo pegue.
  require("sabunv.util.clipboard").yank(path)
end

---@param value string
---@return string
local function decode_html_entities(value)
  local named = {
    amp = "&",
    apos = "'",
    gt = ">",
    lt = "<",
    nbsp = " ",
    quot = '"',
  }
  local function character(number, base)
    local codepoint = tonumber(number, base)
    if
      not codepoint
      or codepoint < 1
      or codepoint > 0x10FFFF
      or codepoint >= 0xD800 and codepoint <= 0xDFFF
    then
      return ""
    end
    local ok, result = pcall(vim.fn.nr2char, codepoint)
    return ok and result or ""
  end
  value = value:gsub("&#[xX]([%da-fA-F]+);", function(hex)
    return character(hex, 16)
  end)
  value = value:gsub("&#(%d+);", function(decimal)
    return character(decimal, 10)
  end)
  return value:gsub("&([%a]+);", function(name)
    return named[name:lower()] or "&" .. name .. ";"
  end)
end

---@param html string
---@return string|?
local function html_title(html)
  local lower = html:lower()
  local start_col, end_col = lower:find("<title[^>]*>")
  if not start_col then
    return nil
  end
  local close = lower:find("</title%s*>", end_col + 1)
  if not close then
    return nil
  end
  local title = html:sub(end_col + 1, close - 1):gsub("<[^>]+>", "")
  title = vim.trim(decode_html_entities(title):gsub("%s+", " "))
  return title ~= "" and title or nil
end

---@param title string
---@return string
local function escape_markdown_label(title)
  return title:gsub("\\", "\\\\"):gsub("%[", "\\["):gsub("%]", "\\]")
end

---@param url string
---@param callback fun(body: string|?, err: string|?)
local function request_url(url, callback)
  if not vim.system then
    return callback(nil, "esta versión de Neovim no dispone de vim.system()")
  end
  vim.system({
    "curl",
    "--location",
    "--fail",
    "--silent",
    "--show-error",
    "--compressed",
    "--connect-timeout",
    "5",
    "--max-time",
    "12",
    "--max-filesize",
    "1048576",
    "--range",
    "0-1048575",
    "--proto",
    "=http,https",
    "--proto-redir",
    "=http,https",
    "--user-agent",
    "Mozilla/5.0 Nyabsidian/1.0",
    url,
  }, { text = true }, function(result)
    vim.schedule(function()
      if result.stdout and html_title(result.stdout) then
        return callback(result.stdout)
      end
      local detail = vim.trim(result.stderr or "")
      callback(nil, detail ~= "" and detail or ("curl terminó con código %s"):format(result.code))
    end)
  end)
end

---@param opts { request?: fun(url: string, callback: fun(body: string|?, err: string|?)), notify?: function }|?
function M.fetch_web_title(opts)
  opts = opts or {}
  local notify_user = opts.notify or notify
  local request = opts.request or request_url
  local ctx = require("lzy.obsidian.links").cursor_context()
  local ref = ctx and ctx.ref or nil
  local url = ref and (ref.raw_target or ref.target) or nil
  if
    not ref
    or (
      ref.kind ~= "markdown"
      and ref.kind ~= "reference"
      and ref.kind ~= "reference_link"
      and ref.kind ~= "autolink"
    )
    or not url
    or not url:match "^https?://"
  then
    return notify_user("No hay un enlace web Markdown bajo el cursor", vim.log.levels.ERROR)
  end
  if ref.embed then
    return notify_user(
      "El enlace bajo el cursor es una imagen, no una página web",
      vim.log.levels.ERROR
    )
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local original = ref.raw
  local row = ref.range.start_row
  local start_col, end_col = ref.range.start_col, ref.range.end_col
  notify_user("Obteniendo el título de " .. url .. "…")
  request(url, function(body, err)
    if not body then
      return notify_user(
        "No se pudo obtener el título: " .. (err or "respuesta vacía"),
        vim.log.levels.ERROR
      )
    end
    local title = html_title(body)
    if not title then
      return notify_user("La página no contiene un título HTML", vim.log.levels.ERROR)
    end
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
    if line:sub(start_col + 1, end_col) ~= original then
      return notify_user(
        "El enlace cambió mientras se obtenía el título; no se ha modificado",
        vim.log.levels.WARN
      )
    end

    title = escape_markdown_label(title)
    if ref.kind == "autolink" then
      vim.api.nvim_buf_set_text(
        bufnr,
        row,
        start_col,
        row,
        end_col,
        { ("[%s](%s)"):format(title, url) }
      )
    else
      local links = require "lzy.obsidian.links"
      local label = links.label_component(ref)
      if not label then
        return notify_user(
          "El enlace Markdown no contiene una etiqueta editable",
          vim.log.levels.ERROR
        )
      end
      if ref.kind == "reference" or label.kind == "reference_id" then
        local edit, rename_err = links.reference_id_edit(ref.label, title, bufnr)
        if not edit then
          return notify_user(rename_err, vim.log.levels.ERROR)
        end
        vim.lsp.util.apply_workspace_edit(edit, "utf-8")
      else
        vim.api.nvim_buf_set_text(
          bufnr,
          row,
          label.start_col,
          row,
          label.end_col,
          { title }
        )
      end
    end
    notify_user("Etiqueta actualizada desde el título web")
  end)
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
M.html_title = html_title

return M
