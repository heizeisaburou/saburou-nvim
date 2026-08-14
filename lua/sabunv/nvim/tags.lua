-- Tags Markdown compartidos por Marksman y obsidian-ls.
--
-- El rango `range` incluye el `#` de un tag inline; `value_range` contiene
-- solo su nombre. En frontmatter ambos rangos coinciden porque el valor no
-- lleva `#`. Las coordenadas son filas y columnas byte, 0-based/end-exclusive.

local M = {}

local MARKDOWN_EXTENSIONS = {
	md = true,
	markdown = true,
	mdx = true,
	mdown = true,
	mkdn = true,
	mkd = true,
	qmd = true,
	rmd = true,
}

local SKIP_DIRECTORIES = {
	[".git"] = true,
	[".hg"] = true,
	[".svn"] = true,
	["node_modules"] = true,
}

local function lower(value)
	return vim.fn.tolower(value)
end

local function allowed_byte(byte)
	return byte
		and (
			byte >= 128
			or byte >= string.byte("a") and byte <= string.byte("z")
			or byte >= string.byte("A") and byte <= string.byte("Z")
			or byte >= string.byte("0") and byte <= string.byte("9")
			or byte == string.byte("_")
			or byte == string.byte("-")
			or byte == string.byte("/")
		)
end

local function is_hex_color(value)
	local size = #value
	return (size == 3 or size == 4 or size == 6 or size == 8) and value:match("^%x+$") ~= nil
end

---@param value string
---@return string|nil normalized
---@return string|nil error
function M.validate(value)
	value = vim.trim(value or ""):gsub("^#", "")
	if value == "" then
		return nil, "El tag no puede estar vacío"
	elseif tonumber(value) or is_hex_color(value) then
		return nil, "El tag no puede ser un número ni un color hexadecimal"
	elseif value:sub(1, 1) == "/" or value:sub(-1) == "/" or value:find("//", 1, true) then
		return nil, "Los subtags necesitan nombres a ambos lados de cada '/'"
	end
	for idx = 1, #value do
		if not allowed_byte(value:byte(idx)) then
			return nil, ("El tag contiene un carácter no válido: %s"):format(value:sub(idx, idx))
		end
	end
	return value
end

---@param line string
---@param row integer
---@return table[]
function M.parse_line(line, row)
	row = row or 0
	if line:find("<!%-%-.*%-%->") then
		return {}
	end

	local result, search = {}, 1
	while search <= #line do
		local hash = line:find("#", search, true)
		if not hash then
			break
		end
		-- Es el mismo límite conservador de obsidian.nvim: principio de línea o
		-- espacio literal. Evita reconocer fragmentos, colores y `foo#bar`.
		local valid_boundary = hash == 1 or line:sub(hash - 1, hash - 1) == " "
		local finish = hash + 1
		while finish <= #line and allowed_byte(line:byte(finish)) do
			finish = finish + 1
		end
		local tag = line:sub(hash + 1, finish - 1)
		if valid_boundary and tag ~= "" and not tonumber(tag) and not is_hex_color(tag) then
			result[#result + 1] = {
				tag = tag,
				range = { start_row = row, start_col = hash - 1, end_row = row, end_col = finish - 1 },
				value_range = { start_row = row, start_col = hash, end_row = row, end_col = finish - 1 },
				frontmatter = false,
			}
		end
		search = math.max(finish, hash + 1)
	end
	return result
end

local function scalar_tag(line, start_byte, end_byte, row)
	while start_byte <= end_byte and line:sub(start_byte, start_byte):match("%s") do
		start_byte = start_byte + 1
	end
	while end_byte >= start_byte and line:sub(end_byte, end_byte):match("%s") do
		end_byte = end_byte - 1
	end
	local quote = line:sub(start_byte, start_byte)
	if quote == '"' or quote == "'" then
		start_byte = start_byte + 1
		if line:sub(end_byte, end_byte) == quote then
			end_byte = end_byte - 1
		end
	end
	if line:sub(start_byte, start_byte) == "#" then
		start_byte = start_byte + 1
	end
	local finish = start_byte
	while finish <= end_byte and allowed_byte(line:byte(finish)) do
		finish = finish + 1
	end
	local value = line:sub(start_byte, finish - 1)
	if value == "" or not M.validate(value) then
		return nil
	end
	return {
		tag = value,
		range = { start_row = row, start_col = start_byte - 1, end_row = row, end_col = finish - 1 },
		value_range = { start_row = row, start_col = start_byte - 1, end_row = row, end_col = finish - 1 },
		frontmatter = true,
	}
end

local function frontmatter_end(lines)
	local delimiter = lines[1]
	if delimiter ~= "---" and delimiter ~= "+++" then
		return nil
	end
	for idx = 2, #lines do
		if lines[idx] == delimiter then
			return idx
		end
	end
end

local function flow_tags(line, start_byte, end_byte, row)
	local result, segment_start, quote = {}, start_byte, nil
	for idx = start_byte, end_byte + 1 do
		local char = line:sub(idx, idx)
		if (char == '"' or char == "'") and (not quote or quote == char) then
			quote = quote and nil or char
		elseif (char == "," or idx == end_byte + 1) and not quote then
			local tag = scalar_tag(line, segment_start, idx - 1, row)
			if tag then
				result[#result + 1] = tag
			end
			segment_start = idx + 1
		end
	end
	return result
end

---@param lines string[]
---@return table[]
function M.frontmatter(lines)
	local closing = frontmatter_end(lines)
	if not closing then
		return {}
	end

	local result, list_indent = {}, nil
	for idx = 2, closing - 1 do
		local line, row = lines[idx], idx - 1
		local indent, key, delimiter, value = line:match("^(%s*)([%w_-]+)%s*([:=])%s*(.*)$")
		if key then
			list_indent = nil
			if key:lower() == "tags" then
				local value_start = assert(line:find(value, #indent + #key + 1, true))
				local open = value:sub(1, 1)
				if open == "[" then
					for _, tag in ipairs(flow_tags(line, value_start + 1, value_start + #value - 2, row)) do
						result[#result + 1] = tag
					end
				elseif value ~= "" then
					local tag = scalar_tag(line, value_start, #line, row)
					if tag then
						result[#result + 1] = tag
					end
				elseif delimiter == ":" then
					list_indent = #indent
				end
			end
		elseif list_indent then
			local item_indent, item = line:match("^(%s*)%-%s+(.+)$")
			if item and #item_indent > list_indent then
				local item_start = assert(line:find(item, #item_indent + 2, true))
				local tag = scalar_tag(line, item_start, #line, row)
				if tag then
					result[#result + 1] = tag
				end
			elseif line:match("%S") then
				list_indent = nil
			end
		end
	end
	return result
end

local function excluded_rows(lines)
	local ok, parser = pcall(require, "lzy.marksman.parser")
	return ok and parser.excluded_rows(lines) or {}
end

---@param lines string[]
---@return table[]
function M.occurrences(lines)
	local result, excluded = M.frontmatter(lines), excluded_rows(lines)
	for idx, line in ipairs(lines) do
		if not excluded[idx - 1] then
			for _, tag in ipairs(M.parse_line(line, idx - 1)) do
				result[#result + 1] = tag
			end
		end
	end
	table.sort(result, function(a, b)
		return a.range.start_row < b.range.start_row
			or a.range.start_row == b.range.start_row and a.range.start_col < b.range.start_col
	end)
	return result
end

local function buffer_lines(path)
	local bufnr = vim.fn.bufnr(path)
	if bufnr > 0 and vim.api.nvim_buf_is_loaded(bufnr) then
		return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	end
	local ok, lines = pcall(vim.fn.readfile, path)
	return ok and lines or {}
end

M.read_lines = buffer_lines

---@param bufnr integer
---@param row integer|nil
---@param col integer|nil
---@return table|nil
function M.at(bufnr, row, col)
	local cursor = vim.api.nvim_win_get_cursor(0)
	row, col = row or cursor[1] - 1, col or cursor[2]
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	for _, tag in ipairs(M.occurrences(lines)) do
		local range = tag.frontmatter and tag.value_range or tag.range
		if range.start_row == row and range.start_col <= col and col < range.end_col then
			return tag
		end
	end
end

---@param candidate string
---@param parent string
---@return boolean
function M.matches(candidate, parent)
	candidate, parent = lower(candidate), lower(parent)
	return candidate == parent or vim.startswith(candidate, parent .. "/")
end

---@param root string
---@return string[]
function M.files(root)
	local result = {}
	for relative, kind in
		vim.fs.dir(root, {
			depth = 100,
			skip = function(dir)
				return not SKIP_DIRECTORIES[vim.fs.basename(dir)]
			end,
		})
	do
		local extension = relative:match("%.([^./\\]+)$")
		if kind == "file" and extension and MARKDOWN_EXTENSIONS[extension:lower()] then
			result[#result + 1] = vim.fs.normalize(vim.fs.joinpath(root, relative))
		end
	end
	table.sort(result)
	return result
end

---@param old_name string
---@param new_name string
---@param root string
---@param opts { files?: string[] }|nil
---@return lsp.WorkspaceEdit|nil
---@return string|nil
---@return integer
function M.rename_edit(old_name, new_name, root, opts)
	local old, old_err = M.validate(old_name)
	if not old then
		return nil, old_err, 0
	end
	local new, new_err = M.validate(new_name)
	if not new then
		return nil, new_err, 0
	end

	local changes, count = {}, 0
	for _, path in ipairs(opts and opts.files or M.files(root)) do
		local edits = {}
		for _, tag in ipairs(M.occurrences(buffer_lines(path))) do
			if M.matches(tag.tag, old) then
				local suffix = tag.tag:sub(#old + 1)
				edits[#edits + 1] = {
					range = {
						start = { line = tag.value_range.start_row, character = tag.value_range.start_col },
						["end"] = { line = tag.value_range.end_row, character = tag.value_range.end_col },
					},
					newText = new .. suffix,
				}
				count = count + 1
			end
		end
		if #edits > 0 then
			changes[vim.uri_from_fname(path)] = edits
		end
	end
	return { changes = changes }, nil, count
end

return M
