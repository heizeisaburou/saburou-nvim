-- hzsr.inp.ask.adapter

local M = {}

---@param prompt string
---@param default? string
---@param completion? hzsr.inp.ask.completion|string
---@param async? boolean
---@return string|nil input string si se respondió, nil si se abortó
function M.ask(prompt, default, completion, async)
  local use_async = hzsr.async.handle_async(async)

  if use_async then
    return hzsr.inp.ask.async(prompt, default, completion)
  end

  return hzsr.inp.ask.sync(prompt, default, completion)
end

return M
