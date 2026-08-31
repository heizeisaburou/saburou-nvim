-- sabunv.terminal

local M = {}
local mode = require "sabunv.mode"

--- Qué shell abren las terminales integradas.
---
---   - `"auto"`: la shell en la que estás, heredada del árbol de procesos. Si
---     no se puede averiguar, cae a `"system"`.
---   - `"system"`: `vim.o.shell` fuera de Windows; en Windows, `pwsh`,
---     Windows PowerShell y `cmd.exe`, en ese orden.
---   - Un nombre (`"pwsh"`, `"zsh"`, `"fish"`, `"cmd"`...) o un comando
---     completo (`{ "nu", "--login" }`) para forzar una concreta.
---@alias sabunv.terminal.Shell "auto"|"system"|string|string[]

---@class sabunv.terminal.Config
---@field shell? sabunv.terminal.Shell

---@class sabunv.terminal.ShellInfo
---@field preference sabunv.terminal.Shell Lo que se pidió.
---@field source "inherited"|"system"|"explicit" De dónde salió la shell final.
---@field selected string Nombre corto de la shell elegida.
---@field command string[]
---@field fallback boolean `true` si no se pudo honrar la preferencia.

-- Shells que sirven como terminal interactiva y que, por tanto, se aceptan al
-- heredar del árbol de procesos.
local interactive_shells = {
  bash = true,
  cmd = true,
  csh = true,
  elvish = true,
  fish = true,
  ksh = true,
  mksh = true,
  nu = true,
  nushell = true,
  osh = true,
  powershell = true,
  pwsh = true,
  tcsh = true,
  xonsh = true,
  zsh = true,
}

-- Shells que existen sobre todo como intérprete de scripts. Heredarlas sería
-- un error casi siempre: si Neovim se lanza desde el `sh -c` de un `.desktop`,
-- de un Makefile o de `xargs`, `/bin/sh` no es la terminal que quieres. Solo se
-- aceptan cuando además son tu shell de login, es decir, cuando de verdad las
-- usas.
local script_shells = {
  ash = true,
  dash = true,
  sh = true,
}

---@type sabunv.terminal.ShellInfo?
local shell_info

-- -----------------------------------------------------------------------------
-- Terminal state
-- -----------------------------------------------------------------------------

local terminals = {
  horizontal = {
    buf = nil,
    win = nil,
    job = nil,
    name = "sbnv_horizontal_terminal",
  },

  vertical = {
    buf = nil,
    win = nil,
    job = nil,
    name = "sbnv_vertical_terminal",
  },

  float = {
    buf = nil,
    win = nil,
    job = nil,
    name = "sbnv_floating_terminal",
    origin = nil,
  },
}

-- -----------------------------------------------------------------------------
-- Helpers
-- -----------------------------------------------------------------------------

local function is_windows()
  if hzsr and hzsr.sys and hzsr.sys.iswin ~= nil then
    return hzsr.sys.iswin
  end

  local sysname = vim.uv.os_uname().sysname:lower()
  return sysname:find("windows", 1, true) ~= nil or sysname:find("mingw", 1, true) ~= nil
end

---@param name string
---@return string?
local function executable_path(name)
  local path = vim.fn.exepath(name)
  if path == "" then
    path = vim.fn.exepath(name .. ".exe")
  end
  return path ~= "" and path or nil
end

---@return string[]
local function cmd_command()
  local comspec = vim.env.COMSPEC
  if comspec and comspec ~= "" then
    return { comspec }
  end

  return { executable_path "cmd" or "cmd.exe" }
end

--- Nombre corto y comparable de un ejecutable: sin ruta, sin `.exe`, en
--- minúsculas.
---@param name string
---@return string
local function short_name(name)
  return (vim.fs.basename(name):lower():gsub("%.exe$", ""))
end

--- Argumentos con los que arrancar una shell como terminal interactiva.
---@param name string Nombre corto de la shell.
---@param path string
---@return string[]
local function shell_command(name, path)
  if name == "pwsh" or name == "powershell" then
    -- Una terminal interactiva debe cargar el perfil del usuario.
    return { path, "-NoLogo" }
  end

  return { path }
end

--- La shell de `vim.o.shell`, ya troceada en comando y argumentos.
---@return string[]?
local function shell_option_command()
  local shell = vim.o.shell
  if shell == "" then
    return nil
  end

  -- `\'shell\'` admite argumentos, pero una ruta con espacios también es legal.
  -- Si la cadena entera es ejecutable, es una ruta y no se parte.
  if vim.fn.executable(shell) == 1 then
    return { shell }
  end

  local parts = vim.split(shell, "%s+", { trimempty = true })
  return #parts > 0 and parts or nil
end

--- La shell que elegiría la plataforma por su cuenta.
---@param preference sabunv.terminal.Shell
---@return sabunv.terminal.ShellInfo
local function system_shell(preference)
  if is_windows() then
    for _, name in ipairs { "pwsh", "powershell" } do
      local path = executable_path(name)
      if path then
        return {
          preference = preference,
          source = "system",
          selected = name,
          command = shell_command(name, path),
          fallback = false,
        }
      end
    end

    local command = cmd_command()
    return {
      preference = preference,
      source = "system",
      selected = "cmd",
      command = command,
      fallback = false,
    }
  end

  local command = shell_option_command()

  return {
    preference = preference,
    source = "system",
    selected = command and short_name(command[1]) or "system",
    command = command or { "/bin/sh" },
    fallback = false,
  }
end

--- La shell en la que se está ejecutando Neovim, buscada hacia arriba en el
--- árbol de procesos.
---
--- `$SHELL` no sirve para esto: es la shell de login y ninguna shell la
--- reescribe al arrancar, así que abrir pwsh desde zsh la deja diciendo zsh.
---@return string? name
---@return string? path
local function inherited_shell()
  local proc = require "hzsr.sys.proc"
  if not proc.available() then
    return nil
  end

  local login = short_name(vim.env.SHELL or "")

  for _, ancestor in ipairs(proc.ancestors()) do
    local name = short_name(ancestor.name)

    if interactive_shells[name] or (script_shells[name] and name == login) then
      -- `path` falta cuando el antepasado es de otro usuario (`sudo`); en ese
      -- caso el nombre basta para volver a encontrarlo en el `PATH`.
      return name, ancestor.path or executable_path(name)
    end
  end
end

---@param preference sabunv.terminal.Shell
---@return sabunv.terminal.ShellInfo
local function resolve_shell(preference)
  -- Un comando completo se respeta tal cual: quien lo escribe sabe lo que
  -- quiere, incluidos los argumentos.
  if type(preference) == "table" then
    return {
      preference = preference,
      source = "explicit",
      selected = short_name(preference[1]),
      command = vim.deepcopy(preference),
      fallback = false,
    }
  end

  if preference == "auto" then
    local name, path = inherited_shell()
    if name and path then
      return {
        preference = preference,
        source = "inherited",
        selected = name,
        command = shell_command(name, path),
        fallback = false,
      }
    end

    -- Sin árbol de procesos consultable (Windows) o sin ninguna shell entre los
    -- antepasados (Neovim lanzado desde un lanzador gráfico): no es un fallo,
    -- es que no hay nada que heredar.
    return system_shell(preference)
  end

  if preference == "system" then
    return system_shell(preference)
  end

  local name = short_name(preference)
  local path = executable_path(preference)

  if path then
    return {
      preference = preference,
      source = "explicit",
      selected = name,
      command = shell_command(name, path),
      fallback = false,
    }
  end

  -- Se pidió una shell que no está instalada: se avisa y se sigue con lo que
  -- haya, porque quedarse sin terminal es peor.
  local info = system_shell(preference)
  info.fallback = true
  return info
end

---@return sabunv.terminal.ShellInfo
local function current_shell()
  if not shell_info then
    shell_info = resolve_shell "auto"
  end
  return shell_info
end

---@param command string|string[]
---@return string
local function command_text(command)
  return type(command) == "table" and table.concat(command, " ") or command
end

local function create_terminal_buffer(term)
  local buf = vim.api.nvim_create_buf(false, true)

  vim.api.nvim_buf_set_name(buf, term.name)
  vim.b[buf].sbnv_terminal = true

  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = buf })
  vim.api.nvim_set_option_value("buflisted", false, { buf = buf })

  return buf
end

local function ensure_terminal_buffer(term)
  if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
    return
  end

  term.buf = create_terminal_buffer(term)
end

local function start_terminal_job(term)
  if term.job then
    return
  end

  vim.api.nvim_buf_call(term.buf, function()
    local info = current_shell()
    local job = vim.fn.jobstart(info.command, {
      term = true,
      on_exit = function()
        term.job = nil
      end,
    })

    if job <= 0 then
      term.job = nil
      vim.notify(
        "No se pudo iniciar la terminal: " .. command_text(info.command),
        vim.log.levels.ERROR,
        { title = "Terminal" }
      )
      return
    end

    term.job = job
  end)
end

local function hide_terminal_window(term)
  vim.api.nvim_win_hide(term.win)
  term.win = nil
end

local function is_window_open(term)
  return term.win and vim.api.nvim_win_is_valid(term.win)
end

local function enter_terminal()
  vim.cmd "startinsert"
end

-- -----------------------------------------------------------------------------
-- Split terminals
-- -----------------------------------------------------------------------------

local function open_horizontal_window(term)
  vim.cmd "split"
  term.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term.win, term.buf)
end

local function open_vertical_window(term)
  vim.cmd "vsplit"
  term.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term.win, term.buf)
end

local function toggle_split(term, open_window)
  if is_window_open(term) then
    hide_terminal_window(term)
    return
  end

  ensure_terminal_buffer(term)
  open_window(term)
  start_terminal_job(term)
  enter_terminal()
end

-- -----------------------------------------------------------------------------
-- Configuration
-- -----------------------------------------------------------------------------

---@param preference any
---@return string
local function preference_text(preference)
  return type(preference) == "table" and command_text(preference) or tostring(preference)
end

---@param opts? sabunv.terminal.Config
function M.setup(opts)
  opts = opts or {}
  assert(type(opts) == "table", "terminal: la configuración debe ser una tabla")

  local preference = opts.shell or "auto"
  assert(
    type(preference) == "string" and preference ~= ""
      or type(preference) == "table" and type(preference[1]) == "string",
    "terminal.shell debe ser 'auto', 'system', el nombre de una shell o un comando completo"
  )

  shell_info = resolve_shell(preference)

  if shell_info.fallback then
    local notify = vim.notify
    local message = ("No se encontró %s; se usará %s"):format(
      preference_text(preference),
      shell_info.selected
    )
    vim.schedule(function()
      notify(message, vim.log.levels.WARN, { title = "Terminal" })
    end)
  end

  vim.api.nvim_create_user_command("TerminalInfo", function()
    local info = current_shell()
    local sources = {
      inherited = "heredada del proceso padre",
      system = "la que elige el sistema",
      explicit = "fijada en la configuración",
    }

    vim.notify(
      table.concat({
        "preferencia: " .. preference_text(info.preference),
        "resuelta:    " .. info.selected .. " (" .. sources[info.source] .. ")",
        "comando:     " .. command_text(info.command),
      }, "\n"),
      vim.log.levels.INFO,
      { title = "Terminal" }
    )
  end, {
    force = true,
    desc = "Mostrar la shell usada por las terminales integradas",
  })
end

---@return sabunv.terminal.ShellInfo
function M.info()
  return vim.deepcopy(current_shell())
end

function M.open_horizontal_split()
  toggle_split(terminals.horizontal, open_horizontal_window)
end

function M.open_vertical_split()
  toggle_split(terminals.vertical, open_vertical_window)
end

-- -----------------------------------------------------------------------------
-- Floating terminal
-- -----------------------------------------------------------------------------

local function open_float_window(term)
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  term.win = vim.api.nvim_open_win(term.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "single",
    title = "  Terminal ",
    title_pos = "center",
  })

  vim.api.nvim_set_option_value(
    "winhighlight",
    "Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle",
    { win = term.win }
  )
end

function M.toggle_float()
  local term = terminals.float

  if is_window_open(term) then
    local origin = term.origin
    hide_terminal_window(term)
    term.origin = nil
    mode.restore(origin)
    return
  end

  term.origin = mode.capture()
  ensure_terminal_buffer(term)
  open_float_window(term)
  start_terminal_job(term)
  enter_terminal()
end

return M
