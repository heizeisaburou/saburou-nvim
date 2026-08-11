-- hzsr/sync.lua — Sync de directorios (origen → destino).
-- Uso CLI (headless): nvim --headless -u NONE -c "lua dofile('$HOME/.config/hzsr12/lua/hzsr/sync.lua').deploy('SRC','DST')" -c "qa!"
-- Uso nvim: :Synco [origen] [destino]
-- Defaults: ~/.config/hzsr12 → ~/.config/nvim

local M = {}

local DEFAULTS = {
  src = vim.fn.expand("~/.config/hzsr12"),
  dst = vim.fn.expand("~/.config/nvim"),
}

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
    cmd = { "rsync", "-a", "--delete", "--exclude", ".git", src .. "/", dst .. "/" }
  else
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
