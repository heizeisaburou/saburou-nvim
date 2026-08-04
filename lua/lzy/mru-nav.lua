local M = {}

local mru_nav = require "mru_nav"

local function set_maps()
  local map = vim.keymap.set
  map("n", "<leader>mf", mru_nav.mru_files, { desc = "Telescope: File picker" })
  map("n", "<leader>mb", mru_nav.mru_buffers, { desc = "Telescope: Buffer picker" })
end

function M.setup()
  mru_nav.setup()
  set_maps()
end

return M
