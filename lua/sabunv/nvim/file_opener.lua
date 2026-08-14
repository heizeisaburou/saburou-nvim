-- Apertura portable de archivos resueltos por los backends Markdown.
-- La extensión nunca decide: el contenido textual se edita en Neovim y el
-- binario se delega a la asociación del sistema mediante `vim.ui.open()`.

local M = {}
local uv = vim.uv or vim.loop

local BINARY_SIGNATURES = {
	"\137PNG\r\n\26\n",
	"%PDF-",
	"\255\216\255", -- JPEG
	"GIF87a",
	"GIF89a",
	"PK\003\004", -- ZIP y formatos contenedores derivados
	"\031\139", -- gzip
	"\127ELF",
	"RIFF", -- WAV, WebP, AVI
}

local TEXT_BOMS = {
	"\239\187\191", -- UTF-8
	"\255\254", -- UTF-16 LE
	"\254\255", -- UTF-16 BE
	"\255\254\000\000", -- UTF-32 LE
	"\000\000\254\255", -- UTF-32 BE
}

local function starts_with_any(value, prefixes)
	for _, prefix in ipairs(prefixes) do
		if value:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

---@param sample string
---@return boolean
local function sample_is_text(sample)
	if sample == "" or starts_with_any(sample, TEXT_BOMS) then
		return true
	end
	if starts_with_any(sample, BINARY_SIGNATURES) or sample:find("\0", 1, true) then
		return false
	end

	local controls = 0
	for index = 1, #sample do
		local byte = sample:byte(index)
		if byte < 32 and byte ~= 9 and byte ~= 10 and byte ~= 12 and byte ~= 13 then
			controls = controls + 1
		end
	end
	return controls <= math.max(1, math.floor(#sample / 100))
end

local function read_sample(path)
	local fd = uv.fs_open(path, "r", 438)
	if not fd then
		return nil
	end
	local stat = uv.fs_fstat(fd)
	local sample = uv.fs_read(fd, math.min(stat and stat.size or 8192, 8192), 0) or ""
	uv.fs_close(fd)
	return sample
end

---@param path string
---@param opts { file_command?: boolean }|nil
---@return boolean
function M.is_text(path, opts)
	opts = opts or {}
	local stat = uv.fs_stat(path)
	if not stat or stat.type ~= "file" then
		return false
	elseif stat.size == 0 then
		return true
	end

	if opts.file_command ~= false and vim.fn.executable("file") == 1 then
		local result = vim.system({ "file", "--brief", "--mime-encoding", "--", path }, { text = true }):wait(1500)
		local encoding = result.code == 0 and vim.trim(result.stdout or "") or ""
		if encoding ~= "" then
			return encoding ~= "binary"
		end
	end

	local sample = read_sample(path)
	return sample ~= nil and sample_is_text(sample) or false
end

local function default_notify(message, level, title)
	vim.notify(message, level, { title = title })
end

---@param target string
---@param opts { notify?: function, title?: string }|nil
---@return boolean
function M.open_external(target, opts)
	opts = opts or {}
	local _, err = vim.ui.open(target)
	if err then
		local notify = opts.notify or default_notify
		notify(
			("No se pudo abrir con la aplicación del sistema:\n%s"):format(err),
			vim.log.levels.ERROR,
			opts.title or "Abrir archivo"
		)
		return false
	end
	return true
end

---@param path string
---@param opts { schedule?: boolean, notify?: function, title?: string }|nil
---@return boolean
function M.open_path(path, opts)
	opts = opts or {}
	local handled = true
	local function open()
		if M.is_text(path) then
			local ok, err = pcall(vim.cmd.edit, vim.fn.fnameescape(path))
			if not ok then
				local notify = opts.notify or default_notify
				notify(
					("No se pudo abrir el archivo en Neovim:\n%s"):format(err),
					vim.log.levels.ERROR,
					opts.title or "Abrir archivo"
				)
				handled = false
			end
		else
			handled = M.open_external(path, opts)
		end
	end

	if opts.schedule == false then
		open()
	else
		vim.schedule(open)
	end
	return handled
end

return M
