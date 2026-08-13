local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

describe("Telescope horizontal preview scrolling", function()
  local previous
  local offsets

  before_each(function()
    previous = {
      telescope = package.loaded["telescope"],
      actions = package.loaded["telescope.actions"],
      action_state = package.loaded["telescope.actions.state"],
      config = package.loaded["lzy.telescope"],
    }
    offsets = {}

    package.loaded["telescope"] = {
      setup = function() end,
      load_extension = function() end,
    }
    package.loaded["telescope.actions"] = {
      close = function() end,
      cycle_history_next = function() end,
      cycle_history_prev = function() end,
    }
    package.loaded["telescope.actions.state"] = {
      get_current_picker = function(prompt_bufnr)
        assert.are.equal(42, prompt_bufnr)
        return {
          previewer = {
            scroll_horizontal_fn = function(_, columns)
              offsets[#offsets + 1] = columns
            end,
          },
        }
      end,
    }
    package.loaded["lzy.telescope"] = nil
  end)

  after_each(function()
    package.loaded["telescope"] = previous.telescope
    package.loaded["telescope.actions"] = previous.actions
    package.loaded["telescope.actions.state"] = previous.action_state
    package.loaded["lzy.telescope"] = previous.config
  end)

  it("uses exact 1 and 10 column steps in insert and normal mode", function()
    local mappings = require("lzy.telescope").config.defaults.mappings

    for _, mode in ipairs { "i", "n" } do
      for _, key in ipairs { "<A-H>", "<A-L>", "<A-h>", "<A-l>" } do
        mappings[mode][key](42)
      end
    end

    assert.are.same({ -1, 1, -10, 10, -1, 1, -10, 10 }, offsets)
  end)
end)
