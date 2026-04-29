-- hzsr.inp.ask.snacks.sync

local M = {}

---@param prompt string
---@param default? string
---@param completion? hzsr.inp.ask.completion|string
---@param on_confirm fun(input: string|nil)
---@return string|nil input string si se respondió, nil si se abortó
function M.ask(prompt, default, completion, on_confirm)
  vim.validate("prompt", prompt, "string")
  vim.validate("default", default, "string", true)
  vim.validate("completion", completion, "string", true)
  vim.validate("on_confirm", on_confirm, "function")

  local snacks = hzsr.inp.detail.snacks

  local group

  local finish = snacks.once(function(value)
    snacks.clear_group(group)
    on_confirm(value)
  end)

  ---@type snacks.input.Opts
  local snack_opts = {
    prompt = prompt,
    default = default,
    completion = completion,
  }

  local before_wins = snacks.snapshot_wins()

  Snacks.input(snack_opts, function(input)
    finish(input)
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
end

return M
