-- gx en markdown: adjuntos y URLs se resuelven con sabunv.nvim.markdown
-- (rutas reales del vault, no la predicción de attachments.folder). El resto
-- cae en vim.ui.open con el cWORD, como haría el netrw original (aquí
-- deshabilitado en rtp.disabled_plugins, así que sin esto gx no existe).

local md = require "sabunv.nvim.markdown"

vim.keymap.set("n", "gx", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local target = md.ref_target(bufnr, row, col)
  if target and md.open(target, { bufnr = bufnr }) then
    return
  end
  -- Fallback al estilo netrw: abrir el cWORD con el visor del sistema.
  -- expand("<cWORD>") puede fallar (E348) si no hay palabra bajo el cursor.
  local ok, word = pcall(vim.fn.expand, "<cWORD>")
  if ok and word ~= "" then
    vim.ui.open(word)
  end
end, { buffer = true, desc = "Abrir enlace o adjunto bajo el cursor" })