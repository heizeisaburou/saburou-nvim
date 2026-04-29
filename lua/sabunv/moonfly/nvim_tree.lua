-- sabunv.moonfly.nvim_tree

local M = {}

local function common()
  local col = sabunv.moonfly.colors
  local update = sabunv.moonfly.hl.update

  -- Archivos sucios
  update("NvimTreeGitDirty", { fg = col.red })

  -- New / renamed
  update("NvimTreeGitNewIcon", { fg = col.yellow })
  update("NvimTreeGitRenamedIcon", { fg = col.yellow })
  update("NvimTreeGitFileNewHL", { fg = col.yellow })
  update("NvimTreeGitFileRenamedHL", { fg = col.yellow })
  update("NvimTreeGitFolderNewHL", { fg = col.yellow })
  update("NvimTreeGitFolderRenamedHL", { fg = col.yellow })

  -- Folder names
  update("NvimTreeFolderName", { fg = col.blue })
  update("NvimTreeOpenedFolderName", { fg = col.blue })
  update("NvimTreeEmptyFolderName", { fg = col.blue })
  update("NvimTreeSymlinkFolderName", { fg = col.blue })

  -- Folder icons
  update("NvimTreeFolderIcon", { fg = col.blue })
  update("NvimTreeOpenedFolderIcon", { fg = col.blue })
  update("NvimTreeClosedFolderIcon", { fg = col.blue })

  -- Executables
  update("NvimTreeExecFile", { fg = col.blue })
end

local function solid()
  local col = sabunv.moonfly.colors
  local uni = sabunv.moonfly.unified_colors.solid
  local update = sabunv.moonfly.hl.update

  -- fondo general
  update("NvimTreeNormal", { bg = col.alt_bg })
  -- fondo de delgada linea derecha
  update("NvimTreeNormalNC", { bg = col.alt_bg })
  -- parte baja (donde no hay ficheros)
  update("NvimTreeEndOfBuffer", { fg = "NONE", bg = "NONE" })
  -- separador al final
  update("NvimTreeWinSeparator", { fg = col.alt_bg, bg = col.alt_bg })
  -- linea del cursor (fondo y texto opcional)
  update("NvimTreeCursorLine", { bg = uni.light_line_bg })
  -- update("NvimTreeCursorLineNr", { bg = "NONE" })
end

local function transparent()
  local col = sabunv.moonfly.colors
  local uni = sabunv.moonfly.unified_colors.transparent
  local update = sabunv.moonfly.hl.update

  -- fondo general
  update("NvimTreeNormal", { bg = "NONE" })
  -- fondo de delgada linea derecha
  update("NvimTreeNormalNC", { bg = "NONE" })
  -- parte baja (donde no hay ficheros)
  update("NvimTreeEndOfBuffer", { bg = "NONE" })
  -- separador al final
  update("NvimTreeWinSeparator", { fg = uni.line_separator, bg = "NONE" })
  -- linea del cursor (fondo y texto opcional)
  update("NvimTreeCursorLine", { fg = uni.light_numbers, bg = "NONE" })
end

---@param state sabunv.moonfly.state
local function apply(state)
  common()

  if state.style == "solid" then
    solid()
  elseif state.style == "transparent" then
    transparent()
  else
    error("invalid moonfly style: " .. tostring(state.style))
  end
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
