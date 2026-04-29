-- sabunv.util.clipboard

local M = {}

M.saburou = {}
M.saburou.legacy_mappings = {}

local legacy_mappings_enabled = false

local legacy_mapping_opts = {
  noremap = true,
  silent = true,
}

local legacy_specs = {
  { { "n", "x" }, "x", '"_x' },
  { { "n", "x" }, "X", "x" },
  { "n", "D", "d" },
  { "n", "d", '"_d' },
  { "n", "s", '"_s' },
  { "n", "S", '"_S' },
  { "n", "C", '"_C' },
}

local legacy_visual_luasnip_specs = {
  { "p", "p", "P" },
  { "P", "P", "p" },
  { "d", "d", '"_d' },
  { "D", "D", "d" },
  { "s", "s", '"_s' },
  { "S", "s", "s" },
}

local function feedkeys(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end

local function make_visual_luasnip_rhs(inside_snip, outside_snip)
  return function()
    local has_luasnip, luasnip = pcall(require, "luasnip")

    if has_luasnip and luasnip.in_snippet() then
      feedkeys(inside_snip)
    else
      feedkeys(outside_snip)
    end
  end
end

local function set_keymap(mode, lhs, rhs)
  vim.keymap.set(mode, lhs, rhs, legacy_mapping_opts)
end

local function del_keymap(mode, lhs)
  pcall(vim.keymap.del, mode, lhs)
end

local function enable_legacy_mappings()
  for _, spec in ipairs(legacy_specs) do
    local mode, lhs, rhs = spec[1], spec[2], spec[3]
    set_keymap(mode, lhs, rhs)
  end

  for _, spec in ipairs(legacy_visual_luasnip_specs) do
    local lhs, inside_snip, outside_snip = spec[1], spec[2], spec[3]
    set_keymap("x", lhs, make_visual_luasnip_rhs(inside_snip, outside_snip))
  end

  legacy_mappings_enabled = true
end

local function disable_legacy_mappings()
  for _, spec in ipairs(legacy_specs) do
    local mode, lhs = spec[1], spec[2]
    del_keymap(mode, lhs)
  end

  for _, spec in ipairs(legacy_visual_luasnip_specs) do
    local lhs = spec[1]
    del_keymap("x", lhs)
  end

  legacy_mappings_enabled = false
end

---@return boolean
function M.saburou.legacy_mappings.enabled()
  return legacy_mappings_enabled
end

---@return boolean enabled
function M.saburou.legacy_mappings.enable()
  if not legacy_mappings_enabled then
    enable_legacy_mappings()
  end

  return legacy_mappings_enabled
end

---@return boolean enabled
function M.saburou.legacy_mappings.disable()
  if legacy_mappings_enabled then
    disable_legacy_mappings()
  end

  return legacy_mappings_enabled
end

---@param enabled? boolean
---@return boolean enabled
function M.saburou.legacy_mappings.set(enabled)
  vim.validate("enabled", enabled, "boolean", true)

  if enabled == nil then
    enabled = true
  end

  if enabled then
    return M.saburou.legacy_mappings.enable()
  end

  return M.saburou.legacy_mappings.disable()
end

---@return boolean enabled
function M.saburou.legacy_mappings.toggle()
  return M.saburou.legacy_mappings.set(not legacy_mappings_enabled)
end

-- Establece `vim.o.clipboard` a "unnamedplus" (sincronizar) o "" (no-sincronizar)
---@param sync? boolean Por defecto `true`
function M.sync(sync)
  vim.validate("sync", sync, "boolean", true)

  if sync == nil then
    sync = true
  end

  local cb = sync and "unnamedplus" or ""

  vim.schedule(function()
    vim.o.clipboard = cb
  end)
end

return M
