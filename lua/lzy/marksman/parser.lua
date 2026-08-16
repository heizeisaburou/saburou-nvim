-- Componentes de enlaces Markdown que Marksman no expone como símbolos LSP.

local M = {}

local function range(start_col, end_col)
	return { start_col = start_col, end_col = end_col }
end

local function contains(value, col)
	return value and value.start_col <= col and col < value.end_col
end

local function inside_inline_code(line, start_col)
	local prefix = line:sub(1, start_col)
	return #prefix:gsub("[^`]", "") % 2 == 1
end

function M.normalize_reference_id(value)
	local normalized = vim.trim(value:gsub("\\(.)", "%1")):gsub("%s+", " ")
	return vim.fn.tolower(normalized)
end

local function split_target(ref)
	local target = ref.raw_target or ""
	local hash = target:find("#", 1, true)
	if not hash then
		ref.path = target
		ref.path_range = vim.deepcopy(ref.target_range)
		return ref
	end

	ref.path = target:sub(1, hash - 1)
	ref.fragment = target:sub(hash + 1)
	ref.path_range = range(ref.target_range.start_col, ref.target_range.start_col + hash - 1)
	ref.fragment_range = range(ref.path_range.end_col + 1, ref.target_range.end_col)
	return ref
end

---@param line string
---@param row integer|nil
---@return table|nil
function M.definition(line, row)
	row = row or 0
	local indent = line:match("^( *)") or ""
	if #indent > 3 or line:sub(#indent + 1, #indent + 1) ~= "[" then
		return nil
	end

	local opening = #indent + 1
	local closing, escaped
	for idx = opening + 1, #line do
		local char = line:sub(idx, idx)
		if char == "]" and not escaped then
			closing = idx
			break
		end
		escaped = char == "\\" and not escaped
	end
	local label = closing and line:sub(opening + 1, closing - 1) or ""
	if not closing or vim.trim(label) == "" or label:sub(1, 1) == "^" or line:sub(closing + 1, closing + 1) ~= ":" then
		return nil
	end

	local token_start = closing + 2
	while line:sub(token_start, token_start):match("[ \t]") do
		token_start = token_start + 1
	end
	if token_start > #line then
		return nil
	end

	local angled = line:sub(token_start, token_start) == "<"
	local target_start = token_start + (angled and 1 or 0)
	local target_end, token_end
	if angled then
		escaped = false
		for idx = target_start, #line do
			local char = line:sub(idx, idx)
			if char == ">" and not escaped then
				target_end, token_end = idx - 1, idx
				break
			end
			escaped = char == "\\" and not escaped
		end
	else
		local depth, idx = 0, target_start
		escaped = false
		while idx <= #line do
			local char = line:sub(idx, idx)
			if not escaped and char:match("[ \t]") and depth == 0 then
				break
			elseif not escaped and char == "(" then
				depth = depth + 1
			elseif not escaped and char == ")" then
				if depth == 0 then
					break
				end
				depth = depth - 1
			end
			escaped = char == "\\" and not escaped
			idx = idx + 1
		end
		if idx > target_start and depth == 0 then
			target_end, token_end = idx - 1, idx - 1
		end
	end
	if not target_end or target_start > target_end then
		return nil
	end

	local title, title_range, title_delimiter
	local title_start = token_end + 1
	while line:sub(title_start, title_start):match("[ \t]") do
		title_start = title_start + 1
	end
	local opening_delimiter = line:sub(title_start, title_start)
	local closing_delimiter = opening_delimiter == "(" and ")" or opening_delimiter
	local definition_end = token_end
	if opening_delimiter == '"' or opening_delimiter == "'" or opening_delimiter == "(" then
		escaped = false
		for idx = title_start + 1, #line do
			local char = line:sub(idx, idx)
			if char == closing_delimiter and not escaped and line:sub(idx + 1):match("^%s*$") then
				title = line:sub(title_start + 1, idx - 1)
				title_range = range(title_start, idx - 1)
				title_delimiter = opening_delimiter
				definition_end = idx
				break
			end
			escaped = char == "\\" and not escaped
		end
	end

	return split_target({
		kind = "reference_definition",
		raw = line:sub(opening, definition_end),
		range = {
			start_row = row,
			start_col = opening - 1,
			end_row = row,
			end_col = definition_end,
		},
		label = label,
		label_range = range(opening, closing - 1),
		raw_target = line:sub(target_start, target_end),
		target_range = range(target_start - 1, target_end),
		target_token_range = range(token_start - 1, token_end),
		angled = angled,
		title = title,
		title_range = title_range,
		title_delimiter = title_delimiter,
	})
end

local function wiki_links(line, row)
	local refs, search = {}, 1
	while search <= #line do
		local start_col, opening_end = line:find("!?%[%[", search)
		if not start_col then
			break
		end
		local close = line:find("]]", opening_end + 1, true)
		if not close then
			break
		end
		if not inside_inline_code(line, start_col - 1) then
			local inner_start = opening_end + 1
			local inner = line:sub(inner_start, close - 1)
			local pipe = inner:find("|", 1, true)
			local raw_target = pipe and inner:sub(1, pipe - 1) or inner
			local ref = split_target({
				kind = "wiki",
				raw = line:sub(start_col, close + 1),
				range = {
					start_row = row,
					start_col = start_col - 1,
					end_row = row,
					end_col = close + 1,
				},
				raw_target = raw_target,
				target_range = range(inner_start - 1, inner_start - 1 + #raw_target),
				embed = line:sub(start_col, start_col) == "!",
			})
			if pipe then
				ref.label = inner:sub(pipe + 1)
				ref.label_range = range(inner_start - 1 + pipe, close - 1)
			end
			refs[#refs + 1] = ref
		end
		search = close + 2
	end
	return refs
end

local function overlaps(refs, start_col, end_col)
	for _, ref in ipairs(refs) do
		if ref.range.start_col < end_col and start_col < ref.range.end_col then
			return true
		end
	end
	return false
end

local function named_child(node, wanted)
	for child in node:iter_children() do
		if child:named() and child:type() == wanted then
			return child
		end
	end
end

local function node_range(node)
	local _, start_col, _, end_col = node:range()
	return range(start_col, end_col)
end

---@param lines string[]
---@return table<integer, boolean>
function M.excluded_rows(lines)
	-- Implementación compartida: la misma estructura de Markdown la necesitan
	-- los diagnósticos y las reescrituras de los dos motores.
	return require("lzy.link_target").excluded_rows(lines)
end

---@param line string
---@param row integer|nil
---@return table[]
function M.links(line, row)
	row = row or 0
	if M.definition(line, row) then
		return {}
	end
	local refs = wiki_links(line, row)
	local ok, parser = pcall(vim.treesitter.get_string_parser, line, "markdown_inline")
	if not ok then
		return refs
	end
	local tree = parser:parse()[1]
	if not tree then
		return refs
	end

	local function walk(node)
		local kind = node:type()
		local _, start_col, _, end_col = node:range()
		if not overlaps(refs, start_col, end_col) then
			if kind == "inline_link" or kind == "image" then
				local label_node = named_child(node, kind == "image" and "image_description" or "link_text")
				local target_node = named_child(node, "link_destination")
				if target_node then
					local title_node = named_child(node, "link_title")
					local title_text = title_node and vim.treesitter.get_node_text(title_node, line) or nil
					local title_range = title_node and node_range(title_node) or nil
					if title_range then
						title_range.start_col = title_range.start_col + 1
						title_range.end_col = title_range.end_col - 1
					end
					refs[#refs + 1] = split_target({
						kind = "inline",
						raw = vim.treesitter.get_node_text(node, line),
						range = { start_row = row, start_col = start_col, end_row = row, end_col = end_col },
						label = label_node and vim.treesitter.get_node_text(label_node, line) or nil,
						label_range = label_node and node_range(label_node) or nil,
						raw_target = vim.treesitter.get_node_text(target_node, line),
						target_range = node_range(target_node),
						title = title_text and title_text:sub(2, -2) or nil,
						title_range = title_range,
						embed = kind == "image",
					})
					return
				end
			elseif kind == "full_reference_link" or kind == "collapsed_reference_link" or kind == "shortcut_link" then
				local label_node = named_child(node, "link_text")
				local id_node = named_child(node, "link_label")
				if label_node then
					local label = vim.treesitter.get_node_text(label_node, line)
					local id, id_range
					if id_node then
						local raw_id = vim.treesitter.get_node_text(id_node, line)
						id = raw_id:sub(2, -2)
						local value = node_range(id_node)
						id_range = range(value.start_col + 1, value.end_col - 1)
					else
						id, id_range = label, node_range(label_node)
					end
					refs[#refs + 1] = {
						kind = "reference_use",
						form = kind:gsub("_reference_link$", ""),
						raw = vim.treesitter.get_node_text(node, line),
						range = { start_row = row, start_col = start_col, end_row = row, end_col = end_col },
						label = label,
						label_range = node_range(label_node),
						reference_id = id,
						reference_id_range = id_range,
					}
					return
				end
			end
		end
		for child in node:iter_children() do
			if child:named() then
				walk(child)
			end
		end
	end
	walk(tree:root())
	table.sort(refs, function(a, b)
		return a.range.start_col < b.range.start_col
	end)
	return refs
end

---@param lines string[]
---@return table<string, table>
function M.definitions(lines, excluded)
	excluded = excluded or M.excluded_rows(lines)
	local result = {}
	for idx, line in ipairs(lines) do
		local definition = not excluded[idx - 1] and M.definition(line, idx - 1) or nil
		if definition then
			local id = M.normalize_reference_id(definition.label)
			result[id] = result[id] or definition
		end
	end
	return result
end

---@param lines string[]
---@param row integer
---@param col integer
---@return table|nil
function M.at(lines, row, col)
	local excluded = M.excluded_rows(lines)
	if excluded[row] then
		return nil
	end
	local line = lines[row + 1] or ""
	local definition = M.definition(line, row)
	if definition and contains(definition.range, col) then
		return definition
	end
	for _, ref in ipairs(M.links(line, row)) do
		if contains(ref.range, col) then
			if ref.kind == "reference_use" then
				ref.definition = M.definitions(lines, excluded)[M.normalize_reference_id(ref.reference_id)]
				if ref.definition then
					ref.raw_target = ref.definition.raw_target
					ref.path = ref.definition.path
					ref.fragment = ref.definition.fragment
				end
			end
			return ref
		end
	end
end

---@param ref table
---@param col integer
---@return table|nil
function M.component(ref, col)
	local function contains_fragment()
		return ref.fragment_range and ref.fragment_range.start_col - 1 <= col and col < ref.fragment_range.end_col
	end
	local function target_kind()
		local is_url = ref.path and ref.path:match("^[%a][%w+.-]*:") and not ref.path:match("^%a:[/\\]")
		return is_url and "url" or "note"
	end
	if target_kind() == "url" and contains(ref.target_range, col) then
		return { kind = "url", text = ref.raw_target, range = ref.target_range }
	end
	if ref.kind == "reference_definition" then
		if contains(ref.label_range, col) then
			return { kind = "reference_id", text = ref.label, range = ref.label_range }
		elseif contains(ref.path_range, col) then
			return { kind = target_kind(), text = ref.path, range = ref.path_range }
		elseif contains_fragment() then
			return { kind = "heading", text = ref.fragment, range = ref.fragment_range }
		elseif contains(ref.title_range, col) then
			return { kind = "description", text = ref.title, range = ref.title_range }
		end
	elseif ref.kind == "reference_use" then
		local collapsed = ref.label_range.start_col == ref.reference_id_range.start_col
			and ref.label_range.end_col == ref.reference_id_range.end_col
		if not collapsed and contains(ref.label_range, col) then
			return { kind = "label", text = ref.label, range = ref.label_range }
		elseif contains(ref.reference_id_range, col) then
			return { kind = "reference_id", text = ref.reference_id, range = ref.reference_id_range }
		end
	else
		if contains(ref.label_range, col) then
			return { kind = "label", text = ref.label, range = ref.label_range }
		elseif contains(ref.path_range, col) then
			return { kind = target_kind(), text = ref.path, range = ref.path_range }
		elseif contains_fragment() then
			return { kind = "heading", text = ref.fragment, range = ref.fragment_range }
		elseif contains(ref.title_range, col) then
			return { kind = "description", text = ref.title, range = ref.title_range }
		end
	end
end

return M
