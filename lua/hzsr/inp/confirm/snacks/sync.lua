-- hzsr.inp.confirm.snacks.sync

local M = {}

local function parse_confirm(input)
  if not input then
    return nil
  end

  local trimmed = input:lower():gsub("^%s+", ""):gsub("%s+$", "")

  if trimmed == "" then
    return nil
  end

  if trimmed:match("^[ssy]") then
    return true
  end

  if trimmed:match("^[nn]") then
    return false
  end

  return nil
end

---@param prompt string
---@param default? boolean
---@param on_confirm fun(result: boolean|nil)
function M.confirm(prompt, default, on_confirm)
  vim.validate("prompt", prompt, "string")
  vim.validate("default", default, "boolean", true)
  vim.validate("on_confirm", on_confirm, "function")

  local snacks = hzsr.inp.detail.snacks

  local group

  local finish = snacks.once(function(value)
    snacks.clear_group(group)
    on_confirm(value)
  end)

  local placeholder = default and "[S/n]" or "[s/N]"

  ---@type snacks.input.Opts
  local snack_opts = {
    prompt = prompt,
    default = "",
    placeholder = placeholder,
  }

  local before_wins = snacks.snapshot_wins()

  Snacks.input(snack_opts, function(input)
    local result = parse_confirm(input)
    finish(result)
  end)

  vim.schedule(function()
    local ref = snacks.find_new_ui(before_wins)

    if not ref then
      return
    end

    group = snacks.install_ui_guards("confirm", ref, finish, {
      cancel_on_leave = true,
      cancel_on_normal_mode = true,
      cancel_delay_ms = nil,
    })
  end)
end

return M
