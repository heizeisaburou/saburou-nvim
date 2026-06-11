-- hzsr.inp.confirm.snacks.async

local M = {}

---@param prompt string
---@param default? boolean
---@return boolean|nil confirmación si se respondió, nil si se abortó
function M.confirm(prompt, default)
  local co = coroutine.running()
  assert(co, "hzsr.inp.confirm.snacks.async() must be called inside a coroutine")

  local snacks = hzsr.inp.detail.snacks

  local resume_once = snacks.resume_once(co)

  hzsr.inp.confirm.snacks.sync(prompt, default, resume_once)

  return coroutine.yield()
end

return M
