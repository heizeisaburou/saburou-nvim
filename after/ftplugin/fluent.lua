-- Neovim detecta `.ftl` como `fluent` pero no trae ftplugin, así que
-- `commentstring` se queda vacío y `gc` falla con "commentstring is empty".
-- Fluent solo tiene comentarios de línea: `#`, `##` (grupo) y `###` (fichero).
vim.bo.commentstring = "# %s"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin and vim.b.undo_ftplugin .. " | " or "")
  .. "setlocal commentstring<"
