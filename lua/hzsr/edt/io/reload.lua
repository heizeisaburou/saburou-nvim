-- hzsr.edt.io.reload

local M = {}

local IO = require "hzsr.edt.io.detail"
local Save = require "hzsr.edt.io.save.save"

---@class hzsr.edt.io.reload.opts
---@field explicit_cancel? boolean
---@field reveal_mode? hzsr.edt.reveal.mode
---@field reveal_strategy? hzsr.edt.reveal.strategy
---@field reveal_hl? string
---@field async? boolean

---@class hzsr.edt.io.reload.opts.internal : hzsr.edt.io.reveal_opts
---@field explicit_cancel boolean

---@param bufnr integer?
---@param opts hzsr.edt.io.reload.opts?
---@return integer
---@return hzsr.edt.io.reload.opts.internal
local function parse_args(bufnr, opts)
  vim.validate("bufnr", bufnr, "number", true)
  vim.validate("opts", opts, "table", true)

  local target = hzsr.buf.resolve(bufnr)
  opts = opts or {}

  vim.validate("opts.explicit_cancel", opts.explicit_cancel, "boolean", true)
  vim.validate("opts.reveal_mode", opts.reveal_mode, function(value)
    return value == nil or hzsr.enum.one_of(value, hzsr.edt.reveal.mode)
  end, "hzsr.edt.reveal.mode?")
  vim.validate("opts.reveal_strategy", opts.reveal_strategy, function(value)
    return value == nil or hzsr.enum.one_of(value, hzsr.edt.reveal.strategy)
  end, "hzsr.edt.reveal.strategy?")
  vim.validate("opts.reveal_hl", opts.reveal_hl, "string", true)
  vim.validate("opts.async", opts.async, "boolean", true)

  ---@type hzsr.edt.io.reload.opts.internal
  local internal = vim.tbl_extend("force", {
    explicit_cancel = true,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = "DiffChange",
  }, opts)

  internal.async = hzsr.async.handle_async(internal.async, "hzsr.edt.io.reload")

  return target, internal
end

---@param reveal hzsr.edt.reveal.Reveal
---@param bufnr integer
---@param opts hzsr.edt.io.reload.opts.internal
---@return "reload"|"save"|"discard"|"cancel"
local function confirm_modified(reveal, bufnr, opts)
  if not vim.bo[bufnr].modified then
    return "reload"
  end

  local prompt = ("¿Guardar cambios antes de recargar '%s'?"):format(hzsr.buf.gen_label(bufnr))
  local answer = reveal:confirm(prompt, {
    default = opts.explicit_cancel and "cancel" or "no",
    explicit_cancel = opts.explicit_cancel,
  })

  if answer == "yes" then
    return "save"
  end

  if answer == "cancel" then
    return "cancel"
  end

  return "discard"
end

---@param bufnr integer
---@param opts hzsr.edt.io.reload.opts.internal
---@return hzsr.edt.io.save.out
local function save_before_reload(bufnr, opts)
  return Save.save(bufnr, {
    path = nil,
    path_policy = hzsr.edt.io.path_policy.AUTO,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = opts.explicit_cancel,
    reveal_mode = hzsr.edt.reveal.mode.NONE,
    reveal_strategy = opts.reveal_strategy,
    reveal_hl = opts.reveal_hl,
    async = opts.async,
  })
end

---Recarga un buffer desde disco conservando la vista. Si hay cambios locales,
---permite guardarlos, descartarlos o cancelar la operación.
---@param bufnr integer?
---@param opts hzsr.edt.io.reload.opts?
---@return hzsr.edt.io.reload.out
function M.reload(bufnr, opts)
  local target, internal = parse_args(bufnr, opts)
  local path = vim.api.nvim_buf_get_name(target)

  if path == "" or vim.bo[target].buftype ~= "" then
    return IO.make_out(
      hzsr.edt.io.status.REJECT,
      target,
      path ~= "" and path or nil,
      "el buffer no representa un archivo recargable"
    )
  end

  local reveal = IO.new_reveal(target, internal)

  return IO.with_reveal(reveal, function()
    local decision = confirm_modified(reveal, target, internal)

    if decision == "cancel" then
      return IO.make_out(hzsr.edt.io.status.CANCEL, target, path, "recarga cancelada")
    end

    if decision == "save" then
      local save_out = save_before_reload(target, internal)

      if save_out.status ~= hzsr.edt.io.status.SUCCESS then
        return IO.make_out(save_out.status, target, path, "recarga abortada al guardar", {
          save_status = save_out.status,
          write_status = save_out.write_status,
          existing_buf = save_out.existing_buf,
        })
      end
    end

    if not reveal:activate() then
      return IO.make_out(hzsr.edt.io.status.ERROR, target, path, "no se pudo enfocar el buffer para recargarlo")
    end

    local view = vim.fn.winsaveview()
    local ok, err = pcall(vim.cmd.edit, { bang = decision == "discard" })

    if not ok then
      return IO.make_out(hzsr.edt.io.status.ERROR, target, path, tostring(err))
    end

    vim.fn.winrestview(view)

    return IO.make_out(hzsr.edt.io.status.SUCCESS, target, path, "recarga correcta")
  end)
end

return M
