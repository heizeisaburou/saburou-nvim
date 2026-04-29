-- sabunv.moonfly.moonfly

local M = {}

local function generate_mf_colors()
  local col = sabunv.moonfly.colors

  local base_colors = {
    blue = col.blue,
    yellow = col.yellow,
    cranberry = col.red,
    green = col.green,
  }

  local mf_colors = {
    solid = vim.tbl_extend("force", vim.deepcopy(base_colors), {
      -- white = col.white,
      -- grey11 = col.darkest_gray,
      grey11 = "NONE",
      bg = col.bg,
      slate = col.blue,
    }),

    transparent = vim.tbl_extend("force", vim.deepcopy(base_colors), {
      -- white = col.darker_white,
      bg = "NONE",
      slate = col.light_blue,
    }),
  }

  return mf_colors
end

local function common()
  local g = vim.g

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
end

local function solid()
  vim.g.moonflyTransparent = false
end

local function transparent()
  vim.g.moonflyTransparent = true
end

---@param state sabunv.moonfly.state
local function configure(state)
  common()

  if state.style == "solid" then
    solid()
  elseif state.style == "transparent" then
    transparent()
  else
    error("invalid moonfly style: " .. tostring(state.style))
  end

  local mf_colors = generate_mf_colors()
  local moonfly = require "moonfly"

  moonfly.custom_colors(mf_colors[state.style])
end

local function diagnostic_highlights()
  local col = sabunv.moonfly.colors
  local update = sabunv.moonfly.hl.update

  local diagnostic_error = col.red
  local diagnostic_warn = col.yellow
  local diagnostic_info = col.blue
  local diagnostic_hint = col.lightest_blue
  local diagnostic_ok = col.green

  -- Diagnostics
  update("DiagnosticError", { fg = diagnostic_error })
  update("DiagnosticWarn", { fg = diagnostic_warn })
  update("DiagnosticInfo", { fg = diagnostic_info })
  update("DiagnosticHint", { fg = diagnostic_hint })
  update("DiagnosticOk", { fg = diagnostic_ok })

  -- Diagnostic signs
  update("DiagnosticSignError", { fg = diagnostic_error, bg = "NONE" })
  update("DiagnosticSignWarn", { fg = diagnostic_warn, bg = "NONE" })
  update("DiagnosticSignInfo", { fg = diagnostic_info, bg = "NONE" })
  update("DiagnosticSignHint", { fg = diagnostic_hint, bg = "NONE" })
  update("DiagnosticSignOk", { fg = diagnostic_ok, bg = "NONE" })

  -- Diagnostic virtual text
  update("DiagnosticVirtualTextError", {
    fg = diagnostic_error,
    bg = "NONE",
  })
  update("DiagnosticVirtualTextWarn", {
    fg = diagnostic_warn,
    bg = "NONE",
  })
  update("DiagnosticVirtualTextInfo", {
    fg = diagnostic_info,
    bg = "NONE",
  })
  update("DiagnosticVirtualTextHint", {
    fg = diagnostic_hint,
    bg = "NONE",
  })
  update("DiagnosticVirtualTextOk", {
    fg = diagnostic_ok,
    bg = "NONE",
  })

  -- Diagnostic underlines
  update("DiagnosticUnderlineError", {
    sp = diagnostic_error,
    undercurl = true,
  })
  update("DiagnosticUnderlineWarn", {
    sp = diagnostic_warn,
    undercurl = true,
  })
  update("DiagnosticUnderlineInfo", {
    sp = diagnostic_info,
    undercurl = true,
  })
  update("DiagnosticUnderlineHint", {
    sp = diagnostic_hint,
    undercurl = true,
  })
  update("DiagnosticUnderlineOk", {
    sp = diagnostic_ok,
    undercurl = true,
  })

  -- Diagnostic floating windows
  update("DiagnosticFloatingError", { fg = diagnostic_error, bg = "NONE" })
  update("DiagnosticFloatingWarn", { fg = diagnostic_warn, bg = "NONE" })
  update("DiagnosticFloatingInfo", { fg = diagnostic_info, bg = "NONE" })
  update("DiagnosticFloatingHint", { fg = diagnostic_hint, bg = "NONE" })
  update("DiagnosticFloatingOk", { fg = diagnostic_ok, bg = "NONE" })

  -- Legacy LSP diagnostic groups
  update("LspDiagnosticsDefaultError", { fg = diagnostic_error })
  update("LspDiagnosticsDefaultWarning", { fg = diagnostic_warn })
  update("LspDiagnosticsDefaultInformation", { fg = diagnostic_info })
  update("LspDiagnosticsDefaultHint", { fg = diagnostic_hint })

  update("LspDiagnosticsVirtualTextError", {
    fg = diagnostic_error,
    bg = "NONE",
  })
  update("LspDiagnosticsVirtualTextWarning", {
    fg = diagnostic_warn,
    bg = "NONE",
  })
  update("LspDiagnosticsVirtualTextInformation", {
    fg = diagnostic_info,
    bg = "NONE",
  })
  update("LspDiagnosticsVirtualTextHint", {
    fg = diagnostic_hint,
    bg = "NONE",
  })

  update("LspDiagnosticsUnderlineError", {
    sp = diagnostic_error,
    undercurl = true,
  })
  update("LspDiagnosticsUnderlineWarning", {
    sp = diagnostic_warn,
    undercurl = true,
  })
  update("LspDiagnosticsUnderlineInformation", {
    sp = diagnostic_info,
    undercurl = true,
  })
  update("LspDiagnosticsUnderlineHint", {
    sp = diagnostic_hint,
    undercurl = true,
  })
end

---@param state sabunv.moonfly.state
local function window_highlights(state)
  local col = sabunv.moonfly.colors
  local update = sabunv.moonfly.hl.update

  local float_bg = state.style == "solid" and col.bg or "NONE"

  -- Bordes de ventanas flotantes: terminal flotante, floats LSP, Claude/Codex,
  -- Telescope/which-key/etc si respetan FloatBorder.
  update("FloatBorder", {
    fg = col.light_blue,
    bg = float_bg,
  })

  update("FloatTitle", {
    fg = col.light_blue,
    bg = float_bg,
  })

  update("NormalFloat", {
    bg = float_bg,
  })
end

---@param state sabunv.moonfly.state
local function volt_highlights(state)
  local col = sabunv.moonfly.colors
  local update = sabunv.moonfly.hl.update

  if state.style == "solid" then
    update("ExLightGrey", { fg = col.gray, bg = col.bg })
    update("ExBlack3Bg", { fg = col.white, bg = col.darker_gray })
    update("ExBlack3Border", { fg = col.darker_gray, bg = col.darker_gray })
    update("ExBlack2Bg", { fg = col.blue, bg = col.bg })
    update("ExBlack2Border", { fg = col.light_blue, bg = col.bg })
  elseif state.style == "transparent" then
    -- HOPES: No se como cambiar el color de los hr ni de las teclas
    update("ExLightGrey", { fg = col.light_blue, bg = "NONE" })
    update("ExBlack3Bg", { fg = col.bg, bg = col.light_blue })
    update("ExBlack3Border", { fg = col.light_blue, bg = col.light_blue })
    update("ExBlack2Bg", { fg = col.blue, bg = "NONE" })
    update("ExBlack2Border", { fg = col.light_blue, bg = "" })

  else
    error("invalid moonfly style: " .. tostring(state.style))
  end
end

---@param state sabunv.moonfly.state
local function highlights(state)
  local col = sabunv.moonfly.colors
  local update = sabunv.moonfly.hl.update
  local uni_t = sabunv.moonfly.unified_colors.transparent
  local uni_s = sabunv.moonfly.unified_colors.solid

  diagnostic_highlights()
  window_highlights(state)
  volt_highlights(state)

  if state.style == "solid" then
    update("IblIndent", { fg = col.medium_gray })
    update("VertSplit", { fg = uni_s.line_separator, bg = "NONE" })

    --

    update("SignColumn", { bg = "NONE" })
    update("CursorLineSign", { bg = uni_s.light_line_bg })

    update("FoldColumn", { bg = "NONE" })
    update("CursorLineFold", { bg = uni_s.light_line_bg })

    update("LineNr", { fg = uni_s.numbers, bg = "NONE" })
    update("CursorLineNr", { fg = uni_s.light_numbers, bg = uni_s.light_line_bg })
  elseif state.style == "transparent" then
    update("IblIndent", { fg = col.medium_gray })
    update("VertSplit", { fg = uni_t.line_separator, bg = "NONE" })

    --

    update("SignColumn", { bg = "NONE" })
    update("CursorLineSign", { bg = "NONE" })

    update("FoldColumn", { bg = "NONE" })
    update("CursorLineFold", { bg = "NONE" })

    update("LineNr", { fg = uni_t.numbers, bg = "NONE" })
    update("CursorLineNr", { fg = uni_t.light_numbers, bg = "NONE" })
  else
    error("invalid moonfly style: " .. tostring(state.style))
  end
end

---@param state sabunv.moonfly.state
local function apply(state)
  configure(state)
  vim.cmd.colorscheme "moonfly"
  highlights(state)
end

---@param state sabunv.moonfly.state
function M.resetup(state)
  apply(state)
end

---@param state sabunv.moonfly.state
function M.setup(state)
  apply(state)
end

return M
