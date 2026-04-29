-- hzsr.edt.io.save.save_all

local M = {}

local IO = require "hzsr.edt.io.detail"
local SaveMulti = require "hzsr.edt.io.save.save_multi"

-- -----------------------------------------------------------------------------

---@class hzsr.edt.io.save_all.opts
---@field confirm? boolean
---@field conflict_policy? hzsr.edt.io.conflict_policy
---@field explicit_cancel? boolean
---@field reveal_mode? hzsr.edt.reveal.mode
---@field reveal_strategy? hzsr.edt.reveal.strategy
---@field reveal_hl? string
---@field async? boolean

---@class hzsr.edt.io.save_all.opts.internal
---@field confirm boolean
---@field conflict_policy hzsr.edt.io.conflict_policy
---@field explicit_cancel boolean
---@field reveal_mode hzsr.edt.reveal.mode
---@field reveal_strategy hzsr.edt.reveal.strategy
---@field reveal_hl string
---@field async boolean

-- -----------------------------------------------------------------------------

---@param opts? hzsr.edt.io.save_all.opts
---@return hzsr.edt.io.save_all.opts.internal
local function parse_save_all_opts(opts)
  vim.validate("opts", opts, "table", true)

  opts = opts or {}

  vim.validate("opts.confirm", opts.confirm, "boolean", true)

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
  vim.validate("opts.async", opts.async, "boolean", true)

  ---@type hzsr.edt.io.save_all.opts.internal
  local iopts = vim.tbl_extend("force", {
    confirm = true,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = false,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = "DiffAdd",
  }, opts)

  iopts.async = hzsr.async.handle_async(iopts.async, "hzsr.edt.io.save_all")

  return iopts
end

---@param status hzsr.edt.io.status
---@param bufnrs integer[]
---@param msg string
---@return hzsr.edt.io.save_multi.report
local function make_save_all_unrun_report(status, bufnrs, msg)
  return IO.make_batch_unrun_report(status, bufnrs, function(bufnr)
    return IO.make_out(status, bufnr, nil, msg)
  end)
end

---@param opts hzsr.edt.io.save_all.opts.internal
---@param prompt string
---@return hzsr.edt.io.status?
local function confirm_save_all(opts, prompt)
  if not opts.confirm then
    return nil
  end

  local answer = hzsr.inp.pick.confirm(prompt, {
    default = "yes",
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

-- -----------------------------------------------------------------------------

---Guarda todos los buffers modificados.
---
---@param opts? hzsr.edt.io.save_all.opts
---@return hzsr.edt.io.save_multi.report
function M.save_all(opts)
  local o = parse_save_all_opts(opts)

  local modified = hzsr.buf.get_all("modified")
  local count = #modified

  if count == 0 then
    return IO.new_batch_report()
  end

  if o.confirm and count >= 1 then
    local prompt = ("¿Guardar %d buffer%s modificado%s?"):format(
      count,
      count == 1 and "" or "s",
      count == 1 and "" or "s"
    )

    local status = confirm_save_all(o, prompt)

    if status == hzsr.edt.io.status.CANCEL then
      return make_save_all_unrun_report(hzsr.edt.io.status.CANCEL, modified, "guardado cancelado")
    end

    if status == hzsr.edt.io.status.REJECT then
      return make_save_all_unrun_report(hzsr.edt.io.status.REJECT, modified, "guardado rechazado")
    end
  end

  return SaveMulti.save_multi(modified, {
    path_policy = hzsr.edt.io.path_policy.AUTO,
    conflict_policy = o.conflict_policy,
    reveal_mode = o.reveal_mode,
    reveal_strategy = o.reveal_strategy,
    reveal_hl = o.reveal_hl,
    async = o.async,
  })
end

-- -----------------------------------------------------------------------------

return M
