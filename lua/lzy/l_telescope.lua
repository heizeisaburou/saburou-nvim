-- lzy.l_telescope

local M = {}

local telescope = require "telescope"
local actions = require "telescope.actions"

---@type table
M.config = {
  defaults = {
    prompt_prefix = "   ",
    selection_caret = " ",
    entry_prefix = " ",
    sorting_strategy = "ascending",
    layout_config = {
      horizontal = {
        prompt_position = "top",
        preview_width = 0.55,
      },
      width = 0.87,
      height = 0.80,
    },
    mappings = {
      n = {
        ["q"] = actions.close,
      },
    },
  },

  extensions = {},
}

M.extensions = {
  "themes",
  "terms",
}

function M.setup(config)
  if config == true then
    config = M.config
  end

  config = config or M.config

  telescope.setup(config)

  for _, extension in ipairs(M.extensions) do
    pcall(telescope.load_extension, extension)
  end

  pcall(vim.keymap.del, "n", "<leader>fo")

  vim.keymap.set("n", "<leader>fr", function()
    require("telescope.builtin").oldfiles()
  end, { desc = "Telescope: Find recent Files" })
end

return M
