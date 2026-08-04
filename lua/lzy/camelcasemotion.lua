local M = {}

local map = vim.keymap.set
local noremap_silent = { noremap = true, silent = true }
local function opts(desc)
  return vim.tbl_extend("force", noremap_silent, { desc = desc })
end

function M.setup()
  map({ "n", "x" }, "]w", "<Plug>CamelCaseMotion_w", opts "CamelCaseMotion: next segment")
  map({ "n", "x" }, "[b", "<Plug>CamelCaseMotion_b", opts "CamelCaseMotion: previous segment")
  map({ "n", "x" }, "]e", "<Plug>CamelCaseMotion_e", opts "CamelCaseMotion: end next segment")
  map({ "n", "x" }, "[g", "<Plug>CamelCaseMotion_ge", opts "CamelCaseMotion: end previous segment")
end

return M
