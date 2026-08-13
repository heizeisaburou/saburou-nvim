-- sabunv.terminal

local M = {}
local mode = require "sabunv.mode"

---@alias sabunv.terminal.WindowsShell "auto"|"pwsh"|"powershell"|"cmd"

---@class sabunv.terminal.Config
---@field windows_shell? sabunv.terminal.WindowsShell

---@class sabunv.terminal.ShellInfo
---@field preference sabunv.terminal.WindowsShell
---@field selected "pwsh"|"powershell"|"cmd"|"system"
---@field command string|string[]
---@field fallback boolean

local valid_windows_shells = {
  auto = true,
  pwsh = true,
  powershell = true,
  cmd = true,
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

---@param name "pwsh"|"powershell"|"cmd"
---@return string[]?
local function windows_command(name)
  if name == "cmd" then
    return cmd_command()
  end

  local path = executable_path(name)
  if path then
    -- Una terminal interactiva debe cargar el perfil del usuario.
    return { path, "-NoLogo" }
  end
end

---@param preference sabunv.terminal.WindowsShell
---@return sabunv.terminal.ShellInfo
local function resolve_windows_shell(preference)
  if preference == "auto" then
    local pwsh = windows_command "pwsh"
    if pwsh then
      return {
        preference = preference,
        selected = "pwsh",
        command = pwsh,
        fallback = false,
      }
    end

    local powershell = windows_command "powershell"
    if powershell then
      return {
        preference = preference,
        selected = "powershell",
        command = powershell,
        fallback = false,
      }
    end

    return {
      preference = preference,
      selected = "cmd",
      command = cmd_command(),
      fallback = false,
    }
  end

  local command = windows_command(preference)
  if command then
    return {
      preference = preference,
      selected = preference,
      command = command,
      fallback = false,
    }
  end

  return {
    preference = preference,
    selected = "cmd",
    command = cmd_command(),
    fallback = true,
  }
end

---@param preference sabunv.terminal.WindowsShell
---@return sabunv.terminal.ShellInfo
local function resolve_shell(preference)
  if is_windows() then
    return resolve_windows_shell(preference)
  end

  return {
    preference = preference,
    selected = "system",
    command = vim.o.shell,
    fallback = false,
  }
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

---@param opts? sabunv.terminal.Config
function M.setup(opts)
  opts = opts or {}
  assert(type(opts) == "table", "terminal: la configuración debe ser una tabla")

  local preference = opts.windows_shell or "auto"
  assert(valid_windows_shells[preference], "terminal.windows_shell debe ser 'auto', 'pwsh', 'powershell' o 'cmd'")

  shell_info = resolve_shell(preference)

  if shell_info.fallback then
    local notify = vim.notify
    vim.schedule(function()
      notify(("No se encontró %s; se usará cmd.exe"):format(preference), vim.log.levels.WARN, { title = "Terminal" })
    end)
  end

  vim.api.nvim_create_user_command("TerminalInfo", function()
    local info = current_shell()
    vim.notify(
      table.concat({
        "preferencia: " .. info.preference,
        "resuelta:    " .. info.selected,
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
