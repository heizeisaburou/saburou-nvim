-- Índice y rename de tags Markdown para la rama Marksman.

local M = {}
local tags = require("sabunv.nvim.tags")

---@param bufnr integer
---@param row integer|nil 0-based
---@param col integer|nil 0-based
---@return table|nil
function M.at(bufnr, row, col)
	return tags.at(bufnr, row, col)
end

---@param wanted string
---@param root string
---@return table[]
function M.collect(wanted, root)
	local result = {}
	for _, path in ipairs(require("lzy.marksman.workspace").files(root, { markdown = true })) do
		local lines = tags.read_lines(path)
		for _, tag in ipairs(tags.occurrences(lines)) do
			if tags.matches(tag.tag, wanted) then
				local idx = tag.range.start_row + 1
				local line = lines[idx] or ""
				result[#result + 1] = {
					file = path,
					filename = path,
					pos = { idx, tag.range.start_col },
					end_pos = { idx, tag.range.end_col },
					lnum = idx,
					col = tag.range.start_col + 1,
					line = line,
					text = vim.trim(line),
					tag = tag.tag,
					label = "#" .. tag.tag,
				}
			end
		end
	end
	return result
end

---@param wanted string
---@param root string
---@return table[]
function M.branches(wanted, root)
	local occurrences = M.collect(wanted, root)
	local grouped = {}
	for _, occurrence in ipairs(occurrences) do
		local key = vim.fn.tolower(occurrence.tag)
		local branch = grouped[key]
		if not branch then
			branch = {
				tag = occurrence.tag,
				text = "#" .. occurrence.tag,
				count = 0,
				files = {},
			}
			grouped[key] = branch
		end
	end
	for _, occurrence in ipairs(occurrences) do
		local key = vim.fn.tolower(occurrence.tag)
		while key do
			local branch = grouped[key]
			if branch then
				branch.count = branch.count + 1
				branch.files[occurrence.file] = true
			end
			key = key:match("^(.*)/[^/]+$")
		end
	end

	local result = {}
	for _, branch in pairs(grouped) do
		branch.notes = vim.tbl_count(branch.files)
		branch.files = nil
		result[#result + 1] = branch
	end
	table.sort(result, function(left, right)
		local left_tag, right_tag = vim.fn.tolower(left.tag), vim.fn.tolower(right.tag)
		local parent = vim.fn.tolower(wanted)
		if left_tag == parent or right_tag == parent then
			return left_tag == parent
		end
		return left_tag < right_tag
	end)
	return result
end

local function tag_format(item)
	local notes = item.notes == 1 and "1 nota" or ("%d notas"):format(item.notes)
	local occurrences = item.count == 1 and "1 aparición" or ("%d apariciones"):format(item.count)
	return {
		{ "#" .. item.tag, "Special" },
		{ ("  %s · %s"):format(notes, occurrences), "Comment" },
	}
end

---@param tag string
---@param root string
---@param opts { pick?: fun(items: table[], opts: table) }|nil
function M.open_results(tag, root, opts)
	opts = opts or {}
	local items = M.collect(tag, root)
	if opts.pick then
		return opts.pick(items, { prompt_title = "#" .. tag })
	end
	local ok, picker = pcall(require, "snacks.picker")
	if ok then
		return picker.pick({
			title = "#" .. tag,
			items = items,
			format = "file",
			preview = "file",
			confirm = "jump",
			show_empty = true,
			jump = { tagstack = true, reuse_win = true },
		})
	end
	vim.ui.select(items, { prompt = "#" .. tag }, function(item)
		if item then
			vim.cmd.edit(vim.fn.fnameescape(item.file))
			vim.api.nvim_win_set_cursor(0, item.pos)
		end
	end)
end

local function select_branch(items, wanted, callback)
	local ok, picker = pcall(require, "snacks.picker")
	if ok then
		return picker.pick({
			title = "Tags: #" .. wanted,
			items = items,
			format = tag_format,
			preview = "none",
			layout = { preview = false },
			show_empty = true,
			confirm = function(current, item)
				current:close()
				if item then
					vim.schedule(function()
						callback(item)
					end)
				end
			end,
		})
	end
	vim.ui.select(items, {
		prompt = "Tags: #" .. wanted,
		format_item = function(item)
			return ("#%s  (%d notas, %d apariciones)"):format(item.tag, item.notes, item.count)
		end,
	}, callback)
end

---@param opts { bufnr?: integer, tag?: string, root?: string, select?: fun(items: table[], opts: table, callback: fun(item: table|nil)), pick?: fun(items: table[], opts: table) }|nil
function M.open(opts)
	opts = opts or {}
	local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
	local tag = opts.tag or M.at(bufnr)
	tag = type(tag) == "table" and tag.tag or tag
	local root = opts.root or require("lzy.marksman.workspace").root(bufnr)
	if not tag or not root then
		return
	end
	local branches = M.branches(tag, root)
	local select = opts.select or function(items, _, callback)
		return select_branch(items, tag, callback)
	end
	return select(branches, { prompt_title = "Tags: #" .. tag }, function(branch)
		if branch then
			M.open_results(branch.tag, root, opts)
		end
	end)
end

---@param bufnr integer|nil
---@param opts { input?: fun(options: table, callback: function), root?: string, apply?: fun(edit: lsp.WorkspaceEdit) }|nil
---@return boolean
function M.rename_at(bufnr, opts)
	bufnr, opts = bufnr or vim.api.nvim_get_current_buf(), opts or {}
	local tag = M.at(bufnr)
	if not tag then
		return false
	end
	local root = opts.root or require("lzy.marksman.workspace").root(bufnr)
	if not root then
		vim.notify("No se encontró el workspace de Marksman", vim.log.levels.ERROR, { title = "Marksman" })
		return true
	end

	(opts.input or vim.ui.input)({ prompt = "Renombrar tag: ", default = tag.tag }, function(new_name)
		if not new_name then
			return
		end
		local edit, err, count = tags.rename_edit(tag.tag, new_name, root, {
			files = require("lzy.marksman.workspace").files(root, { markdown = true }),
		})
		if not edit then
			vim.notify(err, vim.log.levels.ERROR, { title = "Marksman" })
			return
		elseif count == 0 then
			vim.notify("No se encontraron apariciones del tag", vim.log.levels.INFO, { title = "Marksman" })
			return
		end
		if opts.apply then
			opts.apply(edit)
		else
			vim.lsp.util.apply_workspace_edit(edit, "utf-8")
			vim.cmd("silent! wall")
		end
		vim.notify(("Tag renombrado en %d apariciones"):format(count), vim.log.levels.INFO, {
			title = "Marksman",
		})
	end)
	return true
end

return M
