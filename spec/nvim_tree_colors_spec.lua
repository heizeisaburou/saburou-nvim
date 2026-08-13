local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

describe("Sabunv nvim-tree Git colors", function()
  local previous
  local applied

  before_each(function()
    previous = _G.sabunv
    applied = {}
    _G.sabunv = {
      moonfly = {
        colors = {
          alt_bg = "#000000",
          blue = "#0000ff",
          light_blue = "#00ffff",
          pink = "#ff00ff",
          yellow = "#ffff00",
          git_dirty = "#bc3a3a",
        },
        unified_colors = {
          solid = { light_line_bg = "#111111" },
          transparent = { line_separator = "#222222", light_numbers = "#333333" },
        },
        hl = {
          update = function(group, opts)
            applied[group] = opts
          end,
        },
      },
    }
    package.loaded["sabunv.moonfly.nvim_tree"] = nil
  end)

  after_each(function()
    _G.sabunv = previous
    package.loaded["sabunv.moonfly.nvim_tree"] = nil
  end)

  it("uses the dedicated dirty red for tracked modified files", function()
    require("sabunv.moonfly.nvim_tree").setup({ style = "solid" })

    for _, group in ipairs({
      "NvimTreeGitDirtyIcon",
      "NvimTreeGitFileDirtyHL",
      "NvimTreeGitFolderDirtyHL",
    }) do
      assert.are.equal("#771717", applied[group].fg)
    end
  end)
end)
