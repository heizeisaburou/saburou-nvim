-- Hover de notas para obsidian-ls. Los adjuntos y URLs se delegan.

local M = {}

---@param note obsidian.Note
---@return string|nil
local function excerpt(note)
  if not note.path then
    return nil
  end
  local ok, lines = pcall(vim.fn.readfile, tostring(note.path), "", 60)
  if not ok then
    return nil
  end

  if lines[1] == "---" then
    table.remove(lines, 1)
    while #lines > 0 do
      local line = table.remove(lines, 1)
      if line == "---" then
        break
      end
    end
  end
  while lines[1] and lines[1]:match "^%s*$" do
    table.remove(lines, 1)
  end

  local result, characters = {}, 0
  for _, line in ipairs(lines) do
    if #result >= 12 or characters + #line > 900 then
      break
    end
    result[#result + 1] = line
    characters = characters + #line
  end
  while result[#result] and result[#result]:match "^%s*$" do
    table.remove(result)
  end
  return #result > 0 and table.concat(result, "\n") or nil
end

---@param note obsidian.Note
---@param ref table
---@return lsp.Hover|nil
local function hover_result(note, ref)
  local preview = excerpt(note)
  if not preview then
    return nil
  end
  local end_col = ref.range.end_col
  if ref.title_range then
    end_col = math.max(end_col, ref.title_range.end_col)
  end
  return {
    contents = { kind = "markdown", value = preview },
    range = {
      start = { line = ref.range.start_row, character = ref.range.start_col },
      ["end"] = { line = ref.range.end_row, character = end_col },
    },
  }
end

---@param original function|nil
---@param params lsp.HoverParams
---@param callback function
---@param dispatchers table
local function fallback(original, params, callback, dispatchers)
  if original then
    return original(params, callback, dispatchers)
  end
  callback(nil, nil)
end

function M.setup()
  local handlers = require "obsidian.lsp.handlers"
  if handlers.__nyabsidian_hover then
    return
  end

  local initialize = handlers.initialize
  handlers.initialize = function(params, callback, dispatchers)
    initialize(params, function(err, result)
      if result and result.capabilities then
        result.capabilities.hoverProvider = true
      end
      callback(err, result)
    end, dispatchers)
  end

  local original = handlers["textDocument/hover"]
  handlers["textDocument/hover"] = function(params, callback, dispatchers)
    local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
    local ref = require("lzy.obsidian.links").ref_at(
      bufnr,
      params.position.line,
      params.position.character
    )
    if not ref or not ref.target or ref.target == "" then
      return fallback(original, params, callback, dispatchers)
    end

    local util = require "obsidian.util"
    local attachments = require "lzy.obsidian.attachments"
    if util.is_uri(ref.target) or attachments.is_target(ref.target, { bufnr = bufnr }) then
      return fallback(original, params, callback, dispatchers)
    end

    require("lzy.obsidian.notes").resolve_async(ref.target, function(notes)
      if #notes == 0 then
        return fallback(original, params, callback, dispatchers)
      end
      local result = hover_result(notes[1], ref)
      if not result then
        return fallback(original, params, callback, dispatchers)
      end
      callback(nil, result)
    end)
  end
  handlers.__nyabsidian_hover = true
end

M.excerpt = excerpt
M.hover_result = hover_result

return M
