-- sabunv.moonfly.render_markdown

local M = {}

-- -----------------------------------------------------------------------------
-- Terminal detection
-- -----------------------------------------------------------------------------

local function is_pure_tty()
  local term = (vim.env.TERM or ""):lower()
  local colorterm = (vim.env.COLORTERM or ""):lower()
  local session_type = (vim.env.XDG_SESSION_TYPE or ""):lower()
  local tty = vim.fn.system("tty 2>/dev/null"):gsub("%s+", "")

  if term == "linux" or term == "vt100" or term == "vt220" or term == "dumb" then
    return true
  end

  if session_type == "tty" and colorterm == "" then
    return true
  end

  if tty:match "^/dev/tty%d+$" then
    return true
  end

  return false
end

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
    },
    h2 = {
      fg = "black",
      bg = "red",
    },
    h3 = {
      fg = "black",
      bg = "orange",
    },
    h4 = {
      fg = "black",
      bg = "cyan",
    },
    h5 = {
      fg = "black",
      bg = "blue",
    },
    h6 = {
      fg = "black",
      bg = "purple",
    },
  }
end

---@param state sabunv.moonfly.state
local function heading_palette(state)
  if is_pure_tty() then
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
  })

  set("RenderMarkdownH" .. level .. "Bg", {
    bg = colors.bg,
  })

  set("@markup.heading." .. level .. ".markdown", {
    fg = colors.fg,
    bg = colors.bg,
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
  })

  set("@markup.heading", {
    fg = palette.h1.fg,
    bg = palette.h1.bg,
  })

  -- Tables hotfix: quitar fondos de cabecera/texto de tabla
  set("RenderMarkdownTableHead", { fg = "NONE", bg = "NONE" })
  set("RenderMarkdownTableRow", { fg = "NONE", bg = "NONE" })
  set("RenderMarkdownTableFill", { fg = "NONE", bg = "NONE" })
  set("@markup.heading.markdown", { fg = "NONE", bg = "NONE" })

  if is_pure_tty() then
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

  local ok, render_markdown = pcall(require, "lzy.l_render-markdown")

  if ok and render_markdown.is_setup and render_markdown.is_setup() then
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
