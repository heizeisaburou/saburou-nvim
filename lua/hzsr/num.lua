-- hzsr.num

local M = {}

M.assert = {}

---@param name string
---@param x number
---@param min number
---@param max number
function M.assert.range(name, x, min, max)
  if x < min or x > max then
    error(("%s must be between %d and %d"):format(name, min, max))
  end
end

return M
