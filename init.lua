-- init [entrypoint]

-- instanciar variables globables
require "hzsr" -- biblioteca de nvim (heizeisaburou)
require "sabunv" -- biblioteca de esta config (saburou-nvim)

-- configuración de usuario
require("user").setup()

-- folke/lazy.nvim
hzsr.lzy.setup()

-- Instala comando :Luarc [NVIM_APPNAME]
sabunv.nvim.luarc.setup()

-- Persistencia del tema
-- sabunv.moonfly.state()
