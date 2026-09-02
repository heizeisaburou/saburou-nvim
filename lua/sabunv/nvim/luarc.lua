-- sabunv.nvim.luarc

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("Luarc", function(opts)
    local appname = opts.args ~= "" and opts.args or nil

    -- `:Luarc` abre el buffer para que lo mires antes de guardar; `:Luarc!` lo
    -- escribe y ya, que es lo que hace falta desde un script o headless.
    if not opts.bang then
      hzsr.nvim.luarc.create_buffer(appname)
      return
    end

    local ok, result = hzsr.nvim.luarc.write(appname)
    vim.notify(
      ok and ("Luarc: escrito " .. result) or ("Luarc: " .. result),
      ok and vim.log.levels.INFO or vim.log.levels.ERROR,
      { title = "Luarc" }
    )
  end, {
    bang = true,
    nargs = "?",
    desc = "Create .luarc.json buffer (:Luarc! lo escribe sin abrirlo)",
  })
end

return M
