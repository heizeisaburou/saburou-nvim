-- hzsr.inp.confirm.adapter

local M = {}

---@param prompt string
---@param default? boolean
---@param async? boolean
---@return boolean|nil confirmación si se respondió, nil si se abortó
function M.confirm(prompt, default, async)
  local use_async = hzsr.async.handle_async(async)

  if use_async then
    return hzsr.inp.confirm.async(prompt, default)
  end

  return hzsr.inp.confirm.sync(prompt, default)
end

return M
