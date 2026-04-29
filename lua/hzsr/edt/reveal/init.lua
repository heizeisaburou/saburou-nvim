-- hzsr.edt.reveal

local M = {}

-- -----------------------------------------------------------------------------
-- Reveal
--
-- Abstracción para hacer visible el buffer objetivo durante operaciones
-- interactivas como save/close.
--
-- El reveal decide cómo enfocar/mostrar el buffer, pero las operaciones sólo
-- consumen la interfaz común: activate/deactivate/ask/confirm/etc.

---Cómo se comporta reveal respecto al foco.
---@enum hzsr.edt.reveal.mode
M.mode = {
  NONE = "none", -- No activa reveal.

  ENTER = "enter", -- Entra al objetivo y deja el foco ahí.

  RESTORE = "restore", -- Entra al objetivo y restaura el foco al terminar.
}

---Estrategia usada para mostrar/enfocar el buffer objetivo.
---@enum hzsr.edt.reveal.strategy
M.strategy = {
  SIMPLE = "simple", -- Reveal basado en ventanas/tabs existentes.

  -- Futuro:
  -- FLOATING = "floating", -- Reveal con UI flotante propia.
  -- TAB = "tab", -- Reveal con tab temporal dedicada.
}

-- -----------------------------------------------------------------------------

M.simple = require "hzsr.edt.reveal.simple"
M.factory = require "hzsr.edt.reveal.factory"
M.new = M.factory.new

return M
