-- Shell de las terminales integradas en Windows:
--   auto       -> `pwsh`, Windows PowerShell 5.1 o `cmd.exe`, en ese orden.
--   pwsh       -> PowerShell 7; si no está instalado, avisa y usa `cmd.exe`.
--   powershell -> Windows PowerShell 5.1; si no está disponible, usa `cmd.exe`.
--   cmd        -> `cmd.exe` siempre.
--
-- Esta preferencia no modifica `vim.o.shell`: `:!`, `:make` y los plugins
-- conservan la shell de ejecución configurada por Neovim.
return {
  windows_shell = "auto",
}
