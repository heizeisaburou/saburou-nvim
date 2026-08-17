-- lzy/l_mason

local M = {}

M.opts = {
  PATH = "skip",

  ui = {
    icons = {
      package_pending = " ",
      package_installed = " ",
      package_uninstalled = " ",
    },
  },

  -- Los gestores usados por Mason (npm, pip, cargo...) ya pueden descargar en
  -- paralelo internamente; limitarlos evita saturar la red durante el bootstrap.
  max_concurrent_installers = 3,
}

function M.init_setup()
  local mason_bin = vim.fs.joinpath(vim.fn.stdpath "data", "mason", "bin")
  local current_path = vim.env.PATH or ""
  local path_entries = vim.split(current_path, hzsr.sys.path_list_sep, {
    plain = true,
    trimempty = true,
  })
  local normalized_mason_bin = vim.fs.normalize(mason_bin)

  local has_mason_bin = vim.iter(path_entries):any(function(path)
    local normalized = vim.fs.normalize(path)
    if hzsr.sys.iswin then
      return normalized:lower() == normalized_mason_bin:lower()
    end
    return normalized == normalized_mason_bin
  end)

  if not has_mason_bin then
    vim.env.PATH = current_path == "" and mason_bin or (mason_bin .. hzsr.sys.path_list_sep .. current_path)
  end

  vim.api.nvim_create_user_command("MasonInstallAll", function()
    -- El JDK de compilación se prepara antes de cargar Mason: los paquetes que
    -- se construyen al instalar heredan el entorno vivo, y Mason fotografía el
    -- suyo al cargarse. Preparar después deja fuera parte de los caminos.
    require("hzsr.mason").prepare_build_env()

    -- Carga mason.nvim si sigue lazy.
    local ok_lazy, lazy = pcall(require, "lazy")
    if ok_lazy then
      lazy.load { plugins = { "mason.nvim" } }
    end

    require("hzsr.mason").install_all()
  end, {})
end

function M.setup()
  ---@diagnostic disable-next-line
  require("mason").setup(M.opts)

  -- Cualquier instalación prepara antes el JDK de compilación, venga de
  -- :MasonInstallAll o de la UI de Mason. El evento se emite justo antes de
  -- ejecutar el instalador, y el build hereda el entorno vivo del proceso, así
  -- que llega a tiempo. `prepare_build_env` es idempotente: la sonda de JDK se
  -- paga una vez por sesión y solo si se instala algo.
  --
  -- Aquí es el único sitio donde se sabe QUÉ se está instalando, y por eso es el
  -- único que puede avisar de que falta el JDK: sin el paquete delante, avisar
  -- sería adivinar.
  local ok_registry, registry = pcall(require, "mason-registry")
  if ok_registry then
    registry:on("package:install:handle", function(handle)
      require("hzsr.mason").prepare_build_env { package = handle and handle.package }
    end)
  end
end

return M
