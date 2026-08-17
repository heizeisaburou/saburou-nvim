-- Coordenadas de destino, compartidas por las completions de marksman y de
-- obsidian. Las dos integraciones resuelven notas distintas y con buscadores
-- distintos, pero la pregunta "según cómo has empezado a escribir el destino,
-- ¿qué se busca y qué se inserta?" es exactamente la misma en ambas:
--
--   `/algo`   → desde la raíz del proyecto/vault; si ahí no existe, como ruta
--               absoluta del sistema (la barra es ambigua a propósito)
--   `./algo`  → relativo a la nota; `../algo` igual
--   `algo`    → desnudo: lo resuelve el buscador de cada lado
--
-- Aquí vive solo esa parte común. Cada lado sigue decidiendo qué notas hay
-- (find_notes_async en obsidian, workspace.files en marksman) y con qué
-- codificador escribe el path.

local M = {}

M.ROOT = "root"
M.NOTE_RELATIVE = "note_relative"
M.BARE = "bare"

---Cómo ha empezado a escribirse el destino.
---@param query string
---@return "root"|"note_relative"|"bare"
function M.coordinate(query)
  query = query or ""
  if vim.startswith(query, "/") then
    return M.ROOT
  elseif vim.startswith(query, "./") or vim.startswith(query, "../") then
    return M.NOTE_RELATIVE
  end
  return M.BARE
end

---Una coordenada escrita a mano ya expresa intención suficiente: `/` debe
---listar la raíz en cuanto se teclea, sin esperar al mínimo de caracteres que
---se le exige a una búsqueda desnuda.
---@param query string
---@return boolean
function M.is_explicit(query)
  return M.coordinate(query) ~= M.BARE
end

---El texto que de verdad se busca: la coordenada es sintaxis, no aguja.
---@param query string
---@return string
function M.needle(query)
  local stripped = (query or ""):gsub("^%.%./", ""):gsub("^%./", ""):gsub("^/", "")
  return stripped
end

--- Lo que rompe el parseo de un destino de enlace, y sólo eso:
---   - espacio y tabulador: **cortan** el destino en CommonMark
---   - `()` lo cierran, `<>` lo delimitan, `"'` abrirían un título
---   - `[]{}|\`^` confunden a un parser u otro
---
--- `/` y `#` NO están: son estructura, no contenido. Varios sitios codifican
--- `ruta#fragmento` de una pieza, y escapar la almohadilla ahí se comería el
--- separador. Quien necesite un `#` literal dentro de un segmento lo escapa por
--- su cuenta (ver lzy.obsidian.headings.anchor_text).
local UNSAFE = '[ \t\r\n"\'()<>%[%]{}|\\`^]'

---Las filas que NO contienen enlaces aunque lo parezcan: bloques de código
---(con fence o sangrados), frontmatter y HTML.
---
---Un `[[Mi Nota]]` dentro de un ```` ```toml ```` es un ejemplo, no un enlace.
---Tratarlo como enlace tiene dos consecuencias, y la segunda es destructiva:
---diagnosticar «no existe» sobre un ejemplo es ruido, pero **reescribirlo** al
---canonizar corrompe el bloque de código.
---
---Vive aquí, y no en un motor, porque es estructura de Markdown: la usan igual
---los diagnósticos y las reescrituras de los dos lados.
---@param lines string[]
---@return table<integer, boolean> filas 0-based
function M.excluded_rows(lines)
  local excluded = {}
  local text = table.concat(lines, "\n") .. "\n"
  local ok, parser = pcall(vim.treesitter.get_string_parser, text, "markdown")
  local tree = ok and parser:parse()[1] or nil
  if not tree then
    return excluded
  end

  local excluded_nodes = {
    fenced_code_block = true,
    indented_code_block = true,
    minus_metadata = true,
    plus_metadata = true,
    html_block = true,
  }
  local function walk(node)
    if excluded_nodes[node:type()] then
      local start_row, _, end_row = node:range()
      for row = start_row, end_row - 1 do
        excluded[row] = true
      end
      return
    end
    for child in node:iter_children() do
      if child:named() then
        walk(child)
      end
    end
  end
  walk(tree:root())
  return excluded
end

---Los tramos de código en línea de una fila, delimitadores incluidos.
---
---Hermano en pequeño de `excluded_rows`: lo que un fence hace con la fila
---entera, unos backticks lo hacen con un tramo de ella. `` `[x](y.md)` `` es un
---ejemplo de sintaxis, no un enlace — esta documentación está llena de tablas
---que explican `[texto](destino)` entre backticks.
---
---Se emparejan **runs** de backticks de la misma longitud, como CommonMark, y
---no la simple paridad que había copiada por ahí. La paridad se equivoca en los
---dos casos que de verdad aparecen:
---
---  `` ``[x](y.md)`` ``            → dos backticks, un solo tramo
---  ``| `[x](` | `[x](y.md)` |``   → dos tramos; para la paridad el `[` del
---                                   primero abre un enlace que se cierra con
---                                   el `)` del segundo, cruzándolos
---@param line string
---@return { start_col: integer, end_col: integer }[] 1-based, inclusivo
function M.code_spans(line)
  local runs, idx = {}, 1
  while idx <= #line do
    local start_col, end_col = line:find("`+", idx)
    if not start_col then
      break
    end
    -- Un backtick escapado es un backtick literal, no un delimitador.
    local slashes = 0
    while line:sub(start_col - 1 - slashes, start_col - 1 - slashes) == "\\" do
      slashes = slashes + 1
    end
    if slashes % 2 == 0 then
      runs[#runs + 1] = { start_col = start_col, end_col = end_col }
    elseif start_col < end_col then
      runs[#runs + 1] = { start_col = start_col + 1, end_col = end_col }
    end
    idx = end_col + 1
  end

  local spans, index = {}, 1
  while index <= #runs do
    local opening = runs[index]
    local width = opening.end_col - opening.start_col
    local closing
    for candidate = index + 1, #runs do
      if runs[candidate].end_col - runs[candidate].start_col == width then
        closing = candidate
        break
      end
    end
    if not closing then
      -- Sin pareja no abre nada: son backticks literales y lo que venga
      -- detrás sigue siendo texto normal.
      index = index + 1
    else
      spans[#spans + 1] = { start_col = opening.start_col, end_col = runs[closing].end_col }
      index = closing + 1
    end
  end
  return spans
end

---¿La construcción que empieza en `col` está dentro de código en línea?
---@param line string
---@param col integer 1-based, la columna donde abre la construcción
---@return boolean
function M.inside_inline_code(line, col)
  for _, span in ipairs(M.code_spans(line)) do
    if span.start_col <= col and col <= span.end_col then
      return true
    end
  end
  return false
end

---@type table<integer, { tick: integer, rows: table<integer, boolean> }>
local excluded_cache = {}

---¿La fila bajo el cursor es de las que no contienen enlaces?
---
---Lo preguntan las acciones puntuales -- seguir, `gx`, hover, rename -- y en
---una sola pulsación se consulta varias veces, así que el resultado se memoiza
---por `changedtick`: un parseo por cambio del buffer, no por llamada.
---@param bufnr integer
---@param row integer 0-based
---@return boolean
function M.in_excluded_row(bufnr, row)
  local ok, tick = pcall(vim.api.nvim_buf_get_changedtick, bufnr)
  if not ok then
    return false
  end
  local entry = excluded_cache[bufnr]
  if not entry or entry.tick ~= tick then
    entry = {
      tick = tick,
      rows = M.excluded_rows(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)),
    }
    excluded_cache[bufnr] = entry
  end
  return entry.rows[row] == true
end

---Percent-encoding **mínimo** para un destino de enlace.
---
---Único codificador del proyecto, a propósito. Antes había dos y el resultado
---dependía de por qué ruta hubieras llegado: `obsidian.util.urlencode` dejaba
---la `ú` literal y `vim.uri_encode` la convertía en `%c3%ba`, así que la misma
---nota se enlazaba de dos formas distintas según si el candidato venía de la
---búsqueda de notas o del recorrido de carpetas.
---
---Gana la forma legible: un acento no le molesta a nadie —GitHub sirve UTF-8
---en la ruta igual de bien— y percent-encodearlo sólo ensucia el enlace. Se
---escapa lo que de verdad lo rompería.
---
---Espera una ruta **sin** escapar; quien reciba destinos ya escritos debe
---decodificar antes, o `%20` se convertiría en `%2520`.
---@param path string
---@return string
function M.encode(path)
  return (path:gsub(UNSAFE, function(char)
    return ("%%%02X"):format(char:byte())
  end))
end

---El ancla de un heading: su texto en la forma que entiende GitHub.
---
---Único slugificador del proyecto. Vive aquí, con el codificador de destinos,
---porque es la otra mitad de la misma pregunta: cómo se escribe un enlace.
---Y son mitades distintas a propósito, aunque en el mismo enlace convivan dos
---formas de escribir un espacio:
---
---  `/docs/Mi%20nota.md#mi-heading`
---           ^^^ ruta: es el nombre real del fichero, y sólo `%20` lo nombra
---                    ^^^ ancla: es un identificador derivado, y el slug con
---                        guiones es lo único que resuelve GitHub
---
---@param fragment string
---@return string
function M.slug(fragment)
  fragment = vim.fn.tolower(vim.trim(fragment))
  local result = {}
  for _, char in ipairs(vim.fn.split(fragment, "\\zs")) do
    if char == " " or char == "_" or vim.fn.matchstr(char, [[\s]]) == char then
      result[#result + 1] = "-"
    elseif char == "-" or vim.fn.matchstr(char, [[\k]]) == char then
      result[#result + 1] = char
    end
  end
  local slug = table.concat(result):gsub("%-+", "-"):gsub("^%-", "")
  return (slug:gsub("%-$", ""))
end

---Path relativo entre dos rutas absolutas.
---
---`vim.fs.relpath()` no sirve aquí: devuelve nil en cuanto el destino no cuelga
---del directorio base, así que no puede expresar un hermano (`../otro/x.md`),
---que es justo el caso normal al enlazar entre carpetas de notas.
---@param path string destino absoluto
---@param from_dir string directorio desde el que se mide
---@return string
function M.relative(path, from_dir)
  path, from_dir = vim.fs.normalize(path), vim.fs.normalize(from_dir)
  local function parts(value)
    local result = {}
    for part in value:gmatch "[^/]+" do
      result[#result + 1] = part
    end
    return result
  end
  local target, source = parts(path), parts(from_dir)
  local idx = 1
  while target[idx] and source[idx] and target[idx] == source[idx] do
    idx = idx + 1
  end
  local result = {}
  for _ = idx, #source do
    result[#result + 1] = ".."
  end
  for current = idx, #target do
    result[#result + 1] = target[current]
  end
  return #result == 0 and "." or table.concat(result, "/")
end

---Destino relativo a la nota. `./` es una coordenada escrita a propósito: si el
---destino sube de directorio ya empieza por `..` y se respeta, pero si baja hay
---que devolvérselo con el `./` que se pidió.
---@param path string destino absoluto
---@param source_dir string directorio de la nota que enlaza
---@param query string lo tecleado, para saber si pidió `./` o `../`
---@return string
function M.note_relative(path, source_dir, query)
  local target = M.relative(path, source_dir)
  if vim.startswith(query, "./") and not vim.startswith(target, ".") then
    target = "./" .. target
  end
  return target
end

---Con qué texto debe filtrar el cliente de completion.
---
---Este es el punto que más se ha roto: nvim-cmp puntúa lo tecleado contra
---`filterText`, y lo tecleado incluye la coordenada. Filtrar `/docs` contra
---`docs/api.md` da score 0 y el item desaparece entero -- que es justo el
---síntoma de "empezar por / no genera nada". El filtro tiene que hablar el
---mismo idioma que la coordenada: con `/` se filtra contra el destino ya
---prefijado, y desnudo contra el path relativo a la raíz.
---@param query string
---@param target string el destino que se insertaría
---@param root_relative string el path del destino relativo a la raíz
---@return string
function M.filter_text(query, target, root_relative)
  if M.coordinate(query) == M.BARE then
    return root_relative
  end
  return target
end

-- Carpetas que nunca son destino de un enlace.
local SKIP_DIRECTORIES = {
  [".git"] = true,
  [".hg"] = true,
  [".svn"] = true,
  ["node_modules"] = true,
}

M.MARKDOWN_EXTENSIONS = {
  md = true,
  markdown = true,
  mdx = true,
  mdown = true,
  mkdn = true,
  mkd = true,
  qmd = true,
  rmd = true,
}

---@param path string
---@return boolean
function M.is_markdown(path)
  local ext = path:match "%.([^./\\]+)$"
  return ext ~= nil and M.MARKDOWN_EXTENSIONS[ext:lower()] == true
end

---@param base string
---@param prefix string ya en minúsculas
---@param files boolean si además de carpetas se listan notas
---@return { name: string, kind: "directory"|"file" }[]
local function children(base, prefix, files)
  if vim.fn.isdirectory(base) == 0 then
    return {}
  end
  local result = {}
  for name, kind in vim.fs.dir(base, { depth = 1 }) do
    local wanted = kind == "directory" and not SKIP_DIRECTORIES[name]
      or files and kind == "file" and M.is_markdown(name)
    if wanted and name:sub(1, 1) ~= "." and vim.startswith(name:lower(), prefix) then
      result[#result + 1] = { name = name, kind = kind == "directory" and "directory" or "file" }
    end
  end
  table.sort(result, function(left, right)
    if left.kind ~= right.kind then
      return left.kind == "directory" -- primero el camino, luego los destinos
    end
    return left.name:lower() < right.name:lower()
  end)
  return result
end

---Lo que hay en el nivel que se está tecleando, para una coordenada de raíz.
---
---Esto es navegación de rutas, no búsqueda: `/` abre la raíz, `/docs/` abre lo
---que hay dentro de docs. Las carpetas no son destino pero son el camino —
---aceptar `/docs/` deja el cursor listo para pedir el nivel siguiente—, así que
---van con `/` final y de primeras en la lista.
---
---`/` es ambiguo a propósito y aquí se acepta la ambigüedad: puede querer decir
---la raíz del proyecto/vault o la del sistema, así que se ofrecen las dos y el
---`scope` dice cuál es cuál. La resolución hace el mismo recorrido: primero
---bajo la raíz del proyecto y, si ahí no existe, como ruta absoluta.
---@param query string lo tecleado, coordenada incluida
---@param root string raíz del proyecto/vault
---@param opts { files?: boolean }|nil `files` añade las notas del nivel
---@return { target: string, name: string, kind: "directory"|"file", scope: "project"|"system" }[]
function M.entries(query, root, opts)
  if M.coordinate(query) ~= M.ROOT then
    return {}
  end
  local files = opts ~= nil and opts.files == true
  local needle = M.needle(query)
  local parent = vim.fs.dirname(needle)
  if parent == "." then
    parent = ""
  end
  local prefix = vim.fs.basename(needle):lower()

  local result, seen = {}, {}
  local bases = {
    { scope = "project", base = vim.fs.joinpath(vim.fs.normalize(root), parent) },
    { scope = "system", base = "/" .. parent },
  }
  for _, base in ipairs(bases) do
    for _, child in ipairs(children(base.base, prefix, files)) do
      local relative = parent == "" and child.name or parent .. "/" .. child.name
      local target = "/" .. relative .. (child.kind == "directory" and "/" or "")
      if not seen[target] then
        seen[target] = true
        result[#result + 1] = {
          target = target,
          name = child.name,
          kind = child.kind,
          scope = base.scope,
        }
      end
    end
  end
  return result
end

---Un alias solo es un alias si es un nombre. Un path a medio teclear
---(`/docs`, `./nota`, `docs/api`) es una coordenada, y colarlo como etiqueta
---produce enlaces sin sentido del tipo `[[1786867178-OZDA|/docs]]`.
---@param text string|nil
---@return boolean
function M.is_pathish(text)
  if type(text) ~= "string" or text == "" then
    return false
  end
  return M.coordinate(text) ~= M.BARE or text:find("/", 1, true) ~= nil
end

return M
