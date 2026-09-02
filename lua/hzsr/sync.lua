-- hzsr/sync.lua — Sync de directorios (origen → destino).
-- Uso CLI (headless): nvim --headless -u NONE -c "lua dofile('$HOME/.config/hzsr12/lua/hzsr/sync.lua').deploy('SRC','DST')" -c "qa!"
-- Uso nvim: :Synco [origen] [destino]
-- Defaults: ~/.config/hzsr12 → ~/.config/nvim

local M = {}

local DEFAULTS = {
  src = vim.fn.expand("~/.config/hzsr12"),
  dst = vim.fn.expand("~/.config/nvim"),
}

--- Lo que no se copia nunca, porque no es la configuración: es lo que cada
--- instalación genera para sí misma.
---
--- `.luarc.json` es el caso importante. Lleva rutas absolutas al directorio de
--- plugins del NVIM_APPNAME que lo generó (`~/.local/share/<appname>/lazy`), así
--- que copiarlo deja al destino mirando la biblioteca del origen. Cada uno
--- genera el suyo con `:Luarc!`. `lazy-lock.json` es lo mismo con las versiones
--- de los plugins, y el log no es de nadie.
---
--- El `.git` sí se copia: esto reemplaza la carpeta entera, historia incluida.
--- Así el destino queda siendo el origen y su `git status` vuelve a enseñar solo
--- lo que se le haya cambiado encima a mano, en vez de mezclarlo con todo lo que
--- haya avanzado el origen desde la última copia. La contrapartida es que un
--- commit que solo exista en el destino desaparece: esto es un espejo, no una
--- sincronización de ida y vuelta.
local EXCLUDES = { ".luarc.json", "lazy-lock.json", "nvim.log" }

--- Sincroniza src → dst (rsync; fallback cp). Devuelve true/false.
---@param src string|?
---@param dst string|?
function M.deploy(src, dst)
  src = vim.fs.normalize(src and vim.fn.expand(src) or DEFAULTS.src)
  dst = vim.fs.normalize(dst and vim.fn.expand(dst) or DEFAULTS.dst)

  if vim.fn.isdirectory(src) ~= 1 then
    vim.notify("Sync: no existe el origen " .. src, vim.log.levels.ERROR, { title = "Sync" })
    return false
  end

  local cmd
  if vim.fn.executable("rsync") == 1 then
    cmd = { "rsync", "-a", "--delete" }
    for _, name in ipairs(EXCLUDES) do
      vim.list_extend(cmd, { "--exclude", name })
    end
    vim.list_extend(cmd, { src .. "/", dst .. "/" })
  else
    -- `cp` no sabe excluir: copia de más y no borra de menos. Sirve para salir
    -- del paso, pero el destino queda con el `.luarc.json` del origen.
    cmd = { "cp", "-a", src .. "/.", dst .. "/" }
  end

  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    vim.notify("Sync falló:\n" .. out, vim.log.levels.ERROR, { title = "Sync" })
    return false
  end

  vim.notify(("Sync OK: %s → %s"):format(src, dst), vim.log.levels.INFO, { title = "Sync" })
  return true
end

return M
