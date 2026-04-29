-- lzy/l_bufferline

local M = {}

local plugin = require "bufferline"
local groups = require "bufferline.groups"

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------

---@type boolean
local is_setup = false

---@type bufferline.UserConfig?
local active_config = nil

-- -----------------------------------------------------------------------------
-- Manual groups state
--
-- En `mode = "buffer"`, las "tabs" visibles de bufferline NO son tabpages reales
-- de Neovim: son buffers renderizados como pestañas por el plugin.
--
-- Bufferline puede operar sobre grupos (`BufferLineGroupToggle`,
-- `BufferLineGroupClose`), pero esos grupos se definen normalmente en la config
-- mediante `groups.items` + `matcher`.
--
-- Para la alfa usamos una capa rápida de grupos dinámicos:
--
--   manual_buffer_groups[bufnr] = group_name
--
-- Cuando aparece un grupo nuevo, regeneramos `options.groups` y reejecutamos
-- `bufferline.setup()`.
--
-- Limitación:
--   este estado vive sólo en memoria. No sobrevive a reinicios.
--
-- Diseño futuro:
--   integrar estos grupos con persistencia/session state, guardando al menos:
--
--     - buffers abiertos;
--     - orden visual de bufferline;
--     - grupo asignado por buffer;
--     - grupo oculto/visible;
--     - buffer actual.
-- -----------------------------------------------------------------------------

---@type table<integer, string>
local manual_buffer_groups = {}

---@type string[]
local manual_group_names = {}

-- -----------------------------------------------------------------------------
-- Buffer close integration
-- -----------------------------------------------------------------------------

local function close_method(bufnr)
  return hzsr.async.run(function()
    return sabunv.edt.io.close_buffer_replace(bufnr)
  end)
end

-- -----------------------------------------------------------------------------
-- Base options
-- -----------------------------------------------------------------------------

local opts = {
  show_tab_indicators = true,
  diagnostics = true,
  mode = "buffer",
  style_preset = plugin.style_preset.no_italic,
  themable = true,
  numbers = "none",

  hover = {
    enabled = true,
    reveal = {},
    delay = 200,
  },

  diagnostics_indicator = function(count, level, diagnostics_dict, context)
    local icon = level:match "error" and " " or " "
    return " " .. icon .. count
  end,

  close_command = close_method,
  right_mouse_command = close_method,

  groups = {
    options = {
      toggle_hidden_on_enter = true,
    },
    items = {
      groups.builtin.ungrouped,
    },
  },

  custom_filter = function(bufnr)
    local buftype = vim.bo[bufnr].buftype
    local name = vim.api.nvim_buf_get_name(bufnr)

    -- Oculta terminales de Claude Code.
    if buftype == "terminal" and name:match "claude" then
      return false
    end

    return true
  end,
}

---@type bufferline.UserConfig
M.config = {
  options = opts,
  highlights = {},
}

-- -----------------------------------------------------------------------------
-- Theme config
--
-- `sabunv.moonfly.setup.bufferline()` prepara la config visual en:
--
--   sabunv.moonfly.bufferline.config()
--
-- Este módulo no genera colores. Sólo mezcla:
--
--   1. configuración funcional base de lzy.l_bufferline;
--   2. configuración visual preparada por sabunv.moonfly.
-- -----------------------------------------------------------------------------

---@return bufferline.UserConfig
local function theme_config()
  if not sabunv or not sabunv.moonfly or not sabunv.moonfly.bufferline then
    return {}
  end

  return sabunv.moonfly.bufferline.config()
end

---@return bufferline.UserConfig
local function build_config()
  return vim.tbl_deep_extend("force", vim.deepcopy(M.config), theme_config())
end

-- -----------------------------------------------------------------------------
-- Manual groups helpers
-- -----------------------------------------------------------------------------

local function has_group(group_name)
  for _, name in ipairs(manual_group_names) do
    if name == group_name then
      return true
    end
  end

  return false
end

local function add_group_name(group_name)
  if group_name == "" or has_group(group_name) then
    return
  end

  manual_group_names[#manual_group_names + 1] = group_name
  table.sort(manual_group_names)
end

local function group_complete()
  return vim.deepcopy(manual_group_names)
end

local function get_buf_group(bufnr)
  return manual_buffer_groups[bufnr]
end

local function make_manual_group_item(group_name, index)
  return {
    name = group_name,
    icon = "󰓩",
    priority = index,
    matcher = function(buf)
      local bufnr = buf.id or buf.bufnr

      if not bufnr then
        return false
      end

      return get_buf_group(bufnr) == group_name
    end,
  }
end

local function build_group_items()
  local items = {}

  for index, group_name in ipairs(manual_group_names) do
    items[#items + 1] = make_manual_group_item(group_name, index)
  end

  items[#items + 1] = groups.builtin.ungrouped

  return items
end

local function apply_manual_groups()
  if not active_config then
    return
  end

  active_config.options = active_config.options or {}

  active_config.options.groups = {
    options = {
      toggle_hidden_on_enter = true,
    },
    items = build_group_items(),
  }

  plugin.setup(active_config)
  pcall(plugin.refresh)
end

local function assign_current_buffer_to_group(group_name)
  if not group_name or group_name == "" then
    vim.notify("Uso: :Bga <grupo>", vim.log.levels.WARN)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  add_group_name(group_name)
  manual_buffer_groups[bufnr] = group_name
  apply_manual_groups()

  vim.notify(("Buffer %d asignado al grupo '%s'"):format(bufnr, group_name), vim.log.levels.INFO)
end

local function unassign_current_buffer_group()
  local bufnr = vim.api.nvim_get_current_buf()
  local old_group = manual_buffer_groups[bufnr]

  manual_buffer_groups[bufnr] = nil
  apply_manual_groups()

  if old_group then
    vim.notify(("Buffer %d quitado del grupo '%s'"):format(bufnr, old_group), vim.log.levels.INFO)
  else
    vim.notify(("Buffer %d no tenía grupo manual"):format(bufnr), vim.log.levels.INFO)
  end
end

local function list_manual_groups()
  local lines = {
    "Bufferline manual groups:",
    "",
  }

  if #manual_group_names == 0 then
    lines[#lines + 1] = "No hay grupos manuales."
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
    return
  end

  for _, group_name in ipairs(manual_group_names) do
    lines[#lines + 1] = ("[%s]"):format(group_name)

    local any = false

    for bufnr, assigned_group in pairs(manual_buffer_groups) do
      if assigned_group == group_name then
        any = true

        local name = vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_get_name(bufnr)
          or "<invalid>"

        if name == "" then
          name = ("<unnamed:%d>"):format(bufnr)
        end

        lines[#lines + 1] = ("  %d  %s"):format(bufnr, name)
      end
    end

    if not any then
      lines[#lines + 1] = "  <empty>"
    end

    lines[#lines + 1] = ""
  end

  vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
end

-- -----------------------------------------------------------------------------
-- Commands helpers
-- -----------------------------------------------------------------------------

local function notify_group_help()
  vim.notify(
    table.concat({
      "Bufferline group helpers:",
      "",
      ":Bg",
      "  Muestra esta ayuda.",
      "",
      ":Bga <grupo>",
      "  Asigna el buffer actual a un grupo manual. Si no existe, lo crea.",
      "",
      ":Bgu",
      "  Quita el buffer actual de su grupo manual.",
      "",
      ":Bgl",
      "  Lista grupos manuales y buffers asignados.",
      "",
      ":Bgt <grupo>",
      "  Toggle hide/show de un grupo.",
      "",
      ":Bgc <grupo>",
      "  Cierra buffers de un grupo.",
      "",
      "Comandos nativos equivalentes:",
      "  :BufferLineGroupToggle <grupo>",
      "  :BufferLineGroupClose <grupo>",
      "",
      "Debug:",
      "  :command BufferLine",
    }, "\n"),
    vim.log.levels.INFO
  )
end

---@param cmd string
---@param group_name? string
local function run_bufferline_group_cmd(cmd, group_name)
  local full_cmd = group_name and group_name ~= "" and (cmd .. " " .. group_name) or cmd
  local ok, err = pcall(vim.cmd, full_cmd)

  if not ok then
    vim.notify(tostring(err), vim.log.levels.ERROR)
  end
end

-- -----------------------------------------------------------------------------
-- User commands
-- -----------------------------------------------------------------------------

local function setup_group_commands()
  vim.api.nvim_create_user_command("Bg", function()
    notify_group_help()
  end, {})

  vim.api.nvim_create_user_command("Bga", function(opts_cmd)
    assign_current_buffer_to_group(opts_cmd.args)
  end, {
    nargs = 1,
  })

  vim.api.nvim_create_user_command("Bgu", function()
    unassign_current_buffer_group()
  end, {})

  vim.api.nvim_create_user_command("Bgl", function()
    list_manual_groups()
  end, {})

  vim.api.nvim_create_user_command("Bgt", function(opts_cmd)
    run_bufferline_group_cmd("BufferLineGroupToggle", opts_cmd.args)
  end, {
    nargs = 1,
    complete = group_complete,
  })

  vim.api.nvim_create_user_command("Bgc", function(opts_cmd)
    run_bufferline_group_cmd("BufferLineGroupClose", opts_cmd.args)
  end, {
    nargs = 1,
    complete = group_complete,
  })
end

local function setup_close_commands()
  -- Permite seleccionar qué buffer cerrar.
  vim.api.nvim_create_user_command("Bc", function()
    plugin.close_with_pick()
  end, {})

  -- Cierra el buffer actual y si está fijado lo desfija.
  vim.api.nvim_create_user_command("Bd", function()
    plugin.unpin_and_close()
  end, {})

  -- Cierra otros.
  vim.api.nvim_create_user_command("Bda", function()
    plugin.close_others()
  end, {})

  -- Cierra todos.
  vim.api.nvim_create_user_command("Bdat", function()
    plugin.close_others()
    plugin.unpin_and_close()
  end, {})

  -- Cierra todos a la derecha.
  vim.api.nvim_create_user_command("Bdr", function()
    plugin.close_in_direction "right"
  end, {})

  -- Cierra todos a la derecha y este.
  vim.api.nvim_create_user_command("Bdrt", function()
    plugin.close_in_direction "right"
    plugin.unpin_and_close()
  end, {})

  -- Cierra todos a la izquierda.
  vim.api.nvim_create_user_command("Bdl", function()
    plugin.close_in_direction "left"
  end, {})

  -- Cierra todos a la izquierda y este.
  vim.api.nvim_create_user_command("Bdlt", function()
    plugin.close_in_direction "left"
    plugin.unpin_and_close()
  end, {})
end

local function setup_commands()
  setup_group_commands()
  setup_close_commands()
end

-- -----------------------------------------------------------------------------
-- Keymaps
-- -----------------------------------------------------------------------------

local function setup_keymaps()
  local map = vim.keymap.set

  -- Moverse de tab con tabulación.
  map("n", "<Tab>", function()
    plugin.cycle(1)
  end)

  map("n", "<S-Tab>", function()
    plugin.cycle(-1)
  end)

  -- Ir al tab.
  for i = 1, 9, 1 do
    map("n", string.format("<A-%s>", i), function()
      plugin.go_to(i)
    end)
  end

  map("n", "<A-0>", function()
    plugin.go_to(10)
  end)

  -- Reordenar tabs.
  map("n", "<A-,>", function()
    plugin.move(-1)
  end)

  map("n", "<A-.>", function()
    plugin.move(1)
  end)
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

---@return boolean
function M.is_setup()
  return is_setup
end

function M.resetup()
  active_config = build_config()

  apply_manual_groups()
  plugin.setup(active_config)
  pcall(plugin.refresh)
end

---@param config true|bufferline.UserConfig|nil
function M.setup(config)
  if config == true or config == nil then
    config = build_config()
  end

  active_config = config

  apply_manual_groups()
  plugin.setup(active_config)

  is_setup = true

  setup_commands()
  setup_keymaps()
end

return M
