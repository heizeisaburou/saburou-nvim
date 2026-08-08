-- hzsr.sys.java

local M = {}

local sysname = vim.uv.os_uname().sysname:lower()
local iswin = not not (sysname:find "windows" or sysname:find "mingw")
local ismac = sysname:find "darwin" ~= nil

---@class hzsr.sys.java.Info
---@field home string
---@field java string
---@field javac string?
---@field major integer
---@field version_output string

---@class hzsr.sys.java.ResolveOpts
---@field env? string[] Variables que contienen un JAVA_HOME explícito, por prioridad.
---@field versions? integer[] Versiones aceptadas, por orden de preferencia.
---@field require_jdk? boolean Exige `javac`, no sólo un runtime.
---@field extra_homes? string[] Rutas exactas de JDK que se prueban antes de autodetectar.
---@field extra_roots? string[] Directorios adicionales cuyos hijos pueden ser JDK.
---@field timeout? integer Tiempo máximo en milisegundos para consultar cada `java -version`.

local function executable_name(name)
  return iswin and name .. ".exe" or name
end

---@param path string?
---@return string?
local function normalize(path)
  if not path or path == "" then
    return nil
  end

  path = path:gsub('^"(.*)"$', "%1")
  path = vim.fs.normalize(path)
  return vim.uv.fs_realpath(path) or path
end

---@param output string
---@return integer?
local function parse_major(output)
  local version = output:match('[Vv]ersion%s+"([^"]+)"') or output:match("[Oo]pen[Jj][Dd][Kk]%s+([^%s]+)")
  if not version then
    return nil
  end

  local first, second = version:match "^(%d+)[%._]?(%d*)"
  local major = tonumber(first)
  if major == 1 and second ~= "" then
    major = tonumber(second)
  end

  return major
end

---@param home string
---@param opts? hzsr.sys.java.ResolveOpts
---@return hzsr.sys.java.Info?
function M.inspect(home, opts)
  vim.validate("home", home, "string")
  opts = opts or {}

  local normalized = normalize(home)
  if not normalized then
    return nil
  end

  local java = vim.fs.joinpath(normalized, "bin", executable_name "java")
  if vim.fn.executable(java) ~= 1 then
    return nil
  end

  local javac = vim.fs.joinpath(normalized, "bin", executable_name "javac")
  if vim.fn.executable(javac) ~= 1 then
    javac = nil
  end

  if opts.require_jdk and not javac then
    return nil
  end

  local result = vim.system({ java, "-version" }, { text = true }):wait(opts.timeout or 3000)
  local output = (result.stdout or "") .. (result.stderr or "")
  local major = parse_major(output)
  if not major then
    return nil
  end

  return {
    home = normalized,
    java = java,
    javac = javac,
    major = major,
    version_output = vim.trim(output),
  }
end

---@param java string
---@return string?
local function home_from_java(java)
  local path = normalize(java)
  if not path then
    return nil
  end

  return vim.fs.dirname(vim.fs.dirname(path))
end

---@param roots string[]
---@param add fun(path: string?)
local function add_root_children(roots, add)
  for _, root in ipairs(roots) do
    root = normalize(root)
    local handle = root and vim.uv.fs_scandir(root) or nil

    if handle then
      while true do
        local name, kind = vim.uv.fs_scandir_next(handle)
        if not name then
          break
        end

        if kind == "directory" or kind == "link" then
          local child = vim.fs.joinpath(root, name)
          add(child)
          -- Los bundles de macOS guardan el JDK real dentro de Contents/Home.
          add(vim.fs.joinpath(child, "Contents", "Home"))
        end
      end
    end
  end
end

---@return string[]
local function default_roots()
  if iswin then
    local roots = {}

    if vim.env.ProgramFiles and vim.env.ProgramFiles ~= "" then
      vim.list_extend(roots, {
        vim.fs.joinpath(vim.env.ProgramFiles, "Java"),
        vim.fs.joinpath(vim.env.ProgramFiles, "Eclipse Adoptium"),
        vim.fs.joinpath(vim.env.ProgramFiles, "Microsoft"),
      })
    end

    if vim.env.LOCALAPPDATA and vim.env.LOCALAPPDATA ~= "" then
      vim.list_extend(roots, {
        vim.fs.joinpath(vim.env.LOCALAPPDATA, "Programs", "Java"),
        vim.fs.joinpath(vim.env.LOCALAPPDATA, "Programs", "Eclipse Adoptium"),
      })
    end

    if vim.env.USERPROFILE and vim.env.USERPROFILE ~= "" then
      vim.list_extend(roots, {
        vim.fs.joinpath(vim.env.USERPROFILE, ".jdks"),
        vim.fs.joinpath(vim.env.USERPROFILE, ".sdkman", "candidates", "java"),
      })
    end

    return roots
  end

  if ismac then
    local roots = { "/Library/Java/JavaVirtualMachines" }
    if vim.env.HOME and vim.env.HOME ~= "" then
      table.insert(roots, vim.fs.joinpath(vim.env.HOME, "Library", "Java", "JavaVirtualMachines"))
    end
    return roots
  end

  local roots = { "/usr/lib/jvm", "/usr/java" }
  if vim.env.HOME and vim.env.HOME ~= "" then
    vim.list_extend(roots, {
      vim.fs.joinpath(vim.env.HOME, ".sdkman", "candidates", "java"),
      vim.fs.joinpath(vim.env.HOME, ".asdf", "installs", "java"),
      vim.fs.joinpath(vim.env.HOME, ".local", "share", "mise", "installs", "java"),
    })
  end
  return roots
end

---Devuelve todos los JDK/runtimes válidos encontrados, sin duplicados.
---@param opts? hzsr.sys.java.ResolveOpts
---@return hzsr.sys.java.Info[]
function M.find(opts)
  opts = opts or {}
  local homes = {}
  local seen_homes = {}

  local function add(home)
    home = normalize(home)
    if not home then
      return
    end

    local key = iswin and home:lower() or home
    if not seen_homes[key] then
      seen_homes[key] = true
      table.insert(homes, home)
    end
  end

  for _, name in ipairs(opts.env or { "JAVA_HOME", "JDK_HOME" }) do
    add(vim.env[name])
  end

  for _, home in ipairs(opts.extra_homes or {}) do
    add(home)
  end

  local path_java = vim.fn.exepath "java"
  if path_java ~= "" then
    add(home_from_java(path_java))
  end

  local roots = vim.list_extend(vim.deepcopy(opts.extra_roots or {}), default_roots())
  add_root_children(roots, add)

  local found = {}
  for _, home in ipairs(homes) do
    local info = M.inspect(home, opts)
    if info then
      table.insert(found, info)
    end
  end

  return found
end

---Resuelve un JAVA_HOME. Si se indican versiones, respeta ese orden de
---preferencia y no devuelve versiones distintas.
---@param opts? hzsr.sys.java.ResolveOpts
---@return string? home
---@return hzsr.sys.java.Info? info
function M.resolve_home(opts)
  opts = opts or {}
  local found = M.find(opts)
  local versions = opts.versions or {}

  if #versions == 0 then
    local info = found[1]
    return info and info.home or nil, info
  end

  for _, version in ipairs(versions) do
    for _, info in ipairs(found) do
      if info.major == version then
        return info.home, info
      end
    end
  end

  return nil, nil
end

return M
