-- Modo único de creación de nota desde un enlace `[[NAME]]` inexistente.
--
-- obsidian-ls ofrece aquí "Yes" y "Yes as Unique Note": ninguno de los dos
-- crea `NAME.md`. Los dos pasan el id por `note_id_func` (zettelkasten por
-- defecto), así que el archivo termina llamándose por un id generado, y
-- además reescriben el enlace bajo el cursor a `[[id|NAME]]` — pero solo esa
-- ocurrencia. El resto de `[[NAME]]` que haya en el vault se queda apuntando
-- al id viejo (que nunca existió) en vez del nuevo archivo.
--
-- Aquí no hace falta reescribir nada: el archivo se llama exactamente como
-- el enlace (`verbatim = true` se salta `note_id_func`), así que cualquier
-- `[[NAME]]` ya existente en el vault resuelve solo en cuanto el archivo
-- existe. Sin ids, sin rename global.

local M = {}

--- Caracteres que un nombre de nota no puede llevar: `#^[]|` rompen un
--- `[[enlace]]`, y `/\` fabricarían carpetas que nadie pidió. El resto (los
--- espacios y las mayúsculas incluidos) se conserva tal cual.
local UNSAFE_NAME = "[#%^%[%]|/\\%z\r\n]"

--- El id de una nota nueva es su título, no un slug de su título.
---
--- Sustituye a `obsidian.builtin.title_id`, que bajaba a minúsculas y cambiaba
--- los espacios por guiones ("Mi Nota" -> `mi-nota.md`). Eso dejaba la
--- creación de notas incoherente consigo misma: crear desde un enlace
--- (`M.create`, aquí abajo) ya era verbatim, así que `[[Mi Nota]]` daba
--- `Mi Nota.md` pero `:Obsidian new` daba `mi-nota.md`. Ahora las dos puertas
--- producen el mismo nombre, que además es el que escribe la app de Obsidian.
---@param title string|?
---@param dir obsidian.Path|? Si viene, desambigua contra lo que ya existe.
---@return string
function M.verbatim_id(title, dir)
  local builtin = require "obsidian.builtin"
  if type(title) ~= "string" then
    return builtin.zettel_id()
  end

  local base = vim.trim((title:gsub(UNSAFE_NAME, "")):gsub("%s+", " "))
  if base == "" then
    -- Un título que se queda en nada tras quitar lo impronunciable (o vacío de
    -- entrada) no da un nombre de archivo: ahí sí vale el id generado.
    return builtin.zettel_id()
  end
  if not dir then
    return base
  end

  local Path = require "obsidian.path"
  local base_dir = Path.new(dir)
  local candidate, idx = base, 2
  while (base_dir / candidate):with_suffix(".md", true):exists() do
    candidate = ("%s %d"):format(base, idx)
    idx = idx + 1
  end
  return candidate
end

---@param msg string
---@param level integer|?
local function default_notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Nyabsidian" })
end

--- Sí/no, sin nombre editable, y es deliberado: aquí el fichero se llama
--- **exactamente** como el enlace (ver la cabecera de este módulo). Poder
--- cambiarlo rompería ese invariante y obligaría a reapuntar el enlace. En
--- marksman sí es editable, porque allí el servidor escribe los wikilinks en
--- slug y hace falta poder corregirlos (ver lzy.marksman.new_note).
---@param prompt string
---@param done fun(answer: "yes"|"no"|"cancel")
local function default_confirm(prompt, done)
  if rawget(_G, "hzsr") then
    return hzsr.async.run(function()
      done(hzsr.inp.pick.confirm(prompt, { async = true, explicit_cancel = false }))
    end)
  end
  -- Sin hzsr disponible (p.ej. entorno de test): confirm() de toda la vida.
  local choice = vim.fn.confirm(prompt, "&Yes\n&No", 2)
  done(choice == 1 and "yes" or "no")
end

-- Overrides a nivel de módulo (además de `opts.confirm`/`opts.notify` por
-- llamada): permite a los tests sustituir el prompt real sin tener que
-- enhebrar un stub por toda la cadena de follow_link.
M.confirm = default_confirm
M.notify = default_notify
M.default_confirm = default_confirm
M.default_notify = default_notify

---@param opts { bufnr?: integer, notify?: fun(msg: string, level?: integer), confirm?: fun(prompt: string, done: fun(answer: "yes"|"no"|"cancel")) }|?
---@param name string El target literal del enlace, ya decodificado (puede incluir subcarpeta: "sub/Name").
---@param callback fun(note: obsidian.Note|?)
function M.create(name, opts, callback)
  opts = opts or {}
  local notify = opts.notify or M.notify
  local confirm = opts.confirm or M.confirm

  name = vim.trim(name)
  if name == "" then
    return callback(nil)
  end

  confirm(("¿Crear la nota '%s'?"):format(name), function(answer)
    if answer ~= "yes" then
      notify("Creación de nota cancelada", vim.log.levels.WARN)
      return callback(nil)
    end

    local Note = require "obsidian.note"
    local ok, note_or_err = pcall(Note.create, {
      id = name,
      verbatim = true,
      template = Obsidian.opts.note.template,
    })
    if not ok then
      notify("No se pudo crear la nota: " .. tostring(note_or_err), vim.log.levels.ERROR)
      return callback(nil)
    end

    local note = note_or_err
    local write_ok, write_err = pcall(function()
      note:write()
    end)
    if not write_ok then
      notify("No se pudo escribir la nota: " .. tostring(write_err), vim.log.levels.ERROR)
      return callback(nil)
    end

    -- El índice rápido de lzy.obsidian.notes tiene un TTL corto, pero no
    -- hace falta esperarlo: la nota recién creada debería resolver ya en
    -- el próximo refresh de diagnósticos, no hasta 2s después.
    pcall(function()
      require("lzy.obsidian.notes").invalidate_index()
    end)

    -- Si el nombre colisiona con otra nota, los `[[Nombre]]` que ya había
    -- dejan de apuntar donde apuntaban. Se amplían para que sigan señalando la
    -- suya; si no colisiona (lo normal) esto es un lookup y no hace nada más.
    pcall(function()
      require("lzy.obsidian.relink").on_note_added(tostring(note.path), { notify = notify })
    end)

    callback(note)
  end)
end

return M
