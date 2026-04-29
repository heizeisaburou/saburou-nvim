-- sabunv.moonfly

-- Estilos que no tuvimos que ajustar gracias a custom_colors:
--   bg: FoldColumn, SignColumn, LineNr, CursorLineNr

local M = {}

M.hl = require "sabunv.moonfly.hl"
M.persistence = require "sabunv.moonfly.persistence"
M.moonfly = require "sabunv.moonfly.moonfly"
M.nvim_tree = require "sabunv.moonfly.nvim_tree"
M.bufferline = require "sabunv.moonfly.bufferline"
M.lualine = require "sabunv.moonfly.lualine"
M.render_markdown = require "sabunv.moonfly.render_markdown"

-- -----------------------------------------------------------------------------
-- Colors
-- -----------------------------------------------------------------------------

M.colors = {
  bg = "#0c0e0f",
  alt_bg = "#060809",

  lightest_blue = "#5DDCF6",
  light_blue = "#6CCBE0",
  blue = "#74B2FF",
  medium_blue = "#4D6D9C",
  dark_blue = "#32486E",
  darkest_blue = "#1B2949",

  white = "#EDEFF0",
  darker_white = "#E2E4E5",
  lighter_gray = "#c8c8c8",
  gray = "#949494",
  medium_gray = "#505456",
  dark_gray = "#282B2D",
  darker_gray = "#1E2123",
  darkest_gray = "#131618",

  yellow = "#ECD28B",
  medium_yellow = "#b09a5d",

  red = "#DF5B61",
  medium_red = "#591b1e",

  light_green = "#36C692",
  green = "#24b37e",
}

M.unified_colors = {
  solid = {
    line_separator = M.colors.medium_gray,
    numbers = M.colors.medium_gray,
    light_numbers = M.colors.blue,
    line_bg = "NONE",
    light_line_bg = M.colors.darkest_gray,
  },
  transparent = {
    line_separator = M.colors.light_blue,
    numbers = M.colors.gray,
    light_numbers = M.colors.light_blue,
    line_bg = "NONE",
    light_line_bg = "NONE",
  },
}

-- -----------------------------------------------------------------------------
-- State
-- -----------------------------------------------------------------------------

---@type sabunv.moonfly.state?
M._state = nil

---@return boolean
function M.is_setup()
  return M._state ~= nil
end

---@return sabunv.moonfly.state
function M.state()
  if not M._state then
    M._state = M.persistence.load()
  end

  return M._state
end

-- -----------------------------------------------------------------------------
-- Options -> State
-- -----------------------------------------------------------------------------

---@param style any
---@return boolean
local function is_valid_style(style)
  return style == "solid" or style == "transparent"
end

---@param opts any
---@return sabunv.moonfly.opts
local function normalize_opts(opts)
  if opts == nil then
    return {}
  end

  if type(opts) ~= "table" then
    error "sabunv.moonfly: opts must be a table or nil"
  end

  ---@type sabunv.moonfly.opts
  local normalized = {}

  if opts.style ~= nil then
    if not is_valid_style(opts.style) then
      error("sabunv.moonfly: invalid style: " .. tostring(opts.style))
    end

    normalized.style = opts.style
  end

  if opts.force ~= nil then
    normalized.force = opts.force == true
  end

  return normalized
end

---@param base_state sabunv.moonfly.state
---@param opts? sabunv.moonfly.opts
---@return sabunv.moonfly.state
local function generate_state(base_state, opts)
  opts = normalize_opts(opts)

  ---@type sabunv.moonfly.state
  local next_state = {
    style = base_state.style,
  }

  if opts.style ~= nil then
    next_state.style = opts.style
  end

  return next_state
end

---@param opts? sabunv.moonfly.opts
---@return sabunv.moonfly.state
local function resolve_state(opts)
  return generate_state(M.state(), opts)
end

---@param current sabunv.moonfly.state?
---@param next_state sabunv.moonfly.state
---@return boolean
local function state_changed(current, next_state)
  if not current then
    return true
  end

  return current.style ~= next_state.style
end

---@param next_state sabunv.moonfly.state
---@return sabunv.moonfly.state
local function commit_state(next_state)
  M._state = M.persistence.save(next_state)

  return M._state
end

-- -----------------------------------------------------------------------------
-- Setup/resetup namespaces
-- -----------------------------------------------------------------------------

M.setup = {}
M.resetup = {}

-- Core: prepara estado. No aplica plugins.
---@param opts? sabunv.moonfly.opts
---@return sabunv.moonfly.state
function M.core_setup(opts)
  local next_state = resolve_state(opts)

  local state = commit_state(next_state)

  local map = vim.keymap.set
  map("n", "<A-t>", function()
    sabunv.moonfly.toggle_style()
  end, { desc = "Moonfly: Toggle style" })

  return state
end

-- -----------------------------------------------------------------------------
-- Plugins / Integrations
-- -----------------------------------------------------------------------------

function M.volt_highlights()
  M.moonfly.volt_highlights(M.state())
end

---

function M.setup.moonfly()
  M.moonfly.setup(M.state())
end

function M.resetup.moonfly()
  M.moonfly.resetup(M.state())
end

function M.setup.nvim_tree()
  M.nvim_tree.setup(M.state())
end

function M.resetup.nvim_tree()
  M.nvim_tree.resetup(M.state())
end

function M.setup.lualine()
  M.lualine.setup(M.state())
end

function M.resetup.lualine()
  M.lualine.resetup(M.state())
end

function M.setup.render_markdown()
  M.render_markdown.setup(M.state())
end

function M.resetup.render_markdown()
  M.render_markdown.resetup(M.state())
end

function M.setup.bufferline()
  M.bufferline.setup(M.state())
end

function M.resetup.bufferline()
  M.bufferline.resetup(M.state())
end

-- -----------------------------------------------------------------------------
-- High-level API
-- -----------------------------------------------------------------------------

---@param opts? sabunv.moonfly.opts
---@return sabunv.moonfly.state
function M.apply(opts)
  local current = M._state
  local normalized = normalize_opts(opts)
  local next_state = generate_state(M.state(), normalized)
  local changed = normalized.force or state_changed(current, next_state)

  commit_state(next_state)

  if changed then
    M.resetup.moonfly()
    M.resetup.nvim_tree()
    M.resetup.lualine()
    M.resetup.render_markdown()
    M.resetup.bufferline()
  end

  return M._state
end

---@param style sabunv.moonfly.style
---@return sabunv.moonfly.state
function M.set_style(style)
  return M.apply { style = style }
end

---@return sabunv.moonfly.state
function M.toggle_style()
  local current_style = M.state().style
  local next_style = current_style == "transparent" and "solid" or "transparent"

  return M.set_style(next_style)
end

return M
