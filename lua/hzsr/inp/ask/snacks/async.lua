-- hzsr.inp.ask.snacks.async

local M = {}

---@param prompt string
---@param default? string
---@param completion? hzsr.inp.ask.completion|string
---@return string|nil input string si se respondió, nil si se abortó
function M.ask(prompt, default, completion)
  local co = coroutine.running()
  assert(co, "hzsr.inp.ask.snacks.async() must be called inside a coroutine")

  local snacks = hzsr.inp.detail.snacks

  local resume_once = snacks.resume_once(co)

  hzsr.inp.ask.snacks.sync(prompt, default, completion, resume_once)

  return coroutine.yield()
end

return M
