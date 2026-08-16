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
---@return string|nil target lo que se inserta
---@return string|nil root_relative el mismo destino medido desde la raíz del vault
local function note_target(bufnr, query, note)
  local coord = require "lzy.link_target"
  local api = require "obsidian.api"
  local root = vim.fs.normalize(tostring(api.resolve_workspace_dir()))
  local path = vim.fs.normalize(tostring(note.path))
  if vim.fn.isabsolutepath(path) == 0 then
    path = vim.fs.joinpath(root, path)
  end

  local root_relative = vim.fs.relpath(root, path)
  if not root_relative then
    return nil
  end

  local target
  if coord.coordinate(query) == coord.NOTE_RELATIVE then
    target = coord.note_relative(path, vim.fs.dirname(vim.api.nvim_buf_get_name(bufnr)), query)
  elseif coord.coordinate(query) == coord.ROOT then
    -- Se ha escrito `/` a propósito: se conserva. Igual que en marksman, esa
    -- barra significa la raíz del vault, no la del sistema.
    target = "/" .. root_relative
  else
    target = root_relative
  end
  local encode = require("obsidian.util").urlencode
  return encode(target, { keep_path_sep = true }), root_relative
end

---@param params lsp.CompletionParams
---@param context nyabsidian.DefinitionCompletionContext
---@param callback fun(result: lsp.CompletionList)
local function complete_definition_target(params, context, callback)
  local util = require "obsidian.util"
  if util.is_uri(context.raw_target) or context.raw_target:match "^[%a][%w+.-]*:" then
    return callback { isIncomplete = false, items = {} }
  end

  local coord = require "lzy.link_target"
  local decoded = vim.uri_decode(context.search) or context.search
  local search = vim.fs.basename(coord.needle(decoded)):gsub("%.md$", "")
  local min_chars = Obsidian.opts.completion.min_chars or 2
  -- Una coordenada explícita ya expresa intención suficiente: `/` a secas debe
  -- listar la raíz del vault en el acto, sin esperar al mínimo de caracteres
  -- que sí se le exige a una búsqueda desnuda. Mismo criterio que en marksman.
  if not coord.is_explicit(decoded) and #search < min_chars then
    return callback { isIncomplete = true, items = {} }
  end

  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  require("obsidian.search").find_notes_async(search, function(notes)
    local items = {}
    for _, note in ipairs(notes) do
      local target, root_relative = note_target(bufnr, decoded, note)
      if target and root_relative then
        items[#items + 1] = {
          label = target,
          filterText = coord.filter_text(decoded, target, root_relative),
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

---El destino de un enlace wiki a medio teclear: lo que va tras el último `[[`
---mientras no aparezca `]`, `|` ni `#` (a partir de ahí ya es etiqueta o ancla,
---territorio del proveedor original).
---@param line string
---@param character integer 0-based byte column
---@return integer|nil start_col
---@return string|nil search
local function wiki_target_context(line, character)
  local prefix = line:sub(1, character)
  local open = prefix:match ".*()%[%["
  if not open then
    return nil
  end
  local search = prefix:sub(open + 2)
  if search:find "[%]|#]" then
    return nil
  end
  return open + 1, search
end

---`[[/` es navegación de rutas, y obsidian.nvim no la hace: su completion de
---enlaces es una búsqueda de notas por nombre, así que ni ofrece las carpetas
---por las que bajar ni entiende un destino que empieza por `/`. Aquí se recorre
---el nivel entero -- carpetas y notas -- igual que en marksman.
---@param params lsp.CompletionParams
---@param start_col integer
---@param search string
---@param callback fun(result: lsp.CompletionList)
local function complete_wiki_target(params, start_col, search, callback)
  local coord = require "lzy.link_target"
  local query = vim.uri_decode(search) or search
  local root = vim.fs.normalize(tostring(require("obsidian.api").resolve_workspace_dir()))
  local encode = require("obsidian.util").urlencode

  local items = {}
  for _, entry in ipairs(coord.entries(query, root, { files = true })) do
    local target = encode(entry.target, { keep_path_sep = true })
    local directory = entry.kind == "directory"
    local scope = entry.scope == "system" and "del sistema" or "del vault"
    items[#items + 1] = {
      label = target,
      filterText = target,
      -- Las carpetas primero: son el camino, no el destino.
      sortText = (directory and "0" or "1") .. target:lower(),
      detail = (directory and "Carpeta " or "Nota ") .. scope,
      kind = directory and vim.lsp.protocol.CompletionItemKind.Folder
        or vim.lsp.protocol.CompletionItemKind.File,
      textEdit = {
        newText = target,
        range = {
          start = { line = params.position.line, character = start_col },
          ["end"] = { line = params.position.line, character = params.position.character },
        },
      },
    }
  end
  callback { isIncomplete = true, items = items }
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

  local wiki_start, wiki_search = wiki_target_context(line, params.position.character)
  if wiki_start then
    ---@cast wiki_search -nil
    return complete_wiki_target(params, wiki_start, wiki_search, callback)
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

--- obsidian.nvim construye los enlaces wiki con `builtin.wiki_link`, que añade
--- `|etiqueta` en cuanto la etiqueta difiere del nombre de la nota. La etiqueta
--- sale de lo tecleado, así que escribir una coordenada (`[[/docs`) sobre una
--- nota con id Zettel produce `[[1786867178-OZDA|/docs]]`: un enlace cuyo alias
--- es media ruta. Un path no es un nombre; se le quita el alias y queda el
--- enlace a secas.
---@param text string
---@return string
local function drop_pathish_alias(text)
  local coord = require "lzy.link_target"
  return (text:gsub("%[%[([^%[%]|]*)|([^%[%]|]*)%]%]", function(target, label)
    if coord.is_pathish(label) then
      return ("[[%s]]"):format(target)
    end
    return ("[[%s|%s]]"):format(target, label)
  end))
end

--- obsidian.nvim ofrece siempre "crear nota nueva" con lo tecleado como nombre.
--- Una coordenada de ruta no es un nombre: `[[/docs` no pide crear una nota
--- llamada `/docs`, pide bajar por `docs`. El item se retira entero en vez de
--- dejar que proponga un archivo con un nombre que nadie ha escrito.
---@param item lsp.CompletionItem
---@return boolean
local function creates_note_named_like_a_path(item)
  local command = item.command and item.command.command
  if command ~= "obsidian.write_note" then
    return false
  end
  local coord = require "lzy.link_target"
  return coord.is_pathish(item.sortText or item.filterText or item.label)
end

---@param list lsp.CompletionList
---@return lsp.CompletionList
local function sanitize(list)
  local items = {}
  for _, item in ipairs(list.items or {}) do
    if not creates_note_named_like_a_path(item) then
      if item.textEdit and type(item.textEdit.newText) == "string" then
        item.textEdit.newText = drop_pathish_alias(item.textEdit.newText)
      end
      if type(item.insertText) == "string" then
        item.insertText = drop_pathish_alias(item.insertText)
      end
      items[#items + 1] = item
    end
  end
  list.items = items
  return list
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

--- obsidian-ls declara `{ "[", "#", "^" }` como caracteres de disparo. La barra
--- no está, y no es un carácter de palabra, así que al teclear `[[/` el cliente
--- no pide nada: la lista no aparecía hasta escribir la primera letra después.
--- Justo lo contrario de lo que hace falta, porque `/` ya es intención de sobra.
---@param handlers table
local function patch_trigger_characters(handlers)
  local original = handlers["initialize"]
  handlers["initialize"] = function(params, callback, dispatchers)
    return original(params, function(err, result)
      local completion = result
        and result.capabilities
        and result.capabilities.completionProvider
      local triggers = completion and completion.triggerCharacters
      if triggers and not vim.tbl_contains(triggers, "/") then
        triggers[#triggers + 1] = "/"
      end
      return callback(err, result)
    end, dispatchers)
  end
end

function M.setup()
  local handlers = require "obsidian.lsp.handlers"
  if handlers.__nyabsidian_completion then
    return
  end
  patch_trigger_characters(handlers)
  local original = handlers["textDocument/completion"]
  handlers["textDocument/completion"] = function(params, callback, dispatchers)
    local pending, original_result, custom_result, original_error = 2
    local function finish()
      pending = pending - 1
      if pending == 0 then
        callback(
          original_error,
          merge(sanitize(completion_list(original_result)), custom_result)
        )
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
M.wiki_target_context = wiki_target_context
M.reference_id_context = reference_id_context
M.sanitize = sanitize
M.custom_completion = custom_completion
M.drop_pathish_alias = drop_pathish_alias

return M
