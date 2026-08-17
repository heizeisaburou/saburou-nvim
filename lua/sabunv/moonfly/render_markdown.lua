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
      italic = "#702044", -- dark berry on light gray (6.39:1)
    },
    h2 = {
      fg = "#140202",
      bg = "#9C4A4A", -- dimmer muted red
      italic = "#FFF0F4", -- porcelain rose on muted red (5.45:1)
    },
    h3 = {
      fg = "#21190D",
      bg = "#B5995F", -- muted orange / yellow
      italic = "#4B1730", -- dark berry on gold (5.25:1)
    },
    h4 = {
      fg = "#062126",
      bg = "#4F98A7", -- slightly dimmer cyan / light blue
      italic = "#40142D", -- dark berry on cyan (4.71:1)
    },
    h5 = {
      fg = "#050B26",
      bg = "#5064B0", -- slightly dimmer blue
      italic = "#FFF0F4", -- porcelain rose on blue (5.02:1)
    },
    h6 = {
      fg = "#100B34",
      bg = "#8479D0", -- slightly dimmer purple
      italic = "#27112F", -- dark aubergine on purple (4.66:1)
    },
  }
end

local function transparent_heading_palette()
  return {
    h1 = {
      fg = "#EDEFF0",
      bg = "NONE",
      italic = "#F2A7C8",
    },
    h2 = {
      fg = "#E56666",
      bg = "NONE",
      italic = "#F2A7C8",
    },
    h3 = {
      fg = "#DDBE7C",
      bg = "NONE",
      italic = "#F2A7C8",
    },
    h4 = {
      fg = "#61B8CC",
      bg = "NONE",
      italic = "#F2A7C8",
    },
    h5 = {
      fg = "#5F7DDD",
      bg = "NONE",
      italic = "#F2A7C8",
    },
    h6 = {
      fg = "#998CF7",
      bg = "NONE",
      italic = "#F2A7C8",
    },
  }
end

local function tty_heading_palette()
  return {
    h1 = {
      fg = "black",
      bg = "white",
      italic = "black",
      ctermfg = 0,
      ctermbg = 15,
      italic_ctermfg = 0,
    },
    h2 = {
      fg = tty.colors.h2.fg,
      bg = tty.colors.h2.bg,
      italic = "white",
      ctermfg = tty.colors.h2.ctermfg,
      ctermbg = tty.colors.h2.ctermbg,
      italic_ctermfg = 15,
    },
    h3 = {
      fg = "black",
      bg = "orange",
      italic = "black",
      ctermfg = 0,
      ctermbg = 11,
      italic_ctermfg = 0,
    },
    h4 = {
      fg = "black",
      bg = "cyan",
      italic = "black",
      ctermfg = 0,
      ctermbg = 14,
      italic_ctermfg = 0,
    },
    h5 = {
      fg = "black",
      bg = "blue",
      italic = "white",
      ctermfg = 15,
      ctermbg = 4,
      italic_ctermfg = 15,
    },
    h6 = {
      fg = "black",
      bg = "purple",
      italic = "white",
      ctermfg = 15,
      ctermbg = 5,
      italic_ctermfg = 15,
    },
  }
end

--- Colores de lo que no es un heading: el chip de los tags y los avisos de los
--- bloques de código que si no no se verían.
---
--- No dependen del estilo (`solid`/`transparent`) a propósito: son marcas
--- puntuales sobre una palabra o una línea suelta, no franjas de página, así
--- que llevan fondo también en transparente -- que es justo lo que las hace
--- distinguibles del texto de alrededor.
local function annotation_palette()
  if tty.is_pure() then
    return {
      -- En 16 colores no hay un rojo más oscuro: el chip usa el mismo rojo del
      -- H2 con el texto invertido, que ahí es lo que los separa.
      tag = { fg = "black", bg = "red", ctermfg = 0, ctermbg = 1 },
      empty = { fg = "black", bg = "yellow", ctermfg = 0, ctermbg = 3 },
      unclosed = { fg = "white", bg = "red", ctermfg = 15, ctermbg = 1 },
    }
  end

  return {
    -- El rojo del H2 (#9C4A4A) bajado ~30%: se lee como el mismo color, pero
    -- no se confunde con la banda de un heading (8.9:1 con el texto).
    tag = { fg = "#FFF0F4", bg = "#6D3434" },
    -- Ámbar de aviso: el bloque está vacío, no roto.
    empty = { fg = "#FFF2D6", bg = "#6A5220" },
    -- Rojo de error, más saturado que el chip: esto sí está roto.
    unclosed = { fg = "#FFE8E8", bg = "#8B1A1A" },
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

  -- El fondo se repite a propósito: este grupo se aplica como extmark de alta
  -- prioridad sobre el heading y no debe abrir un agujero en la banda sólida.
  set("RenderMarkdownH" .. level .. "Italic", {
    fg = colors.italic,
    bg = colors.bg,
    ctermfg = colors.italic_ctermfg,
    ctermbg = colors.ctermbg,
    italic = true,
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

  local annotations = annotation_palette()

  set("RenderMarkdownTag", {
    fg = annotations.tag.fg,
    bg = annotations.tag.bg,
    ctermfg = annotations.tag.ctermfg,
    ctermbg = annotations.tag.ctermbg,
    bold = true,
  })

  set("RenderMarkdownCodeEmpty", {
    fg = annotations.empty.fg,
    bg = annotations.empty.bg,
    ctermfg = annotations.empty.ctermfg,
    ctermbg = annotations.empty.ctermbg,
  })

  set("RenderMarkdownCodeUnclosed", {
    fg = annotations.unclosed.fg,
    bg = annotations.unclosed.bg,
    ctermfg = annotations.unclosed.ctermfg,
    ctermbg = annotations.unclosed.ctermbg,
    bold = true,
  })

  set("RenderMarkdownSpoiler", {
    fg = palette.h3.fg,
    bg = palette.h3.bg,
    ctermfg = palette.h3.ctermfg,
    ctermbg = palette.h3.ctermbg,
    bold = true,
  })

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
