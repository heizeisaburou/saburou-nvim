-- hzsr.edt.io.close.close_multi

local M = {}

local IO = require "hzsr.edt.io.detail"
local Detail = require "hzsr.edt.io.close.detail"
local Close = require "hzsr.edt.io.close.close"

-- -----------------------------------------------------------------------------

---@class hzsr.edt.io.close_multi.opts
---@field modified_policy? hzsr.edt.io.modified_policy
---@field conflict_policy? hzsr.edt.io.conflict_policy
---@field explicit_cancel? boolean
---@field reveal_mode? hzsr.edt.reveal.mode
---@field reveal_strategy? hzsr.edt.reveal.strategy
---@field reveal_hl? string
---@field window_policy? hzsr.edt.io.window_policy
---@field exit_last? boolean
---@field async? boolean

---@class hzsr.edt.io.close_multi.opts.internal : hzsr.edt.io.reveal_opts
---@field modified_policy hzsr.edt.io.modified_policy
---@field conflict_policy hzsr.edt.io.conflict_policy
---@field explicit_cancel boolean
---@field window_policy hzsr.edt.io.window_policy
---@field exit_last boolean

---@class hzsr.edt.io.close_multi.report : hzsr.edt.io.batch_report
---@field results table<integer, hzsr.edt.io.close.out>

-- -----------------------------------------------------------------------------

---@param opts? hzsr.edt.io.close_multi.opts
---@return hzsr.edt.io.close_multi.opts.internal
local function parse_close_multi_opts(opts)
  vim.validate("opts", opts, "table", true)

  opts = opts or {}

  vim.validate("opts.explicit_cancel", opts.explicit_cancel, "boolean", true)

  vim.validate("opts.modified_policy", opts.modified_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.modified_policy)
  end, [["confirm"|"save"|"discard"|"require"?]])

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

  vim.validate("opts.window_policy", opts.window_policy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.io.window_policy)
  end, [["replace"|"close"|"default"?]])

  vim.validate("opts.exit_last", opts.exit_last, "boolean", true)
  vim.validate("opts.async", opts.async, "boolean", true)

  ---@type hzsr.edt.io.close_multi.opts.internal
  local iopts = vim.tbl_extend("force", {
    modified_policy = hzsr.edt.io.modified_policy.CONFIRM,
    conflict_policy = hzsr.edt.io.conflict_policy.CONFIRM,
    explicit_cancel = true,
    reveal_mode = hzsr.edt.reveal.mode.RESTORE,
    reveal_strategy = hzsr.edt.reveal.strategy.SIMPLE,
    reveal_hl = "DiffDelete",
    window_policy = hzsr.edt.io.window_policy.REPLACE,
    exit_last = false,
  }, opts)

  iopts.async = hzsr.async.handle_async(iopts.async, "hzsr.edt.io.close_multi")

  return iopts
end

---@return hzsr.edt.io.close_multi.report
local function new_close_multi_report()
  return IO.new_batch_report()
end

---@param report hzsr.edt.io.close_multi.report
---@param index integer
---@param out hzsr.edt.io.close.out
local function add_close_multi_result(report, index, out)
  return IO.add_batch_result(report, index, out)
end

---@param opts hzsr.edt.io.close_multi.opts.internal
---@param modified_policy? hzsr.edt.io.modified_policy
---@param after_buf? hzsr.edt.io.close.after_buf
---@return hzsr.edt.io.close.opts
local function make_close_opts_for_multi(opts, modified_policy, after_buf)
  return {
    modified_policy = modified_policy or opts.modified_policy,
    conflict_policy = opts.conflict_policy,
    explicit_cancel = opts.explicit_cancel,
    reveal_mode = opts.reveal_mode,
    reveal_strategy = opts.reveal_strategy,
    reveal_hl = opts.reveal_hl,
    window_policy = opts.window_policy,
    after_buf = after_buf,
    async = opts.async,
    -- `close_multi` es dueño de `exit_last`.
    -- Los cierres individuales no deben ejecutarlo.
    exit_last = false,
  }
end

-- -----------------------------------------------------------------------------

---@param opts hzsr.edt.io.close_multi.opts.internal
---@return boolean ok
---@return string? err
local function maybe_exit_last_after_multi(opts)
  if not opts.exit_last then
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

---@param report hzsr.edt.io.close_multi.report
---@param err string
local function add_close_multi_exit_error(report, err)
  local out = IO.make_out(hzsr.edt.io.status.ERROR, -1, nil, err)

  report.ok = false
  report.results[-1] = out
  table.insert(report.errored, -1)
end

-- -----------------------------------------------------------------------------

---Cierra varios buffers en orden.
---
---@param bufnrs integer[]?
---@param opts hzsr.edt.io.close_multi.opts?
---@return hzsr.edt.io.close_multi.report
function M.close_multi(bufnrs, opts)
  local o = parse_close_multi_opts(opts)
  local buffers = IO.resolve_buffers(bufnrs)
  local report = new_close_multi_report()

  report.tried = vim.deepcopy(buffers)

  for index, bufnr in ipairs(buffers) do
    if not hzsr.buf.is_valid(bufnr) then
      report.ok = false
      table.insert(report.errored, bufnr)
      break
    end

    local modified_policy = o.modified_policy

    if vim.bo[bufnr].modified and o.modified_policy == hzsr.edt.io.modified_policy.CONFIRM then
      local allow_all = Detail.has_later_modified_buffer(buffers, index)
      local decision = Detail.resolve_modified_decision(bufnr, o, allow_all)

      if decision == "cancel" then
        local out = IO.make_out(
          hzsr.edt.io.status.CANCEL,
          bufnr,
          Detail.get_buffer_path(bufnr),
          "cierre cancelado"
        )

        add_close_multi_result(report, index, out)
        break
      end

      if decision == "reject" then
        modified_policy = hzsr.edt.io.modified_policy.REQUIRE
      elseif decision == "save" then
        modified_policy = hzsr.edt.io.modified_policy.SAVE
      elseif decision == "discard" then
        modified_policy = hzsr.edt.io.modified_policy.DISCARD
      elseif decision == "save_all" then
        modified_policy = hzsr.edt.io.modified_policy.SAVE
        o.modified_policy = hzsr.edt.io.modified_policy.SAVE
      elseif decision == "discard_all" then
        modified_policy = hzsr.edt.io.modified_policy.DISCARD
        o.modified_policy = hzsr.edt.io.modified_policy.DISCARD
      end
    end

    ---@type hzsr.edt.io.close.after_buf
    local after_buf = index < #buffers and buffers[index + 1] or "next"

    local out = Close.close(bufnr, make_close_opts_for_multi(o, modified_policy, after_buf))

    if not out then
      report.ok = false
      table.insert(report.errored, bufnr)
      break
    end

    add_close_multi_result(report, index, out)

    if out.status == hzsr.edt.io.status.CANCEL then
      break
    end

    if out.status == hzsr.edt.io.status.ERROR then
      break
    end
  end

  if report.ok then
    local ok_exit, exit_err = maybe_exit_last_after_multi(o)

    if not ok_exit then
      add_close_multi_exit_error(report, exit_err or "salida fallida tras cierre múltiple")
    end
  end

  return report
end

-- -----------------------------------------------------------------------------

return M
