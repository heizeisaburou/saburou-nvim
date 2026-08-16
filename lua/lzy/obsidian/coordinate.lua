-- Cómo se ESCRIBE la coordenada de un destino dentro de un enlace.
--
-- Resolver y escribir son problemas distintos. Al resolver somos indulgentes:
-- vale el nombre pelado, la ruta desde la raíz, la relativa, con `.md` o sin
-- él, y sin distinguir mayúsculas. Al escribir hay que elegir UNA forma, y la
-- correcta no es la misma en las dos sintaxis:
--
--   wiki      [[Nota mía]]                   sin extensión, espacio literal,
--                                            la coordenada más corta que
--                                            siga siendo inequívoca
--   markdown  [x](/docs/Nota%20mía.md)       ruta desde la raíz, con `.md`,
--                                            espacios como %20
--
-- La asimetría no es un capricho: un `[[wiki]]` lo resuelve un motor que
-- busca por todo el vault, mientras que un enlace markdown lo resuelve GitHub
-- siguiendo la ruta literal. Un basename pelado en markdown resuelve aquí y da
-- 404 publicado, que es el peor fallo posible: se ve bien donde lo escribes.
--
-- Ver docs/todo-markdown.md §1.4 a §1.6.

local M = {}

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
---@return string
local function normalize(path)
  return vim.fs.normalize(tostring(path))
end

---@param path string
---@return boolean
local function is_note(path)
  local ext = path:match "%.([^./]+)$"
  return ext ~= nil and NOTE_EXTENSIONS[ext:lower()] == true
end

---@param path string
---@return string
local function strip_note_extension(path)
  local ext = path:match "%.([^./]+)$"
  if ext and NOTE_EXTENSIONS[ext:lower()] then
    return path:sub(1, -(#ext + 2))
  end
  return path
end

---@param value string
---@return string[]
local function segments(value)
  local out = {}
  for part in value:gmatch "[^/]+" do
    out[#out + 1] = part
  end
  return out
end

--- Ficheros del vault que responden al mismo nombre pelado que `path`.
---
--- Para una nota se pregunta al índice de `lzy.obsidian.notes`, que indexa por
--- nombre, título y **alias** — una nota con alias `Mi Nota` colisiona con otra
--- que se llame así aunque el fichero se llame distinto. Para un adjunto se
--- compara por basename, que es su única identidad.
---
--- Sobre `opts.fresh`: el índice de notas está cacheado con un TTL corto, y un
--- índice rancio al que le falta una nota nos haría escribir una coordenada
--- **más corta de lo debido** — que es el error peligroso, porque el enlace
--- queda ambiguo en silencio (el error contrario sólo deja una ruta más larga
--- de lo necesario). Por eso las acciones sueltas del usuario (convertir,
--- copiar, crear) piden `fresh`; las masivas invalidan una vez al empezar y
--- reutilizan el índice para los cientos de enlaces que van a tocar.
---@param path string
---@param opts { root: string, index?: nyabsidian.AttachmentIndex, fresh?: boolean, homonyms?: string[] }
---@return string[] paths incluye siempre el propio `path`
function M.homonyms(path, opts)
  path = normalize(path)
  local basename = vim.fs.basename(path)
  local found, seen = {}, {}
  local function add(candidate)
    candidate = normalize(candidate)
    if not seen[candidate] then
      seen[candidate] = true
      found[#found + 1] = candidate
    end
  end

  -- Lista inyectada: así marksman puede usar esta misma primitiva sin depender
  -- del índice del vault, que fuera de un vault no existe. Ver
  -- lzy.marksman.rename.
  if opts.homonyms then
    for _, candidate in ipairs(opts.homonyms) do
      add(candidate)
    end
    add(path)
    return found
  end

  if is_note(path) then
    local notes = require "lzy.obsidian.notes"
    if opts.fresh then
      pcall(notes.invalidate_index, opts.root)
    end
    local ok, paths = pcall(notes.reference_paths, strip_note_extension(basename), opts.root)
    for _, candidate in ipairs(ok and paths or {}) do
      add(candidate)
    end
  else
    local attachments = require "lzy.obsidian.attachments"
    local index = opts.index
    if index then
      for _, candidate in ipairs(index.by_basename[basename:lower()] or {}) do
        add(candidate)
      end
    else
      attachments.walk_files(opts.root, opts.root, function(candidate)
        if vim.fs.basename(candidate):lower() == basename:lower() then
          add(candidate)
        end
      end, { raw = true })
    end
  end

  add(path) -- puede no estar indexado todavía (recién creado)
  return found
end

--- ¿Hay más de un fichero que responda a este nombre?
---@param path string
---@param opts { root: string, index?: nyabsidian.AttachmentIndex, fresh?: boolean }
---@return boolean
function M.is_ambiguous(path, opts)
  return #M.homonyms(path, opts) > 1
end

--- Forma mínima inequívoca de `path`, para escribirla dentro de un `[[wiki]]`.
---
--- Empieza por el nombre pelado y le añade carpetas de derecha a izquierda
--- hasta que ningún homónimo comparta ese sufijo:
---
---   Nota  ->  carpeta/Nota  ->  otra/carpeta/Nota
---
--- El último recurso es la ruta completa desde la raíz, que siempre distingue.
--- (Antes se saltaba directamente a ella en cuanto había una colisión, así que
--- un homónimo cualquiera te dejaba la ruta entera en el enlace.)
---@param path string
---@param opts { root: string, index?: nyabsidian.AttachmentIndex, fresh?: boolean }
---@return string
function M.minimal(path, opts)
  path = normalize(path)
  local root = normalize(opts.root)
  local relative = vim.fs.relpath(root, path)
  if not relative then
    -- Fuera del vault no hay coordenada corta posible: la identidad es la ruta.
    return path
  end

  local note = is_note(path)
  local parts = segments(note and strip_note_extension(relative) or relative)
  if #parts == 0 then
    return relative
  end

  local rivals = {}
  for _, candidate in ipairs(M.homonyms(path, opts)) do
    if candidate ~= path then
      local candidate_relative = vim.fs.relpath(root, candidate)
      if candidate_relative then
        rivals[#rivals + 1] = (
          note and strip_note_extension(candidate_relative) or candidate_relative
        ):lower()
      end
    end
  end
  if #rivals == 0 then
    return parts[#parts]
  end

  -- Desde 2: si hay rivales, el nombre pelado YA es ambiguo por definición --
  -- son justamente los ficheros que responden a ese nombre. Empezar en 1 y
  -- comprobarlo por sufijo de ruta era un error sutil: un rival que colisiona
  -- por **alias** no tiene ese nombre en su ruta, así que no se detectaba y se
  -- devolvía el nombre pelado. Con `frontmatter.func` añadiendo el título como
  -- alias, eso es el caso común, no el raro.
  for depth = 2, #parts do
    local suffix = table.concat(parts, "/", #parts - depth + 1)
    local lowered = suffix:lower()
    local shared = false
    for _, rival in ipairs(rivals) do
      -- Un rival "comparte" el sufijo si su ruta termina justo en él, en una
      -- frontera de carpeta (`otra/Nota` no lo comparte con `miotra/Nota`).
      if rival == lowered or rival:sub(-(#lowered + 1)) == "/" .. lowered then
        shared = true
        break
      end
    end
    if not shared then
      return suffix
    end
  end

  -- Una nota en la raíz del vault no tiene carpeta que añadir, así que su
  -- nombre pelado es lo único que hay... salvo la barra inicial, que la
  -- convierte en una coordenada posicional y por tanto inequívoca (§1.1).
  return "/" .. (note and strip_note_extension(relative) or relative)
end

--- Destino tal cual se escribe dentro de un enlace, según la sintaxis.
---@param path string
---@param opts { root: string, kind: string, index?: nyabsidian.AttachmentIndex }
---@return string
function M.write(path, opts)
  if opts.kind == "markdown" or opts.kind == "reference" then
    return M.markdown(path, opts)
  end
  return M.minimal(path, opts)
end

--- Destino de un enlace markdown: ruta desde la raíz, con extensión y con los
--- caracteres que romperían el destino ya escapados.
---
--- No se acorta nunca a nombre pelado: `[x](Nota.md)` resuelve en nuestro motor
--- porque busca por el vault, pero GitHub sólo lo encuentra si está en la misma
--- carpeta. Una ruta desde la raíz vale en los dos y no se rompe al mover el
--- fichero que enlaza.
---@param path string
---@param opts { root: string }
---@return string
function M.markdown(path, opts)
  path = normalize(path)
  local relative = vim.fs.relpath(normalize(opts.root), path)
  if not relative then
    return M.encode(path)
  end
  return "/" .. M.encode(relative)
end

--- Percent-encoding para un destino markdown, conservando las barras.
---
--- Un espacio crudo **corta el destino** en CommonMark: `[x](/a/b c.md)` se
--- parsea como `/a/b` y el resto se pierde, en GitHub, pandoc, mdBook y
--- marksman por igual. `%20` es la forma válida, y es la que ya usan los
--- anchors (ver lzy.obsidian.headings.anchor_text).
---@param value string
---@return string
function M.encode(value)
  return require("lzy.link_target").encode(value)
end

M.is_note = is_note
M.strip_note_extension = strip_note_extension

return M
