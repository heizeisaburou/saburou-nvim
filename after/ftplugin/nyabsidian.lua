-- .nyabsidian es Lua, pero con filetype propio ("nyabsidian") para que ninguna
-- config de markdown ni de lua genérica lo toque. Aquí se reclasifica a lua:
-- sintaxis, treesitter y formateo lua (stylua) aplican igualmente.
vim.bo.filetype = "lua"
