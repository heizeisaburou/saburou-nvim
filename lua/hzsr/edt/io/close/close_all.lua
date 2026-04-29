-- hzsr.edt.io.close.close_all

local M = {}

local IO = require "hzsr.edt.io.detail"
local Detail = require "hzsr.edt.io.close.detail"
local CloseMulti = require "hzsr.edt.io.close.close_multi"

-- -----------------------------------------------------------------------------

---@class hzsr.edt.io.close_all.opts
---@field confirm? boolean
---@field modified_policy? hzsr.edt.io.modified_policy
---@field conflict_policy? hzsr.edt.io.conflict_policy
---@field explicit_cancel? boolean
---@field reveal_mode? hzsr.edt.reveal.mode
---@field reveal_strategy? hzsr.edt.reveal.strategy
---@field reveal_hl? string
---@field window_policy? hzsr.edt.io.window_policy
---@field exit_last? boolean
---@field async? boolean

---@class hzsr.edt.io.close_all.opts.internal
---@field confirm boolean
---@field modified_policy hzsr.edt.io.modified_policy
---@field conflict_policy hzsr.edt.io.conflict_policy
---@field explicit_cancel boolean
---@field reveal_mode hzsr.edt.reveal.mode
---@field reveal_strategy hzsr.edt.reveal.strategy
---@field reveal_hl string
---@field window_policy hzsr.edt.io.window_policy
---@field exit_last boolean
---@field async boolean

-- -----------------------------------------------------------------------------

---@param opts? hzsr.edt.io.close_all.opts
---@return hzsr.edt.io.close_all.opts.internal
local function parse_close_all_opts(opts)
  vim.validate("opts", opts, "table", true)

  opts = opts or {}

  vim.validate("opts.confirm", opts.confirm, "boolean", true)

  vim.validate("opts.modified_policy", opts.modified_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.modified_policy)
  end, [["confirm"|"save"|"discard"|"require"?]])

  vim.validate("opts.conflict_policy", opts.conflict_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.conflict_policy)
  end, [["confirm"|"force"|"require"?]])

  vim.validate("opts.explicit_cancel", opts.explicit_cancel, "boolean", true)

  vim.validate("opts.reveal_mode", opts.reveal_mode, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.reveal.mode)
  end, "hzsr.edt.reveal.mode?")

  vim.validate("opts.reveal_strategy", opts.reveal_strategy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.reveal.strategy)
  end, "hzsr.edt.reveal.strategy?")

  vim.validate("opts.reveal_hl", opts.reveal_hl, "string", true)

  vim.validate("opts.window_policy", opts.window_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.window_policy)
  end, [["replace"|"close"|"default"?]])

  vim.validate("opts.exit_last", opts.exit_last, "boolean", true)
  vim.validate("opts.async", opts.async, "boolean", true)

  ---@type hzsr.edt.io.close_all.opts.internal
  local iopts = vim.tbl_extend("force", {
    confirm = true,
    modified_policy = hzsr.edt.io.modified_policy.CONFIRM,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = true,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = "DiffDelete",
    window_policy = hzsr.edt.io.window_policy.REPLACE,
    exit_last = false,
  }, opts)

  iopts.async = hzsr.async.handle_async(iopts.async, "hzsr.edt.io.close_all")

  return iopts
end

---@param opts hzsr.edt.io.close_all.opts.internal
---@param prompt string
---@return hzsr.edt.io.status?
local function confirm_close_all(opts, prompt)
  if not opts.confirm then
    return nil
  end

  local answer = hzsr.inp.pick.confirm(prompt, {
    default = opts.explicit_cancel and "cancel" or "no",
    explicit_cancel = opts.explicit_cancel,
    async = opts.async,
  })

  if answer == "yes" then
    return nil
  end

  if answer == "cancel" then
    return hzsr.edt.io.status.CANCEL
  end

  return hzsr.edt.io.status.REJECT
end

---@param status hzsr.edt.io.status
---@param bufnrs integer[]
---@param msg string
---@return hzsr.edt.io.close_multi.report
local function make_close_all_unrun_report(status, bufnrs, msg)
  return IO.make_batch_unrun_report(status, bufnrs, function(bufnr)
    local path = hzsr.buf.is_valid(bufnr) and Detail.get_buffer_path(bufnr) or nil
    return IO.make_out(status, bufnr, path, msg)
  end)
end

---@param opts hzsr.edt.io.close_all.opts.internal
---@return hzsr.edt.io.close_multi.opts
local function make_close_multi_opts_for_all(opts)
  return {
    modified_policy = opts.modified_policy,
    conflict_policy = opts.conflict_policy,
    explicit_cancel = opts.explicit_cancel,
    reveal_mode = opts.reveal_mode,
    reveal_strategy = opts.reveal_strategy,
    reveal_hl = opts.reveal_hl,
    window_policy = opts.window_policy,
    exit_last = opts.exit_last,
    async = opts.async,
  }
end

-- -----------------------------------------------------------------------------

---Cierra todos los buffers de la colección global.
---
---@param opts? hzsr.edt.io.close_all.opts
---@return hzsr.edt.io.close_multi.report
function M.close_all(opts)
  local filter = hzsr.buf.filter

  local o = parse_close_all_opts(opts)
  local buffers = hzsr.buf.get_all()
  local count = #buffers

  local modified = filter.apply(buffers, filter.modified)
  local modified_count = #modified

  local buffer_s = count == 1 and "" or "s"
  local modified_s = modified_count == 1 and "" or "s"
  if o.confirm and modified_count >= 1 then
    local prompt = ("¿Cerrar %d buffer%s? (%d modificado%s)"):format(
      count,
      buffer_s,
      modified_count,
      modified_s
    )
    local status = confirm_close_all(o, prompt)

    if status == hzsr.edt.io.status.CANCEL then
      return make_close_all_unrun_report(hzsr.edt.io.status.CANCEL, buffers, "cierre cancelado")
    end

    if status == hzsr.edt.io.status.REJECT then
      return make_close_all_unrun_report(hzsr.edt.io.status.REJECT, buffers, "cierre rechazado")
    end
  end

  return CloseMulti.close_multi(buffers, make_close_multi_opts_for_all(o))
end

-- -----------------------------------------------------------------------------

return M
