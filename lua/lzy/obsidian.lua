-- lzy/l_obsidian.lua

local M = {}
local uv = vim.uv or vim.loop

local OBSIDIAN_MARKER = ".obsidian"
local NYABSIDIAN_MARKER = ".nyabsidian"
local DUMMY_NAME = "__nyabsidian_dummy__"
local STATE_DIR = vim.fs.joinpath(vim.fn.stdpath "state", "nyabsidian")
local STATE_FILE = vim.fs.joinpath(STATE_DIR, "workspaces.json")

local state = {
  roots = {},
  dummy = nil,
  initialized = false,
  refreshing = false,
  config_errors = {},
  lsp_server_patched = false,
}

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "Nyabsidian" })
end

local function normalize(path)
  if type(path) ~= "string" or path == "" then
    return nil
  end
  path = vim.fn.expand(path)
  return vim.fs.normalize(uv.fs_realpath(path) or path)
end

local function cwd()
  return normalize(vim.fn.getcwd())
end

local function stat(path, kind)
  local s = uv.fs_stat(path)
  return s ~= nil and (kind == nil or s.type == kind)
end

local function inspect_root(root)
  root = normalize(root)
  if not root or not stat(root, "directory") then
    return nil
  end

  local has_obsidian = stat(vim.fs.joinpath(root, OBSIDIAN_MARKER), "directory")
  local has_nyabsidian = stat(vim.fs.joinpath(root, NYABSIDIAN_MARKER), "file")
  if not has_obsidian and not has_nyabsidian then
    return nil
  end

  return {
    root = root,
    has_obsidian = has_obsidian,
    has_nyabsidian = has_nyabsidian,
    kind = has_obsidian and (has_nyabsidian and "obsidian+nyabsidian" or "obsidian")
      or "nyabsidian",
  }
end

--- Busca el marker más cercano subiendo por parents.
--- Sólo hace stat de .obsidian y .nyabsidian; no recorre directorios.
local function discover(path)
  local dir = normalize(path)
  if not dir then
    return nil
  end

  local s = uv.fs_stat(dir)
  if s and s.type ~= "directory" then
    dir = normalize(vim.fs.dirname(dir))
  end

  while dir do
    local info = inspect_root(dir)
    if info then
      return info
    end

    local parent = normalize(vim.fs.dirname(dir))
    if not parent or parent == dir then
      break
    end
    dir = parent
  end
end

--- Extensiones de archivos que pueden pertenecer a un workspace.
local NOTE_EXTENSIONS = { "md", "markdown", "mdown", "mkdn", "mkd", "qmd", "rmd", "base" }

---@param name string
---@return boolean
local function is_note(name)
  local ext = name:match("%.([^./]+)$")
  return ext ~= nil and vim.tbl_contains(NOTE_EXTENSIONS, ext)
end

--- Detecta roots a partir de los buffers abiertos que no pertenezcan aún a
--- ningún root conocido. Complementa a discover(cwd()).
---@param known string[] Roots ya registrados.
---@return string[] Roots nuevos descubiertos desde buffers.
local function scan_buffers(known)
  local seen = {}
  for _, root in ipairs(known or {}) do
    seen[normalize(root)] = true
  end

  local roots = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name ~= "" then
      local tail = vim.fn.fnamemodify(name, ":t")
      if is_note(name) or tail == NYABSIDIAN_MARKER then
        local found = discover(name)
        if found and not seen[found.root] then
          seen[found.root] = true
          roots[#roots + 1] = found.root
        end
      end
    end
  end
  return roots
end

local function sort_roots(roots)
  local seen, out = {}, {}
  for _, root in ipairs(roots or {}) do
    root = normalize(root)
    if root and not seen[root] then
      seen[root] = true
      out[#out + 1] = root
    end
  end

  -- En workspaces anidados debe ganar el más específico.
  table.sort(out, function(a, b)
    return #a == #b and a < b or #a > #b
  end)
  return out
end

local function same_roots(a, b)
  if #a ~= #b then
    return false
  end
  for i = 1, #a do
    if a[i] ~= b[i] then
      return false
    end
  end
  return true
end

local function read_state()
  local f = io.open(STATE_FILE, "r")
  if not f then
    return {}
  end

  local raw = f:read "*a"
  f:close()
  if not raw or vim.trim(raw) == "" then
    return {}
  end

  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" then
    notify("State inválido; se reconstruirá.\n" .. STATE_FILE, vim.log.levels.WARN)
    return {}
  end

  local roots = data.workspaces
  if roots == nil and vim.islist(data) then
    roots = data
  end
  return type(roots) == "table" and sort_roots(roots) or {}
end

local function write_state(roots)
  vim.fn.mkdir(STATE_DIR, "p")
  local ok, encoded = pcall(vim.json.encode, {
    version = 1,
    workspaces = sort_roots(roots),
  })
  if not ok then
    notify("No se pudo serializar el state: " .. tostring(encoded), vim.log.levels.ERROR)
    return
  end

  local wrote, err = pcall(vim.fn.writefile, { encoded }, STATE_FILE)
  if not wrote then
    notify("No se pudo escribir el state: " .. tostring(err), vim.log.levels.ERROR)
  end
end

local function collect_roots()
  local persisted = read_state()
  local roots = {}

  -- Prune: el state sólo recuerda roots que todavía siguen declarados.
  for _, root in ipairs(persisted) do
    if inspect_root(root) then
      roots[#roots + 1] = root
    end
  end

  local found = discover(cwd())
  if found then
    roots[#roots + 1] = found.root
  end

  -- Roots detectados a partir de los buffers abiertos.
  for _, root in ipairs(scan_buffers(roots)) do
    roots[#roots + 1] = root
  end

  roots = sort_roots(roots)
  if not same_roots(persisted, roots) then
    write_state(roots)
  end

  return roots, found
end

local function config_warning(path, err)
  err = tostring(err)
  if state.config_errors[path] == err then
    return
  end
  state.config_errors[path] = err
  notify(("%s inválido; se usarán defaults.\n%s"):format(path, err), vim.log.levels.WARN)
end

local function read_nyabsidian(root)
  local path = vim.fs.joinpath(root, NYABSIDIAN_MARKER)
  if not stat(path, "file") then
    return {}
  end

  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local raw = f:read "*a"
  f:close()

  -- Archivo vacío = defaults.
  if not raw or vim.trim(raw) == "" then
    state.config_errors[path] = nil
    return {}
  end

  local ok, data = pcall(vim.json.decode, raw)
  if not ok or type(data) ~= "table" or (not vim.tbl_isempty(data) and vim.islist(data)) then
    config_warning(path, ok and "la raíz JSON debe ser un objeto" or data)
    return {}
  end

  state.config_errors[path] = nil
  return data
end

--- Traduce .nyabsidian a overrides de obsidian.nvim.
--- Ampliar aquí cuando Nyabsidian gane más opciones.
local function workspace_overrides(root)
  local cfg = read_nyabsidian(root)
  local overrides = {}

  if cfg.frontmatter ~= nil then
    if type(cfg.frontmatter) ~= "table" then
      config_warning(
        vim.fs.joinpath(root, NYABSIDIAN_MARKER),
        "'frontmatter' debe ser un objeto"
      )
      return {}
    end

    overrides.frontmatter = vim.deepcopy(cfg.frontmatter)
    -- .nyabsidian es JSON: frontmatter.func sigue siendo responsabilidad Lua.
    overrides.frontmatter.func = nil
  end

  if vim.tbl_isempty(overrides) then
    return overrides
  end

  local ok, err = pcall(function()
    require("obsidian.config").normalize(vim.deepcopy(overrides))
  end)
  if not ok then
    config_warning(vim.fs.joinpath(root, NYABSIDIAN_MARKER), err)
    return {}
  end

  return overrides
end

local function dummy_root()
  if state.dummy and stat(state.dummy, "directory") then
    return state.dummy
  end
  local path = vim.fn.tempname()
  vim.fn.mkdir(path, "p")
  state.dummy = normalize(path)
  return state.dummy
end

local function real_spec(root)
  return {
    name = "nyabsidian:" .. root,
    path = root,
    strict = true,
    overrides = workspace_overrides(root),
  }
end

local function dummy_spec()
  return {
    name = DUMMY_NAME,
    path = dummy_root(),
    strict = true,
    overrides = {
      frontmatter = { enabled = false },
      sync = { enabled = false },
    },
  }
end

local function workspace_specs(roots)
  -- Dummy primero: si cwd no pertenece a ningún root real, setup cae aquí.
  local specs = { dummy_spec() }
  for _, root in ipairs(sort_roots(roots)) do
    specs[#specs + 1] = real_spec(root)
  end
  return specs
end

local function make_opts()
  state.roots = collect_roots()

  return {
    legacy_commands = false,
    workspaces = workspace_specs(state.roots),

    frontmatter = {
      enabled = function(_path)
        return false
      end,

      func = function(note)
        if note.title then
          note:add_alias(note.title)
        end

        local out = { id = note.id, aliases = note.aliases, tags = note.tags }
        if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
          for k, v in pairs(note.metadata) do
            out[k] = v
          end
        end
        return out
      end,
    },
  }
end

M.opts = make_opts

local function dummy_workspace()
  for _, ws in ipairs(Obsidian.workspaces or {}) do
    if ws.name == DUMMY_NAME then
      return ws
    end
  end
end

local function set_workspace(ws)
  if ws then
    require("obsidian").Workspace.set(ws)
  end
end

local function workspace_for(path)
  return require("obsidian").Workspace.find(path, Obsidian.workspaces)
end

local function detach_obsidian_lsp(bufnr)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, name = "obsidian-ls" }) do
    pcall(vim.lsp.buf_detach_client, bufnr, client.id)
  end
end

--- Deja un buffer como si obsidian.nvim nunca lo hubiera tocado.
local function reset_obsidian_buffer(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local help = vim.b[bufnr].obsidian_help

  vim.b[bufnr].obsidian_buffer = false
  vim.b[bufnr].obsidian_help = nil
  vim.b[bufnr].note = nil
  vim.b[bufnr].obsidian_status = nil

  -- El footer de obsidian (backlinks/properties) son virt_lines en el
  -- namespace "obsidian.footer": se limpian con su propio autocmd de
  -- BufUnload (para el timer y autocmds) y borrando el namespace.
  local footer_ns = vim.api.nvim_get_namespaces()["obsidian.footer"]
  if footer_ns then
    pcall(vim.api.nvim_buf_clear_namespace, bufnr, footer_ns, 0, -1)
  end
  pcall(vim.api.nvim_exec_autocmds, "BufUnload", {
    group = "obsidian.footer-" .. bufnr,
    buffer = bufnr,
    modeline = false,
  })

  vim.bo[bufnr].includeexpr = ""
  if vim.bo[bufnr].commentstring == "%%%s%%" then
    vim.bo[bufnr].commentstring = "%s"
  end
  if help then
    vim.bo[bufnr].readonly = false
  end

  for _, lhs in ipairs { "<CR>", "]o", "[o" } do
    for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
      if map.lhs == lhs and (map.desc or ""):find("^Obsidian") then
        pcall(vim.keymap.del, "n", lhs, { buffer = bufnr })
      end
    end
  end

  detach_obsidian_lsp(bufnr)
end

--- Sincroniza el estado global con el buffer actual. Si el buffer no pertenece
--- a ningún workspace, usa el workspace del cwd; si tampoco existe, dummy.
local function sync_current_context(reenter)
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  local ws = name ~= "" and require("obsidian").api.find_workspace(name) or nil

  if ws then
    set_workspace(ws)
    if
      reenter and (vim.bo[bufnr].filetype == "markdown" or vim.bo[bufnr].filetype == "quarto")
    then
      pcall(vim.api.nvim_exec_autocmds, "BufEnter", {
        group = "obsidian_setup",
        buffer = bufnr,
        modeline = false,
      })
    end
    return
  end

  if vim.bo[bufnr].filetype == "markdown" or vim.bo[bufnr].filetype == "quarto" then
    reset_obsidian_buffer(bufnr)
  end

  set_workspace(workspace_for(cwd()) or dummy_workspace())
end

local function stop_removed_lsp(roots)
  local valid = { [normalize(dummy_root())] = true }
  for _, root in ipairs(roots) do
    valid[normalize(root)] = true
  end
  for _, ws in ipairs(Obsidian.workspaces or {}) do
    if ws.name == ".obsidian.wiki" then
      valid[normalize(tostring(ws.root))] = true
    end
  end

  for _, client in ipairs(vim.lsp.get_clients { name = "obsidian-ls" }) do
    local root = client.config
      and client.config.root_dir
      and normalize(tostring(client.config.root_dir))
    if root and not valid[root] then
      client:stop(true)
    end
  end
end

---@param roots string[]
---@param removed? string[] Roots que han dejado de existir.
local function rebuild_runtime(roots, removed)
  local obsidian = require "obsidian"
  local workspaces = {}

  workspaces[#workspaces + 1] = assert(obsidian.Workspace.new(dummy_spec()))
  for _, root in ipairs(sort_roots(roots)) do
    local ws = obsidian.Workspace.new(real_spec(root))
    if ws then
      workspaces[#workspaces + 1] = ws
    end
  end

  -- El help workspace lo añade obsidian.nvim después de Workspace.setup().
  for _, ws in ipairs(Obsidian.workspaces or {}) do
    if ws.name == ".obsidian.wiki" then
      workspaces[#workspaces + 1] = ws
    end
  end

  Obsidian.workspaces = workspaces
  stop_removed_lsp(roots)

  -- Des-obsidianiza los buffers abiertos de los roots que desaparecieron.
  for _, root in ipairs(removed or {}) do
    local prefix = normalize(root) .. "/"
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(bufnr) then
        local name = normalize(vim.api.nvim_buf_get_name(bufnr))
        if name and name:sub(1, #prefix) == prefix then
          reset_obsidian_buffer(bufnr)
        end
      end
    end
  end

  sync_current_context(true)
end

---@param opts? { notify?: boolean }
function M.refresh(opts)
  opts = opts or {}
  if state.refreshing then
    return
  end
  state.refreshing = true

  local ok, err = xpcall(function()
    local before = state.roots
    local roots, found = collect_roots()

    local removed = {}
    for _, root in ipairs(before) do
      if not vim.tbl_contains(roots, root) then
        removed[#removed + 1] = root
      end
    end

    state.roots = roots

    if state.initialized then
      rebuild_runtime(roots, removed)
    end

    if opts.notify then
      notify(table.concat({
        ("workspaces: %d"):format(#roots),
        found and ("cwd: %s [%s]"):format(found.root, found.kind) or "cwd: <disabled>",
        same_roots(before, roots) and "changes: none" or "changes: applied",
      }, "\n"))
    end
  end, debug.traceback)

  state.refreshing = false
  if not ok then
    notify("Refresh falló:\n" .. tostring(err), vim.log.levels.ERROR)
  end
end

function M.info()
  local found = discover(cwd())
  local current = rawget(_G, "Obsidian") and Obsidian.workspace or nil
  local persisted = false

  if found then
    for _, root in ipairs(state.roots) do
      if root == found.root then
        persisted = true
        break
      end
    end
  end

  local lines = {
    "cwd:       " .. tostring(cwd()),
    "workspace: " .. (found and found.root or "<disabled>"),
    "marker:    " .. (found and found.kind or "<none>"),
    "persisted: " .. (persisted and "yes" or "no"),
    "known:     " .. tostring(#state.roots),
    "current:   " .. (current and tostring(current.root) or "<not initialized>"),
    "state:     " .. STATE_FILE,
  }
  if found and found.has_nyabsidian then
    lines[#lines + 1] = "config:    " .. vim.fs.joinpath(found.root, NYABSIDIAN_MARKER)
  end
  notify(table.concat(lines, "\n"))
end

--- Volcado de diagnóstico para depurar la descarga de obsidian.nvim.
---@param opts? { notify?: boolean }
function M.debug_info(opts)
  opts = opts or {}
  local out = {}
  local b = vim.api.nvim_get_current_buf()

  table.insert(out, "bufname: " .. vim.api.nvim_buf_get_name(b))
  table.insert(out, "obsidian_buffer: " .. tostring(vim.b[b].obsidian_buffer))
  table.insert(out, "includeexpr: '" .. vim.bo[b].includeexpr .. "'")
  table.insert(out, "cr_desc: " .. tostring(vim.fn.maparg("<CR>", "n", false, true).desc))
  table.insert(out, "state.roots: " .. vim.inspect(state.roots))
  table.insert(out, "lsp_server_patched: " .. tostring(state.lsp_server_patched))

  for _, c in ipairs(vim.lsp.get_clients { name = "obsidian-ls" }) do
    table.insert(
      out,
      ("client %d closing=%s stopped=%s root=%s"):format(
        c.id,
        tostring(c.rpc and c.rpc.is_closing and c.rpc.is_closing() or "?"),
        tostring(c:is_stopped()),
        tostring(c.config.root_dir)
      )
    )
  end

  table.insert(out, "obsidian-ls on buffer: " .. #vim.lsp.get_clients { bufnr = b, name = "obsidian-ls" })
  table.insert(out, "marksman on buffer: " .. #vim.lsp.get_clients { bufnr = b, name = "marksman" })
  table.insert(
    out,
    "all LSP on buffer: "
      .. vim.inspect(vim.tbl_map(function(c)
        return c.name
      end, vim.lsp.get_clients { bufnr = b }))
  )

  local Obsidian = rawget(_G, "Obsidian")
  if Obsidian then
    table.insert(
      out,
      "workspaces: "
        .. vim.inspect(vim.tbl_map(function(w)
          return tostring(w.root)
        end, Obsidian.workspaces or {}))
    )
    table.insert(out, "current: " .. tostring(Obsidian.workspace and Obsidian.workspace.root))
  end

  notify(table.concat(out, "\n"))
end

--- Debe registrarse antes del setup de obsidian.nvim. Así el workspace global
--- ya es correcto cuando sus BufEnter consultan Obsidian.opts / Obsidian.dir.
local function install_workspace_switch()
  local group = vim.api.nvim_create_augroup("nyabsidian_workspace_switch", { clear = true })

  vim.api.nvim_create_autocmd("BufEnter", {
    group = group,
    pattern = { "*.md", "*.markdown", "*.qmd", "*.base" },
    callback = function(ev)
      if not state.initialized then
        return
      end

      local ws = require("obsidian").api.find_workspace(ev.file)
      if ws then
        set_workspace(ws)
      else
        reset_obsidian_buffer(ev.buf)
        set_workspace(workspace_for(cwd()) or dummy_workspace())
      end
    end,
  })
end

--- obsidian-ls es un servidor LSP in-process (función pasada a `vim.lsp.start`).
--- Neovim requiere que un servidor así invoque `dispatchers.on_exit()` para
--- señalizar su fin; obsidian.nvim no lo hace en `terminate()` ni al recibir
--- `exit`, así que `client:stop()` deja el cliente registrado para siempre.
--- Envolvemos la factory y garantizamos exactamente un on_exit. Si upstream lo
--- corrige, el wrapper no duplica la notificación.
local function patch_lsp_server_shutdown()
  if state.lsp_server_patched then
    return
  end

  local module_name = "obsidian.lsp.server"
  local factory = require(module_name)

  package.loaded[module_name] = function(dispatchers)
    local exited = false
    local on_exit = dispatchers.on_exit

    local wrapped_dispatchers = vim.tbl_extend("force", dispatchers, {
      on_exit = function(code, signal)
        if exited then
          return
        end
        exited = true
        return on_exit(code, signal)
      end,
    })

    local server = factory(wrapped_dispatchers)
    local notify_rpc = server.notify
    local terminate_rpc = server.terminate

    server.notify = function(method, ...)
      local result
      if notify_rpc then
        result = notify_rpc(method, ...)
      end

      -- Cierre limpio: shutdown + exit. El servidor debe señalizar su salida.
      if method == "exit" and not exited then
        wrapped_dispatchers.on_exit(0, 0)
      end

      return result
    end

    server.terminate = function(...)
      local result
      if terminate_rpc then
        result = terminate_rpc(...)
      end

      -- Cierre forzado (client:stop(true)): terminar sin esperar al proceso.
      if not exited then
        wrapped_dispatchers.on_exit(0, 15)
      end

      return result
    end

    return server
  end

  state.lsp_server_patched = true
end

--- Cinturón de seguridad: el LSP del plugin usa Obsidian.dir como root_dir.
local function patch_lsp_start()
  local lsp = require "obsidian.lsp"
  if lsp.__nyabsidian_patched then
    return
  end

  local start = lsp.start
  lsp.start = function(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    local ws = name ~= "" and require("obsidian").api.find_workspace(name) or nil
    if ws then
      set_workspace(ws)
    end
    return start(bufnr)
  end
  lsp.__nyabsidian_patched = true
end

local function install_runtime()
  local group = vim.api.nvim_create_augroup("nyabsidian", { clear = true })

  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      M.refresh()
    end,
  })

  vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
    group = group,
    pattern = NYABSIDIAN_MARKER,
    callback = function()
      M.refresh { notify = true }
    end,
  })

  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = group,
    once = true,
    callback = function()
      if state.dummy and stat(state.dummy, "directory") then
        pcall(vim.fn.delete, state.dummy, "rf")
      end
    end,
  })

  pcall(vim.api.nvim_del_user_command, "NyabsidianRefresh")
  pcall(vim.api.nvim_del_user_command, "NyabsidianInfo")
  pcall(vim.api.nvim_del_user_command, "NyabsidianDebug")

  vim.api.nvim_create_user_command("NyabsidianRefresh", function()
    M.refresh { notify = true }
  end, { desc = "Refresh Nyabsidian workspaces" })

  vim.api.nvim_create_user_command("NyabsidianInfo", function()
    M.info()
  end, { desc = "Show Nyabsidian workspace info" })

  vim.api.nvim_create_user_command("NyabsidianDebug", function()
    M.debug_info()
  end, { desc = "Dump Nyabsidian LSP debug info" })
end

function M.setup()
  -- Debe instalarse antes de que pueda arrancar el primer obsidian-ls.
  patch_lsp_server_shutdown()
  install_workspace_switch()
  require("obsidian").setup(M.opts())

  state.initialized = true
  patch_lsp_start()
  install_runtime()

  -- Valida state, aplica configs y cubre el cwd actual.
  M.refresh()
end

return M
