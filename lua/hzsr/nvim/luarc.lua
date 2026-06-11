-- hzsr.nvim.luarc

local M = {}

---@type {
---  runtime: { version: string },
---  diagnostics: { globals: string[] },
---  workspace: {
---    library: string[],
---    maxPreload: integer,
---    preloadFileSize: integer,
---  },
---}
M.base_json = {
  runtime = {
    version = "LuaJIT",
  },
  diagnostics = {
    globals = { "vim" },
  },
  workspace = {
    library = {
      "${workspaceFolder}/lua",
      vim.env.VIMRUNTIME,
      "${3rd}/luv/library",
      "${3rd}/busted/library",
    },
    maxPreload = 10000,
    preloadFileSize = 10000,
  },
}

---@param list string[]
---@return string[]
local function dedup(list)
  local seen = {}
  local out = {}

  for _, v in ipairs(list) do
    if v and v ~= "" and not seen[v] then
      seen[v] = true
      table.insert(out, v)
    end
  end

  return out
end

---@param list string[]
---@param values string[]
local function extend(list, values)
  for _, value in ipairs(values) do
    table.insert(list, value)
  end
end

---@param appname? string
---@return string
function M.config_path(appname)
  return vim.fs.joinpath(hzsr.nvim.configdir(appname), ".luarc.json")
end

---@param appname? string
---@return string
function M.lazy_dir(appname)
  return vim.fs.joinpath(hzsr.nvim.datadir(appname), "lazy")
end

---@param appname? string
---@return { diagnostics: { globals: string[] }, workspace: { library: string[] } }
function M.generate_lazy(appname)
  local result = {
    diagnostics = { globals = {} },
    workspace = { library = {} },
  }

  if not hzsr.lzy.available() then
    return result
  end

  local lazy_dir = M.lazy_dir(appname)
  local stat = vim.uv.fs_stat(lazy_dir)

  if not stat or stat.type ~= "directory" then
    return result
  end

  local handle = vim.uv.fs_scandir(lazy_dir)

  if not handle then
    return result
  end

  while true do
    local name, type = vim.uv.fs_scandir_next(handle)

    if not name then
      break
    end

    if type == "directory" then
      if name == "plenary.nvim" then
        extend(result.diagnostics.globals, {
          "describe",
          "it",
          "before_each",
          "after_each",
        })
      elseif name == "snacks.nvim" then
        table.insert(result.diagnostics.globals, "Snacks")
      end

      local plugin_lua = vim.fs.joinpath(lazy_dir, name, "lua")
      local lua_stat = vim.uv.fs_stat(plugin_lua)

      if lua_stat and lua_stat.type == "directory" then
        table.insert(result.workspace.library, plugin_lua)
      end
    end
  end

  return result
end

---@param appname? string
---@return table
function M.generate(appname)
  local res = vim.deepcopy(M.base_json)
  local lazy_part = M.generate_lazy(appname)

  extend(res.diagnostics.globals, lazy_part.diagnostics.globals)
  extend(res.workspace.library, lazy_part.workspace.library)

  res.diagnostics.globals = dedup(res.diagnostics.globals)
  res.workspace.library = dedup(res.workspace.library)

  -- Normaliza paths al estilo Windows para que lua-language-server los resuelva correctamente
  if hzsr.sys.iswin then
    local sys_path = require "hzsr.sys.path"
    for i, lib_path in ipairs(res.workspace.library) do
      res.workspace.library[i] = sys_path.normalize(lib_path)
    end
  end

  return res
end

---@param appname? string
---@return string
function M.encode(appname)
  return vim.json.encode(M.generate(appname), { indent = "  " })
end

---@param appname? string
---@return integer bufnr
function M.create_buffer(appname)
  local path = M.config_path(appname)
  local json = M.encode(appname)
  local lines = vim.split(json, "\n", { plain = true })

  local existing = vim.fn.bufnr(path)

  if existing ~= -1 then
    vim.api.nvim_set_current_buf(existing)
  else
    vim.cmd "enew"

    local created = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_set_name(created, path)

    vim.bo[created].buftype = ""
    vim.bo[created].bufhidden = "hide"
    vim.bo[created].swapfile = false
    vim.bo[created].filetype = "json"
  end

  local bufnr = vim.api.nvim_get_current_buf()

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modified = true

  return bufnr
end

return M
