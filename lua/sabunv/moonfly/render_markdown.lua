-- sabunv.moonfly.render_markdown

local M = {}
local tty = require "sabunv.moonfly.tty"

-- -----------------------------------------------------------------------------
-- Palettes
-- -----------------------------------------------------------------------------

local function solid_heading_palette()
  return {
    h1 = {
      fg = "#181B1E",
      bg = "#C7C9CC", -- dimmer soft gray-white
    },
    h2 = {
      fg = "#140202",
      bg = "#9C4A4A", -- dimmer muted red
    },
    h3 = {
      fg = "#21190D",
      bg = "#B5995F", -- muted orange / yellow
    },
    h4 = {
      fg = "#062126",
      bg = "#4F98A7", -- slightly dimmer cyan / light blue
    },
    h5 = {
      fg = "#050B26",
      bg = "#5064B0", -- slightly dimmer blue
    },
    h6 = {
      fg = "#100B34",
      bg = "#8479D0", -- slightly dimmer purple
    },
  }
end

local function transparent_heading_palette()
  return {
    h1 = {
      fg = "#EDEFF0",
      bg = "NONE",
    },
    h2 = {
      fg = "#E56666",
      bg = "NONE",
    },
    h3 = {
      fg = "#DDBE7C",
      bg = "NONE",
    },
    h4 = {
      fg = "#61B8CC",
      bg = "NONE",
    },
    h5 = {
      fg = "#5F7DDD",
      bg = "NONE",
    },
    h6 = {
      fg = "#998CF7",
      bg = "NONE",
    },
  }
end

local function tty_heading_palette()
  return {
    h1 = {
      fg = "black",
      bg = "white",
      ctermfg = 0,
      ctermbg = 15,
    },
    h2 = {
      fg = tty.colors.h2.fg,
      bg = tty.colors.h2.bg,
      ctermfg = tty.colors.h2.ctermfg,
      ctermbg = tty.colors.h2.ctermbg,
    },
    h3 = {
      fg = "black",
      bg = "orange",
      ctermfg = 0,
      ctermbg = 11,
    },
    h4 = {
      fg = "black",
      bg = "cyan",
      ctermfg = 0,
      ctermbg = 14,
    },
    h5 = {
      fg = "black",
      bg = "blue",
      ctermfg = 15,
      ctermbg = 4,
    },
    h6 = {
      fg = "black",
      bg = "purple",
      ctermfg = 15,
      ctermbg = 5,
    },
  }
end

---@param state sabunv.moonfly.state
local function heading_palette(state)
  if tty.is_pure() then
    return tty_heading_palette()
  end

  if state.style == "solid" then
    return solid_heading_palette()
  elseif state.style == "transparent" then
    return transparent_heading_palette()
  else
    error("invalid moonfly style: " .. tostring(state.style))
  end
end

-- -----------------------------------------------------------------------------
-- Highlight helpers
-- -----------------------------------------------------------------------------

local function set_heading(level, colors)
  local set = sabunv.moonfly.hl.set

  set("RenderMarkdownH" .. level, {
    fg = colors.fg,
    ctermfg = colors.ctermfg,
  })

  set("RenderMarkdownH" .. level .. "Bg", {
    bg = colors.bg,
    ctermbg = colors.ctermbg,
  })

  set("@markup.heading." .. level .. ".markdown", {
    fg = colors.fg,
    bg = colors.bg,
    ctermfg = colors.ctermfg,
    ctermbg = colors.ctermbg,
  })
end

local function tty_hotfixes()
  local set = sabunv.moonfly.hl.set

  -- render-markdown.nvim: quitar fondo raro del label de lenguaje en fences:
  -- ```js
  --
  -- En TTY pura algunos grupos degradan a fondo blanco.
  set("RenderMarkdownCode", { bg = "NONE" })
  set("RenderMarkdownCodeInline", { bg = "NONE" })
  set("RenderMarkdownCodeInfo", { bg = "NONE" })
  set("RenderMarkdownCodeBorder", { bg = "NONE" })
  set("RenderMarkdownCodeFallback", { bg = "NONE" })
end

---@param state sabunv.moonfly.state
local function heading_highlights(state)
  local set = sabunv.moonfly.hl.set
  local palette = heading_palette(state)

  set_heading(1, palette.h1)
  set_heading(2, palette.h2)
  set_heading(3, palette.h3)
  set_heading(4, palette.h4)
  set_heading(5, palette.h5)
  set_heading(6, palette.h6)

  -- Fallbacks
  set("@markup.heading.markdown", {
    fg = palette.h1.fg,
    bg = palette.h1.bg,
    ctermfg = palette.h1.ctermfg,
    ctermbg = palette.h1.ctermbg,
  })

  set("@markup.heading", {
    fg = palette.h1.fg,
    bg = palette.h1.bg,
    ctermfg = palette.h1.ctermfg,
    ctermbg = palette.h1.ctermbg,
  })

  -- Tables hotfix: quitar fondos de cabecera/texto de tabla
  set("RenderMarkdownTableHead", { fg = "NONE", bg = "NONE" })
  set("RenderMarkdownTableRow", { fg = "NONE", bg = "NONE" })
  set("RenderMarkdownTableFill", { fg = "NONE", bg = "NONE" })
  set("@markup.heading.markdown", { fg = "NONE", bg = "NONE" })

  if tty.is_pure() then
    tty_hotfixes()
  end
end

-- -----------------------------------------------------------------------------
-- Public API
-- -----------------------------------------------------------------------------

---@param state sabunv.moonfly.state
function M.setup(state)
  heading_highlights(state)
end

---@param state sabunv.moonfly.state
function M.resetup(state)
  heading_highlights(state)

  local render_markdown = require "lzy.render-markdown"

  if render_markdown.is_setup() then
    render_markdown.resetup()
  end
end

function M.config()
  return {
    heading = {
      foregrounds = {
        "RenderMarkdownH1",
        "RenderMarkdownH2",
        "RenderMarkdownH3",
        "RenderMarkdownH4",
        "RenderMarkdownH5",
        "RenderMarkdownH6",
      },
      backgrounds = {
        "RenderMarkdownH1Bg",
        "RenderMarkdownH2Bg",
        "RenderMarkdownH3Bg",
        "RenderMarkdownH4Bg",
        "RenderMarkdownH5Bg",
        "RenderMarkdownH6Bg",
      },
    },
    pipe_table = {
      cell = "padded",
      padding = 1,
    },
  }
end

return M
