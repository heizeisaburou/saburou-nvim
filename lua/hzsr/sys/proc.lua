-- hzsr.sys.proc

-- Consultas sobre el árbol de procesos.
--
-- Existe por una razón muy concreta: `$SHELL` no dice en qué shell estás, dice
-- cuál es tu shell de *login*. Ninguna shell la reescribe al arrancar, así que
-- si abres pwsh desde zsh, `$SHELL` sigue diciendo zsh. Lo único que sabe la
-- verdad es el árbol de procesos.

local M = {}

local sysname = vim.uv.os_uname().sysname:lower()
local iswin = not not (sysname:find "windows" or sysname:find "mingw")
local haveproc = not iswin and vim.uv.fs_stat "/proc/self/stat" ~= nil

--- Cuántos antepasados se recorren como máximo.
---
--- El padre directo cubre el caso normal (shell → nvim), pero no `sudo nvim` ni
--- `git commit` (padre `git`, shell un nivel más arriba). Seis niveles llegan de
--- sobra a esos casos sin convertir la búsqueda en una excursión.
local MAX_DEPTH = 6

---@param path string
---@return string?
local function read_file(path)
  local fd = vim.uv.fs_open(path, "r", 292)
  if not fd then
    return nil
  end

  local stat = vim.uv.fs_fstat(fd)
  -- Los archivos de /proc reportan size 0; hay que pedir un bloque a ciegas.
  local data = vim.uv.fs_read(fd, stat and stat.size ~= 0 and stat.size or 4096, 0)
  vim.uv.fs_close(fd)

  return data
end

---@param pid integer
---@return integer? ppid
local function proc_ppid(pid)
  local stat = read_file("/proc/" .. pid .. "/stat")
  if not stat then
    return nil
  end

  -- Campo 2 (comm) va entre paréntesis y puede contener espacios y paréntesis,
  -- así que se corta por el ÚLTIMO ")" y se cuenta desde ahí: state, ppid.
  local tail = stat:match "%)%s+(.*)$"
  if not tail then
    return nil
  end

  local ppid = tail:match "^%S+%s+(%d+)"
  return ppid and tonumber(ppid) or nil
end

---@param pid integer
---@return string? path Ruta del ejecutable, si se puede resolver.
---@return string? name Nombre corto, siempre que /proc responda.
local function proc_exe(pid)
  -- `exe` es la ruta real y es lo que queremos, pero es un enlace que solo
  -- puede leer el dueño del proceso: con `sudo` en medio, falla. `comm` no
  -- falla nunca, pero viene truncado a 15 caracteres, así que sirve para
  -- identificar la shell y no para ejecutarla.
  local path = vim.uv.fs_readlink("/proc/" .. pid .. "/exe")
  local comm = read_file("/proc/" .. pid .. "/comm")
  local name = comm and vim.trim(comm)

  if path then
    return path, name ~= "" and name or vim.fs.basename(path)
  end

  return nil, name ~= "" and name or nil
end

--- Tabla pid -> { ppid, name }, de un solo `ps`.
---@return table<integer, { ppid: integer, name: string }>
local function ps_table()
  local out = vim.system({ "ps", "-Ao", "pid=,ppid=,comm=" }, { text = true }):wait()
  local processes = {}

  if out.code ~= 0 or not out.stdout then
    return processes
  end

  for line in vim.gsplit(out.stdout, "\n") do
    local pid, ppid, name = line:match "^%s*(%d+)%s+(%d+)%s+(.+)$"
    if pid then
      processes[tonumber(pid)] = { ppid = tonumber(ppid), name = vim.trim(name) }
    end
  end

  return processes
end

---@class hzsr.sys.proc.Ancestor
---@field pid integer
---@field name string Nombre corto del ejecutable, sin ruta ni `.exe`.
---@field path string? Ruta completa, cuando se puede resolver.

--- Antepasados del proceso actual, del más cercano al más lejano.
---
--- Devuelve una lista vacía donde no se puede averiguar (Windows, o un Unix sin
--- `/proc` y sin `ps`); quien llame debe tener un plan para ese caso.
---@param depth? integer Máximo de niveles; por defecto `MAX_DEPTH`.
---@return hzsr.sys.proc.Ancestor[]
function M.ancestors(depth)
  depth = depth or MAX_DEPTH

  if iswin then
    return {}
  end

  local ancestors = {}
  ---@type integer?
  local pid = vim.uv.os_getppid()

  if haveproc then
    while pid and pid > 1 and #ancestors < depth do
      local path, name = proc_exe(pid)
      if not name then
        break
      end

      ancestors[#ancestors + 1] = { pid = pid, name = name, path = path }
      pid = proc_ppid(pid)
    end

    return ancestors
  end

  -- macOS y BSD: un único `ps` y se recorre la tabla en memoria.
  local processes = ps_table()

  while pid and pid > 1 and #ancestors < depth do
    local entry = processes[pid]
    if not entry then
      break
    end

    ancestors[#ancestors + 1] = {
      pid = pid,
      name = vim.fs.basename(entry.name),
      path = entry.name:find "/" and entry.name or nil,
    }
    pid = entry.ppid
  end

  return ancestors
end

--- `true` si el árbol de procesos es consultable en esta plataforma.
---@return boolean
function M.available()
  return not iswin and (haveproc or vim.fn.executable "ps" == 1)
end

return M
