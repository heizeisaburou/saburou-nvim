-- lzy/obsidian/init.lua

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Módulo y estado
-- ─────────────────────────────────────────────────────────────────────────────

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
  cursor_link_patched = false,
  note_save_patched = false,
  backlink_escaped_pipe_patched = false,
  backlink_picker_patched = false,
  follow_link_patched = false,
  attachment_rename_patched = false,
  heading_links_patched = false,
  path_resolve_race_patched = false,
}

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Utilidades
-- ─────────────────────────────────────────────────────────────────────────────

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

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Detección de vaults
-- ─────────────────────────────────────────────────────────────────────────────

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

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Keymaps y notas
-- ─────────────────────────────────────────────────────────────────────────────

--- Extensiones de archivos que pueden pertenecer a un workspace.
local NOTE_EXTENSIONS = { "md", "markdown", "mdown", "mkdn", "mkd", "qmd", "rmd", "base" }

--- Keymaps de obsidian.nvim (buffer-local, solo en notas). Namespace
--- <leader>n*: lo expone which-key, que ya tiene "n" registrado como grupo.
local NOTE_KEYMAPS = {
  { "<leader>nn", "Obsidian new", "Obsidian: nueva nota" },
  { "<leader>nr", "Obsidian rename", "Obsidian: renombrar nota (actualiza enlaces)" },
  { "<leader>nq", "Obsidian quick_switch", "Obsidian: cambiar de nota" },
  { "<leader>nb", "Obsidian backlinks", "Obsidian: qué notas enlazan a esta" },
  { "<leader>nl", "Obsidian link_new", "Obsidian: enlazar selección a nota nueva" },
  { "<leader>nL", "Obsidian link", "Obsidian: enlazar a nota existente" },
  { "<leader>nd", "Obsidian dailies", "Obsidian: notas diarias" },
  { "<leader>nt", "Obsidian template", "Obsidian: insertar plantilla" },
  { "<leader>nT", "Obsidian tags", "Obsidian: tags del vault" },
  { "<leader>nf", "Obsidian follow_link", "Obsidian: seguir el enlace bajo el cursor" },
  { "<leader>nx", "Obsidian toggle_checkbox", "Obsidian: toggle checkbox" },
  { "<leader>np", "Obsidian paste_img", "Obsidian: pegar imagen del portapapeles" },
  { "<leader>nc", "NyabsidianCopyPath", "Nyabsidian: copiar path absoluto" },
  { "<leader>nC", "NyabsidianConvertLink", "Nyabsidian: cambiar formato del enlace" },
  { "<leader>nu", "NyabsidianFetchTitle", "Nyabsidian: usar el título de la web como etiqueta" },
  { "<leader>ns", "NyabsidianSmartCopy", "Nyabsidian: copia inteligente (código/enlace/...)" },
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

---Elimina únicamente mappings propiedad de Obsidian/Nyabsidian. Es
---importante hacerlo por `desc`: fuera de un vault, Marksman reutiliza parte
---del namespace `<leader>n*` y no debemos borrar sus mappings buffer-locales.
---@param bufnr integer
local function uninstall_note_keymaps(bufnr)
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(bufnr, "n")) do
    local desc = map.desc or ""
    if desc:find("^Obsidian") or desc:find("^Nyabsidian") then
      pcall(vim.api.nvim_buf_del_keymap, bufnr, map.lhs)
    end
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

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Persistencia de workspaces
-- ─────────────────────────────────────────────────────────────────────────────

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

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Config del vault (.nyabsidian)
-- ─────────────────────────────────────────────────────────────────────────────

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
  local plugin_overrides = vim.deepcopy(overrides)
  local custom = plugin_overrides.nyabsidian
  plugin_overrides.nyabsidian = nil

  local configured, custom_error = require("lzy.obsidian.attachments").configure(root, custom)
  if not configured then
    config_warning(vim.fs.joinpath(root, NYABSIDIAN_MARKER), custom_error)
    return {}
  end

  if vim.tbl_isempty(plugin_overrides) then
    return plugin_overrides
  end

  local ok, err = pcall(function()
    -- Validar contra los defaults del plugin dispara la deprecación de
    -- legacy_commands (true por defecto); el merge real usa Obsidian._opts
    -- (legacy_commands = false), así que aquí lo neutralizamos también.
    local copy = vim.deepcopy(plugin_overrides)
    copy.legacy_commands = false
    require("obsidian.config").normalize(copy)
  end)
  if not ok then
    require("lzy.obsidian.attachments").configure(root, nil)
    config_warning(vim.fs.joinpath(root, NYABSIDIAN_MARKER), err)
    return {}
  end

  return plugin_overrides
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Workspaces y opts
-- ─────────────────────────────────────────────────────────────────────────────

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

    -- El default de obsidian.nvim es `zettel_id`: el nombre que tecleas no
    -- llega a ser el id de la nota, solo su etiqueta, así que el enlace que se
    -- inserta acaba siendo `[[1786869003-VDUY|lo que escribiste]]`.
    --
    -- El id es el título tal cual, no su slug: "Mi Nota" -> `Mi Nota.md`. Así
    -- esta puerta y la de crear desde un enlace ya escrito
    -- (`lzy.obsidian.new_note.create`, verbatim desde siempre) producen el
    -- mismo nombre. Solo afecta a notas nuevas.
    note_id_func = require("lzy.obsidian.new_note").verbatim_id,

    -- Default de obsidian.nvim es { " ", "~", "!", ">", "x" }: pone "~"
    -- justo después de "[ ]", antes que "x". Poco natural para toggle
    -- normal ([ ] -> [x]); "x" va segundo, igual que en marksman
    -- (lzy.marksman: CHECKBOX_STATES).
    checkbox = {
      order = { " ", "x", "~", "!", ">" },
    },

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

        -- Campos de mantenimiento: se rellenan al crear y **no se pisan**.
        -- Quien los mueve después es scripts/frontmatter.py del propio vault,
        -- en el pre-commit: sube `version` y `updated` de lo que cambió.
        -- `reviewed` no lo toca nadie automáticamente: es criterio propio.
        local hoy = os.date "%Y-%m-%d"
        if out.updated == nil or out.updated == "" then
          out.updated = hoy
        end
        if out.version == nil or out.version == "" then
          out.version = 1
        end
        if out.reviewed == nil or out.reviewed == "" then
          out.reviewed = hoy
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

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Conmutación LSP (marksman <-> obsidian-ls)
-- ─────────────────────────────────────────────────────────────────────────────
--
-- Reglas:
--   - Buffer EN un vault (tiene .obsidian/.nyabsidian por parents): marksman
--     sobra → enter_vault() lo desconecta/detiene; obsidian-ls gestiona el
--     buffer.
--   - Buffer FUERA de un vault (p.ej. se borró el .nyabsidian y se lanzó
--     NyabsidianRefresh): obsidian-ls se desconecta y marksman toma el
--     relevo; nunca se queda un .md sin LSP → leave_vault().
--
-- marksman está registrado globalmente (lzy.lspconfig) con root_dir que
-- devuelve nil en vaults; aquí solo se maneja lo que ese root_dir no cubre:
-- clients ya arrancados y buffers que cambian de estado en runtime.

--- Normaliza un root de workspace (string o Path) a string con separador
--- consistente. El normalize() del módulo solo acepta strings.
---@param root string|Path
---@return string
local function root_str(root)
  return vim.fs.normalize(tostring(root))
end

--- El root de marksman puede ser un string o nil.
---@param client vim.lsp.Client
---@return string|?
local function marksman_root(client)
  local cfg = client.config
  if not cfg or not cfg.root_dir then
    return nil
  end
  return root_str(cfg.root_dir)
end

--- El buffer entra en un vault: marksman sobra en notas de vault. El root_dir
--- de marksman ya bloquea su arranque en vaults; esto cubre clients ya
--- arrancados (p.ej. al crear el marker .nyabsidian en la misma sesión).
---@param bufnr integer
---@param root string|Path Root del vault (workspace root).
local function enter_vault(bufnr, root)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  root = root_str(root)
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, name = "marksman" }) do
    local client_root = marksman_root(client)
    if client_root and (client_root == root or client_root:sub(1, #root + 1) == root .. "/") then
      -- Sirve a este vault: se detiene del todo.
      client:stop(true)
    else
      -- Sirve a otro proyecto: solo se desconecta de este buffer.
      pcall(vim.lsp.buf_detach_client, bufnr, client.id)
    end
  end
end

--- El buffer deja de estar en un vault: obsidian-ls se desconecta y marksman
--- toma el relevo para no dejar el .md sin LSP. Idempotente.
---@param bufnr integer
local function leave_vault(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  -- obsidian-ls ya no gestiona este buffer (el client puede seguir vivo para
  -- otras notas del vault).
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr, name = "obsidian-ls" }) do
    pcall(vim.lsp.buf_detach_client, bufnr, client.id)
  end

  local ft = vim.bo[bufnr].filetype
  if ft ~= "markdown" and ft ~= "markdown.mdx" then
    return
  end

  local marksman_clients = vim.lsp.get_clients { bufnr = bufnr, name = "marksman" }
  if #marksman_clients > 0 then
    -- Si Obsidian había pisado `<leader>nb`/`<leader>nf` antes de descubrir
    -- que este buffer está fuera del vault, el LSP ya adjunto no volverá a
    -- disparar LspAttach. Reinstalar es idempotente y repara el buffer ahora.
    require("lzy.marksman").on_attach(marksman_clients[1], bufnr)
    return
  end

  -- marksman puede no estar configurado (p.ej. harness headless sin
  -- lzy.lspconfig): en ese caso no hay nada que arrancar.
  -- En 0.12 vim.lsp.config es un índice; la forma llamable es la de registro.
  local config = vim.lsp.config["marksman"]
  if not config then
    local ok, cfg = pcall(vim.lsp.config, "marksman")
    config = ok and cfg or nil
  end
  if not config then
    return
  end

  -- vim.lsp.start() NO resuelve root_dir funcref (eso solo lo hace el camino
  -- de vim.lsp.enable): pasarle el config registrado tal cual crearía un client
  -- con root_dir de tipo function (nunca reutilizable, rompe checkhealth con
  -- E729). Se resuelve igual que nvim (lsp.lua _enabled_configs): on_dir + copy.
  local function start_marksman(resolved)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end
    -- El camino normal (FileType) puede haber arrancado marksman mientras el
    -- root_dir se resolvía; vim.lsp.start reutiliza por name+root igualmente.
    local ok, err = pcall(vim.lsp.start, resolved, { bufnr = bufnr })
    if not ok then
      vim.notify_once(
        ("No se pudo arrancar marksman para el buffer: %s"):format(tostring(err)),
        vim.log.levels.WARN,
        { title = "Nyabsidian" }
      )
    end
  end

  config = vim.deepcopy(config)
  if type(config.root_dir) == "function" then
    config.root_dir(bufnr, function(root)
      config.root_dir = root
      vim.schedule(function()
        start_marksman(config)
      end)
    end)
    return
  end
  start_marksman(config)
end

--- Líneas de resumen LSP del buffer para NyabsidianDebug.
---@param bufnr integer
---@return string[]
local function summary(bufnr)
  local lines = {}
  table.insert(
    lines,
    "obsidian-ls on buffer: " .. #vim.lsp.get_clients { bufnr = bufnr, name = "obsidian-ls" }
  )
  table.insert(
    lines,
    "marksman on buffer: " .. #vim.lsp.get_clients { bufnr = bufnr, name = "marksman" }
  )
  table.insert(lines, "all LSP on buffer: " .. vim.inspect(vim.tbl_map(function(client)
    return client.name
  end, vim.lsp.get_clients { bufnr = bufnr })))
  return lines
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

  -- Obsidian puede haber instalado tanto su `<CR>` como todo `<leader>n*`
  -- durante FileType/BufEnter. Si permanecen fuera del vault, pisan los
  -- backlinks/follow de Marksman y ejecutan comandos contra el dummy vault.
  uninstall_note_keymaps(bufnr)

  -- Fuera del vault ya no aplica "esta nota no existe": lo limpia igual que
  -- BufUnload, por si el buffer sigue cargado (p.ej. se borró .nyabsidian
  -- sin cerrar el archivo).
  require("lzy.obsidian.diagnostics").clear(bufnr)

  -- Fuera del vault: obsidian-ls se desconecta y marksman toma el relevo.
  leave_vault(bufnr)
end

---@param bufnr integer
---@return boolean
local function has_obsidian_bufenter(bufnr)
  local ok, autocmds = pcall(vim.api.nvim_get_autocmds, {
    group = "obsidian_setup",
    event = "BufEnter",
    buffer = bufnr,
  })
  return ok and #autocmds > 0
end

---Repara un buffer cuya lectura/FileType ocurrió antes de que lazy.nvim
---instalase los autocmds de obsidian.nvim o Treesitter (caso típico al
---restaurar varias ventanas mediante `:restart source session`).
---@param bufnr integer
---@param ws obsidian.Workspace
---@param select_workspace boolean|?
local function rehydrate_vault_buffer(bufnr, ws, select_workspace)
  if not vim.api.nvim_buf_is_valid(bufnr) or not vim.api.nvim_buf_is_loaded(bufnr) then
    return
  end
  local ft = vim.bo[bufnr].filetype
  if ft ~= "markdown" and ft ~= "quarto" then
    return
  end

  install_note_keymaps(bufnr)
  local missing_bufenter = not has_obsidian_bufenter(bufnr)
  local missing_runtime = vim.b[bufnr].obsidian_buffer ~= true
    or #vim.lsp.get_clients { bufnr = bufnr, name = "obsidian-ls" } == 0
  if select_workspace ~= false and (missing_bufenter or missing_runtime) then
    set_workspace(ws)
  end
  enter_vault(bufnr, ws.root)

  -- obsidian.nvim crea sus BufEnter/BufWrite autocmds desde FileType. Si el
  -- FileType precedió a la carga lazy del plugin, hay que registrar esa capa
  -- una vez para este buffer antes de poder ejecutar su entrada.
  if missing_bufenter then
    pcall(vim.api.nvim_exec_autocmds, "FileType", {
      group = "obsidian_setup",
      buffer = bufnr,
      modeline = false,
    })
  end

  if missing_runtime then
    pcall(vim.api.nvim_exec_autocmds, "BufEnter", {
      group = "obsidian_setup",
      buffer = bufnr,
      modeline = false,
    })
  end

  -- El highlighter también se instala desde FileType en esta configuración.
  -- start() es idempotente y cubre los buffers restaurados antes de ese hook.
  pcall(vim.treesitter.start, bufnr)
end

--- Sincroniza el estado global con el buffer actual. Si el buffer no pertenece
--- a ningún workspace, usa el workspace del cwd; si tampoco existe, dummy.
local function sync_current_context()
  local bufnr = vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_get_name(bufnr)
  local ws = name ~= "" and require("obsidian").api.find_workspace(name) or nil

  if ws then
    set_workspace(ws)
    enter_vault(bufnr, ws.root)
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
  -- reset_obsidian_buffer() deja el LSP a leave_vault(): obsidian-ls fuera,
  -- marksman dentro (no se queda un .md sin LSP).
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

  -- Rehidrata todas las notas cargadas, no solo las de roots recién añadidos.
  -- En una sesión restaurada `make_opts()` ya conoce los roots antes del
  -- primer refresh, por lo que comparar solo roots añadidos dejaba algunos
  -- buffers sin autocmds, LSP, footer ni Treesitter.
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local name = vim.api.nvim_buf_get_name(bufnr)
      local ws = name ~= "" and obsidian.api.find_workspace(name) or nil
      if ws then
        rehydrate_vault_buffer(bufnr, ws)
      end
    end
  end

  -- El bucle anterior cambia el workspace global para preparar cada buffer;
  -- termina restaurando el correspondiente a la ventana actual.
  sync_current_context()
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Comandos
-- ─────────────────────────────────────────────────────────────────────────────

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
  table.insert(out, "cursor_link_patched: " .. tostring(state.cursor_link_patched))
  table.insert(out, "follow_link_patched: " .. tostring(state.follow_link_patched))
  table.insert(out, "attachment_rename_patched: " .. tostring(state.attachment_rename_patched))
  table.insert(out, "heading_links_patched: " .. tostring(state.heading_links_patched))
  table.insert(out, "backlink_picker_patched: " .. tostring(state.backlink_picker_patched))

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

  for _, line in ipairs(summary(b)) do
    table.insert(out, line)
  end

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

--- Template de .nyabsidian para NyabsidianMake.
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

---@class nyabsidian.AttachmentPathOpts
---@field vault? "preserve"|"simplify" Cómo reescribir referencias a archivos dentro del vault.
---@field external? "preserve"|"absolute" Cómo reescribir referencias a archivos fuera del vault.

---@class nyabsidian.OwnOpts
---@field attachment_paths? nyabsidian.AttachmentPathOpts Políticas propias; no pertenecen a obsidian.nvim.

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
---@field nyabsidian? nyabsidian.OwnOpts Opciones exclusivas de esta integración.

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
  --
  --     local hoy = os.date "%Y-%m-%d"
  --     out.updated = out.updated or hoy
  --     out.version = out.version or 1
  --     out.reviewed = out.reviewed or hoy
  --     return out
  --   end,
  -- },

  --- Otros ejemplos (claves por vault):

  -- link = { style = "markdown" },
  -- templates = { folder = "Templates" },
  -- daily_notes = { folder = "Daily", default_tags = { "diario" } },
  -- attachments = { folder = "Archivos" },

  --- Opciones propias de Nyabsidian, no de obsidian.nvim. Ambas usan
  --- "preserve" por defecto: cada referencia conserva su clase original
  --- (absoluta, file://, relativa a la nota, relativa al vault o basename).
  -- nyabsidian = {
  --   attachment_paths = {
  --     vault = "preserve",    -- "preserve" | "simplify" (usa link.format)
  --     external = "preserve", -- "preserve" | "absolute"
  --   },
  -- },
}
]]
end

--- :NyabsidianMake — buffer sin nombre con el template de .nyabsidian.
function M.nyabsidian_make()
  vim.cmd "enew"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(nyabsidian_template(), "\n"))
  -- El ftplugin de nyabsidian lo reclasifica a lua (sintaxis, stylua).
  vim.bo.filetype = "nyabsidian"
  notify "Guárdalo como .nyabsidian en el directorio que quieras tratar como vault"
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Instalación
-- ─────────────────────────────────────────────────────────────────────────────

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
        install_note_keymaps(ev.buf)
        set_workspace(ws)
        enter_vault(ev.buf, ws.root)
        -- Este callback puede ejecutarse antes que el BufEnter buffer-local de
        -- obsidian.nvim. Comprobarlo en el siguiente tick permite que el flujo
        -- normal termine primero y solo repara los buffers restaurados que se
        -- quedaron sin su FileType/BufEnter durante `rs`.
        vim.schedule(function()
          if
            vim.api.nvim_buf_is_valid(ev.buf)
            and vim.api.nvim_buf_is_loaded(ev.buf)
            and vim.api.nvim_get_current_buf() == ev.buf
          then
            local current_ws = require("obsidian").api.find_workspace(
              vim.api.nvim_buf_get_name(ev.buf)
            )
            if current_ws then
              rehydrate_vault_buffer(ev.buf, current_ws)
            end
          end
        end)
      else
        reset_obsidian_buffer(ev.buf)
        set_workspace(workspace_for(cwd()) or dummy_workspace())
      end
    end,
  })
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Parches a obsidian.nvim
-- ─────────────────────────────────────────────────────────────────────────────

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

--- Los backlinks se buscan con rg y términos literales del tipo `[[%s|`
--- (pipe normal). Los enlaces wiki escritos con el pipe escapado (`[[target\|...]]`)
--- —habitual en filas de tablas Markdown— nunca se encuentran, así que no
--- generan backlinks. Se añaden a get_reference_paths() las variantes con `\`
--- para que el término `[[target\|` matchee esos enlaces (en rename también
--- ayuda a localizarlos).
local function patch_backlink_escaped_pipe()
  if state.backlink_escaped_pipe_patched then
    return
  end

  local Note = require "obsidian.note"
  local get_reference_paths = Note.get_reference_paths

  ---@diagnostic disable-next-line: duplicate-set-field -- overwrite intencionado
  Note.get_reference_paths = function(self, opts)
    local refs = get_reference_paths(self, opts)
    local escaped = {}
    for _, ref in ipairs(refs) do
      escaped[#escaped + 1] = ref .. "\\"
    end
    return vim.list_extend(refs, escaped)
  end

  state.backlink_escaped_pipe_patched = true
end

--- Race condition en obsidian.nvim: al escribir
--- `[[algo` se dispara una búsqueda async (rg+fd) por todo el vault, y cada
--- match pasa por `Path.resolve{strict=true}` (`obsidian/path.lua`), que hace
--- `vim.uv.fs_realpath` síncrono y lanza un error duro si el archivo no
--- existe *justo* en ese instante. El callback que procesa esos matches
--- (`search/init.lua`: `dedup_send` y los matches de `find_async`/
--- `search_async`) viene del callback crudo de `vim.system`, fuera de
--- cualquier pcall nuestro — si cae justo en la ventana de milisegundos en
--- la que `:write` está haciendo su baile de backup/rename sobre ese mismo
--- archivo, el archivo "desaparece" un instante y el plugin revienta con un
--- FileNotFoundError que ningún pcall de por aquí puede atrapar.
---
--- IMPORTANTE (versión revisada -- la primera que se probó acá, con
--- reintentos y `uv.sleep`, no sirve): el traceback muestra el callback
--- del job anidado DENTRO de la pila de `:write` (`write.lua` ->
--- `nvim_exec2` -> `system:244` -> ... -> `resolve`). Todo corre en el
--- mismo hilo; `:write` está *pausado* esperando a que este callback
--- devuelva el control, no corriendo en paralelo. El paso que "hace
--- reaparecer" el archivo (rescribir el contenido nuevo sobre el nombre
--- original, después de haberlo movido a un backup) es el siguiente paso
--- de ese mismo `:write` -- no puede ocurrir mientras estemos bloqueados
--- en un sleep esperándolo, porque literalmente está esperándonos a
--- nosotros. Reintentar con retraso no cambia nada: se agota el margen y
--- se sigue lanzando igual, solo que unos ms más tarde.
---
--- La solución real no depende de que pase el tiempo: `Path.resolve` YA
--- tiene, en la propia rama no-strict (dos líneas más abajo en
--- `path.lua`), un fallback correcto para "el archivo no existe pero su
--- directorio sí": recorre hacia arriba hasta un padre que resuelva, y
--- reconstruye la ruta desde ahí. Para nuestra race eso basta de sobra --
--- el padre (la carpeta del vault) nunca desaparece, solo el archivo hoja
--- durante el rename de `:write` -- así que ese mismo fallback reconstruye
--- la ruta absoluta correcta al toque, sin esperar nada. Lo único que hace
--- `strict=true` distinto es negarse a usar ese fallback y explotar en su
--- lugar. Así que: si falla el intento estricto, reintentamos la MISMA
--- función original pero en modo no-strict (cero código nuevo de
--- resolución, cero riesgo de que se desvíe del comportamiento ya
--- probado del plugin) y usamos ese resultado. Solo en el caso límite en
--- que ni siquiera un padre resuelve (todo el árbol de verdad no existe:
--- vault mal configurado, etc.) seguimos lanzando el error original --
--- ahí sí es una señal real, no la race.
---
--- No podemos interceptar `dedup_send` directamente (es un local de
--- search/init.lua), pero `Path.resolve` es el único punto de despacho que
--- comparten todos los callers de `resolve{strict=true}`: `Path.__index`
--- hace `rawget(Path, k)` contra la tabla que devuelve
--- `require("obsidian.path")` (cacheada por Lua), así que reasignar el
--- método acá se propaga a *todo* el plugin sin tocar un solo archivo del
--- vendor.
local function patch_path_resolve_race()
  if state.path_resolve_race_patched then
    return
  end

  local Path = require "obsidian.path"
  local resolve = Path.resolve

  ---@param self obsidian.Path
  ---@param opts { strict: boolean }|?
  ---@diagnostic disable-next-line: duplicate-set-field -- overwrite intencionado
  Path.resolve = function(self, opts)
    local ok, result = pcall(resolve, self, opts)
    if ok then
      return result
    end

    -- El original solo lanza cuando opts.strict es true; si igual llegamos
    -- acá con strict=false/nil, no es esta race: propagamos el error tal
    -- cual, sin tocar el comportamiento original.
    if not (opts and opts.strict) then
      error(result, 0)
    end

    -- Mismo resolve original, pidiéndole su propio fallback no-strict
    -- (parent traversal) en vez del error duro. Esa rama nunca lanza --
    -- si ni el archivo ni ningún padre resuelven, devuelve `self` tal
    -- cual (la MISMA referencia, sin crear un Path nuevo) en vez de
    -- fallar. Por eso NO alcanza con comparar `soft_result.filename`
    -- contra `self.filename`: cuando sí hay padre y se reconstruye la
    -- ruta, el string reconstruido suele ser idéntico al original (no
    -- había nada que normalizar de por medio), así que un string-compare
    -- confunde "reconstruyó la misma ruta" con "no reconstruyó nada".
    -- `rawequal` sí distingue: identidad de tabla, no de contenido, y
    -- solo la rama de fallo total devuelve la referencia sin tocar.
    local ok_soft, soft_result = pcall(resolve, self, { strict = false })
    if ok_soft and not rawequal(soft_result, self) then
      -- Encontró un padre real (o el propio archivo) y construyó un Path
      -- nuevo desde ahí: es exactamente el caso "el archivo desapareció
      -- un instante pero su carpeta sigue ahí". Nos quedamos con eso.
      return soft_result
    end

    -- Ni el propio archivo ni ningún padre resuelven: el fallback
    -- no-strict devolvió `self` tal cual (falla total, no una race
    -- transitoria). Ahí sí es el error real que el `strict=true` original
    -- estaba señalizando.
    error(result, 0)
  end

  state.path_resolve_race_patched = true
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

-- ─────────────────────────────────────────────────────────────────────────────
-- ― Arranque
-- ─────────────────────────────────────────────────────────────────────────────

local function install_runtime()
  local group = vim.api.nvim_create_augroup("nyabsidian", { clear = true })

  vim.api.nvim_create_autocmd("DirChanged", {
    group = group,
    callback = function()
      M.refresh()
    end,
  })

  vim.api.nvim_create_autocmd("SessionLoadPost", {
    group = group,
    callback = function()
      -- `:restart source session` puede restaurar varios buffers después del
      -- setup inicial. El refresh posterior cubre todos ellos, no solo el que
      -- terminó siendo la ventana actual.
      vim.schedule(function()
        M.refresh()
      end)
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
  pcall(vim.api.nvim_del_user_command, "NyabsidianMake")
  pcall(vim.api.nvim_del_user_command, "NyabsidianCopyPath")
  pcall(vim.api.nvim_del_user_command, "NyabsidianConvertLink")
  pcall(vim.api.nvim_del_user_command, "NyabsidianFetchTitle")
  pcall(vim.api.nvim_del_user_command, "NyabsidianSmartCopy")
  pcall(vim.api.nvim_del_user_command, "NyabsidianRelink")

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

  vim.api.nvim_create_user_command("NyabsidianMake", function()
    M.nyabsidian_make()
  end, { desc = "New .nyabsidian template buffer" })

  vim.api.nvim_create_user_command("NyabsidianCopyPath", function()
    require("lzy.obsidian.link_actions").copy_path()
  end, { desc = "Copy absolute path of note or attachment" })

  vim.api.nvim_create_user_command("NyabsidianConvertLink", function()
    require("lzy.obsidian.link_actions").convert_link()
  end, { desc = "Change the path format of the link under cursor" })

  vim.api.nvim_create_user_command("NyabsidianFetchTitle", function()
    require("lzy.obsidian.link_actions").fetch_web_title()
  end, { desc = "Use the web page title as the Markdown link label" })

  vim.api.nvim_create_user_command("NyabsidianRelink", function()
    require("lzy.obsidian.relink").run()
  end, {
    desc = "Llevar todos los enlaces del vault a su forma canónica (pide confirmación)",
  })

  vim.api.nvim_create_user_command("NyabsidianSmartCopy", function()
    require("lzy.obsidian.smart_copy").smart_copy()
  end, {
    desc = "Copia según el cursor: enlace (label/target/url), negrita/cursiva, o header como [[Nota#anchor]]",
  })
end

function M.setup()
  -- El filetype de .nyabsidian se registra en ftdetect/nyabsidian.lua para
  -- que aplique desde el arranque, sin depender de que este módulo cargue.
  -- Debe instalarse antes de que pueda arrancar el primer obsidian-ls.
  require("lzy.obsidian.links").setup { notify = notify, state = state }
  require("lzy.obsidian.backlinks").setup(state)
  require("lzy.obsidian.diagnostics").setup()
  patch_lsp_server_shutdown()
  patch_note_save()
  patch_backlink_escaped_pipe()
  patch_path_resolve_race()
  install_workspace_switch()
  require("obsidian").setup(M.opts())

  state.initialized = true
  patch_lsp_start()
  install_runtime()

  -- Valida state, aplica configs y cubre el cwd actual.
  M.refresh()
end

--- Inicializa el módulo a demanda (lo usan los comandos registrados al
--- arranque por lzy.obsidian.commands). Si lazy.nvim está presente, carga el plugin
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
