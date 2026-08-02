-- sabunv.moonfly.hl

local M = {}

function M.get(group)
  return vim.api.nvim_get_hl(0, {
    name = group,
    link = false,
  })
end

function M.get_raw(group)
  return vim.api.nvim_get_hl(0, {
    name = group,
    link = true,
  })
end

function M.set(group, opts)
  vim.api.nvim_set_hl(0, group, opts)
end

function M.update(group, opts)
  vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", M.get(group), opts))
end

function M.update_raw(group, opts)
  vim.api.nvim_set_hl(0, group, vim.tbl_extend("force", M.get_raw(group), opts))
end

function M.update_many(groups, opts)
  for _, group in ipairs(groups) do
    M.update(group, opts)
  end
end

function M.inspect(group)
  local hl = M.get(group)

  if vim.tbl_isempty(hl) then
    vim.notify("HL " .. group .. ": no existe o está vacío", vim.log.levels.INFO)
    return
  end

  vim.notify("HL " .. group .. ": " .. vim.inspect(hl), vim.log.levels.INFO)
end

vim.api.nvim_create_user_command("CopyHighlights", function()
  local path = vim.fs.joinpath(vim.fn.stdpath "cache", "nvim-highlights.txt")
  local output = vim.fn.execute "silent highlight"
  local ok = vim.fn.writefile(vim.split(output, "\n", { plain = true }), path)

  if ok == 0 then
    vim.notify("Highlights written to " .. path, vim.log.levels.INFO)
  else
    vim.notify("Could not write highlights to " .. path, vim.log.levels.ERROR)
  end
end, {})

-- vim.api.nvim_create_user_command("CopyHighlights", function()
--   vim.cmd [[
--     redir @+
--     silent highlight
--     redir END
--   ]]
-- end, {})

return M
