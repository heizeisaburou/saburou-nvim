-- Neovim no trae ftplugin de D2, así que `commentstring` se queda vacío y `gc`
-- falla con "commentstring is empty". El comentario de línea es `#`; el de
-- bloque, `""" ... """`.
vim.bo.commentstring = "# %s"
vim.b.undo_ftplugin = (vim.b.undo_ftplugin and vim.b.undo_ftplugin .. " | " or "")
  .. "setlocal commentstring<"
