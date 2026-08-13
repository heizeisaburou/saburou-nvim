local config = "/home/saburou/.config/hzsr12"

vim.opt.runtimepath:prepend(config)
package.path = config .. "/lua/?.lua;" .. config .. "/lua/?/init.lua;" .. package.path

describe("Sabunv lualine filename", function()
  local captured
  local current_path
  local previous = {}

  local function windows_fnamemodify(path, modifier)
    path = path:gsub("\\", "/")

    if modifier == ":t" then
      if path == "/" or path:match "^%a:/$" then
        return ""
      end
      return path:match "([^/]+)$" or ""
    elseif modifier == ":h" then
      if path == "/" or path:match "^%a:/$" then
        return path
      end

      local parent = path:match "^(.*)/[^/]+$"
      if parent and parent:match "^%a:$" then
        return parent .. "/"
      end
      return parent or "."
    end

    error("unsupported fnamemodify modifier in test: " .. modifier)
  end

  before_each(function()
    previous.sabunv = _G.sabunv
    previous.hzsr = _G.hzsr
    previous.get_name = vim.api.nvim_buf_get_name
    previous.fnamemodify = vim.fn.fnamemodify
    previous.lualine = package.loaded.lualine
    previous.module = package.loaded["lzy.lualine"]

    _G.sabunv = nil
    _G.hzsr = { sys = { os_sep = "\\" } }
    vim.api.nvim_buf_get_name = function()
      return current_path
    end
    vim.fn.fnamemodify = windows_fnamemodify
    package.loaded.lualine = {
      setup = function(opts)
        captured = opts
      end,
    }
    package.loaded["lzy.lualine"] = nil
    require("lzy.lualine").setup()
  end)

  after_each(function()
    _G.sabunv = previous.sabunv
    _G.hzsr = previous.hzsr
    vim.api.nvim_buf_get_name = previous.get_name
    vim.fn.fnamemodify = previous.fnamemodify
    package.loaded.lualine = previous.lualine
    package.loaded["lzy.lualine"] = previous.module
  end)

  it("uses one Windows separator for drive roots and every path segment", function()
    local filename = captured.sections.lualine_c[5][1]
    local expected = "C:\\Users\\mateo\\AppData\\Local\\srnv\\.luarc.json"

    current_path = "C:/Users/mateo/AppData/Local/srnv/.luarc.json"
    assert.are.equal(expected, filename())

    current_path = "C:\\Users\\mateo\\AppData\\Local\\srnv\\.luarc.json"
    assert.are.equal(expected, filename())
  end)
end)
