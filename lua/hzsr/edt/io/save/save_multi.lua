-- hzsr.edt.io.save.save_multi

local M = {}

local IO = require "hzsr.edt.io.detail"
local Save = require "hzsr.edt.io.save.save"

-- -----------------------------------------------------------------------------

---@class hzsr.edt.io.save_multi.opts
---@field path_policy? hzsr.edt.io.path_policy
---@field conflict_policy? hzsr.edt.io.conflict_policy
---@field reveal_mode? hzsr.edt.reveal.mode
---@field reveal_strategy? hzsr.edt.reveal.strategy
---@field reveal_hl? string
---@field async? boolean

---@class hzsr.edt.io.save_multi.opts.internal
---@field path_policy hzsr.edt.io.path_policy
---@field conflict_policy hzsr.edt.io.conflict_policy
---@field reveal_mode hzsr.edt.reveal.mode
---@field reveal_strategy hzsr.edt.reveal.strategy
---@field reveal_hl string
---@field async boolean

---@class hzsr.edt.io.save_multi.report : hzsr.edt.io.batch_report
---@field results table<integer, hzsr.edt.io.save.out>

-- -----------------------------------------------------------------------------

---@param opts? hzsr.edt.io.save_multi.opts
---@return hzsr.edt.io.save_multi.opts.internal
local function parse_save_multi_opts(opts)
  vim.validate("opts", opts, "table", true)

  opts = opts or {}

  vim.validate("opts.path_policy", opts.path_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.path_policy)
  end, [["auto"|"ask"|"require"?]])

  vim.validate("opts.conflict_policy", opts.conflict_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.conflict_policy)
  end, [["confirm"|"force"|"require"?]])

  vim.validate("opts.reveal_mode", opts.reveal_mode, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.reveal.mode)
  end, "hzsr.edt.reveal.mode?")

  vim.validate("opts.reveal_strategy", opts.reveal_strategy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.reveal.strategy)
  end, "hzsr.edt.reveal.strategy?")

  vim.validate("opts.reveal_hl", opts.reveal_hl, "string", true)
  vim.validate("opts.async", opts.async, "boolean", true)

  ---@type hzsr.edt.io.save_multi.opts.internal
  local iopts = vim.tbl_extend("force", {
    path_policy = hzsr.edt.io.path_policy.AUTO,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = "DiffAdd",
  }, opts)

  iopts.async = hzsr.async.handle_async(iopts.async, "hzsr.edt.io.save_multi")

  return iopts
end

---@return hzsr.edt.io.save_multi.report
local function new_save_multi_report()
  return IO.new_batch_report()
end

---@param report hzsr.edt.io.save_multi.report
---@param index integer
---@param out hzsr.edt.io.save.out
local function add_save_multi_result(report, index, out)
  return IO.add_batch_result(report, index, out)
end

---@param opts hzsr.edt.io.save_multi.opts.internal
---@return hzsr.edt.io.save.opts
local function make_save_opts_for_multi(opts)
  return {
    path = nil,
    path_policy = opts.path_policy,
    conflict_policy = opts.conflict_policy,
    explicit_cancel = true,
    reveal_mode = opts.reveal_mode,
    reveal_strategy = opts.reveal_strategy,
    reveal_hl = opts.reveal_hl,
    async = opts.async,
  }
end

-- -----------------------------------------------------------------------------

---Guarda varios buffers modificados.
---
---@param bufnrs integer[]?
---@param opts hzsr.edt.io.save_multi.opts?
---@return hzsr.edt.io.save_multi.report
function M.save_multi(bufnrs, opts)
  local filter = hzsr.buf.filter

  local o = parse_save_multi_opts(opts)

  local buffers = IO.resolve_buffers(bufnrs, "modified")
  buffers = filter.apply(buffers, filter.modified)

  local report = new_save_multi_report()

  report.tried = vim.deepcopy(buffers)

  for index, bufnr in ipairs(buffers) do
    if not hzsr.buf.is_valid(bufnr) then
      report.ok = false
      table.insert(report.errored, bufnr)
      break
    end

    if not vim.bo[bufnr].modified then
      goto continue
    end

    local out = Save.save(bufnr, make_save_opts_for_multi(o))

    if not out then
      report.ok = false
      table.insert(report.errored, bufnr)
      break
    end

    add_save_multi_result(report, index, out)

    if out.status == hzsr.edt.io.status.CANCEL then
      break
    end

    if out.status == hzsr.edt.io.status.ERROR then
      break
    end

    ::continue::
  end

  return report
end

-- -----------------------------------------------------------------------------

return M
