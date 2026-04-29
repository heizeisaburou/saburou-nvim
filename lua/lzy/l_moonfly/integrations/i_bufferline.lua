-- lzy/l_moonfly/integrations/i_bufferline

---@type HzsrIntegration
---@diagnostic disable-next-line: missing-fields
local M = {}

local colors = require "hzsr.moonfly_manager.colors"
local bufferline = require "bufferline"

local SEPARATOR_COLOR_HL = {
  thin = {
    separator_selected = {
      fg = colors.darkest_gray,
      bg = colors.darkest_gray,
    },
    separator_visible = {
      fg = colors.darkest_gray,
      bg = colors.darkest_gray,
    },
    separator = {
      fg = colors.darkest_gray,
      bg = colors.darkest_gray,
    },
  },
  blue = {
    separator_selected = {
      fg = colors.blue,
      bg = colors.darkest_gray,
    },
    separator_visible = {
      fg = colors.medium_blue,
      bg = colors.darkest_gray,
    },
    separator = {
      fg = colors.darker_blue,
      bg = colors.darkest_gray,
    },
  },
  gray = {
    separator_selected = {
      fg = colors.white,
      bg = colors.darkest_gray,
    },
    separator_visible = {
      fg = colors.lighter_gray,
      bg = colors.darkest_gray,
    },
    separator = {
      fg = colors.medium_gray,
      bg = colors.darkest_gray,
    },
  },
}

local BASE_HL = {
  fill = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  background = {
    bg = colors.darkest_gray,
  },
  tab = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  tab_selected = {
    fg = colors.white,
    bg = colors.darkest_gray,
  },
  tab_separator = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  tab_separator_selected = {
    fg = colors.white,
    bg = colors.darkest_gray,
    sp = colors.darkest_gray,
    underline = false,
  },
  tab_close = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  close_button = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  close_button_visible = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  close_button_selected = {
    fg = colors.red,
    bg = colors.darkest_gray,
  },
  buffer_visible = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  buffer_selected = {
    fg = colors.white,
    bg = colors.darkest_gray,
    bold = true,
    italic = false,
  },
  numbers = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  numbers_visible = {
    fg = colors.lighter_gray,
    bg = colors.darkest_gray,
  },
  numbers_selected = {
    fg = colors.white,
    bg = colors.darkest_gray,
    bold = false,
    italic = false,
  },
  diagnostic = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  diagnostic_visible = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  diagnostic_selected = {
    fg = colors.white,
    bg = colors.darkest_gray,
    bold = false,
    italic = false,
  },
  hint = {
    sp = colors.blue,
    bg = colors.darkest_gray,
  },
  hint_visible = {
    bg = colors.darkest_gray,
  },
  hint_selected = {
    bg = colors.darkest_gray,
    sp = colors.blue,
    bold = false,
    italic = false,
  },
  hint_diagnostic = {
    sp = colors.blue,
    bg = colors.darkest_gray,
  },
  hint_diagnostic_visible = {
    bg = colors.darkest_gray,
  },
  hint_diagnostic_selected = {
    bg = colors.darkest_gray,
    sp = colors.blue,
    bold = false,
    italic = false,
  },
  info = {
    sp = colors.blue,
    bg = colors.darkest_gray,
  },
  info_visible = {
    bg = colors.darkest_gray,
  },
  info_selected = {
    bg = colors.darkest_gray,
    sp = colors.blue,
    bold = false,
    italic = false,
  },
  info_diagnostic = {
    sp = colors.blue,
    bg = colors.darkest_gray,
  },
  info_diagnostic_visible = {
    bg = colors.darkest_gray,
  },
  info_diagnostic_selected = {
    bg = colors.darkest_gray,
    sp = colors.blue,
    bold = false,
    italic = false,
  },
  warning = {
    sp = colors.blue,
    bg = colors.darkest_gray,
  },
  warning_visible = {
    bg = colors.darkest_gray,
  },
  warning_selected = {
    bg = colors.darkest_gray,
    sp = colors.blue,
    bold = false,
    italic = false,
  },
  warning_diagnostic = {
    sp = colors.blue,
    bg = colors.darkest_gray,
  },
  warning_diagnostic_visible = {
    bg = colors.darkest_gray,
  },
  warning_diagnostic_selected = {
    bg = colors.darkest_gray,
    sp = colors.blue,
    bold = false,
    italic = false,
  },
  error = {
    bg = colors.darkest_gray,
    sp = colors.blue,
  },
  error_visible = {
    bg = colors.darkest_gray,
  },
  error_selected = {
    bg = colors.darkest_gray,
    sp = colors.blue,
    bold = false,
    italic = false,
  },
  error_diagnostic = {
    bg = colors.darkest_gray,
    sp = colors.blue,
  },
  error_diagnostic_visible = {
    bg = colors.darkest_gray,
  },
  error_diagnostic_selected = {
    bg = colors.darkest_gray,
    sp = colors.blue,
    bold = false,
    italic = false,
  },
  modified = {
    fg = colors.light_green,
    bg = colors.darkest_gray,
  },
  modified_visible = {
    fg = colors.light_green,
    bg = colors.darkest_gray,
  },
  modified_selected = {
    fg = colors.light_green,
    bg = colors.darkest_gray,
  },
  duplicate_selected = {
    fg = colors.white,
    bg = colors.darkest_gray,
    italic = false,
  },
  duplicate_visible = {
    fg = colors.gray,
    bg = colors.darkest_gray,
    italic = false,
  },
  duplicate = {
    fg = colors.gray,
    bg = colors.darkest_gray,
    italic = false,
  },
  indicator_visible = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  indicator_selected = {
    fg = colors.white,
    bg = colors.darkest_gray,
  },
  pick_selected = {
    fg = colors.white,
    bg = colors.darkest_gray,
    bold = false,
    italic = false,
  },
  pick_visible = {
    fg = colors.gray,
    bg = colors.darkest_gray,
    bold = false,
    italic = false,
  },
  pick = {
    fg = colors.gray,
    bg = colors.darkest_gray,
    bold = false,
    italic = false,
  },
  offset_separator = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
  trunc_marker = {
    fg = colors.gray,
    bg = colors.darkest_gray,
  },
}

local BASE_OPTS = {
  show_tab_indicators = true,
  style_preset = bufferline.style_preset.no_italic,
  diagnostics = true,
  mode = "buffer",
  numbers = "none",
  hover = { enabled = true, reveal = {}, delay = 200 },
  diagnostics_indicator = function(count, level, diagnostics_dict, context)
    local icon = level:match "error" and " " or " "
    return " " .. icon .. count
  end,
}

---@param opts HzsrThemeInternalOpts
function M.integrate(opts)
  -- Configuracion
  local input_bl_opts = opts.bufferline

  local bl_opts =
    vim.tbl_deep_extend("force", BASE_OPTS, { separator_style = input_bl_opts.sep_style })

  local separator_style = SEPARATOR_COLOR_HL[input_bl_opts.sep_style]
  local bl_hls = vim.tbl_deep_extend("force", BASE_HL, separator_style)

  local config = {
    options = bl_opts,
    highlights = bl_hls,
  }

  local g = vim.g

  -- Globales
  g.moonflyTransparent = opts.transparent

  g.moonflyCursorColor = true
  g.moonflyItalics = false
  g.moonflyNormalPmenu = false
  g.moonflyTerminalColors = false
  g.moonflyUndercurls = true
  g.moonflyUnderlineMatchParen = false
  g.moonflyVirtualTextColor = false

  -- Separador de ventanas
  g.moonflyWinSeparator = 0

  -- Recomendable activar juntos
  g.moonflyNormalFloat = false
  -- vim.o.winborder = "single"

  -- Lanzamos bufferline
  ---@diagnostic disable-next-line
  require("cfg.c_bufferline").setup(config)
end

return M
