-- Shell de las terminales integradas (Alt+I y los splits):
--   auto     -> la shell en la que estás, heredada del árbol de procesos.
--               Si no se puede averiguar, cae a `system`.
--   system   -> `vim.o.shell` fuera de Windows; en Windows, `pwsh`,
--               Windows PowerShell 5.1 y `cmd.exe`, en ese orden.
--   "pwsh"   -> una shell concreta, por nombre. Si no está instalada, avisa
--               y usa la que elija el sistema.
--   { ... }  -> un comando completo con sus argumentos, p. ej.
--               `{ "nu", "--login" }`.
--
-- `auto` existe porque `$SHELL` no dice en qué shell estás, sino cuál es tu
-- shell de login: si abres pwsh desde zsh, `$SHELL` sigue diciendo zsh. Lo
-- único que lo sabe es el proceso padre de Neovim.
--
-- Esta preferencia no modifica `vim.o.shell`: `:!`, `:make` y los plugins
-- conservan la shell de ejecución configurada por Neovim.
return {
  shell = "auto",
}
