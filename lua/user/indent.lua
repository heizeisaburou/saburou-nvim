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
    -- Tabs a propósito: con tabs la anchura NO se guarda en el archivo, la
    -- decide cada editor. Aquí se ven a 4; Obsidian los pinta según su propio
    -- `tabSize` en `.obsidian/app.json` (por defecto 2). Si los quieres iguales
    -- en los dos, cambia ese ajuste de Obsidian, no este: el archivo es el
    -- mismo. Con espacios la anchura quedaría fijada en el archivo y los dos
    -- editores tendrían que ponerse de acuerdo.
    markdown = {
      style = "tabs",
      width = 4,
    },
  },
}
