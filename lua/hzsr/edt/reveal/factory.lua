-- hzsr.edt.reveal.factory

local M = {}

---@class hzsr.edt.reveal.factory.opts : hzsr.edt.reveal.Reveal.opts
---@field strategy? hzsr.edt.reveal.strategy

---@param bufnr? integer
---@param opts? hzsr.edt.reveal.factory.opts
---@return hzsr.edt.reveal.Reveal
function M.new(bufnr, opts)
  vim.validate("opts", opts, "table", true)

  opts = opts or {}

  vim.validate("opts.strategy", opts.strategy, function(v)
    return v == nil or hzsr.enum.one_of(v, hzsr.edt.reveal.strategy)
  end, "hzsr.edt.reveal.strategy?")

  local strategy = opts.strategy or hzsr.edt.reveal.strategy.SIMPLE

  if strategy == hzsr.edt.reveal.strategy.SIMPLE then
    ---@diagnostic disable-next-line: param-type-mismatch
    return hzsr.edt.reveal.simple.Reveal.new(bufnr, opts)
  end

  hzsr
    .err
    .Error
    .new(
      "hzsr.edt.reveal.factory",
      "REVEAL_STRATEGY_NOT_IMPLEMENTED",
      ("la estrategia de reveal %q todavía no está implementada"):format(strategy),
      {
        strategy = strategy,
      }
    )
    ---@diagnostic disable-next-line: missing-return
    :sraise()
end

return M
