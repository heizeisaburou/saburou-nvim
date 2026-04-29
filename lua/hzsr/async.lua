-- hzsr.async

local M = {}

---@generic T
---@param fn fun(): T
---@return T result
function M.run(fn)
  local co = coroutine.create(fn)
  local ok, result = coroutine.resume(co)

  if not ok then
    error(result)
  end

  return ok, result
end

---@param async boolean?
---@param method_name string?
---@return boolean async
function M.handle_async(async, method_name)
  vim.validate("async", async, "boolean", true)
  vim.validate("method_name", method_name, "string", true)

  local co = coroutine.running()

  if async == nil then
    return co ~= nil
  end

  if async and co == nil then
    local prefix = method_name and (method_name .. "(): ") or ""
    error(("%sif async is true, you must be inside a coroutine"):format(prefix))
  end

  return async
end

return M
