-- .nyabsidian es JSON, pero con filetype propio ("nyabsidian") para que ninguna
-- config de markdown ni de json genérica lo toque. Aquí se reclasifica a json:
-- sintaxis, LSP y formateo json aplican igualmente.
vim.bo.filetype = "json"
