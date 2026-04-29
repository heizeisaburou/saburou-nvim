-- hzsr.inp.pick.confirm

local M = {}

---@alias hzsr.inp.pick.confirm.result "yes"|"no"|"cancel"

---@class hzsr.inp.pick.confirm
---@field default? hzsr.inp.pick.confirm.result
---@field explicit_cancel? boolean
---@field async? boolean

---@class hzsr.inp.pick.confirm.internal
---@field default integer
---@field explicit_cancel boolean
---@field async boolean

---@param opts hzsr.inp.pick.confirm?
---@return hzsr.inp.pick.confirm.internal
local function parse_opts(opts)
  vim.validate("opts", opts, "table", true)

  opts = opts or {}

  ---@type hzsr.inp.pick.confirm.internal
  local int = vim.tbl_extend("force", {
    explicit_cancel = true,
  }, opts)

  vim.validate("opts.default", int.default, function(v)
    return v == nil or v == "yes" or v == "no" or v == "cancel"
  end, [["yes"|"no"|"cancel"?]])

  vim.validate("opts.explicit_cancel", int.explicit_cancel, "boolean")
  vim.validate("opts.async", int.async, "boolean", true)

  int.async = hzsr.async.handle_async(int.async)

  if int.default == nil then
    int.default = int.explicit_cancel and 3 or 2
  elseif int.default == "yes" then
    int.default = 1
  elseif int.default == "no" then
    int.default = 2
  elseif int.default == "cancel" then
    if not int.explicit_cancel then
      hzsr.err.Error
        .new(
          "hzsr.inp.pick.confirm",
          "INVALID_DEFAULT",
          "default='cancel' requiere explicit_cancel=true",
          {
            default = int.default,
            explicit_cancel = int.explicit_cancel,
          }
        )
        :raise()
    end

    int.default = 3
  end

  return int
end

-- Muestra un prompt de confirmación con `Yes` y `No`, y opcionalmente también `Cancel`.
--
-- Por defecto:
--   - si `explicit_cancel = true`, default = `"cancel"`
--   - si `explicit_cancel = false`, default = `"no"`
--
-- Retorno:
--   `"yes"`    => se eligió Yes
--   `"no"`     => se eligió No
--   `"cancel"` => se eligió Cancel o el prompt fue interrumpido/cancelado
--
---@param prompt string
---@param opts? hzsr.inp.pick.confirm
---@return hzsr.inp.pick.confirm.result
function M.confirm(prompt, opts)
  vim.validate("prompt", prompt, "string")

  local int = parse_opts(opts)

  local items = int.explicit_cancel and { "Yes", "No", "Cancel" } or { "Yes", "No" }
  local choice = hzsr.inp.pick.choose.adapter(prompt, items, int.default, int.async)

  if choice == 1 then
    return "yes"
  end

  if choice == 2 then
    return "no"
  end

  return "cancel"
end

return M
