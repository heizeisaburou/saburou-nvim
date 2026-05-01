-- hzsr.edt.io.close.close

local M = {}

local Detail = require "hzsr.edt.io.close.detail"
local IO = require "hzsr.edt.io.detail"

-- -----------------------------------------------------------------------------

---@class hzsr.edt.io.close.opts
---@field modified_policy? hzsr.edt.io.modified_policy
---@field conflict_policy? hzsr.edt.io.conflict_policy
---@field explicit_cancel? boolean
---@field path_policy? hzsr.edt.io.path_policy
---@field reveal_mode? hzsr.edt.reveal.mode
---@field reveal_strategy? hzsr.edt.reveal.strategy
---@field reveal_hl? string
---@field window_policy? hzsr.edt.io.window_policy
---@field exit_last? boolean
---@field async? boolean

---@class hzsr.edt.io.close.opts.internal : hzsr.edt.io.reveal_opts
---@field modified_policy hzsr.edt.io.modified_policy
---@field conflict_policy hzsr.edt.io.conflict_policy
---@field explicit_cancel boolean
---@field path_policy hzsr.edt.io.path_policy
---@field window_policy hzsr.edt.io.window_policy
---@field exit_last boolean

---@alias hzsr.edt.io.close.modified_opts
---| hzsr.edt.io.close.opts.internal
---| hzsr.edt.io.close_multi.opts.internal

---@alias hzsr.edt.io.close.modified_decision
---| "save"
---| "save_all"
---| "discard"
---| "discard_all"
---| "reject"
---| "cancel"

-- -----------------------------------------------------------------------------

---@param bufnr integer
---@param was_normal boolean
---@param opts hzsr.edt.io.close.opts.internal
---@return boolean ok
---@return string? err
local function maybe_exit_last(bufnr, was_normal, opts)
  if not opts.exit_last then
    return true, nil
  end

  if not was_normal then
    return true, nil
  end

  if not M.would_leave_no_meaningful_normal(bufnr) then
    return true, nil
  end

  local ok, err = pcall(function()
    vim.cmd "qall"
  end)

  if not ok then
    return false, tostring(err)
  end

  return true, nil
end

-- -----------------------------------------------------------------------------

---Cierra un buffer.
---
---@param bufnr integer?
---@param opts hzsr.edt.io.close.opts?
---@return hzsr.edt.io.close.out
function M.close(bufnr, opts)
  local b, o = Detail.parse_close_args(bufnr, opts)
  local path = Detail.get_buffer_path(b)
  local was_normal = hzsr.buf.filter.normal(b)

  -- Si está modificado dependiendo de las políticas guardamos directamente, preguntamos, ... etc.
  local decision = Detail.resolve_modified_decision(b, o, false)

  if decision == "save_all" then
    -- Esta función trabaja con un solo buffer, así save_all == save
    decision = "save"
  elseif decision == "discard_all" then
    decision = "discard"
  end

  if decision == "cancel" then
    return IO.make_out(hzsr.edt.io.status.CANCEL, b, path, "cierre cancelado")
  end

  if decision == "reject" then
    return IO.make_out(
      hzsr.edt.io.status.REJECT,
      b,
      path,
      "cierre rechazado: el buffer tiene cambios pendientes"
    )
  end

  if decision == "save" then
    local save_out = Detail.save_before_close(b, o)
    local failure_out = Detail.make_close_out_from_save_failure(b, save_out)

    if failure_out then
      return failure_out
    end
  end

  local ok_delete, delete_err = Detail.delete_buffer(b, decision == "discard", was_normal, o)

  if not ok_delete then
    return IO.make_out(hzsr.edt.io.status.ERROR, b, path, delete_err)
  end

  local ok_exit, exit_err = maybe_exit_last(b, was_normal, o)

  if not ok_exit then
    return IO.make_out(hzsr.edt.io.status.ERROR, b, path, exit_err)
  end

  return IO.make_out(hzsr.edt.io.status.SUCCESS, b, path, "cierre correcto")
end

-- -----------------------------------------------------------------------------

return M
