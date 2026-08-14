-- Backlinks estructurales para el workspace de Marksman.
--
-- No delegamos en una búsqueda textual: cada candidato se resuelve con las
-- mismas coordenadas que hover/gd/rename. Así un basename ambiguo no se
-- convierte silenciosamente en backlink de una nota cualquiera y los usos
-- CommonMark apuntan a través de su declaración.

local M = {}

local function read_lines(path)
	local bufnr = vim.fn.bufnr(path)
	if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
		return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	end
	local ok, lines = pcall(vim.fn.readfile, path)
	return ok and lines or {}
end

local function same_path(left, right)
	return vim.fs.normalize(left) == vim.fs.normalize(right)
end

local function points_to(ref, source_path, target_path, root)
	if not ref or not ref.path then
		return false
	end
	local paths = require("lzy.marksman.workspace").resolve(ref.path, {
		source_path = source_path,
		root = root,
	})
	return #paths == 1 and same_path(paths[1], target_path)
end

---@param target_path string
---@param root string
---@return table[]
function M.collect(target_path, root)
	target_path, root = vim.fs.normalize(target_path), vim.fs.normalize(root)
	local parser = require("lzy.marksman.parser")
	local workspace = require("lzy.marksman.workspace")
	local result = {}

	for _, source_path in ipairs(workspace.files(root, { markdown = true })) do
		local lines = read_lines(source_path)
		local excluded = parser.excluded_rows(lines)
		local definitions = parser.definitions(lines, excluded)
		for idx, line in ipairs(lines) do
			if not excluded[idx - 1] then
				for _, ref in ipairs(parser.links(line, idx - 1)) do
					local declared = ref
					if ref.kind == "reference_use" then
						declared = definitions[parser.normalize_reference_id(ref.reference_id)]
					end
					if points_to(declared, source_path, target_path, root) then
						result[#result + 1] = {
							filename = source_path,
							lnum = idx,
							col = ref.range.start_col + 1,
							text = vim.trim(line),
							file = source_path,
							pos = { idx, ref.range.start_col },
							end_pos = { idx, ref.range.end_col },
							line = line,
						}
					end
				end
			end
		end
	end

	table.sort(result, function(left, right)
		if left.filename ~= right.filename then
			return left.filename < right.filename
		elseif left.lnum ~= right.lnum then
			return left.lnum < right.lnum
		end
		return left.col < right.col
	end)
	return result
end

local function default_pick(items, opts)
	local ok, picker = pcall(require, "snacks.picker")
	if ok then
		picker.pick({
			title = opts.prompt_title,
			items = items,
			format = "file",
			preview = "file",
			confirm = "jump",
			show_empty = true,
			jump = { tagstack = true, reuse_win = true },
			win = {
				preview = {
					-- La configuración general usa cursorlineopt=number. El preview
					-- necesita `line` para marcar de verdad la fila del backlink;
					-- `end_pos` resalta además el enlace exacto dentro de ella.
					wo = { cursorline = true, cursorlineopt = "line" },
				},
			},
		})
		return
	end

	if #items == 0 then
		vim.notify("Esta nota no tiene backlinks", vim.log.levels.INFO, { title = "Marksman" })
		return
	end
	vim.ui.select(items, {
		prompt = opts.prompt_title,
		format_item = function(item)
			return ("%s:%d  %s"):format(vim.fn.fnamemodify(item.filename, ":~:."), item.lnum, item.text)
		end,
	}, function(item)
		if item then
			vim.cmd.edit(vim.fn.fnameescape(item.filename))
			vim.api.nvim_win_set_cursor(0, item.pos)
		end
	end)
end

---@param opts { bufnr?: integer, root?: string, path?: string, pick?: fun(items: table[], opts: table) }|nil
function M.open(opts)
	opts = opts or {}
	local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
	local path = opts.path or vim.api.nvim_buf_get_name(bufnr)
	local root = opts.root or require("lzy.marksman.workspace").root(bufnr)
	if path == "" or not root then
		vim.notify("El buffer no pertenece a un workspace de Marksman", vim.log.levels.ERROR, { title = "Marksman" })
		return
	end
	(opts.pick or default_pick)(M.collect(path, root), { prompt_title = "Backlinks" })
end

return M
