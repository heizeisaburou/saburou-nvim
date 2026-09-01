-- sabunv.wrap

-- Política de ajuste de línea por filetype.
--
-- Antes esto vivía como tres líneas dentro de `after/ftplugin/markdown.lua`:
-- funcionaba, pero no había forma de saber de dónde salía ni de cambiarlo sin
-- editar fontanería. La decisión vive ahora en `lua/user/wrap.lua`, junto al
-- resto de lo que se toca a mano.
--
-- El mecanismo de bajo nivel es `hzsr.win.wrap`, que liga el valor al buffer
-- dentro de la ventana; aquí solo se decide qué valor toca.

local M = {}

---@class sabunv.wrap.user_config
---@field default boolean
---@field filetypes table<string, boolean>

---@type sabunv.wrap.user_config?
local user_config

---@param config any
---@return sabunv.wrap.user_config
local function validate_user_config(config)
  assert(type(config) == "table", "La configuración de wrap debe ser una tabla")
  assert(type(config.default) == "boolean", "wrap.default debe ser true o false")

  local normalized = { default = config.default, filetypes = {} }

  for filetype, enabled in pairs(config.filetypes or {}) do
    assert(
      type(filetype) == "string" and filetype ~= "",
      "wrap.filetypes contiene un filetype inválido"
    )
    assert(
      type(enabled) == "boolean",
      "wrap.filetypes." .. filetype .. " debe ser true o false"
    )
    normalized.filetypes[filetype] = enabled
  end

  return normalized
end

--- Ajuste que le corresponde a un filetype.
---@param filetype? string
---@return boolean
function M.get(filetype)
  assert(user_config, "sabunv.wrap.setup debe ejecutarse antes de usar la política")

  local configured = user_config.filetypes[filetype or ""]
  if configured ~= nil then
    return configured
  end

  return user_config.default
end

--- `true` si el usuario ya decidió a mano para este buffer.
---
--- A partir de ese momento la política deja de tocarlo: abrirlo en otra ventana
--- respeta lo que eligió, no lo que diga la tabla.
---@param bufnr integer
---@return boolean
local function decided_by_hand(bufnr)
  return vim.b[bufnr].sabunv_wrap_touched == true
end

--- Aplica la política a las ventanas que muestran un buffer.
---@param bufnr integer
function M.apply(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) or decided_by_hand(bufnr) then
    return
  end

  local enabled = M.get(vim.bo[bufnr].filetype)

  for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
    if enabled then
      hzsr.win.wrap.enable(winid)
    else
      hzsr.win.wrap.disable(winid)
    end
  end
end

--- Alterna el ajuste de la ventana actual y marca el buffer como decidido.
---@return boolean enabled Estado en el que queda.
function M.toggle()
  local enabled = hzsr.win.wrap.toggle()
  vim.b.sabunv_wrap_touched = true

  return enabled
end

---@param config sabunv.wrap.user_config
function M.setup(config)
  user_config = validate_user_config(config)

  -- `FileType` es cuando se sabe qué política toca; `BufWinEnter` es cuando el
  -- buffer llega a una ventana nueva, que puede ser mucho después (un `:split`
  -- de un archivo ya cargado no vuelve a disparar `FileType`). Hacen falta los
  -- dos, y `decided_by_hand` evita que el segundo pise un `<A-w>`.
  vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
    group = vim.api.nvim_create_augroup("SabunvWrapPolicy", { clear = true }),
    callback = function(args)
      M.apply(args.buf)
    end,
    desc = "Aplicar la política de ajuste de línea del filetype",
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    M.apply(bufnr)
  end
end

return M
