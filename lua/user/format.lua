-- Configuración de formateo.
--
-- `line_length` es el ancho por defecto: a partir de cuántas columnas un
-- formateador considera que una línea es demasiado larga. Lo consume
-- lzy.conform y se lo pasa a cada herramienta con el flag que use cada una
-- (`--print-width`, `--line-length`, `--max_width`...).
--
-- Es un default, no una imposición. Los formateadores que leen configuración
-- de proyecto ceden ante ella: un `.prettierrc` o un `.editorconfig` en el
-- repositorio manda sobre este valor, y esto solo se usa cuando no hay ninguno.
--
-- `85` coincide con el ancho de Obsidian y es probable que coincida con el del
-- usuario. `97` queda bien con `JetBrainsMono Nerd Font` de `11px`; probado en
-- Kitty con zsh y en la Terminal de Windows con PowerShell.
--
-- Markdown es el caso aparte: su prosa no se ajusta a ningún ancho, se deja en
-- una línea por párrafo. Ver lzy.conform.
return {
  line_length = 85,
}
