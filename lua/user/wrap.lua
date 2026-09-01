-- Ajuste de línea (`wrap`) por lenguaje.
--
-- `default` vale para todo lo que no aparezca en `filetypes`. Las claves de
-- `filetypes` son los valores de `:set filetype?`.
--
-- Markdown va ajustado porque el formateador no corta la prosa: un párrafo es
-- una línea, por larga que sea, y el ajuste lo pone el editor (ver
-- lzy.conform). Cortarla en el archivo se ve mal en Obsidian y en cualquier
-- editor gráfico de markdown.
--
-- Esto es el valor de partida de cada archivo, no una imposición: `<A-w>` lo
-- alterna, y lo que decidas manda hasta que cierres el archivo.
return {
  default = false,

  filetypes = {
    markdown = true,
  },
}
