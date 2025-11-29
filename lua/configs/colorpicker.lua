local noremap_silent = { noremap = true, silent = true }
local map = vim.keymap.set

-- h and l will increment the color slider value by 1.
-- u and i / a and d / A and D will increment the color slider value by 5.
-- s and w / S and W will increment the color slider value by 10.
-- o will change your color output
-- Number 0 to 9 will set the slider at your cursor to certain percentages. 0 sets to 0%, 9 sets to 90%, 5 sets to 50%.
-- H sets to 0%, M sets to 50%, L sets to 100%.

map("n", "<leader>i", "<cmd>PickColor<cr>", noremap_silent)
map("n", "<leader>i", "<cmd>PickColorInsert<cr>", noremap_silent)
-- vim.keymap.set("n", "your_keymap", "<cmd>ConvertHEXandRGB<cr>", opts)
-- vim.keymap.set("n", "your_keymap", "<cmd>ConvertHEXandHSL<cr>", opts)

require("color-picker").setup { -- for changing icons & mappings
    -- ["icons"] = { "ﱢ", "" },
    -- ["icons"] = { "ﮊ", "" },
    -- ["icons"] = { "", "ﰕ" },
    -- ["icons"] = { "", "" },
    -- ["icons"] = { "", "" },
    -- ["icons"] = { "ﱢ", "" },
    ["icons"] = { "", "" },
    ["border"] = "rounded", -- none | single | double | rounded | solid | shadow
    ["keymap"] = { -- mapping example:
        ["U"] = "<Plug>ColorPickerSlider5Decrease",
        ["O"] = "<Plug>ColorPickerSlider5Increase",
    },
    ["background_highlight_group"] = "Normal", -- default
    ["border_highlight_group"] = "FloatBorder", -- default
    ["text_highlight_group"] = "Normal", --default
}

vim.cmd [[hi FloatBorder guibg=NONE]] -- if you don't want weird border background colors around the popup.
