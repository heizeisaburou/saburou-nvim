-- hzsr.inp.pick.choose.adapter

local M = {}

---@param prompt string
---@param items string[]
---@param default? integer
---@param async? boolean
---@return integer|nil idx
function M.choose(prompt, items, default, async)
  local use_async = hzsr.async.handle_async(async)

  if use_async then
    return hzsr.inp.pick.choose.async(prompt, items, default)
  end

  return hzsr.inp.pick.choose.sync(prompt, items, default)
end

return M
