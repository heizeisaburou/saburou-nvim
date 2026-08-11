-- hzsr/test — harness headless para probar módulos de esta config.
--
-- Uso (CLI): nvim --headless -u NONE -c "lua dofile('$HOME/.config/hzsr12/lua/hzsr/test/init.lua').run({args...})" -c "qa!"
--
-- Args:
--   --root=<path>     raíz del vault (default: primer workspace del state file;
--                     si no existe, cwd)
--   --config=<path>   raíz de la config para el rtp (default: ~/.config/hzsr12)
--   --plenary         corre los tests plenary de <root>/spec (o <config>/spec)
--
-- Esqueleto en evolución: se irá mockeando lo que haga falta.

local M = {}

local function lazy_dir()
  return vim.fs.joinpath(vim.fn.stdpath("data"), "lazy")
end

local function find_plugin(name)
  local path = vim.fs.joinpath(lazy_dir(), name)
  return vim.fn.isdirectory(path) == 1 and path or nil
end

--- Primer workspace del state de nyabsidian (la raíz la sacamos de ahí).
local function state_first_workspace()
  local file = vim.fs.joinpath(vim.fn.stdpath("state"), "nyabsidian", "workspaces.json")
  local f = io.open(file, "r")
  if not f then
    return nil
  end
  local raw = f:read "*a"
  f:close()
  local ok, data = pcall(vim.json.decode, raw)
  if ok and type(data) == "table" and type(data.workspaces) == "table" then
    return data.workspaces[1]
  end
  return nil
end

local function prepare_rtp(config_dir)
  vim.opt.rtp:prepend(config_dir)
  for _, name in ipairs({ "obsidian.nvim", "plenary.nvim" }) do
    local p = find_plugin(name)
    if p then
      vim.opt.rtp:prepend(p)
    end
  end
end

local function parse_args(args)
  local opts = { root = nil, config = vim.fn.expand("~/.config/hzsr12"), plenary = false }
  for _, a in ipairs(args or {}) do
    if a == "--plenary" then
      opts.plenary = true
    else
      local flag, value = a:match("^%-%-([^=]+)=(.*)$")
      if flag == "root" then
        opts.root = vim.fn.expand(value)
      elseif flag == "config" then
        opts.config = vim.fn.expand(value)
      end
    end
  end
  return opts
end

--- Raíz: flag --root → state file → cwd.
local function resolve_root(opts)
  local root = opts.root
  if not root or vim.fn.isdirectory(root) ~= 1 then
    root = state_first_workspace()
  end
  if not root or vim.fn.isdirectory(root) ~= 1 then
    root = vim.fn.getcwd()
  end
  return root
end

local function test_nyabsidian(root)
  require("lzy.obsidian").setup()
  local Obsidian = rawget(_G, "Obsidian")
  local roots = {}
  for _, ws in ipairs(Obsidian and Obsidian.workspaces or {}) do
    roots[#roots + 1] = tostring(ws.root)
  end
  print("ROOT:", root)
  print("WORKSPACES:", vim.inspect(roots))
end

local function test_plenary(root, config)
  local spec = vim.fs.joinpath(root, "spec")
  if vim.fn.isdirectory(spec) ~= 1 then
    spec = vim.fs.joinpath(config, "spec")
  end
  if vim.fn.isdirectory(spec) ~= 1 then
    vim.notify("hzsr.test: no hay spec/ en " .. root .. " ni en " .. config, vim.log.levels.WARN, {
      title = "Harness",
    })
    return
  end
  require("plenary.test_harness").test_directory(spec)
end

---@param args string[]
function M.run(args)
  local opts = parse_args(args)
  prepare_rtp(opts.config)
  local root = resolve_root(opts)
  vim.fn.chdir(root)

  if opts.plenary then
    test_plenary(root, opts.config)
  else
    test_nyabsidian(root)
  end
end

return M
