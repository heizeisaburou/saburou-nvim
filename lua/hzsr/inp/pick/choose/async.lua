-- hzsr.inp.pick.choose.async

local M = {}

---@param prompt string
---@param items string[]
---@param default? integer
---@return integer|nil idx
function M.choose(prompt, items, default)
  if rawget(_G, "Snacks") then
    return hzsr.inp.pick.choose.snacks.async(prompt, items, default)
  end

  return hzsr.inp.pick.choose.sync(prompt, items, default)
end

return M
