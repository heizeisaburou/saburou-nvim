-- Mappings del preview compartidos por todos los pickers de Snacks.

local M = {}

local function preview_hscroll(left, columns)
  return function(picker)
    local preview = picker.preview and picker.preview.win
    if not preview or not preview:valid() then
      return
    end
    for _ = 1, columns do
      preview:hscroll(left)
    end
  end
end

local function horizontal_preview_keys(modes)
  return {
    ["<A-H>"] = { "preview_scroll_left", mode = modes },
    ["<A-L>"] = { "preview_scroll_right", mode = modes },
    ["<A-h>"] = { "preview_scroll_left_fast", mode = modes },
    ["<A-l>"] = { "preview_scroll_right_fast", mode = modes },
  }
end

-- <C-u> y <C-BS> borran la palabra anterior en el prompt, igual que <C-w>
-- (que ya viene así por default en Snacks). Mismo mapeo que usa Snacks
-- internamente para su <C-w> (ver snacks/picker/config/defaults.lua:
-- `["<C-w>"] = { "<c-s-w>", mode = { "i" }, expr = true, desc = "delete word" }`).
local delete_word_backward = { "<c-s-w>", mode = { "i" }, expr = true, desc = "delete word" }

M.config = {
  enabled = true,
  actions = {
    preview_scroll_left_fast = preview_hscroll(true, 10),
    preview_scroll_right_fast = preview_hscroll(false, 10),
  },
  win = {
    -- Sobrescribe `<A-h>` de Snacks (`toggle_hidden`) y evita que los
    -- mappings globales `10zh`/`10zl` se inserten como texto en el prompt.
    -- El contrato queda idéntico al preview de Telescope.
    input = {
      keys = vim.tbl_extend("force", horizontal_preview_keys({ "i", "n" }), {
        ["<C-u>"] = delete_word_backward,
        ["<C-BS>"] = delete_word_backward,
      }),
    },
    list = { keys = horizontal_preview_keys({ "n" }) },
  },
}

return M
