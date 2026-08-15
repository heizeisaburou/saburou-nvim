-- hzsr.mason.init

local M = {}

local nvchad = require "hzsr.mason.nvchad"

-- JDK con el que se compilan los paquetes de Mason que no llegan ya
-- construidos.
--
-- Gradle y Maven rechazan los JDK más nuevos que ellos mismos, así que el JDK
-- del sistema puede ir por delante de lo que la herramienta de build tolera.
-- Cuando eso pasa la instalación falla, y no hay nada que la configuración del
-- servidor pueda hacer: el problema ocurre antes de que exista el servidor.
--
-- Caso real: `groovy-language-server` se instala con `./gradlew build` y su
-- wrapper fija Gradle 9.1, de septiembre de 2025, que no conoce los JDK
-- posteriores.
local BUILD_JAVA_VERSIONS = { 21, 17 }

M.get_pkgs = function()
  return nvchad.get_pkgs()
end

---@param message string
---@param level integer
local function notify(message, level)
  vim.notify(message, level, { title = "MasonInstallAll" })
end

--- Deja el entorno listo para los paquetes que se compilan al instalar.
---
--- Hay que llamarla **antes** de que Mason arranque: el build hereda el
--- entorno vivo del proceso, y cuanto más tarde se prepare, más caminos de
--- instalación se quedan fuera.
---
--- Es idempotente y respeta un `JAVA_HOME` explícito: si el usuario ha
--- elegido JDK, no se le cambia por la espalda.
---
---@return string|nil java_home El JDK elegido, si se ha fijado alguno.
function M.prepare_build_env()
  if vim.env.JAVA_HOME then
    return vim.env.JAVA_HOME
  end

  local home = require("hzsr.sys.java").resolve_home {
    versions = BUILD_JAVA_VERSIONS,
    require_jdk = true,
  }

  if not home then
    notify(
      "No hay un JDK "
        .. table.concat(BUILD_JAVA_VERSIONS, " ni ")
        .. " disponible. Los paquetes que se compilan con Gradle o Maven van a "
        .. "fallar si el JDK del sistema es más nuevo que su herramienta de build.",
      vim.log.levels.WARN
    )
    return nil
  end

  vim.env.JAVA_HOME = home
  notify("Compilando con JAVA_HOME=" .. home, vim.log.levels.INFO)
  return home
end

M.install_all = function()
  M.prepare_build_env()
  return nvchad.install_all()
end

return M
