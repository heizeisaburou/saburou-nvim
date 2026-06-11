-- hzsr.inp.confirm.async

local M = {}

---@param prompt string
---@param default? boolean
---@return boolean|nil confirmación si se respondió, nil si se abortó
function M.confirm(prompt, default)
  local co = coroutine.running()
  assert(co, "hzsr.inp.confirm.async() must be called inside a coroutine")

  if rawget(_G, "Snacks") then
    return hzsr.inp.confirm.snacks.async(prompt, default)
  end

  return hzsr.inp.confirm.sync(prompt, default)
end

return M
