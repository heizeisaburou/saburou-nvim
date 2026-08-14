local M = {}

local function unquote(value)
	value = vim.trim(value or "")
	local first, last = value:sub(1, 1), value:sub(-1)
	if #value >= 2 and (first == '"' and last == '"' or first == "'" and last == "'") then
		return value:sub(2, -2)
	end
	return value
end

local function list_value(value)
	value = vim.trim(value or "")
	if value:sub(1, 1) == "[" and value:sub(-1) == "]" then
		local result = {}
		for item in value:sub(2, -2):gmatch("[^,]+") do
			item = unquote(item)
			if item ~= "" then
				result[#result + 1] = item
			end
		end
		return result
	elseif value ~= "" then
		return { unquote(value) }
	end
	return {}
end

local function frontmatter(lines)
	local delimiter = lines[1]
	if delimiter ~= "---" and delimiter ~= "+++" then
		return lines, { aliases = {}, tags = {} }
	end

	local raw = {}
	table.remove(lines, 1)
	while #lines > 0 do
		local line = table.remove(lines, 1)
		if line == delimiter then
			break
		end
		raw[#raw + 1] = line
	end

	-- Solo hacen falta los campos que muestra la tarjeta de obsidian-ls. Este
	-- parser tolerante cubre escalares, arrays inline y listas YAML de bloque;
	-- el resto del frontmatter se conserva fuera del brief.
	local metadata, active = { aliases = {}, tags = {} }, nil
	for _, line in ipairs(raw) do
		local key, value = line:match("^([%w_-]+)%s*:%s*(.*)$")
		if not key and delimiter == "+++" then
			key, value = line:match("^([%w_-]+)%s*=%s*(.*)$")
		end
		if key then
			key = key:lower()
			active = key
			if key == "aliases" or key == "tags" then
				metadata[key] = list_value(value)
			elseif key == "id" then
				metadata[key] = unquote(value)
			end
		elseif active == "aliases" or active == "tags" then
			local item = line:match("^%s*%-%s*(.-)%s*$")
			if item and item ~= "" then
				metadata[active][#metadata[active] + 1] = unquote(item)
			elseif not line:match("^%s*$") then
				active = nil
			end
		end
	end
	return lines, metadata
end

local function trim_blank(lines)
	while lines[1] and lines[1]:match("^%s*$") do
		table.remove(lines, 1)
	end
	while lines[#lines] and lines[#lines]:match("^%s*$") do
		table.remove(lines)
	end
	return lines
end

local function section(lines, fragment)
	if not fragment or fragment == "" then
		return lines
	end
	local workspace = require("lzy.marksman.workspace")
	local wanted = workspace.slug(vim.uri_decode(fragment) or fragment)
	local start, finish
	local headings = workspace.headings(lines)
	for index, heading in ipairs(headings) do
		if heading.anchor == wanted then
			start = heading.row + 1
			for next_index = index + 1, #headings do
				if headings[next_index].level <= heading.level then
					finish = headings[next_index].row
					break
				end
			end
			break
		end
	end
	if not start then
		return lines
	end
	local result = {}
	for idx = start, finish or #lines do
		result[#result + 1] = lines[idx]
	end
	return result
end

---@param path string
---@param fragment string|nil
---@return string|nil
function M.render(path, fragment)
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return nil
	end
	local metadata
	lines, metadata = frontmatter(lines)
	lines = section(trim_blank(lines), fragment)
	trim_blank(lines)

	local result, characters = {}, 0
	for _, line in ipairs(lines) do
		if #result >= 18 or characters + #line > 1200 then
			break
		end
		result[#result + 1] = line
		characters = characters + #line
	end
	trim_blank(result)
	if #result > 0 then
		return table.concat(result, "\n")
	end

	local name = metadata.aliases[#metadata.aliases] or metadata.id or vim.fs.basename(path):gsub("%.[^%.]+$", "")
	local empty = {
		"> **Nota vacía**",
		">",
		("> `%s` no tiene contenido fuera del frontmatter."):format(name),
	}
	if #metadata.aliases > 0 then
		empty[#empty + 1] = ""
		empty[#empty + 1] = "**Aliases:** " .. table.concat(metadata.aliases, ", ")
	end
	if #metadata.tags > 0 then
		local tags = {}
		for _, tag in ipairs(metadata.tags) do
			tags[#tags + 1] = "#" .. tag:gsub("^#", "")
		end
		empty[#empty + 1] = ""
		empty[#empty + 1] = "**Tags:** " .. table.concat(tags, " ")
	end
	return table.concat(empty, "\n")
end

---@param value string
function M.open(value)
	local lines = vim.split(value, "\n", { plain = true })
	vim.lsp.util.open_floating_preview(lines, "markdown", {
		border = "rounded",
		focus_id = "marksman-reference-hover",
	})
end

return M
