-- Resolución de notas con una garantía adicional para extensiones explícitas.

local M = {}

---@param target string
---@return string|nil
local function explicit_extension(target)
  return target:lower():match "%.(md)$"
    or target:lower():match "%.(qmd)$"
    or target:lower():match "%.(base)$"
end

---@param target string
---@param note obsidian.Note
---@return boolean
local function matches_explicit_path(target, note)
  if not explicit_extension(target) or not note.path then
    return true
  end
  local decoded = vim.uri_decode(target) or target
  decoded = require("obsidian.util").unescape_single_backslash(decoded):gsub("\\", "/")
  local actual = vim.fs.normalize(tostring(note.path)):gsub("\\", "/")
  local wanted = decoded:gsub("^%./", ""):lower()
  local actual_lower = actual:lower()

  if wanted:find("/", 1, true) then
    return actual_lower:sub(-#wanted) == wanted
  end
  return vim.fs.basename(actual_lower) == wanted
end

---@param target string
---@param callback fun(notes: obsidian.Note[])
---@param opts { notes?: obsidian.note.LoadOpts }|nil
function M.resolve_async(target, callback, opts)
  require("obsidian.search").resolve_note_async(target, function(notes)
    callback(vim.tbl_filter(function(note)
      return matches_explicit_path(target, note)
    end, notes))
  end, opts)
end

M.matches_explicit_path = matches_explicit_path

return M
