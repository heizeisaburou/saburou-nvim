-- Resolución y refactor estructural de headings de un vault Obsidian.

local M = {}

local uv = vim.uv or vim.loop
local NOTE_EXTENSIONS = { md = true, qmd = true, base = true }
local HAS_NVIM_012 = vim.fn.has("nvim-0.12.0") == 1

---@param path string
---@return string
local function normalize(path)
  return vim.fs.normalize(uv.fs_realpath(path) or path)
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

---@param note_or_path obsidian.Note|string
---@return obsidian.Note|?
function M.load_note(note_or_path)
  if type(note_or_path) == "table" and note_or_path.sections and note_or_path.path then
    return note_or_path
  end
  local path = type(note_or_path) == "table" and note_or_path.path or note_or_path
  if not path then
    return nil
  end
  path = normalize(tostring(path))

  local opts = {
    collect_anchor_links = true,
    collect_sections = true,
    max_lines = math.huge,
  }
  local bufnr = vim.fn.bufnr(path)
  if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
    return require("obsidian.note").from_buffer(bufnr, opts)
  end
  return require("obsidian.note").from_file(path, opts)
end

---@param anchor string
---@return string[]
function M.split_anchor(anchor)
  anchor = vim.uri_decode(anchor or "") or anchor or ""
  anchor = anchor:gsub("^#", ""):gsub("\\$", "")
  local segments = {}
  local start = 1
  while start <= #anchor + 1 do
    local hash = anchor:find("#", start, true)
    local finish = hash and hash - 1 or #anchor
    local segment = anchor:sub(start, finish)
    if segment ~= "" then
      segments[#segments + 1] = segment
    end
    if not hash then
      break
    end
    start = hash + 1
  end
  return segments
end

---@param section obsidian.Section
---@return obsidian.Section[]
local function section_chain(section)
  local chain = {}
  while section do
    if section.header then
      table.insert(chain, 1, section)
    end
    section = section.parent
  end
  return chain
end

---@param note obsidian.Note
---@param anchor string
---@return { note: obsidian.Note, section: obsidian.Section, chain: obsidian.Section[], chain_start: integer }[] matches
---@return string[] segments
function M.resolve(note, anchor)
  note = M.load_note(note)
  if not note then
    return {}, M.split_anchor(anchor)
  end

  local util = require("obsidian.util")
  local segments = M.split_anchor(anchor)
  local standardized = vim.tbl_map(function(segment)
    return util.standardize_anchor("#" .. segment)
  end, segments)
  local matches = {}

  for _, section in ipairs(note.sections or {}) do
    if section.header then
      local chain = section_chain(section)
      local matches_section = false
      local chain_start = #chain - #standardized + 1
      if #standardized > 0 and chain_start > 0 then
        matches_section = true
        for idx, expected in ipairs(standardized) do
          if chain[chain_start + idx - 1].anchor ~= expected then
            matches_section = false
            break
          end
        end
      end

      if matches_section then
        matches[#matches + 1] = {
          note = note,
          section = section,
          chain = chain,
          chain_start = chain_start,
        }
      end
    end
  end

  return matches, segments
end

---@param note obsidian.Note
---@param anchor string
---@return string
function M.missing_message(note, anchor)
  local segments = M.split_anchor(anchor)
  local path = note.path and vim.fs.basename(tostring(note.path)) or tostring(note.id)
  if #segments == 0 then
    return ("El enlace no contiene un heading válido en %s"):format(path)
  end

  for idx = 1, #segments do
    local prefix = table.concat(vim.list_slice(segments, 1, idx), "#")
    if #M.resolve(note, prefix) == 0 then
      return ("No existe el heading '%s' de '#%s' en %s"):format(segments[idx], table.concat(segments, "#"), path)
    end
  end

  return ("No existe la jerarquía '#%s' en %s"):format(table.concat(segments, "#"), path)
end

---@param note obsidian.Note
---@param section obsidian.Section
---@return lsp.Location
function M.location(note, section)
  return note:_location({ range = section.range })
end

--- Devuelve los rangos byte-indexados de cada componente del target.
---@param ref obsidian.parse.Ref
---@return { text: string, start_col: integer, end_col: integer } note_part
---@return { text: string, start_col: integer, end_col: integer, index: integer }[] anchors
function M.ref_parts(ref)
  local raw = ref.raw
  local target_offset
  if ref.target_range then
    target_offset = ref.target_range.start_col - ref.range.start_col
  elseif ref.kind == "wiki" then
    target_offset = ref.embed and 3 or 2 -- ![[ / [[
  else
    local _, close = raw:find("](", 1, true)
    target_offset = close or 0
  end

  local target_start = ref.range.start_col + target_offset
  local note_part = {
    text = ref.target,
    start_col = target_start,
    end_col = target_start + #ref.target,
  }

  local anchors = {}
  local raw_anchor = (ref.anchor or ""):gsub("\\$", "")
  local anchor_start = target_start + #ref.target + 1 -- salta el primer '#'
  local cursor = 1
  for idx, segment in ipairs(M.split_anchor(raw_anchor)) do
    local found = raw_anchor:find(segment, cursor, true)
    if found then
      local start_col = anchor_start + found - 1
      anchors[#anchors + 1] = {
        text = segment,
        start_col = start_col,
        end_col = start_col + #segment,
        index = idx,
      }
      cursor = found + #segment + 1
    end
  end
  return note_part, anchors
end

---@param ref obsidian.parse.Ref
---@param col integer 0-based byte column
---@return { kind: "note"|"heading", text: string, start_col: integer, end_col: integer, index?: integer }
function M.component_at(ref, col)
  local note_part, anchors = M.ref_parts(ref)
  for _, part in ipairs(anchors) do
    -- El '#' pertenece al heading que introduce.
    if part.start_col - 1 <= col and col < part.end_col then
      return vim.tbl_extend("force", { kind = "heading" }, part)
    end
  end
  if note_part.text == "" and #anchors > 0 then
    return vim.tbl_extend("force", { kind = "heading" }, anchors[#anchors])
  end
  return vim.tbl_extend("force", { kind = "note" }, note_part)
end

---@param bufnr integer
---@param row integer 0-based
---@return { section: obsidian.Section, text: string, range: lsp.Range, note: obsidian.Note }|?
function M.declaration_at(bufnr, row)
  local note = require("obsidian.note").from_buffer(bufnr, {
    collect_sections = true,
    collect_anchor_links = true,
    max_lines = math.huge,
  })
  if not note then
    return nil
  end

  for _, section in ipairs(note.sections or {}) do
    local heading_range = section.heading_range
    if section.header and heading_range.start_row <= row and row < heading_range.end_row then
      local text_row = heading_range.start_row
      local line = vim.api.nvim_buf_get_lines(bufnr, text_row, text_row + 1, false)[1] or ""
      local start_col
      local _, prefix_end = line:find("^%s*#+%s+")
      if prefix_end then
        start_col = line:find(section.header, prefix_end + 1, true)
      else
        start_col = line:find(section.header, 1, true)
      end
      start_col = (start_col or 1) - 1
      return {
        section = section,
        text = section.header,
        note = note,
        range = {
          start = { line = text_row, character = start_col },
          ["end"] = { line = text_row, character = start_col + #section.header },
        },
      }
    end
  end
end

---@param root string
---@return string[]
local function note_paths(root)
  local paths = {}
  for path in require("obsidian.api").dir(root) do
    local ext = path:match("%.([^./]+)$")
    if ext and NOTE_EXTENSIONS[ext:lower()] then
      paths[#paths + 1] = normalize(path)
    end
  end
  table.sort(paths)
  return paths
end

---@param index table<string, table<string, boolean>>
---@param key string|?
---@param path string
local function index_add(index, key, path)
  if not key or key == "" then
    return
  end
  key = string.lower(vim.uri_decode(key) or key):gsub("\\", "/")
  index[key] = index[key] or {}
  index[key][path] = true
end

---@param paths string[]
---@param root string
---@return table<string, table<string, boolean>>
local function build_note_index(paths, root)
  local index = {}
  local Note = require("obsidian.note")
  for _, path in ipairs(paths) do
    local note = Note.from_file(path, { max_lines = 200 })
    if note then
      for _, id in ipairs(note:reference_ids()) do
        index_add(index, id, path)
      end
      local relative = vim.fs.relpath(root, path)
      if relative then
        index_add(index, relative, path)
        index_add(index, relative:gsub("%.[^./]+$", ""), path)
      end
    end
  end
  return index
end

---@param target string
---@return string[]
local function target_names(target)
  local ext = target:match("%.([^./\\]+)$")
  if ext then
    return { target }
  end
  return { target, target .. ".md", target .. ".qmd", target .. ".base" }
end

---@param ref obsidian.parse.Ref
---@param source_path string
---@param target_path string
---@param root string
---@param index table<string, table<string, boolean>>
---@return boolean matches
---@return boolean ambiguous
local function ref_targets_note(ref, source_path, target_path, root, index)
  local target = vim.uri_decode(ref.target or "") or ref.target or ""
  target = target:gsub("\\", "/")
  if target == "" then
    return normalize(source_path) == target_path, false
  end
  if require("obsidian.util").is_uri(target) then
    return false, false
  end

  local direct = {}
  local function add(path)
    path = normalize(path)
    local stat = uv.fs_stat(path)
    if stat and stat.type == "file" then
      direct[path] = true
    end
  end

  local absolute = vim.fn.isabsolutepath(target) == 1
  if absolute then
    for _, name in ipairs(target_names(target)) do
      add(name)
    end
  end
  if vim.tbl_isempty(direct) then
    for _, name in ipairs(target_names(target:gsub("^/", ""))) do
      add(vim.fs.joinpath(vim.fs.dirname(source_path), name))
      add(vim.fs.joinpath(root, name))
    end
  end

  if not vim.tbl_isempty(direct) then
    local contains_target = direct[target_path] == true
    return contains_target and vim.tbl_count(direct) == 1, contains_target and vim.tbl_count(direct) > 1
  end

  local candidates = index[string.lower(target)] or {}
  local count = vim.tbl_count(candidates)
  local contains_target = candidates[target_path] == true
  return contains_target and count == 1, contains_target and count > 1
end

---@param name string
---@return string anchor Segmento canónico sin `#`.
function M.anchor_segment(name)
  return require("obsidian.util").standardize_anchor("#" .. name):gsub("^#", "")
end

--- Cómo se ESCRIBE un anchor, que no es lo mismo que cómo se resuelve.
---
--- `M.resolve` estandariza los dos lados antes de comparar, así que un enlace
--- resuelve igual escrito `#Mi Heading` que `#mi-heading`. El slug nunca fue
--- un requisito del motor: era solo la forma que elegíamos al escribir. Y era
--- la forma equivocada -- la app de Obsidian escribe el texto del heading tal
--- cual, y es lo que ya usa la inmensa mayoría del vault. Cada rename que
--- pasaba por aquí convertía ese estilo al slug y erosionaba el vault.
---
--- Lo único que sigue dependiendo de la sintaxis es qué puede representar cada
--- una:
---   - wiki `[[Nota#Mi Heading]]`: admite espacios y mayúsculas tal cual.
---   - markdown `[x](nota.md#Mi%20Heading)`: NO. Un espacio corta el destino
---     y el parser se queda con medio enlace, así que se percent-encodea
---     siempre (antes solo se hacía si el anchor ya venía encodeado).
---@param name string Texto del heading.
---@param kind string|? Sintaxis que aloja el anchor (`ref.kind`).
---@return string
function M.anchor_text(name, kind)
  if kind == "markdown" or kind == "reference" then
    -- Mismo codificador que los destinos (lzy.link_target.encode): escapa el
    -- espacio y deja legible lo que no molesta. El `#` sí hay que escaparlo
    -- aquí, y sólo aquí: dentro de un segmento de anchor sería una división de
    -- nivel falsa, mientras que en un destino es el separador legítimo.
    return (require("lzy.link_target").encode(name):gsub("#", "%%23"))
  end
  if name:find "[%[%]|#]" then
    -- `]]` cierra el enlace, `|` abre el alias y `#` baja un nivel: un heading
    -- que los contenga no es representable verbatim dentro de `[[...]]`. Solo
    -- ahí se cae al anchor canónico, que sí lo es.
    return M.anchor_segment(name)
  end
  return name
end

---@param name string
---@return string|? err
function M.validate_name(name)
  if name == "" then
    return "El heading nuevo no puede estar vacío"
  end
  if name ~= vim.trim(name) then
    return "El heading nuevo no puede empezar ni terminar con espacios"
  end
  if name:find("[\r\n]") then
    return "El heading nuevo no puede contener saltos de línea"
  end
  if name:find("#", 1, true) then
    return "El heading nuevo no puede contener '#': separa niveles en los enlaces Obsidian"
  end
  if M.anchor_segment(name) == "" then
    return "El heading nuevo debe contener algún carácter válido para construir su enlace"
  end
end

---@param edits_by_path table<string, lsp.TextEdit[]>
---@param path string
---@param edit lsp.TextEdit
local function add_edit(edits_by_path, path, edit)
  local edits = edits_by_path[path] or {}
  local key = table.concat({
    edit.range.start.line,
    edit.range.start.character,
    edit.range["end"].line,
    edit.range["end"].character,
  }, ":")
  for _, existing in ipairs(edits) do
    local existing_key = table.concat({
      existing.range.start.line,
      existing.range.start.character,
      existing.range["end"].line,
      existing.range["end"].character,
    }, ":")
    if existing_key == key then
      return
    end
  end
  edits[#edits + 1] = edit
  edits_by_path[path] = edits
end

---@param note obsidian.Note
---@param section obsidian.Section
---@param new_name string
---@param callback fun(err: any, edit: lsp.WorkspaceEdit|?)
---@param opts { notify?: fun(msg: string, level?: integer) }|?
function M.rename(note, section, new_name, callback, opts)
  opts = opts or {}
  local notify = opts.notify or function(msg, level)
    vim.notify(msg, level, { title = "Nyabsidian" })
  end
  new_name = new_name or ""
  local validation_error = M.validate_name(new_name)
  if validation_error then
    notify(validation_error, vim.log.levels.ERROR)
    return callback(nil, {})
  end
  if new_name == section.header then
    return callback(nil, {})
  end

  note = assert(M.load_note(note), "no se pudo cargar la nota del heading")
  local selected_row = section.heading_range.start_row
  section = assert(
    vim.iter(note.sections or {}):find(function(candidate)
      return candidate.header and candidate.heading_range.start_row == selected_row
    end),
    "no se pudo reubicar el heading"
  )

  local root = normalize(tostring(Obsidian.dir))
  local target_path = normalize(tostring(note.path))
  local paths = note_paths(root)
  local index = build_note_index(paths, root)
  local edits_by_path = {}
  local skipped_ambiguous = 0
  local changed_refs = 0
  local parse_refs = require("obsidian.parse.refs")

  for _, source_path in ipairs(paths) do
    for row, line in ipairs(read_lines(source_path)) do
      for _, ref in ipairs(parse_refs.extract(line, { row = row - 1 })) do
        if ref.anchor then
          local targets, ambiguous = ref_targets_note(ref, source_path, target_path, root, index)
          if ambiguous then
            skipped_ambiguous = skipped_ambiguous + 1
          elseif targets then
            local matches = M.resolve(note, ref.anchor)
            if #matches == 1 then
              local match = matches[1]
              local _, anchor_parts = M.ref_parts(ref)
              local selected_idx
              for idx, chain_section in ipairs(match.chain) do
                if chain_section.heading_range.start_row == selected_row then
                  local anchor_idx = idx - match.chain_start + 1
                  if anchor_idx >= 1 and anchor_idx <= #anchor_parts then
                    selected_idx = anchor_idx
                  end
                  break
                end
              end

              local part = selected_idx and anchor_parts[selected_idx] or nil
              if part then
                add_edit(edits_by_path, source_path, {
                  range = {
                    start = { line = row - 1, character = part.start_col },
                    ["end"] = { line = row - 1, character = part.end_col },
                  },
                  newText = M.anchor_text(new_name, ref.kind),
                })
                changed_refs = changed_refs + 1
              end
            end
          end
        end
      end
    end
  end

  local declaration
  local target_lines = read_lines(target_path)
  local line = target_lines[selected_row + 1] or ""
  local _, prefix_end = line:find("^%s*#+%s+")
  local start_col = line:find(section.header, (prefix_end or 0) + 1, true)
  if not start_col then
    start_col = line:find(section.header, 1, true)
  end
  if start_col then
    start_col = start_col - 1
    declaration = {
      range = {
        start = { line = selected_row, character = start_col },
        ["end"] = { line = selected_row, character = start_col + #section.header },
      },
      newText = new_name,
    }
    add_edit(edits_by_path, target_path, declaration)
  else
    notify("No se pudo localizar el texto del heading en su nota", vim.log.levels.ERROR)
    return callback(nil, {})
  end

  local document_changes = {}
  local touched_buffers = {}
  for path, edits in pairs(edits_by_path) do
    table.sort(edits, function(a, b)
      if a.range.start.line == b.range.start.line then
        return a.range.start.character > b.range.start.character
      end
      return a.range.start.line > b.range.start.line
    end)
    document_changes[#document_changes + 1] = {
      textDocument = {
        uri = vim.uri_from_fname(path),
        version = HAS_NVIM_012 and vim.NIL or nil,
      },
      edits = edits,
    }
    touched_buffers[#touched_buffers + 1] = vim.fn.bufnr(path, true)
  end
  table.sort(document_changes, function(a, b)
    return a.textDocument.uri < b.textDocument.uri
  end)

  callback(nil, { documentChanges = document_changes })
  vim.schedule(function()
    for _, bufnr in ipairs(touched_buffers) do
      if vim.api.nvim_buf_is_valid(bufnr) then
        vim.bo[bufnr].filetype = "markdown"
      end
    end
    vim.cmd("silent! wall")
    local suffix = skipped_ambiguous > 0
        and ("; %d referencia(s) ambiguas se dejaron intactas"):format(skipped_ambiguous)
      or ""
    notify(("Heading renombrado; %d referencia(s) actualizadas%s"):format(changed_refs, suffix))
  end)
end

return M
