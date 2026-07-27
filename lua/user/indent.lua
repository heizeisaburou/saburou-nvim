-- Configuración de indentación.
-- Las claves de `filetypes` son los valores de `:set filetype?`.
-- Overrides temporales:
--   :IndentSet {spaces|tabs} [width] [filetype]
--   :IndentReset [filetype]
--   :IndentReset!  (todos)
return {
  default = {
    style = "spaces",
    width = 2,
  },

  filetypes = {
    -- CommonMark interpreta los tabs cada 4 columnas. Mantener width = 4 evita
    -- diferencias entre lo que muestra Neovim y lo que renderiza Obsidian.
    markdown = {
      style = "tabs",
      width = 4,
    },
  },
}
