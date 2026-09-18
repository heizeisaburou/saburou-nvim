-- Completion LSP para las piezas CommonMark que obsidian.nvim no reconoce.

local M = {}

--- Un destino de enlace a medio teclear. La sintaxis que lo envuelve cambia
--- --`[[destino`, `[texto](destino`, `[id]: destino`-- pero la pregunta es la
--- misma en las tres, así que se reducen a un único contexto y una única
--- completion: escribir una ruta es escribir una ruta.
---@class nyabsidian.TargetContext
---@field kind "wiki"|"inline"|"definition"
---@field search string lo tecleado desde el inicio del destino hasta el cursor
---@field raw_target string el destino entero, esté tecleado del todo o no
---@field start_col integer 0-based, inicio del trozo de línea que se sustituye
---@field end_col integer 0-based, final de ese trozo
---@field notes boolean si además de rutas hay que buscar notas por nombre

--- El destino que arranca en `token_start` y acaba donde diga la sintaxis: en
--- `>` si viene entre `<...>`, y si no en el primer carácter de `stop`. Solo se
--- sustituye el path: un `#fragment` ya escrito sobrevive intacto.
---@param line string
---@param character integer 0-based byte column
---@param token_start integer 1-based, primer byte tras el delimitador de apertura
---@param stop string patrón Lua de los caracteres que cierran el destino
---@return { search: string, raw_target: string, start_col: integer, end_col: integer }|nil
local function target_bounds(line, character, token_start, stop)
  local angled = line:sub(token_start, token_start) == "<"
  local content_start = token_start + (angled and 1 or 0)
  local token_finish = content_start
  while token_finish <= #line do
    local char = line:sub(token_finish, token_finish)
    if angled and char == ">" or not angled and char:match(stop) then
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
  }
end

---El destino de una definición `[id]: destino "descripción"`.
---@param line string
---@param character integer 0-based byte column
---@return nyabsidian.TargetContext|nil
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
  local bounds = target_bounds(line, character, token_start, "[ \t]")
  return bounds and vim.tbl_extend("error", bounds, { kind = "definition", notes = true })
end

---El destino de un enlace o embed Markdown a medio teclear: lo que va tras
---`](`. Es el mismo caso que `[[`, y hasta ahora era el que faltaba: aquí
---obsidian-ls no completa nada, ni rutas ni notas.
---@param line string
---@param character integer 0-based byte column
---@return nyabsidian.TargetContext|nil
local function inline_target_context(line, character)
  local open = line:sub(1, character):match ".*()%]%("
  if not open then
    return nil
  end
  local bounds = target_bounds(line, character, open + 2, "[%s%)]")
  return bounds and vim.tbl_extend("error", bounds, { kind = "inline", notes = true })
end

---El destino de un enlace wiki a medio teclear: lo que va tras el último `[[`
---mientras no aparezca `]`, `|` ni `#` (a partir de ahí ya es etiqueta o ancla,
---territorio del proveedor original), que además ya busca notas por nombre.
---@param line string
---@param character integer 0-based byte column
---@return nyabsidian.TargetContext|nil
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
  return {
    kind = "wiki",
    search = search,
    raw_target = search,
    start_col = open + 1,
    end_col = character,
    notes = false,
  }
end

---Un anchor de enlace wiki a medio teclear: lo que va tras un `#` dentro de
---`[[...]]`. El proveedor original sí completa aquí, pero escribe el anchor en
---slug --`#soy-un-header`--, que es la forma de la sintaxis markdown. Dentro de
---`[[...]]` lo que se escribe es el texto del heading tal cual, con espacios y
---mayúsculas, que es lo que hace la app de Obsidian (ver headings.anchor_text).
---@class nyabsidian.AnchorContext
---@field note string el destino tecleado antes del primer `#`
---@field done string[] los segmentos de anchor ya cerrados por un `#` posterior
---@field search string lo tecleado tras el último `#`
---@field start_col integer 0-based, inicio del trozo que se sustituye
---@field end_col integer 0-based, final de ese trozo

---@param line string
---@param character integer 0-based byte column
---@return nyabsidian.AnchorContext|nil
local function wiki_anchor_context(line, character)
  local prefix = line:sub(1, character)
  local open = prefix:match ".*()%[%["
  if not open then
    return nil
  end
  local body = prefix:sub(open + 2)
  -- Un `]` cierra el enlace y un `|` abre el alias: ahí ya no se teclea anchor.
  if body:find "[%]|]" then
    return nil
  end
  local first = body:find("#", 1, true)
  if not first then
    return nil
  end

  local last = first
  while true do
    local nxt = body:find("#", last + 1, true)
    if not nxt then
      break
    end
    last = nxt
  end

  local segments = {}
  for segment in body:sub(first + 1, last - 1):gmatch "[^#]+" do
    segments[#segments + 1] = segment
  end

  return {
    note = body:sub(1, first - 1),
    done = segments,
    search = body:sub(last + 1),
    -- body[i] ocupa la columna 0-based `open + i`, así que el `#` está en
    -- `open + last`; lo que se sustituye empieza en el carácter siguiente, que
    -- es lo único que se reescribe: el `#` ya tecleado se queda donde está.
    start_col = open + last + 1,
    end_col = character,
  }
end

---Cada heading de la nota, con el anchor mas corto que lo identifica.
---
---El calculo vive en `headings.shortest_anchor` porque no es cosa del
---autocompletado: la copia inteligente tiene que escribir exactamente el mismo
---anchor para el mismo heading.
---@param note obsidian.Note
---@return { segments: string[], header: string, parents: string[] }[]
local function anchor_suggestions(note)
  local headings = require "lzy.obsidian.headings"
  local out = {}
  for _, entry in ipairs(headings.heading_chains(note)) do
    local parents = {}
    for idx = 1, #entry.chain - 1 do
      parents[#parents + 1] = entry.chain[idx].header
    end
    out[#out + 1] = {
      segments = headings.shortest_anchor(note, entry.section),
      header = entry.section.header,
      parents = parents,
    }
  end
  return out
end

---El anchor tal cual se escribe dentro de `[[...]]`.
---@param segments string[]
---@return string
local function anchor_written(segments)
  local headings = require "lzy.obsidian.headings"
  return table.concat(
    vim.tbl_map(function(segment)
      return headings.anchor_text(segment, "wiki")
    end, segments),
    "#"
  )
end

---@param note obsidian.Note
---@param name string
---@return boolean
local function note_is_named(note, name)
  name = vim.trim(name):lower()
  if name == "" then
    return false
  end
  local candidates = { tostring(note.id or "") }
  if note.path then
    candidates[#candidates + 1] = vim.fs.basename(tostring(note.path)):gsub("%.md$", "")
  end
  for _, alias in ipairs(note.aliases or {}) do
    candidates[#candidates + 1] = alias
  end
  for _, candidate in ipairs(candidates) do
    if candidate:lower() == name then
      return true
    end
  end
  return false
end

---Un destino de enlace bajo el cursor, sea cual sea su sintaxis.
---@param line string
---@param character integer 0-based byte column
---@return nyabsidian.TargetContext|nil
local function target_context(line, character)
  return definition_target_context(line, character)
    or wiki_target_context(line, character)
    or inline_target_context(line, character)
end

---@param path string
---@return string
-- Codificador único del proyecto (ver lzy.link_target.encode).
local function encode(path)
  return require("lzy.link_target").encode(path)
end

--- El destino tal cual se inserta, según la sintaxis que lo va a alojar.
---
--- Un `[[wiki]]` lo resuelve nuestro motor buscando por el vault: admite el
--- espacio literal y no necesita extensión — el vault tiene 9101 wikilinks y
--- ni uno lleva `.md`. El destino de un enlace markdown lo resuelve GitHub
--- siguiendo la ruta literal: ahí un espacio **corta el destino** y sin `.md`
--- da 404. Antes se codificaba siempre, así que completar dentro de `[[`
--- producía `[[Nota%20mía.md]]`.
---
--- Ver docs/todo-markdown.md §1.5 y §1.6.
---@param target string
---@param kind string|nil `context.kind`: "wiki" | "inline" | "definition"
---@return string
local function write_target(target, kind)
  if kind == "wiki" then
    return (target:gsub("%.md$", ""))
  end
  return encode(target)
end

---@param bufnr integer
---@param query string
---@param note obsidian.Note
---@param root string
---@param kind string|nil `context.kind`
---@return string|nil target lo que se inserta
---@return string|nil root_relative el mismo destino medido desde la raíz del vault
local function note_target(bufnr, query, note, root, kind)
  local coord = require "lzy.link_target"
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
  return write_target(target, kind), root_relative
end

---La aguja de la búsqueda por nombre, o nil si no toca buscar.
---@param query string lo tecleado, coordenada incluida
---@return string|nil
local function note_needle(query)
  local coord = require "lzy.link_target"
  local search = vim.fs.basename(coord.needle(query)):gsub("%.md$", "")
  if search == "" then
    -- Un nivel recién abierto (`/`, `/docs/`) ya lo lista la navegación de
    -- rutas; buscar la cadena vacía traería el vault entero de una vez.
    return nil
  end
  -- Una coordenada explícita ya expresa intención suficiente: `/do` debe
  -- responder en el acto, sin esperar al mínimo de caracteres que sí se le
  -- exige a una búsqueda desnuda. Mismo criterio que en marksman.
  if not coord.is_explicit(query) and #search < (Obsidian.opts.completion.min_chars or 2) then
    return nil
  end
  return search
end

---Busca las notas cuyo nombre coincide con lo tecleado y les pide sus
---headings.
---@param needle string
---@param exact boolean si sólo valen las notas que se llaman exactamente así
---@param done fun(notes: obsidian.Note[])
local function notes_named(needle, exact, done)
  if vim.trim(needle) == "" then
    return done {}
  end
  require("obsidian.search").find_notes_async(needle, function(notes)
    if not exact then
      return done(notes)
    end
    local matched = {}
    for _, note in ipairs(notes) do
      if note_is_named(note, needle) then
        matched[#matched + 1] = note
      end
    end
    done(matched)
  end, {
    dir = require("obsidian.api").resolve_workspace_dir(),
    search = { sort = false, include_templates = false, ignore_case = true },
    notes = {},
  })
end

---`/` es navegación de rutas, y obsidian.nvim no la hace: su completion de
---enlaces es una búsqueda de notas por nombre, así que ni ofrece las carpetas
---por las que bajar ni entiende un destino que empieza por `/`. Aquí se recorre
---el nivel entero --carpetas y notas-- igual que en marksman, y se añade la
---búsqueda por nombre en las sintaxis donde el proveedor original no llega.
---@param params lsp.CompletionParams
---@param context nyabsidian.TargetContext
---@param callback fun(result: lsp.CompletionList)
local function complete_target(params, context, callback)
  local util = require "obsidian.util"
  if util.is_uri(context.raw_target) or context.raw_target:match "^[%a][%w+.-]*:" then
    return callback { isIncomplete = false, items = {} }
  end

  local coord = require "lzy.link_target"
  local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
  local root = vim.fs.normalize(tostring(require("obsidian.api").resolve_workspace_dir()))
  local query = vim.uri_decode(context.search) or context.search

  local items, seen = {}, {}
  local function add(item)
    if not seen[item.textEdit.newText] then
      seen[item.textEdit.newText] = true
      items[#items + 1] = item
    end
  end
  local function edit(target)
    return {
      newText = target,
      range = {
        start = { line = params.position.line, character = context.start_col },
        ["end"] = { line = params.position.line, character = context.end_col },
      },
    }
  end

  for _, entry in ipairs(coord.entries(query, root, { files = true })) do
    local target = write_target(entry.target, context.kind)
    local directory = entry.kind == "directory"
    local scope = entry.scope == "system" and "del sistema" or "del vault"
    add {
      label = target,
      filterText = target,
      -- Las carpetas primero: son el camino, no el destino.
      sortText = (directory and "0" or "1") .. target:lower(),
      detail = (directory and "Carpeta " or "Nota ") .. scope,
      kind = directory and vim.lsp.protocol.CompletionItemKind.Folder
        or vim.lsp.protocol.CompletionItemKind.File,
      textEdit = edit(target),
    }
  end

  -- Un `[[Nota con` sin `#` todavía: además de la nota, se ofrecen sus
  -- headings ya montados --`Nota con espacios#Soy un Header`--, para no tener
  -- que escribir el `#` y volver a pedir la lista. Las notas en sí las sigue
  -- poniendo el proveedor original, así que aquí sólo se añaden los anchors.
  if context.kind == "wiki" then
    local needle = note_needle(query)
    if not needle then
      return callback { isIncomplete = true, items = items }
    end
    return notes_named(needle, false, function(notes)
      for _, note in ipairs(notes) do
        local target = note_target(bufnr, query, note, root, context.kind)
        for _, suggestion in ipairs(target and anchor_suggestions(note) or {}) do
          local written = target .. "#" .. anchor_written(suggestion.segments)
          add {
            label = written,
            filterText = written,
            -- Detrás de la nota a secas: primero se elige nota, luego heading.
            sortText = "2" .. written:lower(),
            detail = #suggestion.parents > 0 and table.concat(suggestion.parents, " › ")
              or "Heading",
            kind = vim.lsp.protocol.CompletionItemKind.Reference,
            textEdit = edit(written),
          }
        end
      end
      callback { isIncomplete = true, items = items }
    end)
  end

  local needle = context.notes and note_needle(query) or nil
  if not needle then
    return callback { isIncomplete = true, items = items }
  end

  require("obsidian.search").find_notes_async(needle, function(notes)
    for _, note in ipairs(notes) do
      local target, root_relative = note_target(bufnr, query, note, root, context.kind)
      if target and root_relative then
        add {
          label = target,
          filterText = coord.filter_text(query, target, root_relative),
          sortText = "1" .. target:lower(),
          detail = "Nota del vault",
          kind = vim.lsp.protocol.CompletionItemKind.File,
          documentation = {
            kind = "markdown",
            value = note:display_info { label = target },
          },
          textEdit = edit(target),
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

---Completa el anchor de un `[[Nota#...]]`.
---
---El proveedor original ya ofrece estos headings, pero escritos en slug, que es
---la forma de la sintaxis markdown y no la de un wikilink (ver `sanitize`). Aquí
---se escriben con `headings.anchor_text`, o sea tal cual los lee una persona.
---@param params lsp.CompletionParams
---@param context nyabsidian.AnchorContext
---@param callback fun(result: lsp.CompletionList)
local function complete_anchor(params, context, callback)
  notes_named(context.note, true, function(notes)
    local items = {}
    for _, note in ipairs(notes) do
      for _, suggestion in ipairs(anchor_suggestions(note)) do
        local written = anchor_written(suggestion.segments)
        items[#items + 1] = {
          label = written,
          filterText = written,
          sortText = written:lower(),
          detail = #suggestion.parents > 0 and table.concat(suggestion.parents, " › ") or "Heading",
          kind = vim.lsp.protocol.CompletionItemKind.Reference,
          textEdit = {
            newText = written,
            range = {
              start = { line = params.position.line, character = context.start_col },
              ["end"] = { line = params.position.line, character = context.end_col },
            },
          },
        }
      end
    end
    callback { isIncomplete = true, items = items }
  end)
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
  local target = target_context(line, params.position.character)
  if target then
    return complete_target(params, target, callback)
  end

  local anchor = wiki_anchor_context(line, params.position.character)
  if anchor then
    return complete_anchor(params, anchor, callback)
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

--- Dentro de `[[Nota#...]]` el proveedor original escribe el anchor en slug
--- --`#soy-un-header`--, que es la forma de la sintaxis markdown: ahí sobra
--- entera, porque un wikilink lleva el texto del heading tal cual. Sus items se
--- retiran y los pone `complete_anchor`.
---@param list lsp.CompletionList
---@param in_wiki_anchor boolean|nil
---@return lsp.CompletionList
local function sanitize(list, in_wiki_anchor)
  if in_wiki_anchor then
    return { isIncomplete = list.isIncomplete, items = {} }
  end
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
--- no está, y no es un carácter de palabra, así que al teclear `/` en cualquier
--- destino el cliente no pide nada: la lista no aparecía hasta la primera letra.
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
    local bufnr = vim.uri_to_bufnr(params.textDocument.uri)
    local line = vim.api.nvim_buf_get_lines(
      bufnr,
      params.position.line,
      params.position.line + 1,
      false
    )[1] or ""
    local in_wiki_anchor = wiki_anchor_context(line, params.position.character) ~= nil
    local pending, original_result, custom_result, original_error = 2
    local function finish()
      pending = pending - 1
      if pending == 0 then
        callback(
          original_error,
          merge(sanitize(completion_list(original_result), in_wiki_anchor), custom_result)
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

M.target_context = target_context
M.definition_target_context = definition_target_context
M.inline_target_context = inline_target_context
M.wiki_target_context = wiki_target_context
M.wiki_anchor_context = wiki_anchor_context
M.anchor_suggestions = anchor_suggestions
M.anchor_written = anchor_written
M.reference_id_context = reference_id_context
M.sanitize = sanitize
M.custom_completion = custom_completion
M.drop_pathish_alias = drop_pathish_alias

return M
