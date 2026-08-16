-- Crear la nota que un enlace pide y todavía no existe, fuera de un vault.
--
-- El equivalente de lzy.obsidian.new_note para proyectos Markdown normales. No
-- puede reutilizarlo: aquél va por `obsidian.note.Note.create`, que necesita el
-- estado global de obsidian.nvim y aquí no hay ninguno.
--
-- Mismo criterio que allí, que es el que importa: **el fichero se llama
-- exactamente como el enlace**. Sin ids generados y sin slugificar, para que
-- cualquier otro `[[Nombre]]` que ya hubiera en el proyecto resuelva solo en
-- cuanto el fichero exista, sin reescribir nada.

local M = {}

--- Lo que no puede ir en el nombre: `#^[]|` romperían un `[[enlace]]` y `\`
--- fabricaría rutas raras. La barra sí se conserva: `sub/Nota` es una
--- subcarpeta pedida a propósito.
local UNSAFE = "[#%^%[%]|\\%z\r\n]"

---@param name string
---@return string|nil
local function sanitize(name)
  local clean = vim.trim((name:gsub(UNSAFE, "")):gsub("%s+", " "))
  return clean ~= "" and clean or nil
end

--- Dónde cae la nota que pide este destino.
---@param target string
---@param source_path string
---@param root string
---@return string|nil
function M.destination(target, source_path, root)
  local name = sanitize(vim.uri_decode(target) or target)
  if not name then
    return nil
  end

  local path
  if vim.startswith(name, "/") then
    path = vim.fs.joinpath(root, name:sub(2))
  elseif vim.startswith(name, "./") or vim.startswith(name, "../") then
    path = vim.fs.joinpath(vim.fs.dirname(source_path), name)
  else
    path = vim.fs.joinpath(root, name)
  end

  path = vim.fs.normalize(path)
  if not path:match "%.[^./]+$" then
    path = path .. ".md"
  end
  return path
end

--- Avisar al servidor de un fichero que hemos creado a sus espaldas.
---
--- `writefile` no pasa por el LSP, así que marksman sigue con su índice viejo:
--- el enlace resuelve para nosotros (leemos disco) pero él lo diagnostica como
--- «Link to non-existent document». Un `didChangeWatchedFiles` de tipo Created
--- lo pone al día sin tener que reiniciar nada.
---@param path string
local function announce(path)
  local ok, clients = pcall(vim.lsp.get_clients, { name = "marksman" })
  if not ok then
    return
  end
  for _, client in ipairs(clients) do
    pcall(function()
      client:notify("workspace/didChangeWatchedFiles", {
        changes = { { uri = vim.uri_from_fname(path), type = 1 } },
      })
    end)
  end
end

---@param path string
---@param opts { notify?: fun(msg: string, level?: integer) }|?
---@return boolean created
local function write_note(path, opts)
  local notify = opts and opts.notify
    or function(msg, level)
      vim.notify(msg, level or vim.log.levels.INFO, { title = "Marksman" })
    end

  local parent = vim.fs.dirname(path)
  if vim.fn.isdirectory(parent) ~= 1 and vim.fn.mkdir(parent, "p") ~= 1 then
    notify(("No se pudo crear '%s'"):format(parent), vim.log.levels.ERROR)
    return false
  end

  -- Un H1 con el nombre: marksman usa el primer heading como título de la nota
  -- (`core.title_from_heading`), así que la nota nace ya encontrable por título
  -- y no sólo por nombre de fichero.
  local title = vim.fs.basename(path):gsub("%.[^./]+$", "")
  local ok = pcall(vim.fn.writefile, { "# " .. title, "" }, path)
  if not ok then
    notify(("No se pudo escribir '%s'"):format(path), vim.log.levels.ERROR)
    return false
  end
  announce(path)
  -- Y a nuestro propio lado: sin esto el diagnóstico podría marcar "no existe"
  -- una nota que acaba de crearse, hasta que expirase el TTL de la caché.
  pcall(require("lzy.marksman.workspace").invalidate_files)
  return true
end

--- El nombre con el que se va a crear, editable y con el del enlace de partida.
---
--- Un sí/no obligaría a aceptar el nombre que dijera el enlace, y ése es justo
--- el caso incómodo: sigues un `[[mi-nota]]` que escribió el servidor en slug y
--- quieres que el fichero se llame `Mi nota`. Aceptar sin tocar equivale al
--- «sí» de antes.
---@param default string
---@return string|nil nil o vacío = cancelado
local function default_ask(default)
  local ok, answer = pcall(vim.fn.input, { prompt = "Crear nota: ", default = default })
  return ok and answer or nil
end

M.ask = default_ask
M.default_ask = default_ask

--- Pregunta el nombre y crea. `ask`/`notify`/`open` son inyectables para los tests.
---@param target string el destino literal del enlace
---@param opts { source_path: string, root: string, ask?: fun(default: string): string|nil, notify?: fun(msg: string, level?: integer), open?: fun(path: string) }
---@return string|nil path
---@return boolean renamed el nombre elegido difiere del que pedía el enlace
function M.create(target, opts)
  local notify = opts.notify
    or function(msg, level)
      vim.notify(msg, level or vim.log.levels.INFO, { title = "Marksman" })
    end

  local path = M.destination(target, opts.source_path, opts.root)
  if not path then
    return nil, false
  end
  if vim.uv.fs_stat(path) then
    return path, false -- ya existe: no hay nada que preguntar
  end

  local suggested = vim.uri_decode(target) or target
  local chosen = (opts.ask or M.ask)(suggested)
  if not chosen or vim.trim(chosen) == "" then
    notify("Creación de nota cancelada", vim.log.levels.WARN)
    return nil, false
  end

  path = M.destination(chosen, opts.source_path, opts.root)
  if not path then
    notify("Ese nombre no da un fichero válido", vim.log.levels.ERROR)
    return nil, false
  end
  if vim.uv.fs_stat(path) then
    -- Ya existía con el nombre nuevo: se abre y el enlace se reapunta igual.
    if opts.open then
      opts.open(path)
    else
      vim.cmd("edit " .. vim.fn.fnameescape(path))
    end
    return path, chosen ~= suggested
  end

  if not write_note(path, { notify = notify }) then
    return nil, false
  end

  if opts.open then
    opts.open(path)
  else
    vim.cmd("edit " .. vim.fn.fnameescape(path))
  end
  return path, chosen ~= suggested
end

return M
