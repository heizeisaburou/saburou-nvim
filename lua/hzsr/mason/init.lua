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

-- Las herramientas de build que necesitan el JDK. Lo demás —un binario ya
-- compilado, un `.tar.gz` que se descarga— se instala igual sin Java.
local JVM_BUILD_TOOLS = { "gradlew", "gradle", "mvnw", "mvn", "maven" }

M.get_pkgs = function()
  return nvchad.get_pkgs()
end

---@param message string
---@param level integer
local function notify(message, level)
  vim.notify(message, level, { title = "MasonInstallAll" })
end

---Los comandos con los que se construye un paquete, si es que se construye.
---
---`spec.source.build` es una entrada suelta (`{ run = "..." }`) o una lista con
---una por plataforma.
---@param source table|nil
---@return string[]
local function build_commands(source)
  local build = type(source) == "table" and source.build or nil
  if type(build) ~= "table" then
    return {}
  end
  if type(build.run) == "string" then
    return { build.run }
  end
  local runs = {}
  for _, entry in ipairs(build) do
    if type(entry) == "table" and type(entry.run) == "string" then
      runs[#runs + 1] = entry.run
    end
  end
  return runs
end

---¿Este paquete necesita un JDK para **instalarse**?
---
---No es una lista escrita a mano: se le pregunta al propio registro de Mason,
---que declara cómo se construye cada paquete. De todo lo que instalamos sólo
---`groovy-language-server` sale que sí (`./gradlew --no-daemon build`); el resto
---llega ya compilado, así que avisar del JDK al instalarlos era ruido puro.
---@param pkg table|nil el paquete de mason-registry
---@return boolean
function M.needs_jvm_build(pkg)
  if type(pkg) ~= "table" then
    return false
  end
  local ok, spec = pcall(function()
    return pkg.spec
  end)
  if not ok or type(spec) ~= "table" then
    return false
  end
  for _, run in ipairs(build_commands(spec.source)) do
    local lowered = run:lower()
    for _, tool in ipairs(JVM_BUILD_TOOLS) do
      if lowered:find(tool, 1, true) then
        return true
      end
    end
  end
  return false
end

-- La sonda de JDK se paga una vez por sesión, encuentre o no encuentre.
--
-- Sólo se recordaba el acierto, porque el único recuerdo era el `JAVA_HOME` que
-- se fijaba al encontrarlo. Sin JDK no quedaba rastro, así que cada llamada
-- volvía a sondear y a avisar: dos veces por `:MasonInstallAll` (el comando y
-- `install_all`) y una más por cada paquete que se instalara.
local probe = { done = false, home = nil, warned = false }

--- Deja el entorno listo para los paquetes que se compilan al instalar.
---
--- Hay que llamarla **antes** de que Mason arranque: el build hereda el
--- entorno vivo del proceso, y cuanto más tarde se prepare, más caminos de
--- instalación se quedan fuera.
---
--- Es idempotente y respeta un `JAVA_HOME` explícito: si el usuario ha
--- elegido JDK, no se le cambia por la espalda.
---
--- Y **sólo avisa cuando el aviso sirve**: si no hay JDK pero tampoco hay nada
--- que compilar, no se dice nada. Tener un JDK instalado no es un requisito de
--- esta configuración, así que exigirlo a quien instala `prettier` y `stylua`
--- era pedirle que arreglara un problema que no tiene.
---
---@param opts? { package?: table } el paquete que va a instalarse, cuando se
---sabe cuál es: es lo que decide si el aviso tiene sentido.
---@return string|nil java_home El JDK elegido, si se ha fijado alguno.
function M.prepare_build_env(opts)
  if vim.env.JAVA_HOME then
    return vim.env.JAVA_HOME
  end

  if not probe.done then
    probe.done = true
    probe.home = require("hzsr.sys.java").resolve_home {
      versions = BUILD_JAVA_VERSIONS,
      require_jdk = true,
    }
    if probe.home then
      vim.env.JAVA_HOME = probe.home
      notify("Compilando con JAVA_HOME=" .. probe.home, vim.log.levels.INFO)
    end
  end

  if probe.home then
    return probe.home
  end

  local pkg = opts and opts.package
  if pkg and not probe.warned and M.needs_jvm_build(pkg) then
    probe.warned = true
    notify(
      ("%s se compila al instalarse y no hay ningún JDK %s disponible. "):format(
        pkg.name or "El paquete",
        table.concat(BUILD_JAVA_VERSIONS, " ni ")
      ) .. "Gradle y Maven rechazan los JDK más nuevos que ellos mismos, así que "
        .. "la instalación va a fallar si el JDK del sistema va por delante.",
      vim.log.levels.WARN
    )
  end
  return nil
end

M.install_all = function()
  M.prepare_build_env()
  return nvchad.install_all()
end

return M
