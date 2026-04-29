-- hzsr.inp.ask.async

local M = {}

---@param prompt string
---@param default? string
---@param completion? hzsr.inp.ask.completion|string
---@return string|nil input string si se respondió, nil si se abortó
function M.ask(prompt, default, completion)
  local co = coroutine.running()
  assert(co, "hzsr.inp.ask.async() must be called inside a coroutine")

  if rawget(_G, "Snacks") then
    return hzsr.inp.ask.snacks.async(prompt, default, completion)
  end

  return hzsr.inp.ask.sync(prompt, default, completion)
end

return M
