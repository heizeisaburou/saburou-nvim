-- Completion LSP para las piezas CommonMark que obsidian.nvim no reconoce.

local M = {}

---@class nyabsidian.DefinitionCompletionContext
---@field search string
---@field raw_target string
---@field start_col integer
---@field end_col integer
---@field angled boolean

---@param line string
---@param character integer 0-based byte column
---@return nyabsidian.DefinitionCompletionContext|nil
local function definition_target_context(line, character)
  local indent = line:match "^( *)" or ""
  if #indent > 3 or line:sub(#indent + 1, #indent + 1) ~= "[" then
    return nil
  end

  local closing, escaped
  for idx = #indent + 2, #line do
    local char = line:sub(idx, idx)
    if char == "]" and not escaped then
      closing = idx
      break
    end
    escaped = char == "\\" and not escaped
  end
  if not closing or line:sub(closing + 1, closing + 1) ~= ":" then
    return nil
  end

  local token_start = closing + 2
  while line:sub(token_start, token_start):match "[ \t]" do
    token_start = token_start + 1
  end
  local angled = line:sub(token_start, token_start) == "<"
  local content_start = token_start + (angled and 1 or 0)
  local token_finish = content_start
  while token_finish <= #line do
    local char = line:sub(token_finish, token_finish)
    if angled and char == ">" or not angled and char:match "[ \t]" then
      break
    end
    token_finish = token_finish + 1
  end

  local start_col, target_end = content_start - 1, token_finish - 1
  if character < start_col or character > target_end then
    return nil
  end
  local raw_target = line:sub(content_start, token_finish - 1)
  local hash = raw_target:find("#", 1, true)
  local path_end = hash and start_col + hash - 1 or target_end
  if character > path_end then
    return nil -- headings y blocks siguen perteneciendo al proveedor original
  end

  return {
    search = line:sub(content_start, character),
    raw_target = raw_target,
    start_col = start_col,
    end_col = path_end,
    angled = angled,
  }
end

---@param bufnr integer
---@param query string
---@param note obsidian.Note
---@return string|nil
local function note_target(bufnr, query, note)
  local api = require "obsidian.api"
  local root = vim.fs.normalize(tostring(api.resolve_workspace_dir()))
  local path = vim.fs.normalize(tostring(note.path))
  if vim.fn.isabsolutepath(path) == 0 then
    path = vim.fs.joinpath(root, path)
  end

  local target
  if vim.startswith(query, "./") or vim.startswith(query, "../") then
    local source_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr))
    target = vim.fs.relpath(source_dir, path)
    if not target then
      return nil
    end
    if vim.startswith(query, "./") and not vim.startswith(target, ".") then
      target = "./" .. target
    end
  else
    target = vim.fs.relpath(root, path)
  end
  if not target then
    return nil
  end
  return require("obsidian.util").urlencode(target, { keep_path_sep = true })
end

---@param params lsp.CompletionParams
---@param context nyabsidian.DefinitionCompletionContext
---@param callback fun(result: lsp.CompletionList)
local function complete_definition_target(params, context, callback)
  local util = require "obsidian.util"
  if util.is_uri(context.raw_target) or context.raw_target:match "^[%a][%w+.-]*:" then
    return callback { isIncomplete = false, items = {} }
  end

  local decoded = vim.uri_decode(context.search) or context.search
  local search = vim.fs.basename(decoded):gsub("%.md$", "")
  local min_chars = Obsidian.opts.completion.min_chars or 2
  if #search < min_chars then
    return callback { isIncomplete = true, items = {} }
  end

  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  require("obsidian.search").find_notes_async(search, function(notes)
    local items = {}
    for _, note in ipairs(notes) do
      local target = note_target(bufnr, decoded, note)
      if target then
        items[#items + 1] = {
          label = target,
          filterText = target,
          sortText = target:lower(),
          detail = "Nota del vault",
          kind = vim.lsp.protocol.CompletionItemKind.File,
          documentation = {
            kind = "markdown",
            value = note:display_info { label = target },
          },
          textEdit = {
            newText = target,
            range = {
              start = { line = params.position.line, character = context.start_col },
              ["end"] = { line = params.position.line, character = context.end_col },
            },
          },
        }
      end
    end
    callback { isIncomplete = true, items = items }
  end, {
    dir = require("obsidian.api").resolve_workspace_dir(),
    search = { sort = false, include_templates = false, ignore_case = true },
    notes = {},
  })
end

---@param bufnr integer
---@return { label: string, target: string }[]
local function definitions(bufnr)
  local found, result = {}, {}
  for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
    for _, ref in ipairs(require("lzy.obsidian.attachments").parse_refs(line, row - 1)) do
      if ref.kind == "reference" then
        local key = vim.trim(ref.label):gsub("%s+", " "):lower()
        if not found[key] then
          found[key] = true
          result[#result + 1] = { label = ref.label, target = ref.raw_target }
        end
      end
    end
  end
  return result
end

---@param line string
---@param character integer
---@return integer|nil start_col
---@return string|nil search
local function reference_id_context(line, character)
  local prefix = line:sub(1, character)
  local _, finish, search = prefix:find "!?%[[^%[%]]+%]%[([^%]]*)$"
  if finish then
    return finish - #search, search
  end
  local opening
  opening, _, search = prefix:find "()%[([^%[%]]*)$"
  if opening and line:sub(opening - 1, opening - 1) ~= "]" then
    return opening, search
  end
end

---@param params lsp.CompletionParams
---@param callback fun(result: lsp.CompletionList)
local function custom_completion(params, callback)
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  local line = vim.api.nvim_buf_get_lines(
    bufnr,
    params.position.line,
    params.position.line + 1,
    false
  )[1] or ""
  local target = definition_target_context(line, params.position.character)
  if target then
    return complete_definition_target(params, target, callback)
  end

  local start_col = reference_id_context(line, params.position.character)
  if not start_col then
    return callback { isIncomplete = false, items = {} }
  end
  local items = {}
  for _, definition in ipairs(definitions(bufnr)) do
    items[#items + 1] = {
      label = definition.label,
      filterText = definition.label,
      detail = definition.target,
      kind = vim.lsp.protocol.CompletionItemKind.Reference,
      textEdit = {
        newText = definition.label,
        range = {
          start = { line = params.position.line, character = start_col },
          ["end"] = { line = params.position.line, character = params.position.character },
        },
      },
    }
  end
  callback { isIncomplete = true, items = items }
end

---@param value lsp.CompletionList|lsp.CompletionItem[]|nil
---@return lsp.CompletionList
local function completion_list(value)
  if not value then
    return { isIncomplete = false, items = {} }
  elseif value.items then
    return value
  end
  return { isIncomplete = false, items = value }
end

---@param left lsp.CompletionList
---@param right lsp.CompletionList
---@return lsp.CompletionList
local function merge(left, right)
  local items, seen = {}, {}
  for _, list in ipairs { left, right } do
    for _, item in ipairs(list.items or {}) do
      local edit = item.textEdit
      local key = table.concat({
        item.label or "",
        edit and edit.newText or item.insertText or "",
        edit and vim.inspect(edit.range) or "",
      }, "\0")
      if not seen[key] then
        seen[key] = true
        items[#items + 1] = item
      end
    end
  end
  return { isIncomplete = left.isIncomplete or right.isIncomplete, items = items }
end

function M.setup()
  local handlers = require "obsidian.lsp.handlers"
  if handlers.__nyabsidian_completion then
    return
  end
  local original = handlers["textDocument/completion"]
  handlers["textDocument/completion"] = function(params, callback, dispatchers)
    local pending, original_result, custom_result, original_error = 2
    local function finish()
      pending = pending - 1
      if pending == 0 then
        callback(original_error, merge(completion_list(original_result), custom_result))
      end
    end
    original(params, function(err, result)
      original_error = err
      original_result = result
      finish()
    end, dispatchers)
    custom_completion(params, function(result)
      custom_result = result
      finish()
    end)
  end
  handlers.__nyabsidian_completion = true
end

M.definition_target_context = definition_target_context
M.reference_id_context = reference_id_context
M.custom_completion = custom_completion

return M
