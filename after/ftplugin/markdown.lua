-- gx en un vault usa exactamente el resolvedor de adjuntos de Nyabsidian.
-- Fuera de un vault conserva el flujo independiente de Marksman/Markdown.

vim.keymap.set("n", "gx", function()
  local bufnr = vim.api.nvim_get_current_buf()
  local attachments = require "lzy.obsidian.attachments"
  if attachments.in_vault(bufnr) then
    if attachments.open_under_cursor(bufnr) then
      return
    end
  else
    local md = require "sabunv.nvim.markdown"
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local target = md.ref_target(bufnr, row, col)
    if target and md.open(target, { bufnr = bufnr }) then
      return
    end
  end
  -- Fallback al estilo netrw: abrir el cWORD con el visor del sistema.
  -- expand("<cWORD>") puede fallar (E348) si no hay palabra bajo el cursor.
  local ok, word = pcall(vim.fn.expand, "<cWORD>")
  if ok and word ~= "" then
    vim.ui.open(word)
  end
end, { buffer = true, desc = "Abrir enlace o adjunto bajo el cursor" })
