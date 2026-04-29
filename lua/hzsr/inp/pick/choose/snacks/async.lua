-- hzsr.inp.pick.choose.snacks.async

local M = {}

---@param items string[]
---@param default_idx integer
---@return string[]
local function sort_default(items, default_idx)
  local def = table.remove(items, default_idx)
  table.insert(items, 1, def)
  return items
end

---@param original_items string[]
---@param item string?
---@return integer|nil
local function get_original_index(original_items, item)
  if not item then
    return nil
  end

  local idx = vim.fn.index(original_items, item)

  if idx < 0 then
    return nil
  end

  return idx + 1
end

---@param prompt string
---@param items string[]
---@param default? integer
---@return integer|nil idx
function M.choose(prompt, items, default)
  local co = coroutine.running()
  assert(co, "hzsr.inp.pick.choose.snacks.async() must be called inside a coroutine")

  local snacks = hzsr.inp.detail.snacks

  local validate = hzsr.inp.pick.choose.detail.validate
  prompt, items, default = validate(prompt, items, default)

  local preview = sort_default(vim.deepcopy(items), default)

  local group

  local finish = snacks.once(function(value)
    snacks.clear_group(group)
    snacks.resume_once(co)(value)
  end)

  local before_wins = snacks.snapshot_wins()

  Snacks.picker.select(preview, { prompt = prompt }, function(item, _)
    finish(get_original_index(items, item))
  end)

  vim.schedule(function()
    local ref = snacks.find_new_ui(before_wins)

    if not ref then
      return
    end

    group = snacks.install_ui_guards("choose", ref, finish, {
      cancel_on_leave = true,
      cancel_on_normal_mode = true,
      cancel_delay_ms = nil,
    })
  end)

  return coroutine.yield()
end

return M
