-- sabunv.moonfly.persistence

local M = {}

---@type sabunv.moonfly.state
local DEFAULT_STATE = {
  style = "solid",
}

local function state_dir()
  return vim.fs.joinpath(hzsr.nvim.statedir(), "sabunv")
end

local function state_path()
  return vim.fs.joinpath(state_dir(), "moonfly.json")
end

local function is_valid_style(style)
  return style == "solid" or style == "transparent"
end

---@param state any
---@return sabunv.moonfly.state
local function normalize_state(state)
  state = type(state) == "table" and state or {}

  local normalized = vim.deepcopy(DEFAULT_STATE)

  if type(state.style) == "string" and is_valid_style(state.style) then
    normalized.style = state.style
  end

  return normalized
end

local function ensure_state_dir()
  vim.fn.mkdir(state_dir(), "p")
end

---@param path string
---@return string?
local function read_file(path)
  local fd = vim.uv.fs_open(path, "r", 438)

  if not fd then
    return nil
  end

  local stat = vim.uv.fs_fstat(fd)

  if not stat then
    vim.uv.fs_close(fd)
    return nil
  end

  local data = vim.uv.fs_read(fd, stat.size, 0)

  vim.uv.fs_close(fd)

  return data
end

---@param path string
---@param data string
---@return boolean ok
---@return string? err
local function write_file(path, data)
  ensure_state_dir()

  local fd, err = vim.uv.fs_open(path, "w", 438)

  if not fd then
    return false, err
  end

  vim.uv.fs_write(fd, data, 0)
  vim.uv.fs_close(fd)

  return true, nil
end

---@return string
function M.path()
  return state_path()
end

---@return sabunv.moonfly.state
function M.default()
  return vim.deepcopy(DEFAULT_STATE)
end

---@return sabunv.moonfly.state
function M.load()
  ensure_state_dir()

  local raw = read_file(state_path())
  local decoded = nil

  if raw and raw ~= "" then
    local ok, result = pcall(vim.json.decode, raw)

    if ok and type(result) == "table" then
      decoded = result
    end
  end

  local state = normalize_state(decoded)

  M.save(state)

  return state
end

---@param state sabunv.moonfly.state?
---@return sabunv.moonfly.state
function M.save(state)
  state = normalize_state(state)

  local json = vim.json.encode(state, { indent = "  " })
  local ok, err = write_file(state_path(), json .. "\n")

  if not ok then
    vim.notify("moonfly persistence: " .. tostring(err), vim.log.levels.ERROR)
  end

  return state
end

return M
