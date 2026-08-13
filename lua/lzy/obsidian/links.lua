-- Integración única de enlaces para obsidian-ls.
--
-- `gd`, la acción inteligente de `<CR>`, `:Obsidian follow_link` y el rename
-- LSP pasan por los mismos parsers y resolutores. Así no pueden discrepar sobre
-- qué significan `nota`, `#header` y `#subheader`.

local M = {}

local installed = false
local prepared_heading
local prepared_attachment
local choose_heading
local notify = function(msg, level)
  vim.notify(msg, level, { title = "Nyabsidian" })
end

---@param line string
---@param row integer
---@param col integer
---@return table|?
local function angle_ref_at(line, row, col)
  local function inside_inline_code(start_col)
    local prefix = line:sub(1, start_col - 1)
    return #prefix:gsub("[^`]", "") % 2 == 1
  end

  for start_col, target, end_col in line:gmatch "()<([^<>%s]+)>()" do
    if
      target:match "^[%a][%w%+%.%-]*://"
      and not inside_inline_code(start_col)
      and start_col - 1 <= col
      and col < end_col - 1
    then
      return {
        kind = "autolink",
        raw = "<" .. target .. ">",
        range = { start_row = row, start_col = start_col - 1, end_row = row, end_col = end_col - 1 },
        target = target,
        raw_target = target,
        target_range = { start_col = start_col, end_col = end_col - 2 },
        embed = false,
      }
    end
  end
end

---@param value string
---@return string
local function normalize_reference_id(value)
  value = require("obsidian.util").unescape_single_backslash(value)
  return vim.trim(value):gsub("%s+", " "):lower()
end

---@param line string
---@param row integer
---@return table[]
local function reference_usages(line, row)
  local refs, search = {}, 1
  local function inside_inline_code(start_col)
    local prefix = line:sub(1, start_col - 1)
    return #prefix:gsub("[^`]", "") % 2 == 1
  end

  while search <= #line do
    local start_col, end_col, label, id = line:find("!?%[([^%[%]]+)%]%[([^%[%]]*)%]", search)
    if not start_col then
      break
    end
    if not inside_inline_code(start_col) then
      local opening = line:sub(start_col, start_col) == "!" and start_col + 1 or start_col
      local label_range = { start_col = opening, end_col = opening + #label }
      local id_range
      if id == "" then
        id = label
        id_range = label_range
      else
        local id_opening = opening + #label + 2
        id_range = { start_col = id_opening, end_col = id_opening + #id }
      end
      refs[#refs + 1] = {
        kind = "reference_link",
        raw = line:sub(start_col, end_col),
        range = { start_row = row, start_col = start_col - 1, end_row = row, end_col = end_col },
        label = label,
        label_range = label_range,
        reference_id = id,
        reference_id_range = id_range,
        embed = line:sub(start_col, start_col) == "!",
      }
    end
    search = end_col + 1
  end
  search = 1
  while search <= #line do
    local start_col, end_col, label = line:find("!?%[([^%[%]]+)%]", search)
    if not start_col then
      break
    end
    local before = line:sub(start_col - 1, start_col - 1)
    local after = line:sub(end_col + 1, end_col + 1)
    local prefix = line:sub(1, start_col - 1)
    local task = (label == " " or label:lower() == "x")
      and (
        prefix:match("^%s*[%-%*+]%s*$")
        or prefix:match("^%s*%d+[%.%)]%s*$")
      )
    local overlaps = false
    for _, ref in ipairs(refs) do
      if ref.range.start_col < end_col and start_col - 1 < ref.range.end_col then
        overlaps = true
        break
      end
    end
    if
      not overlaps
      and not task
      and label:sub(1, 1) ~= "^"
      and before ~= "["
      and before ~= "]"
      and after ~= "("
      and after ~= "["
      and after ~= ":"
      and not inside_inline_code(start_col)
    then
      local opening = line:sub(start_col, start_col) == "!" and start_col + 1 or start_col
      local range = { start_col = opening, end_col = opening + #label }
      refs[#refs + 1] = {
        kind = "reference_link",
        raw = line:sub(start_col, end_col),
        range = { start_row = row, start_col = start_col - 1, end_row = row, end_col = end_col },
        label = label,
        label_range = range,
        reference_id = label,
        reference_id_range = range,
        shortcut = true,
        embed = line:sub(start_col, start_col) == "!",
      }
    end
    search = end_col + 1
  end
  table.sort(refs, function(a, b)
    return a.range.start_col < b.range.start_col
  end)
  return refs
end

---@param id string
---@param bufnr integer
---@return table|?
local function reference_definition(id, bufnr)
  local wanted = normalize_reference_id(id)
  for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    for _, ref in ipairs(require("lzy.obsidian.attachments").parse_refs(line, row - 1)) do
      if ref.kind == "reference" and normalize_reference_id(ref.label) == wanted then
        return ref
      end
    end
  end
end

---@param ref table
---@return table
local function split_reference_target(ref)
  local target = ref.raw_target
  local hash = target and target:find("#", 1, true) or nil
  if hash then
    local fragment = target:sub(hash + 1)
    ref.target = target:sub(1, hash - 1)
    if fragment:sub(1, 1) == "^" then
      ref.block = fragment:sub(2)
    else
      ref.anchor = fragment
    end
  else
    ref.target = target
  end
  return ref
end

---@param bufnr integer
---@param row integer 0-based
---@param col integer 0-based byte column
---@return obsidian.parse.Ref|table|?
local function ref_at(bufnr, row, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1] or ""
  local parsed_refs = require("obsidian.parse.refs").extract(line, { row = row })
  local ranged_refs = require("lzy.obsidian.attachments").parse_refs(line, row)
  for _, usage in ipairs(reference_usages(line, row)) do
    if usage.range.start_col <= col and col < usage.range.end_col then
      local definition = reference_definition(usage.reference_id, bufnr)
      if definition then
        usage.raw_target = definition.raw_target
        usage.definition = definition
        return split_reference_target(usage)
      end
      if not usage.shortcut then
        return usage
      end
    end
  end
  for _, ref in ipairs(ranged_refs) do
    if
      ref.kind == "reference"
      and (
        ref.label_range.start_col <= col
        and col < ref.label_range.end_col
        or ref.target_range.start_col <= col
          and col < ref.target_range.end_col
        or ref.title_range
          and ref.title_range.start_col <= col
          and col < ref.title_range.end_col
      )
    then
      return split_reference_target(ref)
    end
  end
  for _, ref in ipairs(parsed_refs) do
    if ref.range.start_col <= col and col < ref.range.end_col then
      for _, ranged in ipairs(ranged_refs) do
        if
          ranged.raw == ref.raw
          and ranged.range.start_col == ref.range.start_col
          and ranged.range.end_col == ref.range.end_col
        then
          ref.raw_target = ranged.target
          ref.target_range = ranged.target_range
          break
        end
      end
      return ref
    end
  end
  return angle_ref_at(line, row, col)
end

---@param bufnr integer|?
---@return obsidian.parse.Ref|table|?
local function cursor_ref(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cursor_row, col = unpack(vim.api.nvim_win_get_cursor(0))
  return ref_at(bufnr, cursor_row - 1, col)
end

---@param ref table
---@return table|?
local function label_component(ref)
  if not ref.label then
    return nil
  end
  local offset
  if ref.kind == "markdown" then
    offset = ref.embed and 2 or 1
  elseif ref.kind == "reference" then
    return {
      kind = "reference_id",
      text = ref.label,
      start_col = ref.label_range.start_col,
      end_col = ref.label_range.end_col,
    }
  elseif ref.kind == "reference_link" then
    local collapsed = ref.label_range.start_col == ref.reference_id_range.start_col
      and ref.label_range.end_col == ref.reference_id_range.end_col
    return {
      kind = collapsed and "reference_id" or "label",
      text = ref.label,
      start_col = ref.label_range.start_col,
      end_col = ref.label_range.end_col,
    }
  elseif ref.kind == "wiki" then
    local pipe = ref.raw:find("|", 1, true)
    if not pipe then
      return nil
    end
    offset = pipe
  else
    return nil
  end
  return {
    kind = "label",
    text = ref.label,
    start_col = ref.range.start_col + offset,
    end_col = ref.range.start_col + offset + #ref.label,
  }
end

---@return { ref: table, component: table, label?: table }|?
local function cursor_context()
  local ref = cursor_ref()
  if not ref then
    return nil
  end
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  local attachments = require "lzy.obsidian.attachments"
  local label = label_component(ref)
  if label and label.start_col <= col and col < label.end_col then
    return { ref = ref, component = label, label = label }
  end

  if ref.kind == "reference_link" then
    local id = ref.reference_id_range
    if id.start_col <= col and col < id.end_col then
      return {
        ref = ref,
        label = label,
        component = {
          kind = "reference_id",
          text = ref.reference_id,
          start_col = id.start_col,
          end_col = id.end_col,
        },
      }
    end
    return nil
  end

  if
    ref.kind == "reference"
    and ref.title_range
    and ref.title_range.start_col <= col
    and col < ref.title_range.end_col
  then
    return {
      ref = ref,
      label = label,
      component = {
        kind = "description",
        text = ref.title,
        start_col = ref.title_range.start_col,
        end_col = ref.title_range.end_col,
      },
    }
  end

  local raw_target = ref.raw_target or ref.target
  if attachments.is_target(raw_target, { bufnr = vim.api.nvim_get_current_buf() }) then
    return {
      ref = ref,
      label = label,
      component = {
        kind = "attachment",
        text = raw_target,
        start_col = ref.target_range.start_col,
        end_col = ref.target_range.end_col,
      },
    }
  end

  if ref.kind == "autolink" or require("obsidian.util").is_uri(raw_target) then
    if
      ref.target_range
      and ref.target_range.start_col <= col
      and col < ref.target_range.end_col
    then
      return {
        ref = ref,
        label = label,
        component = {
          kind = "url",
          text = raw_target,
          start_col = ref.target_range.start_col,
          end_col = ref.target_range.end_col,
        },
      }
    end
    return nil
  end
  return {
    ref = ref,
    label = label,
    component = require("lzy.obsidian.headings").component_at(ref, col),
  }
end

---@param note obsidian.Note
---@return lsp.Location
local function note_location(note)
  return note:_location()
end

---@param location string
---@param bufnr integer
---@param callback fun(notes: obsidian.Note[])
local function resolve_notes(location, bufnr, callback)
  local headings = require "lzy.obsidian.headings"
  if location == "" then
    local note = require("obsidian.api").current_note(bufnr, {
      collect_sections = true,
      collect_anchor_links = true,
      max_lines = math.huge,
    })
    return callback(note and { headings.load_note(note) } or {})
  end

  require("lzy.obsidian.notes").resolve_async(location, function(notes)
    callback(vim.tbl_map(function(note)
      return headings.load_note(note)
    end, notes))
  end)
end

---@param link string
---@param callback function
---@param opts table|?
---@param original function
---@return boolean handled
local function follow_structured(link, callback, opts, original)
  opts = opts or {}
  local util = require "obsidian.util"
  local attachments = require "lzy.obsidian.attachments"
  local headings = require "lzy.obsidian.headings"
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  -- El parser upstream incluye títulos Markdown dentro de `target`. Nuestro
  -- parser conserva el rango y el target real, que es el que también consume
  -- rename. Así definición, acción inteligente y rename ven el mismo enlace.
  local attachment_ref = attachments.parse_refs(link, 0)[1]
  if attachment_ref and attachments.is_target(attachment_ref.target, { bufnr = bufnr }) then
    return attachments.follow(attachment_ref.target, {
      bufnr = bufnr,
      callback = callback,
      notify = notify,
    })
  end

  local location, _, link_type = util.parse_link(link)
  if not location or (link_type ~= "wiki" and link_type ~= "markdown") then
    return false
  end

  location = vim.uri_decode(location) or location
  local without_block, block = util.strip_block_links(location)
  if block then
    return false
  end
  local note_target, anchor, raw_anchor = util.strip_anchor_links(without_block)
  anchor = raw_anchor or anchor

  if attachments.is_target(note_target, { bufnr = bufnr }) then
    return attachments.follow(note_target, {
      bufnr = bufnr,
      callback = callback,
      notify = notify,
    })
  end
  if not anchor then
    return false
  end

  resolve_notes(note_target, bufnr, function(notes)
    if #notes == 0 then
      -- Conserva la creación de notas del upstream cuando la nota tampoco
      -- existe. El caso corregido aquí es nota existente + heading ausente.
      return original(link, callback, opts)
    end

    local locations = {}
    for _, note in ipairs(notes) do
      for _, match in ipairs(headings.resolve(note, anchor)) do
        locations[#locations + 1] = headings.location(match.note, match.section)
      end
    end
    if #locations > 0 then
      return callback(nil, locations)
    end

    -- Un fragmento roto no convierte una nota existente en una nota ausente:
    -- se diagnostica el heading y se devuelve la nota como fallback. Esto hace
    -- que gd y <CR> sigan siendo útiles mientras el enlace se repara.
    notify(headings.missing_message(notes[1], anchor), vim.log.levels.ERROR)
    callback(nil, vim.tbl_map(note_location, notes))
  end)
  return true
end

local function patch_cursor_autolink()
  local api = require "obsidian.api"
  if api.__nyabsidian_cursor_link then
    return
  end
  local original = api.cursor_link

  api.cursor_link = function(...)
    local link, kind, range = original(...)
    if link then
      return link, kind, range
    end

    local line = vim.api.nvim_get_current_line()
    local _, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    local structured = cursor_ref()
    if
      structured
      and (structured.kind == "reference" or structured.kind == "reference_link")
      and structured.raw_target
    then
      return ("[%s](%s)"):format(structured.label, structured.raw_target), "markdown", {
        structured.range.start_col,
        structured.range.end_col,
      }
    end
    local ref = angle_ref_at(line, 0, cur_col)
    if ref then
      return ("[%s](%s)"):format(ref.target, ref.target), "markdown", {
        ref.range.start_col,
        ref.range.end_col,
      }
    end
  end
  api.__nyabsidian_cursor_link = true
end

---@param old_id string
---@param new_id string
---@param bufnr integer|?
---@return lsp.WorkspaceEdit|?
---@return string|? err
local function reference_id_edit(old_id, new_id, bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if new_id == "" or vim.trim(new_id) == "" then
    return nil, "El identificador de referencia no puede estar vacío"
  elseif new_id:find("[%[%]\r\n]") then
    return nil, "El identificador de referencia no puede contener corchetes ni saltos de línea"
  end

  local wanted = normalize_reference_id(old_id)
  local edits, seen = {}, {}
  local function add(row, range)
    local key = table.concat({ row, range.start_col, range.end_col }, ":")
    if not seen[key] then
      seen[key] = true
      edits[#edits + 1] = {
        range = {
          start = { line = row, character = range.start_col },
          ["end"] = { line = row, character = range.end_col },
        },
        newText = new_id,
      }
    end
  end

  for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    for _, ref in ipairs(require("lzy.obsidian.attachments").parse_refs(line, row - 1)) do
      if ref.kind == "reference" and normalize_reference_id(ref.label) == wanted then
        add(row - 1, ref.label_range)
      end
    end
    for _, ref in ipairs(reference_usages(line, row - 1)) do
      if normalize_reference_id(ref.reference_id) == wanted then
        add(row - 1, ref.reference_id_range)
      end
    end
  end
  if #edits == 0 then
    return nil, "No se encontró la referencia que se quería renombrar"
  end
  table.sort(edits, function(a, b)
    if a.range.start.line == b.range.start.line then
      return a.range.start.character > b.range.start.character
    end
    return a.range.start.line > b.range.start.line
  end)
  return { changes = { [vim.uri_from_bufnr(bufnr)] = edits } }
end

local function patch_definition()
  local definition = require "obsidian.lsp.handlers._definition"
  if definition.__nyabsidian_links then
    return
  end
  local original = definition.follow_link

  definition.follow_link = function(link, callback, opts)
    if follow_structured(link, callback, opts, original) then
      return
    end
    return original(link, callback, opts)
  end
  definition.__nyabsidian_links = true
end

local function patch_action_follow()
  local actions = require "obsidian.actions"
  if actions.__nyabsidian_attachments then
    return
  end
  local original = actions.follow_link

  actions.follow_link = function(link, opts)
    local attachments = require "lzy.obsidian.attachments"
    local bufnr = vim.api.nvim_get_current_buf()
    local ref
    if link then
      ref = attachments.parse_refs(link, 0)[1]
    else
      ref = attachments.cursor_ref(bufnr)
    end
    if ref and attachments.is_target(ref.target, { bufnr = bufnr }) then
      return attachments.follow(ref.target, { bufnr = bufnr, notify = notify })
    end
    return original(link, opts)
  end
  actions.__nyabsidian_attachments = true
end

---@param result table
---@param callback function
local function prepare_result(result, callback)
  callback(nil, {
    range = result.range,
    placeholder = result.text,
  })
end

---@param context table
---@return string
local function context_key(context)
  return table.concat({
    vim.api.nvim_get_current_buf(),
    context.ref.range.start_row,
    context.component.start_col,
    context.component.end_col,
    context.component.index or 0,
    context.ref.raw,
  }, ":")
end

---@param context table
---@param callback fun(candidates: table[], err: string|?)
local function heading_candidates(context, callback)
  local headings = require "lzy.obsidian.headings"
  local ref = context.ref
  local target = vim.uri_decode(ref.target or "") or ref.target or ""
  resolve_notes(target, vim.api.nvim_get_current_buf(), function(notes)
    if #notes == 0 then
      return callback({}, ("No existe la nota '%s'"):format(target))
    end

    local candidates = {}
    for _, note in ipairs(notes) do
      local matches, segments = headings.resolve(note, ref.anchor or "")
      for _, match in ipairs(matches) do
        local chain_idx = match.chain_start + context.component.index - 1
        local section = context.component.index <= #segments and match.chain[chain_idx] or nil
        if section then
          candidates[#candidates + 1] = { note = match.note, section = section }
        end
      end
    end
    if #candidates == 0 then
      return callback({}, headings.missing_message(notes[1], ref.anchor or ""))
    end
    callback(candidates)
  end)
end

local function patch_prepare_rename()
  local handlers = require "obsidian.lsp.handlers"
  if handlers.__nyabsidian_prepare_rename then
    return
  end
  local original = handlers["textDocument/prepareRename"]

  handlers["textDocument/prepareRename"] = function(params, callback, dispatchers)
    prepared_heading = nil
    prepared_attachment = nil
    local context = cursor_context()
    if context then
      local component = context.component
      if component.kind == "attachment" then
        local attachments = require "lzy.obsidian.attachments"
        local attachment_target = context.ref.raw_target or context.ref.target
        local result = attachments.resolve(attachment_target, {
          bufnr = vim.api.nvim_get_current_buf(),
        })
        if result.status == "missing" then
          notify("Rename de adjunto: " .. result.reason, vim.log.levels.ERROR)
          return callback(nil, nil)
        end
        prepared_attachment = { key = context_key(context), path = result.path }
        local row = context.ref.range.start_row
        return prepare_result({
          text = attachments.rename_placeholder(attachment_target, result.path, {
            bufnr = vim.api.nvim_get_current_buf(),
          }),
          range = {
            start = { line = row, character = component.start_col },
            ["end"] = { line = row, character = component.end_col },
          },
        }, callback)
      elseif component.kind == "heading" then
        local row = context.ref.range.start_row
        local range = {
          start = { line = row, character = component.start_col },
          ["end"] = { line = row, character = component.end_col },
        }
        return heading_candidates(context, function(candidates, err)
          if err then
            notify(err, vim.log.levels.ERROR)
            return callback(nil, nil)
          end
          choose_heading(candidates, function(candidate)
            if not candidate then
              return callback(nil, nil)
            end
            prepared_heading = { key = context_key(context), candidate = candidate }
            prepare_result({ text = candidate.section.header, range = range }, callback)
          end)
        end)
      elseif component.text ~= "" then
        local row = context.ref.range.start_row
        return prepare_result({
          text = component.text,
          range = {
            start = { line = row, character = component.start_col },
            ["end"] = { line = row, character = component.end_col },
          },
        }, callback)
      end
    end

    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local declaration = require("lzy.obsidian.headings").declaration_at(0, row)
    if declaration then
      return prepare_result({ text = declaration.text, range = declaration.range }, callback)
    end
    return original(params, callback, dispatchers)
  end
  handlers.__nyabsidian_prepare_rename = true
end

---@param candidates table[]
---@param callback fun(candidate: table|?)
choose_heading = function(candidates, callback)
  if #candidates == 1 then
    return callback(candidates[1])
  end
  if #candidates == 0 then
    return callback(nil)
  end
  vim.ui.select(candidates, {
    prompt = "Renombrar heading: elige la definición",
    format_item = function(candidate)
      return ("%s:%d  %s"):format(
        tostring(candidate.note.path),
        candidate.section.heading_range.start_row + 1,
        candidate.section.header
      )
    end,
  }, callback)
end

---@param context table
---@param new_name string
---@param callback function
local function rename_link_heading(context, new_name, callback)
  local headings = require "lzy.obsidian.headings"
  if prepared_heading and prepared_heading.key == context_key(context) then
    local candidate = prepared_heading.candidate
    prepared_heading = nil
    return headings.rename(
      candidate.note,
      candidate.section,
      new_name,
      callback,
      { notify = notify }
    )
  end
  prepared_heading = nil

  heading_candidates(context, function(candidates, err)
    if err then
      notify(err, vim.log.levels.ERROR)
      return callback(nil, {})
    end
    choose_heading(candidates, function(candidate)
      if not candidate then
        return callback(nil, {})
      end
      headings.rename(candidate.note, candidate.section, new_name, callback, { notify = notify })
    end)
  end)
end

---@param edit lsp.WorkspaceEdit|nil
---@param context table
---@param new_name string Nombre base que espera el rename de Obsidian.
---@return lsp.WorkspaceEdit
local function add_reference_note_edit(edit, context, new_name)
  edit = edit or {}
  edit.documentChanges = edit.documentChanges or {}

  local uri = vim.uri_from_bufnr(vim.api.nvim_get_current_buf())
  local row = context.ref.range.start_row
  local start_col, end_col = context.component.start_col, context.component.end_col
  for _, change in ipairs(edit.documentChanges) do
    if change.textDocument and change.textDocument.uri == uri then
      for _, text_edit in ipairs(change.edits or {}) do
        local range = text_edit.range
        if
          range.start.line == row
          and range.start.character <= start_col
          and range["end"].character >= end_col
        then
          return edit
        end
      end
    end
  end

  local replacement = new_name
  if context.component.text:lower():sub(-3) == ".md" then
    replacement = replacement .. ".md"
  end
  table.insert(edit.documentChanges, 1, {
    textDocument = { uri = uri, version = vim.NIL },
    edits = {
      {
        range = {
          start = { line = row, character = start_col },
          ["end"] = { line = row, character = end_col },
        },
        newText = replacement,
      },
    },
  })
  return edit
end

local function patch_rename()
  local handlers = require "obsidian.lsp.handlers"
  if handlers.__nyabsidian_rename then
    return
  end
  local original = handlers["textDocument/rename"]

  handlers["textDocument/rename"] = function(params, callback, dispatchers)
    local ok_wall, err_wall = pcall(vim.cmd.wall)
    if not ok_wall then
      notify("No se pudieron guardar los buffers: " .. tostring(err_wall), vim.log.levels.ERROR)
      return callback(nil, {})
    end

    local context = cursor_context()
    if context then
      local attachments = require "lzy.obsidian.attachments"
      if context.component.kind == "reference_id" then
        prepared_heading = nil
        prepared_attachment = nil
        local edit, err = reference_id_edit(
          context.component.text,
          params.newName,
          vim.api.nvim_get_current_buf()
        )
        if not edit then
          notify(err, vim.log.levels.ERROR)
          return callback(nil, {})
        end
        return callback(nil, edit)
      elseif
        context.component.kind == "label"
        or context.component.kind == "url"
        or context.component.kind == "description"
      then
        prepared_heading = nil
        prepared_attachment = nil
        local row = context.ref.range.start_row
        local component = context.component
        return callback(nil, {
          changes = {
            [vim.uri_from_bufnr(vim.api.nvim_get_current_buf())] = {
              {
                range = {
                  start = { line = row, character = component.start_col },
                  ["end"] = { line = row, character = component.end_col },
                },
                newText = params.newName,
              },
            },
          },
        })
      elseif context.component.kind == "attachment" then
        prepared_heading = nil
        local function rename_path(path)
          prepared_attachment = nil
          if not path then
            return callback(nil, {})
          end
          local edit, err = attachments.rename(path, params.newName, {
            bufnr = vim.api.nvim_get_current_buf(),
          })
          if not edit then
            if err then
              notify("Rename de adjunto: " .. err, vim.log.levels.ERROR)
            end
            return callback(nil, {})
          end
          vim.schedule(function()
            vim.cmd "silent! wall"
          end)
          return callback(nil, edit)
        end

        if prepared_attachment and prepared_attachment.key == context_key(context) then
          return rename_path(prepared_attachment.path)
        end
        prepared_attachment = nil

        local result = attachments.resolve(context.ref.raw_target or context.ref.target, {
          bufnr = vim.api.nvim_get_current_buf(),
        })
        if result.status == "missing" then
          notify("Rename de adjunto: " .. result.reason, vim.log.levels.ERROR)
          return callback(nil, {})
        end
        return rename_path(result.path)
      elseif context.component.kind == "heading" then
        prepared_attachment = nil
        return rename_link_heading(context, params.newName, callback)
      elseif context.component.kind == "note" then
        prepared_heading = nil
        prepared_attachment = nil
        local upstream_params = params
        local new_name = params.newName
        if #new_name > 3 and new_name:lower():sub(-3) == ".md" then
          new_name = new_name:sub(1, -4)
          upstream_params = vim.tbl_extend("force", {}, params, { newName = new_name })
        end
        if context.ref.kind == "reference" then
          return original(upstream_params, function(err, edit)
            if err then
              return callback(err, edit)
            end
            callback(nil, add_reference_note_edit(edit, context, new_name))
          end, dispatchers)
        end
        return original(upstream_params, callback, dispatchers)
      end
      prepared_heading = nil
      prepared_attachment = nil
      return original(params, callback, dispatchers)
    end

    prepared_heading = nil
    prepared_attachment = nil
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1
    local declaration = require("lzy.obsidian.headings").declaration_at(0, row)
    if declaration then
      return require("lzy.obsidian.headings").rename(
        declaration.note,
        declaration.section,
        params.newName,
        callback,
        { notify = notify }
      )
    end
    return original(params, callback, dispatchers)
  end
  handlers.__nyabsidian_rename = true
end

---@param opts { notify?: fun(msg: string, level?: integer), state?: table }|?
function M.setup(opts)
  opts = opts or {}
  if opts.state then
    opts.state.cursor_link_patched = true
    opts.state.follow_link_patched = true
    opts.state.attachment_rename_patched = true
    opts.state.heading_links_patched = true
  end
  if installed then
    return
  end
  notify = opts.notify or notify
  patch_cursor_autolink()
  patch_definition()
  patch_action_follow()
  patch_prepare_rename()
  patch_rename()
  require("lzy.obsidian.completion").setup()
  require("lzy.obsidian.hover").setup()
  installed = true
end

function M.status()
  return { installed = installed }
end

-- API pequeña para pruebas y diagnóstico.
M.cursor_ref = cursor_ref
M.ref_at = ref_at
M.cursor_context = cursor_context
M.label_component = label_component
M.reference_id_edit = reference_id_edit

return M
