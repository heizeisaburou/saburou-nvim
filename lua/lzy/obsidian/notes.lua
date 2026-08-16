-- Resolución de notas con una garantía adicional para extensiones explícitas.
--
-- `resolve_async` delegaba siempre en `obsidian.search.resolve_note_async`,
-- que en el caso común (target sin ruta, nota fuera de las carpetas
-- "candidatas" baratas del plugin: buf_dir, notes_subdir, daily notes,
-- vault root) dispara un escaneo completo del vault (rg + fd) POR CADA
-- llamada. Una nota-índice con cientos de enlaces únicos son cientos de
-- esos escaneos -> varios segundos de demora al abrir/cerrar el buffer.
--
-- Antes de caer a esa vía cara, probamos un índice construido con un solo
-- recorrido síncrono del vault (mismo walker que usa
-- lzy.obsidian.attachments para adjuntos: vim.fs.dir puro, sin
-- subprocesos).
--
-- HISTORIA (medida en uso real):
--   v1: índice por filename-stem solamente. Casi nunca acertaba porque los
--   `[[Título]]` no siempre matchean el filename.
--   v2: índice por `reference_ids()` (id, título, filename, aliases) --
--   mismo criterio que el tier "exact match" de `resolve_note_async`.
--   Tampoco alcanzó: en un profiler de `uv.spawn` sobre el vault real
--   seguían saliendo los mismos 135 rg/fd. Resultó que ese vault linkea en
--   buena parte por coincidencia DIFUSA -- `[[vi]]` resuelve porque hay una
--   nota "vim" que lo contiene como substring, no porque exista una nota
--   "vi" exacta -- que es justo el tier que v2 decidió (mal) no replicar.
--
-- v3 (esta versión) replica el algoritmo completo de
-- `resolve_note_async`, no solo el tier exacto:
--   1. Candidatos: notas cuyo filename o CONTENIDO contiene el target como
--      substring (case-insensitive) -- equivalente a lo que hacían los
--      `rg`/`fd` combinados (`M.search_async` + `M.find_async`).
--   2. Entre esos candidatos, exact match: algún `reference_id` (id,
--      título, filename, alias) es EXACTAMENTE el target.
--   3. Si no hay exact match, fuzzy: algún `reference_id` CONTIENE el
--      target como substring.
--   4. Se prioriza exact sobre fuzzy, igual que el original.
--
-- Todo esto corre en memoria contra un índice construido una sola vez por
-- ventana de TTL (ver INDEX_TTL_NS) -- nada de esto vuelve a tocar disco
-- ni un proceso por link.

local M = {}

local uv = vim.uv or vim.loop

---@param target string
---@return string|nil
local function explicit_extension(target)
  return target:lower():match "%.(md)$"
    or target:lower():match "%.(qmd)$"
    or target:lower():match "%.(base)$"
end

---@param target string
---@param note obsidian.Note
---@return boolean
local function matches_explicit_path(target, note)
  if not explicit_extension(target) or not note.path then
    return true
  end
  local decoded = vim.uri_decode(target) or target
  decoded = require("obsidian.util").unescape_single_backslash(decoded):gsub("\\", "/")
  local actual = vim.fs.normalize(tostring(note.path)):gsub("\\", "/")
  local wanted = decoded:gsub("^%./", ""):lower()
  local actual_lower = actual:lower()

  if wanted:find("/", 1, true) then
    return actual_lower:sub(-#wanted) == wanted
  end
  return vim.fs.basename(actual_lower) == wanted
end

-- ─────────────────────────────────────────────────────────────────────────
-- ― Índice rápido del vault (fast path, sin subprocesos)
-- ─────────────────────────────────────────────────────────────────────────

-- Ahora que construir el índice implica leer cada nota entera (para poder
-- buscar substrings en el contenido, igual que rg), un TTL corto haría que
-- ráfagas de TextChanged paguen el costo completo una y otra vez. 15s da
-- margen para amortizarlo sin volverse un problema de obsolescencia real:
-- `new_note.lua` ya invalida el índice al crear una nota, así que el caso
-- que más importa (enlace roto que se acaba de arreglar) no depende de
-- esperar el TTL.
local INDEX_TTL_NS = 15000 * 1e6

---@class nyabsidian.IndexedNote
---@field path string
---@field ref_ids string[] reference_ids() en minúsculas (id, título, filename, aliases)
---@field basename_lower string
---@field content_lower string contenido completo en minúsculas, para el tier difuso

---@class nyabsidian.NoteIndex
---@field by_reference_id table<string, string[]> id/título/filename/alias (lower) -> paths
---@field by_basename table<string, string> nombre de archivo con extensión (lower) -> path
---@field notes nyabsidian.IndexedNote[]

---@type table<string, { built_at: integer, index: nyabsidian.NoteIndex }>
local index_cache = {}

---@param index nyabsidian.NoteIndex
---@param key string
---@param path string
local function add_reference(index, key, path)
  if key == "" then
    return
  end
  local list = index.by_reference_id[key]
  if not list then
    list = {}
    index.by_reference_id[key] = list
  end
  -- Evitar duplicar la misma nota bajo la misma key (p.ej. filename y
  -- stem coincidiendo, o reference_ids con entradas repetidas).
  for _, existing in ipairs(list) do
    if existing == path then
      return
    end
  end
  list[#list + 1] = path
end

-- `Note.from_file` empieza con `Path.new(path):resolve{strict=true}` --
-- otra syscall por nota (1232 en el vault real). Reproducimos acá lo
-- mínimo que hace falta de `Note.from_lines` (detectar el bloque de
-- frontmatter y pasarlo por `obsidian.frontmatter`, el mismo parser YAML
-- real del plugin) SIN pasar por `Path.resolve` en absoluto -- ya tenemos
-- una ruta abrible de `walk_files(raw=true)`, no hace falta canonizarla.
--
---@param path string
---@param basename_lower string
---@param stem_lower string
---@param content string contenido crudo (sin lowercasear) del archivo
---@return string[] ref_ids en minúsculas, iguales a Note.reference_ids()
local function extract_reference_ids(path, basename_lower, stem_lower, content)
  local Frontmatter = require "obsidian.frontmatter"

  local frontmatter_lines = {}
  local in_frontmatter = false
  local found_end = false
  local line_idx = 0
  for line in (content .. "\n"):gmatch "([^\n]*)\n" do
    line_idx = line_idx + 1
    line = line:gsub("%s+$", "")
    local is_boundary = line:match "^%-%-%-+$" ~= nil
    if line_idx == 1 and is_boundary then
      in_frontmatter = true
    elseif in_frontmatter and is_boundary then
      in_frontmatter = false
      found_end = true
      break
    elseif in_frontmatter then
      frontmatter_lines[#frontmatter_lines + 1] = line
    end
    if line_idx > 200 and not found_end then
      -- Frontmatter mal cerrado o inexistente: no seguimos leyendo todo
      -- el archivo solo para buscar un "---" que capaz no está.
      break
    end
  end

  local id, aliases
  if found_end then
    local ok, info = pcall(Frontmatter.parse, frontmatter_lines, path)
    if ok and info then
      id, aliases = info.id, info.aliases
    end
  end
  aliases = aliases or {}

  -- Mismo default que Note.from_lines: el id cae al stem del filename si
  -- no hay uno explícito (o si por error coincide con el basename).
  if id == nil or tostring(id) == basename_lower then
    id = stem_lower
  end

  -- Mismo orden/composición que Note.reference_ids(): id, display_name()
  -- (título -- que Note.from_lines nunca setea para notas cargadas de
  -- disco, así que equivale al último alias o al id --), filename con y
  -- sin extensión, y el resto de los aliases.
  local display_name = #aliases > 0 and aliases[#aliases] or tostring(id)

  local ref_ids = { tostring(id):lower(), tostring(display_name):lower(), basename_lower, stem_lower }
  for _, alias in ipairs(aliases) do
    ref_ids[#ref_ids + 1] = tostring(alias):lower()
  end
  return ref_ids
end

---@param root string
---@return nyabsidian.NoteIndex
local function build_note_index(root)
  local attachments = require "lzy.obsidian.attachments"

  ---@type nyabsidian.NoteIndex
  local index = { by_reference_id = {}, by_basename = {}, notes = {} }

  -- raw = true: sin esto, walk_files hace un uv.fs_realpath() (syscall)
  -- por archivo -- en un vault de ~1600 archivos eso terminó siendo la
  -- mayoría del costo real (perfilado con jit.p: ~76% del tiempo total en
  -- normalize()/fs.*). No necesitamos
  -- symlinks resueltos para indexar contenido, solo una ruta abrible.
  attachments.walk_files(root, root, function(path)
    local basename = vim.fs.basename(path)
    local ext = basename:match "%.([^./]+)$"
    if ext and attachments.NOTE_EXTENSIONS[ext:lower()] then
      -- Basename completo: solo debería haber un archivo físico por
      -- nombre+extensión exactos, pero por si el vault tiene sorpresas
      -- (symlinks, casing raro) nos quedamos con el primero encontrado.
      local basename_lower = basename:lower()
      index.by_basename[basename_lower] = index.by_basename[basename_lower] or path
      local stem_lower = basename:sub(1, -(#ext + 2)):lower()

      local content = ""
      local fh = io.open(path, "r")
      if fh then
        content = fh:read "*a" or ""
        fh:close()
      end

      local ok, ref_ids = pcall(extract_reference_ids, path, basename_lower, stem_lower, content)
      if not ok or not ref_ids or #ref_ids == 0 then
        -- Nota que no pudo parsearse (YAML roto, etc.): que al menos el
        -- stem del filename siga siendo encontrable.
        ref_ids = { stem_lower }
      end
      for _, ref_id in ipairs(ref_ids) do
        add_reference(index, ref_id, path)
      end

      index.notes[#index.notes + 1] = {
        path = path,
        ref_ids = ref_ids,
        basename_lower = basename_lower,
        content_lower = content:lower(),
      }
    end
  end, { raw = true })

  return index
end

---@param root string
---@return nyabsidian.NoteIndex
local function get_note_index(root)
  local cached = index_cache[root]
  local now = uv.hrtime()
  if cached and (now - cached.built_at) < INDEX_TTL_NS then
    return cached.index
  end

  local index = build_note_index(root)
  index_cache[root] = { built_at = now, index = index }
  return index
end

--- Invalida el índice cacheado. Lo llaman los flujos que crean/renombran/
--- borran notas (new_note.lua, link_actions.lua, etc.) para que el
--- próximo resolve vea el vault al día en vez de esperar el TTL.
---@param root string|table|nil Si se omite, invalida todo lo cacheado.
function M.invalidate_index(root)
  if root == nil then
    index_cache = {}
    return
  end
  index_cache[tostring(root)] = nil
end

---@return string|nil root
local function current_vault_root()
  if not rawget(_G, "Obsidian") or not Obsidian.dir then
    return nil
  end
  return tostring(Obsidian.dir)
end

---@param index nyabsidian.NoteIndex
---@param key string
---@return string[]|nil
local function fuzzy_resolve(index, key)
  -- Mismo algoritmo que el tier difuso de resolve_note_async: candidatos
  -- son notas cuyo filename o contenido contiene `key`; entre esas, las
  -- que tienen algún reference_id que a su vez contiene `key`.
  local fuzzy = {}
  for _, note in ipairs(index.notes) do
    if note.basename_lower:find(key, 1, true) or note.content_lower:find(key, 1, true) then
      for _, ref_id in ipairs(note.ref_ids) do
        if ref_id:find(key, 1, true) then
          fuzzy[#fuzzy + 1] = note.path
          break
        end
      end
    end
  end
  return #fuzzy > 0 and fuzzy or nil
end

---@param value string
---@return string forma canónica para comparar: sin escapes, sin acentos de
---caja y reducida al slug
local function comparable(value)
  local decoded = vim.uri_decode(value) or value
  -- `vim.fn.tolower` sí entiende UTF-8, a diferencia de `:lower()`.
  return require("lzy.obsidian.headings").anchor_segment(vim.fn.tolower(decoded))
end

--- Busca `target` de forma indulgente: escapes deshechos, caja real (también
--- con acentos) y slug. Recorre el índice, así que se usa **sólo** cuando la
--- vía exacta no ha encontrado nada.
---@param index nyabsidian.NoteIndex
---@param target string
---@return string[]|nil
function M.tolerant_lookup(index, target)
  local ok, wanted = pcall(comparable, target)
  if not ok or wanted == "" then
    return nil
  end

  local found = {}
  for key, paths in pairs(index.by_reference_id) do
    local ok_key, candidate = pcall(comparable, key)
    if ok_key and candidate == wanted then
      for _, path in ipairs(paths) do
        if not vim.tbl_contains(found, path) then
          found[#found + 1] = path
        end
      end
    end
  end
  return #found > 0 and found or nil
end

--- Intenta resolver `target` contra el índice rápido.
---@param target string
---@return string[]|? paths nil si no se pudo/debió intentar por esta vía
local function try_fast_resolve(target)
  -- Rutas explícitas (relativas, absolutas, con `/`) las deja el resolver
  -- completo: ese ya hace las comprobaciones baratas de path directo antes
  -- de tocar el vault, y replicarlas acá solo duplicaría lógica sin ganar
  -- velocidad real.
  if target == "" or target:find("/", 1, true) then
    return nil
  end

  local root = current_vault_root()
  if not root then
    return nil
  end

  local index = get_note_index(root)
  local ext = target:match "%.([%w]+)$"

  if ext then
    local path = index.by_basename[target:lower()]
    return path and { path } or nil
  end

  local key = target:lower()

  local exact = index.by_reference_id[key]
  if exact and #exact > 0 then
    return exact
  end

  -- Rescate: sólo cuando la vía exacta no ha encontrado nada.
  --
  -- Cubre tres formas que el vault no escribe pero que llegan igual (pegadas
  -- de otra herramienta, de un export, de marksman): el destino escapado
  -- (`Espacios%20y%20may%C3%BAs`), el slug (`espacios-y-mayús`), y la misma
  -- caja en no-ASCII -- porque `:lower()` de Lua es byte a byte y deja la `Ú`
  -- intacta, así que `ESPACIOS Y MAYÚS` no casaba con `espacios y mayús`
  -- aunque la resolución se supone insensible a mayúsculas (§1.1).
  local rescued = M.tolerant_lookup(index, target)
  if rescued then
    return rescued
  end

  -- `fuzzy_resolve` devuelve nil si no hay candidatos; acá lo normalizamos
  -- a `{}` porque, a esta altura, SÍ intentamos las dos vías (exact y
  -- fuzzy) contra un índice que replica el mismo criterio que usaría
  -- rg/fd -- es un "no está" con fundamento, no un "no lo intentamos".
  return fuzzy_resolve(index, key) or {}
end

--- Rutas de las notas que responden a `name` como nombre, título o alias.
---
--- Es el lookup sobre el que se calcula la ambigüedad (ver
--- lzy.obsidian.coordinate). Saber si un nombre pelado colisiona tiene que ser
--- barato: se pregunta por cada enlace que se escribe, y antes eso costaba un
--- recorrido completo del vault leyendo cada nota de disco.
---@param name string
---@param root string|table|nil Por defecto, el vault activo.
---@return string[] paths
function M.reference_paths(name, root)
  root = root and tostring(root) or current_vault_root()
  if not root or name == nil or name == "" then
    return {}
  end
  local found = get_note_index(root).by_reference_id[tostring(name):lower()]
  -- Copia: el índice está cacheado y compartido, quien pregunte no debe poder
  -- mutarlo sin querer.
  return found and vim.list_extend({}, found) or {}
end

--- Resolución sincrónica contra el índice, sin caer al resolutor completo.
---
--- Para reescrituras masivas (`lzy.obsidian.relink`), que tienen que mirar
--- miles de enlaces y no pueden encadenar un callback por cada uno. Si el
--- índice no lo resuelve, devuelve vacío y quien llama **deja el enlace como
--- está**: en una pasada que reescribe ficheros, no saber es razón para no
--- tocar, no para adivinar.
---@param target string ya sin fragmento
---@param root string|table|nil
---@return string[] paths
function M.resolve_sync(target, root)
  root = root and tostring(root) or current_vault_root()
  if not root or not target or target == "" then
    return {}
  end
  local index = get_note_index(root)

  local decoded = vim.uri_decode(target) or target
  decoded = require("obsidian.util").unescape_single_backslash(decoded):gsub("\\", "/")
  decoded = decoded:gsub("^%./", ""):gsub("^/", "")
  if decoded == "" then
    return {}
  end

  if not decoded:find("/", 1, true) then
    local paths = index.by_reference_id[decoded:lower()]
    return paths and vim.list_extend({}, paths) or {}
  end

  -- Con carpeta, la coordenada es un sufijo de ruta: se compara contra la ruta
  -- desde la raíz, con y sin extensión de nota.
  local wanted = decoded:lower()
  local found = {}
  for _, note in ipairs(index.notes) do
    local relative = vim.fs.relpath(root, note.path)
    if relative then
      relative = relative:lower()
      local stem = relative:gsub("%.[^./]+$", "")
      for _, candidate in ipairs { relative, stem } do
        if candidate == wanted or candidate:sub(-(#wanted + 1)) == "/" .. wanted then
          found[#found + 1] = note.path
          break
        end
      end
    end
  end
  return found
end

--- Ordena candidatos como `attachments.best_match_order`: gana el más local al
--- fichero que enlaza y, a igualdad, la ruta más corta.
---
--- Las notas no ordenaban nada, así que ante dos notas homónimas el "ganador"
--- dependía del orden de indexación del vault mientras que un adjunto homónimo
--- sí desempataba por cercanía. Misma ambigüedad, dos respuestas distintas.
---@generic T
---@param items T[]
---@param source_dir string|nil
---@param get_path fun(item: T): string
---@return T[]
local function by_locality(items, source_dir, get_path)
  if not source_dir or source_dir == "" or #items < 2 then
    return items
  end
  source_dir = vim.fs.normalize(source_dir)

  local indexed = {}
  for position, item in ipairs(items) do
    local path = vim.fs.normalize(tostring(get_path(item)))
    indexed[#indexed + 1] = {
      item = item,
      local_to_source = path:sub(1, #source_dir + 1) == source_dir .. "/",
      length = #path,
      position = position,
    }
  end
  table.sort(indexed, function(a, b)
    if a.local_to_source ~= b.local_to_source then
      return a.local_to_source
    elseif a.length ~= b.length then
      return a.length < b.length
    end
    -- Estable: a igualdad total, el orden de indexación del vault.
    return a.position < b.position
  end)
  return vim.tbl_map(function(entry)
    return entry.item
  end, indexed)
end

M.by_locality = by_locality

---@param target string
---@param callback fun(notes: obsidian.Note[])
---@param opts { notes?: obsidian.note.LoadOpts, trust_not_found?: boolean, source_path?: string }|nil
function M.resolve_async(target, callback, opts)
  local fast_paths = try_fast_resolve(target)

  local source_path = opts and opts.source_path or vim.api.nvim_buf_get_name(0)
  local source_dir = source_path ~= "" and vim.fs.dirname(source_path) or nil
  local function ordered(notes)
    return by_locality(notes, source_dir, function(note)
      return tostring(note.path)
    end)
  end

  local function fallback()
    require("obsidian.search").resolve_note_async(target, function(notes)
      callback(ordered(vim.tbl_filter(function(note)
        return matches_explicit_path(target, note)
      end, notes)))
    end, opts)
  end

  if fast_paths == nil then
    -- No se intentó por esta vía (target con ruta explícita, sin vault
    -- activo, etc.): el resolver completo es la única fuente de verdad
    -- disponible acá.
    return fallback()
  end

  if #fast_paths == 0 then
    -- Se intentaron exact Y fuzzy contra el índice completo (mismo
    -- criterio de candidatos que rg/fd+reference_ids) y no hay nada. Para
    -- callers que solo necesitan "¿existe?" y tienen que preguntar por
    -- CIENTOS de targets a la vez (diagnostics.lua), confiar en esto es lo
    -- que evita pagar un escaneo completo del vault por cada link
    -- roto/pendiente.
    -- Los callers on-demand de un solo link (hover.lua, links.lua) NO
    -- pasan `trust_not_found`, así que ahí se sigue verificando con el
    -- resolver real antes de decir "no existe" — un follow-link o rename
    -- equivocado pesa más que un diagnóstico ocasionalmente de más.
    if opts and opts.trust_not_found then
      return vim.schedule(function()
        callback {}
      end)
    end
    return fallback()
  end

  local Note = require "obsidian.note"
  local ok, notes = pcall(function()
    local out = {}
    for _, path in ipairs(fast_paths) do
      local note = Note.from_file(path, opts and opts.notes)
      if note then
        out[#out + 1] = note
      end
    end
    return out
  end)

  if ok and #notes > 0 then
    return vim.schedule(function()
      callback(ordered(vim.tbl_filter(function(note)
        return matches_explicit_path(target, note)
      end, notes)))
    end)
  end

  -- Si por lo que sea no se pudo cargar ninguno de los matches (archivo
  -- borrado justo ahora, YAML corrupto, etc.), no lo tratamos como "no
  -- existe": caemos al resolver completo, que es la fuente de verdad.
  fallback()
end

M.matches_explicit_path = matches_explicit_path

--- Diagnóstico: estadísticas del índice rápido y, si se pasa `target`, si
--- matchea (exacto o difuso) o no y por qué.
---@param target string|nil
function M.debug_index(target)
  local root = current_vault_root()
  if not root then
    print "Sin vault activo: current_vault_root() dio nil (¿Obsidian.dir sin setear?)"
    return
  end

  local t0 = uv.hrtime()
  local index = get_note_index(root)
  local build_ms = (uv.hrtime() - t0) / 1e6

  local n_keys, n_notes_covered = 0, 0
  local seen_paths = {}
  for _, paths in pairs(index.by_reference_id) do
    n_keys = n_keys + 1
    for _, p in ipairs(paths) do
      seen_paths[p] = true
    end
  end
  for _ in pairs(seen_paths) do
    n_notes_covered = n_notes_covered + 1
  end
  local n_basename = 0
  for _ in pairs(index.by_basename) do
    n_basename = n_basename + 1
  end

  print(("root: %s"):format(root))
  print(("get_note_index tardó %.1fms (build o cache hit)"):format(build_ms))
  print(
    ("by_reference_id: %d keys distintas, cubriendo %d notas | by_basename: %d archivos | notas indexadas: %d"):format(
      n_keys,
      n_notes_covered,
      n_basename,
      #index.notes
    )
  )

  if target then
    local key = target:lower()
    local t1 = uv.hrtime()
    local exact = index.by_reference_id[key]
    ---@type string[]|nil
    local result = exact
    local via = "exact"
    if not (exact and #exact > 0) then
      result = fuzzy_resolve(index, key)
      via = "fuzzy"
    end
    local lookup_ms = (uv.hrtime() - t1) / 1e6
    print(
      ("target '%s' (key '%s') -> %s [%s, %.1fms]"):format(
        target,
        key,
        result and vim.inspect(result) or "NO ENCONTRADO (ni exacto ni difuso)",
        via,
        lookup_ms
      )
    )
  end
end

vim.api.nvim_create_user_command("NyabsidianNotesIndexDebug", function(cmd_opts)
  require("lzy.obsidian.notes").debug_index(cmd_opts.args ~= "" and cmd_opts.args or nil)
end, { nargs = "?", desc = "Nyabsidian: estadísticas/lookup del índice rápido de notes.lua" })

return M
