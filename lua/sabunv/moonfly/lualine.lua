-- sabunv.moonfly.lualine

local M = {}

---@type table?
M._config = nil

local function solid()
  local col = sabunv.moonfly.colors

  local bg = col.darkest_gray
  local selected_bg = col.darker_gray
  local fg = col.gray
  local selected_fg = col.white
  local inactive_fg = col.medium_gray

  return {
    theme = {
      normal = {
        a = { fg = col.bg, bg = col.blue, gui = "bold" },
        b = { fg = selected_fg, bg = selected_bg },
        c = { fg = fg, bg = bg },
      },
      insert = {
        a = { fg = col.bg, bg = col.green, gui = "bold" },
        b = { fg = selected_fg, bg = selected_bg },
        c = { fg = fg, bg = bg },
      },
      visual = {
        a = { fg = col.bg, bg = col.yellow, gui = "bold" },
        b = { fg = selected_fg, bg = selected_bg },
        c = { fg = fg, bg = bg },
      },
      replace = {
        a = { fg = col.bg, bg = col.red, gui = "bold" },
        b = { fg = selected_fg, bg = selected_bg },
        c = { fg = fg, bg = bg },
      },
      command = {
        a = { fg = col.bg, bg = col.light_blue, gui = "bold" },
        b = { fg = selected_fg, bg = selected_bg },
        c = { fg = fg, bg = bg },
      },
      inactive = {
        a = { fg = inactive_fg, bg = bg },
        b = { fg = inactive_fg, bg = bg },
        c = { fg = inactive_fg, bg = bg },
      },
    },

    component_colors = {
      appname = {
        icon = "",
        fg = "#1B2949",
      },
      claude = {
        icon = "",
        fg = col.yellow,
      },
      codex = {
        icon = "󰞶",
        fg = col.blue,
      },
      copilot = {
        icon = "",
        fg = col.light_green,
      },
      filename = {
        fg = col.darker_white,
      },
      filename_inactive = {
        fg = col.medium_gray,
      },
    },
  }
end

local function transparent()
  local col = sabunv.moonfly.colors

  local bg = col.darkest_gray
  local selected_bg = col.darker_gray
  local fg = col.gray
  local selected_fg = col.darker_white
  local inactive_fg = col.medium_gray

  return {
    theme = {
      normal = {
        a = { fg = col.bg, bg = col.light_blue, gui = "bold" },
        b = { fg = selected_fg, bg = selected_bg },
        c = { fg = fg, bg = bg },
      },
      insert = {
        a = { fg = col.bg, bg = col.light_green, gui = "bold" },
        b = { fg = selected_fg, bg = selected_bg },
        c = { fg = fg, bg = bg },
      },
      visual = {
        a = { fg = col.bg, bg = col.yellow, gui = "bold" },
        b = { fg = selected_fg, bg = selected_bg },
        c = { fg = fg, bg = bg },
      },
      replace = {
        a = { fg = col.bg, bg = col.red, gui = "bold" },
        b = { fg = selected_fg, bg = selected_bg },
        c = { fg = fg, bg = bg },
      },
      command = {
        a = { fg = col.bg, bg = col.lightest_blue, gui = "bold" },
        b = { fg = selected_fg, bg = selected_bg },
        c = { fg = fg, bg = bg },
      },
      inactive = {
        a = { fg = inactive_fg, bg = bg },
        b = { fg = inactive_fg, bg = bg },
        c = { fg = inactive_fg, bg = bg },
      },
    },

    component_colors = {
      appname = {
        icon = "",
        fg = "#1B2949",
      },
      claude = {
        icon = "",
        fg = col.yellow,
      },
      codex = {
        icon = "󰞶",
        fg = col.light_blue,
      },
      copilot = {
        icon = "",
        fg = col.light_green,
      },
      filename = {
        fg = col.darker_white,
      },
      filename_inactive = {
        fg = col.medium_gray,
      },
    },
  }
end

---@param state sabunv.moonfly.state
---@return table
local function generate_config(state)
  if state.style == "solid" then
    return solid()
  elseif state.style == "transparent" then
    return transparent()
  else
    error("invalid moonfly style: " .. tostring(state.style))
  end
end

---@param state sabunv.moonfly.state
function M.setup(state)
  M._config = generate_config(state)
end

---@param state sabunv.moonfly.state
function M.resetup(state)
  M._config = generate_config(state)

  local ok, lualine = pcall(require, "lzy.l_lualine")

  if ok and lualine.is_setup and lualine.is_setup() then
    lualine.resetup()
  end
end

---@return table
function M.config()
  if not M._config then
    M.setup(sabunv.moonfly.state())
  end

  return vim.deepcopy(M._config)
end

return M
