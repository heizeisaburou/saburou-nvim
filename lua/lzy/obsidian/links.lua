-- Integración única de enlaces para obsidian-ls.
--
-- `gd`, la acción inteligente de `<CR>`, `:Obsidian follow_link` y el rename
-- LSP pasan por los mismos parsers y resolutores. Así no pueden discrepar sobre
-- qué significan `nota`, `#header` y `#subheader`.

local M = {}

local installed = false
local prepared_heading
local choose_heading
local notify = function(msg, level)
  vim.notify(msg, level, { title = "Nyabsidian" })
end

---@param bufnr integer|?
---@return obsidian.parse.Ref|?
local function cursor_ref(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local line = vim.api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1] or ""
  for _, ref in ipairs(require("obsidian.parse.refs").extract(line, { row = row - 1 })) do
    if ref.range.start_col <= col and col < ref.range.end_col then
      return ref
    end
  end
end

---@return { ref: obsidian.parse.Ref, component: table }|?
local function cursor_context()
  local ref = cursor_ref()
  if not ref then
    return nil
  end
  local _, col = unpack(vim.api.nvim_win_get_cursor(0))
  return {
    ref = ref,
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
  local headings = require("lzy.obsidian.headings")
  if location == "" then
    local note = require("obsidian.api").current_note(bufnr, {
      collect_sections = true,
      collect_anchor_links = true,
      max_lines = math.huge,
    })
    return callback(note and { headings.load_note(note) } or {})
  end

  require("obsidian.search").resolve_note_async(location, function(notes)
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
  local util = require("obsidian.util")
  local attachments = require("lzy.obsidian.attachments")
  local headings = require("lzy.obsidian.headings")
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

  if attachments.is_target(note_target) then
    return attachments.follow(note_target, {
      bufnr = opts.bufnr or vim.api.nvim_get_current_buf(),
      callback = callback,
    })
  end
  if not anchor then
    return false
  end

  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
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
  local api = require("obsidian.api")
  if api.__nyabsidian_cursor_link then
    return
  end
  local original = api.cursor_link

  local function inside_inline_code(line, start_col)
    local prefix = line:sub(1, start_col - 1)
    return #prefix:gsub("[^`]", "") % 2 == 1
  end

  api.cursor_link = function(...)
    local link, kind, range = original(...)
    if link then
      return link, kind, range
    end

    local line = vim.api.nvim_get_current_line()
    local _, cur_col = unpack(vim.api.nvim_win_get_cursor(0))
    for start_col, inner, end_col in line:gmatch("()<([^<>%s]+)>()") do
      if
        inner:match("^[%a][%w%+%.%-]*://")
        and not inside_inline_code(line, start_col)
        and start_col - 1 <= cur_col
        and cur_col < end_col - 1
      then
        return ("[%s](%s)"):format(inner, inner), "markdown", { start_col - 1, end_col - 1 }
      end
    end
  end
  api.__nyabsidian_cursor_link = true
end

local function patch_definition()
  local definition = require("obsidian.lsp.handlers._definition")
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
  local headings = require("lzy.obsidian.headings")
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
  local handlers = require("obsidian.lsp.handlers")
  if handlers.__nyabsidian_prepare_rename then
    return
  end
  local original = handlers["textDocument/prepareRename"]

  handlers["textDocument/prepareRename"] = function(params, callback, dispatchers)
    prepared_heading = nil
    local context = cursor_context()
    if context then
      local component = context.component
      if component.kind == "heading" then
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
  local headings = require("lzy.obsidian.headings")
  if prepared_heading and prepared_heading.key == context_key(context) then
    local candidate = prepared_heading.candidate
    prepared_heading = nil
    return headings.rename(candidate.note, candidate.section, new_name, callback, { notify = notify })
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

local function patch_rename()
  local handlers = require("obsidian.lsp.handlers")
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
      local attachments = require("lzy.obsidian.attachments")
      if attachments.is_target(context.ref.target) then
        prepared_heading = nil
        local edit, err = attachments.rename(context.ref.target, params.newName, {
          bufnr = vim.api.nvim_get_current_buf(),
        })
        if edit then
          vim.schedule(function()
            vim.cmd("silent! wall")
          end)
          return callback(nil, edit)
        elseif err then
          notify("Rename de adjunto: " .. err, vim.log.levels.ERROR)
          return callback(nil, {})
        end
      elseif context.component.kind == "heading" then
        return rename_link_heading(context, params.newName, callback)
      end
      prepared_heading = nil
      return original(params, callback, dispatchers)
    end

    prepared_heading = nil
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
  patch_prepare_rename()
  patch_rename()
  installed = true
end

function M.status()
  return { installed = installed }
end

-- API pequeña para pruebas y diagnóstico.
M.cursor_ref = cursor_ref
M.cursor_context = cursor_context

return M
