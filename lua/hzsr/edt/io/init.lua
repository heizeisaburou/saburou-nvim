-- hzsr.edt.io

local M = {}

-- -----------------------------------------------------------------------------
-- Enums públicos de IO editorial.
--
-- Se exponen directamente en `hzsr.edt.io` para que caller e implementación usen
-- la misma fuente de verdad:
--
--   hzsr.edt.io.status.SUCCESS
--   hzsr.edt.io.path_policy.AUTO
--   hzsr.edt.io.conflict_policy.CONFIRM
--   hzsr.edt.io.modified_policy.CONFIRM
--   hzsr.edt.io.window_policy.REPLACE
--
-- Internamente siguen siendo tablas enum normales y se validan con:
--
--   hzsr.enum.one_of(value, hzsr.edt.io.status)

---Qué hacer con cambios pendientes al cerrar.
---@enum hzsr.edt.io.modified_policy
M.modified_policy = {
  CONFIRM = "confirm", -- Preguntar al usuario.
  SAVE = "save", -- Guardar antes de cerrar.
  DISCARD = "discard", -- Descartar cambios.
  REQUIRE = "require", -- Rechazar si hay cambios.
}

---Qué hacer con las ventanas que muestran un buffer normal al cerrarlo.
---@enum hzsr.edt.io.window_policy
M.window_policy = {
  REPLACE = "replace", -- Sustituir por un buffer válido.
  CLOSE = "close", -- Cerrar ventanas contenedoras.
  DEFAULT = "default", -- Dejar que Neovim resuelva.
}

---Resultado común de operaciones editoriales.
---@enum hzsr.edt.io.status
M.status = {
  SUCCESS = "success", -- Operación completada.
  CANCEL = "cancel", -- Cancelación explícita.
  REJECT = "reject", -- Rechazo por política/usuario.
  ERROR = "error", -- Error inesperado o de ejecución.
}

---Cómo obtener la ruta de destino.
---@enum hzsr.edt.io.path_policy
M.path_policy = {
  AUTO = "auto", -- Usar ruta disponible o preguntar.
  ASK = "ask", -- Preguntar siempre.
  REQUIRE = "require", -- Exigir ruta explícita.
}

---Cómo resolver conflictos de sobrescritura.
---@enum hzsr.edt.io.conflict_policy
M.conflict_policy = {
  CONFIRM = "confirm", -- Preguntar antes de sobrescribir.
  FORCE = "force", -- Sobrescribir sin preguntar.
  REQUIRE = "require", -- Rechazar si requiere sobrescritura.
}

-- -----------------------------------------------------------------------------

M.detail = require "hzsr.edt.io.detail"

M.save = require "hzsr.edt.io.save"
M.close = require "hzsr.edt.io.close"

return M
