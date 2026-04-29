-- sabunv.moonfly.bufferline

-- Se podrían permitir modificar separator_style, pero requiere argumentos y
-- bifurcaciones complejas, para algo que es en si mismo temporal.

local M = {}

---@type bufferline.UserConfig?
M._config = nil

local function solid()
  local col = sabunv.moonfly.colors

  local bg = col.darkest_gray
  local selected_bg = col.darker_gray
  local fg = col.gray
  local visible_fg = col.lighter_gray
  local selected_fg = col.white
  local diagnostic = col.blue
  local separator = col.dark_gray
  local selected_line = col.blue

  return {
    options = {
      separator_style = "thin",
    },

    highlights = {
      fill = { fg = fg, bg = bg },
      background = { fg = fg, bg = bg },

      tab = { fg = fg, bg = bg },
      tab_selected = { fg = selected_fg, bg = selected_bg },
      tab_separator = { fg = separator, bg = bg },
      tab_separator_selected = {
        fg = selected_bg,
        bg = selected_bg,
        sp = selected_bg,
        underline = false,
      },
      tab_close = { fg = fg, bg = bg },

      close_button = { fg = fg, bg = bg },
      close_button_visible = { fg = fg, bg = bg },
      close_button_selected = { fg = col.red, bg = selected_bg },

      buffer_visible = { fg = visible_fg, bg = bg },
      buffer_selected = {
        fg = selected_fg,
        bg = selected_bg,
        bold = true,
        italic = false,
      },

      numbers = { fg = fg, bg = bg },
      numbers_visible = { fg = visible_fg, bg = bg },
      numbers_selected = {
        fg = selected_fg,
        bg = selected_bg,
        bold = false,
        italic = false,
      },

      diagnostic = { fg = fg, bg = bg },
      diagnostic_visible = { fg = fg, bg = bg },
      diagnostic_selected = {
        fg = selected_fg,
        bg = selected_bg,
        bold = false,
        italic = false,
      },

      hint = { sp = diagnostic, bg = bg },
      hint_visible = { bg = bg },
      hint_selected = {
        bg = selected_bg,
        sp = diagnostic,
        bold = false,
        italic = false,
      },

      hint_diagnostic = { sp = diagnostic, bg = bg },
      hint_diagnostic_visible = { bg = bg },
      hint_diagnostic_selected = {
        bg = selected_bg,
        sp = diagnostic,
        bold = false,
        italic = false,
      },

      info = { sp = diagnostic, bg = bg },
      info_visible = { bg = bg },
      info_selected = {
        bg = selected_bg,
        sp = diagnostic,
        bold = false,
        italic = false,
      },

      info_diagnostic = { sp = diagnostic, bg = bg },
      info_diagnostic_visible = { bg = bg },
      info_diagnostic_selected = {
        bg = selected_bg,
        sp = diagnostic,
        bold = false,
        italic = false,
      },

      warning = { sp = col.yellow, bg = bg },
      warning_visible = { bg = bg },
      warning_selected = {
        bg = selected_bg,
        sp = col.yellow,
        bold = false,
        italic = false,
      },

      warning_diagnostic = { sp = col.yellow, bg = bg },
      warning_diagnostic_visible = { bg = bg },
      warning_diagnostic_selected = {
        bg = selected_bg,
        sp = col.yellow,
        bold = false,
        italic = false,
      },

      error = { sp = col.red, bg = bg },
      error_visible = { bg = bg },
      error_selected = {
        bg = selected_bg,
        sp = col.red,
        bold = false,
        italic = false,
      },

      error_diagnostic = { sp = col.red, bg = bg },
      error_diagnostic_visible = { bg = bg },
      error_diagnostic_selected = {
        bg = selected_bg,
        sp = col.red,
        bold = false,
        italic = false,
      },

      modified = { fg = col.light_green, bg = bg },
      modified_visible = { fg = col.light_green, bg = bg },
      modified_selected = { fg = col.light_green, bg = selected_bg },

      duplicate = { fg = fg, bg = bg, italic = false },
      duplicate_visible = { fg = fg, bg = bg, italic = false },
      duplicate_selected = { fg = selected_fg, bg = selected_bg, italic = false },

      -- indicator
      indicator_visible = { fg = fg, bg = bg },
      indicator_selected = { fg = selected_line, bg = selected_bg },

      -- separator
      separator = { fg = bg, bg = bg },
      separator_visible = { fg = bg, bg = bg },
      separator_selected = { fg = selected_line, bg = selected_bg },

      pick = { fg = fg, bg = bg, bold = false, italic = false },
      pick_visible = { fg = fg, bg = bg, bold = false, italic = false },
      pick_selected = { fg = selected_fg, bg = selected_bg, bold = false, italic = false },

      offset_separator = { fg = separator, bg = bg },
      trunc_marker = { fg = fg, bg = bg },
    },
  }
end

local function transparent()
  local col = sabunv.moonfly.colors

  local bg = col.darkest_gray
  local selected_bg = col.darker_gray
  local fg = col.gray
  local visible_fg = col.lighter_gray
  local selected_fg = col.darker_white
  local diagnostic = col.light_blue
  local separator = col.dark_gray
  local selected_line = col.light_blue

  return {
    options = {
      separator_style = "thin",
    },

    highlights = {
      fill = { fg = fg, bg = bg },
      background = { fg = fg, bg = bg },

      tab = { fg = fg, bg = bg },
      tab_selected = { fg = selected_fg, bg = selected_bg },
      tab_separator = { fg = separator, bg = bg },
      tab_separator_selected = {
        fg = selected_bg,
        bg = selected_bg,
        sp = selected_bg,
        underline = false,
      },
      tab_close = { fg = fg, bg = bg },

      close_button = { fg = fg, bg = bg },
      close_button_visible = { fg = fg, bg = bg },
      close_button_selected = { fg = col.red, bg = selected_bg },

      buffer_visible = { fg = visible_fg, bg = bg },
      buffer_selected = {
        fg = selected_fg,
        bg = selected_bg,
        bold = true,
        italic = false,
      },

      numbers = { fg = fg, bg = bg },
      numbers_visible = { fg = visible_fg, bg = bg },
      numbers_selected = {
        fg = selected_fg,
        bg = selected_bg,
        bold = false,
        italic = false,
      },

      diagnostic = { fg = fg, bg = bg },
      diagnostic_visible = { fg = fg, bg = bg },
      diagnostic_selected = {
        fg = selected_fg,
        bg = selected_bg,
        bold = false,
        italic = false,
      },

      hint = { sp = diagnostic, bg = bg },
      hint_visible = { bg = bg },
      hint_selected = {
        bg = selected_bg,
        sp = diagnostic,
        bold = false,
        italic = false,
      },

      hint_diagnostic = { sp = diagnostic, bg = bg },
      hint_diagnostic_visible = { bg = bg },
      hint_diagnostic_selected = {
        bg = selected_bg,
        sp = diagnostic,
        bold = false,
        italic = false,
      },

      info = { sp = diagnostic, bg = bg },
      info_visible = { bg = bg },
      info_selected = {
        bg = selected_bg,
        sp = diagnostic,
        bold = false,
        italic = false,
      },

      info_diagnostic = { sp = diagnostic, bg = bg },
      info_diagnostic_visible = { bg = bg },
      info_diagnostic_selected = {
        bg = selected_bg,
        sp = diagnostic,
        bold = false,
        italic = false,
      },

      warning = { sp = col.yellow, bg = bg },
      warning_visible = { bg = bg },
      warning_selected = {
        bg = selected_bg,
        sp = col.yellow,
        bold = false,
        italic = false,
      },

      warning_diagnostic = { sp = col.yellow, bg = bg },
      warning_diagnostic_visible = { bg = bg },
      warning_diagnostic_selected = {
        bg = selected_bg,
        sp = col.yellow,
        bold = false,
        italic = false,
      },

      error = { sp = col.red, bg = bg },
      error_visible = { bg = bg },
      error_selected = {
        bg = selected_bg,
        sp = col.red,
        bold = false,
        italic = false,
      },

      error_diagnostic = { sp = col.red, bg = bg },
      error_diagnostic_visible = { bg = bg },
      error_diagnostic_selected = {
        bg = selected_bg,
        sp = col.red,
        bold = false,
        italic = false,
      },

      modified = { fg = col.light_green, bg = bg },
      modified_visible = { fg = col.light_green, bg = bg },
      modified_selected = { fg = col.light_green, bg = selected_bg },

      duplicate = { fg = fg, bg = bg, italic = false },
      duplicate_visible = { fg = fg, bg = bg, italic = false },
      duplicate_selected = { fg = selected_fg, bg = selected_bg, italic = false },

      -- indicator
      indicator_visible = { fg = fg, bg = bg },
      indicator_selected = { fg = selected_line, bg = selected_bg },

      -- separator
      separator = { fg = bg, bg = bg },
      separator_visible = { fg = bg, bg = bg },
      separator_selected = { fg = selected_bg, bg = selected_bg },

      pick = { fg = fg, bg = bg, bold = false, italic = false },
      pick_visible = { fg = fg, bg = bg, bold = false, italic = false },
      pick_selected = { fg = selected_fg, bg = selected_bg, bold = false, italic = false },

      offset_separator = { fg = separator, bg = bg },
      trunc_marker = { fg = fg, bg = bg },
    },
  }
end

local function clear_highlights()
  local all = vim.api.nvim_get_hl(0, {})

  for group, _ in pairs(all) do
    if group:match "^BufferLine" then
      vim.api.nvim_set_hl(0, group, {})
    end
  end
end

---@param state sabunv.moonfly.state
---@return bufferline.UserConfig
local function generate_config(state)
  if state.style == "solid" then
    return solid()
  elseif state.style == "transparent" then
    return transparent()
  else
    error("invalid moonfly style: " .. tostring(state.style))
  end
end

---@param state sabunv.moonfly.state
function M.setup(state)
  clear_highlights()
  M._config = generate_config(state)
end

---@param state sabunv.moonfly.state
function M.resetup(state)
  clear_highlights()
  M._config = generate_config(state)

  local ok, bufferline = pcall(require, "lzy.l_bufferline")

  if ok and bufferline.is_setup and bufferline.is_setup() then
    bufferline.resetup()
  end
end

---@return bufferline.UserConfig
function M.config()
  if not M._config then
    M.setup(sabunv.moonfly.state())
  end

  local cfg = vim.deepcopy(M._config)

  vim.defer_fn(function()
    sabunv.restart.restore_bufferline()
  end, 500)
  return cfg
end

return M
