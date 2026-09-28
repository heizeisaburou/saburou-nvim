local M = {}

local map = vim.keymap.set
local noremap_silent = { noremap = true, silent = true }
local function opts(desc)
  return vim.tbl_extend("force", noremap_silent, { desc = desc })
end

function M.setup()
  -- `\` y `|` en lugar de un prefijo con corchete: son una sola pulsación, así
  -- que la acción se encadena repitiendo la tecla (`\\\\`) en vez de teclear
  -- `]w` cuatro veces. `\` es la única tecla que Neovim documenta como «not
  -- used» en modo normal, y el builtin de `|` (ir a la columna N) lo cubre `0`.
  map({ "n", "x", "o" }, "\\", "<Plug>CamelCaseMotion_w", opts "CamelCaseMotion: next segment")
  map({ "n", "x", "o" }, "|", "<Plug>CamelCaseMotion_b", opts "CamelCaseMotion: previous segment")
  map({ "n", "x" }, "]e", "<Plug>CamelCaseMotion_e", opts "CamelCaseMotion: end next segment")
  map({ "n", "x" }, "[g", "<Plug>CamelCaseMotion_ge", opts "CamelCaseMotion: end previous segment")
end

return M
