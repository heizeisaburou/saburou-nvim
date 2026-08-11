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
  note_save_patched = false,
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

--- Keymaps de obsidian.nvim (buffer-local, solo en notas). Namespace
--- <leader>n*: lo expone which-key, que ya tiene "n" registrado como grupo.
local NOTE_KEYMAPS = {
  { "<leader>nn", "Obsidian new", "Obsidian: nueva nota" },
  { "<leader>nr", "Obsidian rename", "Obsidian: renombrar nota (actualiza enlaces)" },
  { "<leader>ns", "Obsidian quick_switch", "Obsidian: cambiar de nota" },
  { "<leader>nb", "Obsidian backlinks", "Obsidian: qué notas enlazan a esta" },
  { "<leader>nl", "Obsidian link_new", "Obsidian: enlazar selección a nota nueva" },
  { "<leader>nL", "Obsidian link", "Obsidian: enlazar a nota existente" },
  { "<leader>nd", "Obsidian dailies", "Obsidian: notas diarias" },
  { "<leader>nt", "Obsidian template", "Obsidian: insertar plantilla" },
  { "<leader>nT", "Obsidian tags", "Obsidian: tags del vault" },
  { "<leader>nf", "Obsidian follow_link", "Obsidian: seguir el enlace bajo el cursor" },
  { "<leader>nx", "Obsidian toggle_checkbox", "Obsidian: toggle checkbox" },
  { "<leader>np", "Obsidian paste_img", "Obsidian: pegar imagen del portapapeles" },
}

--- Keymaps buffer-local para notas. Se llaman por buffer (idempotente).
---@param bufnr integer
local function install_note_keymaps(bufnr)
  for _, spec in ipairs(NOTE_KEYMAPS) do
    vim.keymap.set("n", spec[1], ("<cmd>%s<CR>"):format(spec[2]), {
      buffer = bufnr,
      desc = spec[3],
    })
  end
end

---@param name string
---@return boolean
local function is_note(name)
  local ext = name:match "%.([^./]+)$"
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

  -- Todas las notas de un mismo directorio comparten el mismo climb de
  -- parents: se resuelve el root una vez por directorio y se reusa. Con
  -- decenas de buffers abiertos evita repetir la subida para cada nota.
  local dir_cache = {}

  local roots = {}
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    local name = vim.api.nvim_buf_get_name(bufnr)
    if name ~= "" then
      local tail = vim.fn.fnamemodify(name, ":t")
      if is_note(name) or tail == NYABSIDIAN_MARKER then
        local dir = normalize(vim.fs.dirname(name))
        local root = false
        if dir and dir_cache[dir] ~= nil then
          root = dir_cache[dir]
        elseif dir then
          local found = discover(dir)
          root = found and found.root or false
          dir_cache[dir] = root
        end
        if root and not seen[root] then
          seen[root] = true
          roots[#roots + 1] = root
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
  -- ws.root puede ser un Path (tabla): joinpath lo descartaría y acabaríamos
  -- leyendo el .nyabsidian del cwd. Normalizamos a string siempre.
  root = vim.fs.normalize(tostring(root))
  local path = vim.fs.joinpath(root, NYABSIDIAN_MARKER)
  if not stat(path, "file") then
    return {}
  end

  -- El archivo es Lua: loadfile no depende del nombre. El chunk debe devolver
  -- una tabla (el fragmento de overrides); sin return = defaults.
  local chunk, load_err = loadfile(path)
  if not chunk then
    config_warning(path, load_err)
    return {}
  end

  local ok, data = pcall(chunk)
  if not ok then
    config_warning(path, data)
    return {}
  end

  -- Archivo vacío o solo comentarios = defaults.
  if data == nil then
    state.config_errors[path] = nil
    return {}
  end

  if type(data) ~= "table" or (not vim.tbl_isempty(data) and vim.islist(data)) then
    config_warning(path, "la raíz debe ser una tabla; p.ej. return { ... }")
    return {}
  end

  state.config_errors[path] = nil
  return data
end

--- Traduce .nyabsidian a overrides de obsidian.nvim.
--- El archivo devuelve un fragmento de overrides (Lua); el deep-merge por clave
--- con los defaults del plugin lo hace Workspace.set (config.normalize).
--- Las funciones (frontmatter.func, enabled, ...) se reemplazan por clave,
--- nunca se fusionan; si un vault no define frontmatter.func, aplica la
--- función global de make_opts (fallback por merge).
local function workspace_overrides(root)
  local overrides = read_nyabsidian(root)

  if vim.tbl_isempty(overrides) then
    return overrides
  end

  local ok, err = pcall(function()
    -- Validar contra los defaults del plugin dispara la deprecación de
    -- legacy_commands (true por defecto); el merge real usa Obsidian._opts
    -- (legacy_commands = false), así que aquí lo neutralizamos también.
    local copy = vim.deepcopy(overrides)
    copy.legacy_commands = false
    require("obsidian.config").normalize(copy)
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
      -- Por defecto desactivado: los metatags solo se generan en vaults
      -- cuyo .nyabsidian lo activa, p.ej. frontmatter = { enabled = true }.
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
    -- .nyabsidian es live: releerlo en cada BufEnter para que ediciones
    -- (p.ej. activar frontmatter) apliquen sin reiniciar nvim.
    if ws.name ~= DUMMY_NAME then
      ws.overrides = workspace_overrides(ws.root)
    end
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

--- marksman sobra en notas de vault: obsidian-ls gestiona los enlaces wiki
--- (root_dir de marksman ya bloquea su arranque en vaults; esto cubre clients
--- ya arrancados, p.ej. al crear el marker .nyabsidian en la misma sesión).
---@param bufnr integer
---@param ws table
local function detach_marksman(bufnr, ws)
  if not ws then
    return
  end
  local root = normalize(tostring(ws.root))
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, name = "marksman" }) do
    local client_root = client.config
      and client.config.root_dir
      and normalize(tostring(client.config.root_dir))
    if client_root and (client_root == root or client_root:sub(1, #root + 1) == root .. "/") then
      -- El root del client es el vault: no le sirve a ninguna nota, se detiene.
      client:stop(true)
    else
      pcall(vim.lsp.buf_detach_client, bufnr, client.id)
    end
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
      if map.lhs == lhs and (map.desc or ""):find "^Obsidian" then
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
    detach_marksman(bufnr, ws)
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

  table.insert(
    out,
    "obsidian-ls on buffer: " .. #vim.lsp.get_clients { bufnr = b, name = "obsidian-ls" }
  )
  table.insert(
    out,
    "marksman on buffer: " .. #vim.lsp.get_clients { bufnr = b, name = "marksman" }
  )
  table.insert(out, "all LSP on buffer: " .. vim.inspect(vim.tbl_map(function(c)
    return c.name
  end, vim.lsp.get_clients { bufnr = b })))

  local Obsidian = rawget(_G, "Obsidian")
  if Obsidian then
    table.insert(out, "workspaces: " .. vim.inspect(vim.tbl_map(function(w)
      return tostring(w.root)
    end, Obsidian.workspaces or {})))
    table.insert(out, "current: " .. tostring(Obsidian.workspace and Obsidian.workspace.root))
  end

  notify(table.concat(out, "\n"))
end

--- El parser YAML del plugin es permisivo: un flow marker sin cerrar (p.ej.
--- `aliases: [` o `id: [broken`) lo convierte en scalar y el round-trip
--- escribe basura normalizada. Si el body del frontmatter tiene [ { sin
--- balancear, mejor no reescribir.
---@param lines string[]
---@return boolean
local function has_unclosed_flow(lines)
  local open, close = 0, 0
  for _, line in ipairs(lines) do
    for ch in line:gmatch "." do
      if ch == "[" or ch == "{" then
        open = open + 1
      elseif ch == "]" or ch == "}" then
        close = close + 1
      end
    end
  end
  return open ~= close
end

--- Regenera el frontmatter del buffer actual, esté activado o no el frontmatter
--- del workspace. Fuerza la escritura saltando should_save_frontmatter().
function M.frontmatter()
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  if name == "" or not is_note(name) then
    notify("NyabsidianFrontmatter solo funciona en notas", vim.log.levels.WARN)
    return
  end

  local ok, note = pcall(require("obsidian.note").from_buffer, bufnr)
  if not ok or not note then
    notify("No se pudo leer la nota: " .. tostring(note), vim.log.levels.ERROR)
    return
  end

  -- Protección: no reescribir frontmatters malformados (flow sin cerrar).
  if note.has_frontmatter and note.frontmatter_end_line and note.frontmatter_end_line > 1 then
    local body = vim.api.nvim_buf_get_lines(bufnr, 1, note.frontmatter_end_line - 1, false)
    if has_unclosed_flow(body) then
      notify(
        "Frontmatter malformado (flow [ { sin cerrar); no se tocó la nota",
        vim.log.levels.WARN
      )
      return
    end
  end

  local saved, updated = pcall(note.save_to_buffer, note, { bufnr = bufnr })
  if not saved then
    notify("Falló al generar el frontmatter: " .. tostring(updated), vim.log.levels.ERROR)
    return
  end

  notify(updated and "Frontmatter actualizado" or "Frontmatter sin cambios")
end

--- Template de .nyabsidian para NyabsidianInit.
local function nyabsidian_template()
  return [[-- Config de Nyabsidian para este vault.
-- Guarda este archivo como ".nyabsidian" en el directorio que quieras
-- tratar como vault: ese archivo ES el marker que lo convierte en vault
-- (junto a .obsidian si existe). Es live: se relee al entrar en cada nota.

-- Claves disponibles (fragmento de la config de obsidian.nvim; el resto
-- hereda de los defaults de la config global).
--
-- Los tipos de abajo son un espejo resumido de obsidian.config.* del plugin:
-- sirven para validar y completar este archivo en cualquier carpeta, sin
-- depender de los tipos del plugin. El plugin acepta más claves; consulta
-- la wiki de obsidian.nvim para el detalle completo.

---@class nyabsidian.Note
---@field id string
---@field title string|? Título legible de la nota.
---@field aliases string[]
---@field tags string[]
---@field contents string[]
---@field metadata table
---@field path string|?
---@field has_frontmatter boolean|?
---@field frontmatter_end_line integer|?
---@field add_alias fun(self: nyabsidian.Note, alias: string)

---@class nyabsidian.FrontmatterOpts
---@field enabled? boolean|fun(fname: string|?): boolean
---@field func? fun(note: nyabsidian.Note): table<string, any>
---@field sort? string[]|fun(a: any, b: any): boolean|false

---@class nyabsidian.LinkOpts
---@field style? "wiki"|"markdown"
---@field format? "shortest"|"relative"|"absolute"
---@field auto_update? boolean

---@class nyabsidian.TemplateOpts
---@field enabled? boolean
---@field folder? string
---@field date_format? string
---@field time_format? string
---@field substitutions? table<string, string|fun(ctx: table, suffix: string|?): string|?>
---@field customizations? table<string, table>

---@class nyabsidian.DailyNotesOpts
---@field enabled? boolean
---@field folder? string
---@field date_format? string
---@field alias_format? string
---@field template? string
---@field default_tags? string[]
---@field workdays_only? boolean

---@class nyabsidian.AttachmentsOpts
---@field folder? string
---@field img_name_func? fun(): string
---@field img_text_func? fun(path: string): string
---@field confirm_img_paste? boolean

---@class nyabsidian.SearchOpts
---@field sort_by? "path"|"modified"|"accessed"|"created"|false
---@field sort_reversed? boolean
---@field max_lines? integer

---@class nyabsidian.CallbackConfig
---@field post_setup? fun()
---@field create_note? fun(note: nyabsidian.Note, opts: table)
---@field enter_note? fun(note: nyabsidian.Note)
---@field leave_note? fun(note: nyabsidian.Note)
---@field pre_write_note? fun(note: nyabsidian.Note)
---@field add_attachment? fun(path: string, ctx: table)
---@field post_set_workspace? fun(workspace: table)

---@class nyabsidian.VaultConfig
---@field frontmatter? nyabsidian.FrontmatterOpts
---@field link? nyabsidian.LinkOpts
---@field templates? nyabsidian.TemplateOpts
---@field daily_notes? nyabsidian.DailyNotesOpts
---@field attachments? nyabsidian.AttachmentsOpts
---@field note_id_func? fun(title: string|?, path: string|?): string
---@field note_path_func? fun(spec: { id: string, dir: string, title: string|? }): string
---@field callbacks? nyabsidian.CallbackConfig
---@field search? nyabsidian.SearchOpts

---@type nyabsidian.VaultConfig
return {
  --- frontmatter: activa la generación de metatags (id, aliases, tags).
  --- false: desactivado (default global). true: en todas las notas.
  --- También acepta una función por nota: enabled = function(fname) return true end.

  -- frontmatter = { enabled = true },

  --- frontmatter.func: cómo se construye el frontmatter de cada nota.
  --- Si no se define, aplica la función global de la config; esta es esa
  --- función, como ejemplo para editar por vault.

  -- frontmatter = {
  --   enabled = true,
  --   func = function(note)
  --     if note.title then
  --       note:add_alias(note.title)
  --     end
  --
  --     local out = { id = note.id, aliases = note.aliases, tags = note.tags }
  --     if note.metadata ~= nil and not vim.tbl_isempty(note.metadata) then
  --       for k, v in pairs(note.metadata) do
  --         out[k] = v
  --       end
  --     end
  --     return out
  --   end,
  -- },

  --- Otros ejemplos (claves por vault):

  -- link = { style = "markdown" },
  -- templates = { folder = "Templates" },
  -- daily_notes = { folder = "Daily", default_tags = { "diario" } },
  -- attachments = { folder = "Archivos" },
}
]]
end

--- :NyabsidianInit — buffer sin nombre con el template de .nyabsidian.
function M.nyabsidian_init()
  vim.cmd "enew"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(nyabsidian_template(), "\n"))
  -- El ftplugin de nyabsidian lo reclasifica a lua (sintaxis, stylua).
  vim.bo.filetype = "nyabsidian"
  notify "Guárdalo como .nyabsidian en el directorio que quieras tratar como vault"
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

      install_note_keymaps(ev.buf)

      local ws = require("obsidian").api.find_workspace(ev.file)
      if ws then
        set_workspace(ws)
        detach_marksman(ev.buf, ws)
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

--- El guardado automático (BufWritePre del plugin) reescribe el frontmatter
--- con un round-trip del parser YAML, que es permisivo con los flow markers
--- sin cerrar (`aliases: [` se convierte en scalar y se escribe basura
--- normalizada). Vetamos el reescritura en ese caso, igual que M.frontmatter().
local function patch_note_save()
  if state.note_save_patched then
    return
  end

  local Note = require "obsidian.note"
  local update = Note.update_frontmatter

  ---@diagnostic disable-next-line: duplicate-set-field -- overwrite intencionado
  Note.update_frontmatter = function(self, bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    if self.has_frontmatter and self.frontmatter_end_line and self.frontmatter_end_line > 1 then
      local body = vim.api.nvim_buf_get_lines(bufnr, 1, self.frontmatter_end_line - 1, false)
      if has_unclosed_flow(body) then
        notify(
          "Frontmatter malformado (flow [ { sin cerrar); no se tocó la nota",
          vim.log.levels.WARN
        )
        return false
      end
    end
    return update(self, bufnr)
  end

  state.note_save_patched = true
end

--- Cinturón de seguridad: el LSP del plugin usa Obsidian.dir como root_dir.
local function patch_lsp_start()
  local lsp = require "obsidian.lsp"
  if lsp.__nyabsidian_patched then
    return
  end

  local start = lsp.start
  ---@diagnostic disable-next-line: duplicate-set-field -- overwrite intencionado
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

  -- La detección solo al guardar un .nyabsidian (abrir el archivo no dispara).
  vim.api.nvim_create_autocmd("BufWritePost", {
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
  pcall(vim.api.nvim_del_user_command, "NyabsidianFrontmatter")
  pcall(vim.api.nvim_del_user_command, "NyabsidianInit")

  vim.api.nvim_create_user_command("NyabsidianRefresh", function()
    M.refresh { notify = true }
  end, { desc = "Refresh Nyabsidian workspaces" })

  vim.api.nvim_create_user_command("NyabsidianInfo", function()
    M.info()
  end, { desc = "Show Nyabsidian workspace info" })

  vim.api.nvim_create_user_command("NyabsidianDebug", function()
    M.debug_info()
  end, { desc = "Dump Nyabsidian LSP debug info" })

  vim.api.nvim_create_user_command("NyabsidianFrontmatter", function()
    M.frontmatter()
  end, { desc = "Regenerate note frontmatter (forced)" })

  vim.api.nvim_create_user_command("NyabsidianInit", function()
    M.nyabsidian_init()
  end, { desc = "New .nyabsidian template buffer" })
end

function M.setup()
  -- El filetype de .nyabsidian se registra en ftdetect/nyabsidian.lua para
  -- que aplique desde el arranque, sin depender de que este módulo cargue.
  -- Debe instalarse antes de que pueda arrancar el primer obsidian-ls.
  patch_lsp_server_shutdown()
  patch_note_save()
  install_workspace_switch()
  require("obsidian").setup(M.opts())

  state.initialized = true
  patch_lsp_start()
  install_runtime()

  -- Valida state, aplica configs y cubre el cwd actual.
  M.refresh()
end

--- Inicializa el módulo a demanda (lo usan los comandos registrados al
--- arranque por lzy.obsidian_cmd). Si lazy.nvim está presente, carga el plugin
--- primero para que su `config` ejecute M.setup(); si no, lo intenta directo.
function M.ensure_setup()
  if state.initialized then
    return
  end

  local ok_lazy, lazy = pcall(require, "lazy")
  if ok_lazy then
    pcall(lazy.load, { plugins = { "obsidian.nvim" } })
  end

  if not state.initialized then
    local ok, err = pcall(M.setup)
    if not ok then
      notify("No se pudo inicializar: " .. tostring(err), vim.log.levels.ERROR)
    end
  end
end

return M
