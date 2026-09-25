-- Apertura portable de archivos resueltos por los backends Markdown.
-- La extensión nunca decide: el contenido textual se edita en Neovim y el
-- binario se delega a la asociación del sistema mediante `vim.ui.open()`.
--
-- Con una excepción que también sale del contenido, no de la extensión: hay
-- formatos que son texto por codificación pero media por tipo (SVG, EPS). Su
-- enlace se sigue para verlos, no para editar su fuente, así que el tipo MIME
-- que reporta `file` los manda a la aplicación del sistema igual que un PNG.

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

-- Tipos MIME cuyo destino natural es un visor aunque su contenido sea texto.
local MEDIA_MIME_PREFIXES = { "image/", "audio/", "video/" }
local MEDIA_MIME_TYPES = { ["application/postscript"] = true }

-- Fallback para sistemas sin el ejecutable `file` (Windows por defecto): ahí no
-- hay tipo MIME que consultar y la extensión es el único dato disponible.
local MEDIA_EXTENSIONS = { svg = true, svgz = true, eps = true, ps = true }

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

--- Tipo y codificación en una sola llamada: `image/svg+xml; charset=us-ascii`.
---@param path string
---@return string|? mime, string|? charset
local function file_mime(path)
	if vim.fn.executable("file") ~= 1 then
		return nil, nil
	end
	local result = vim.system({ "file", "--brief", "--mime", "--", path }, { text = true }):wait(1500)
	if result.code ~= 0 then
		return nil, nil
	end
	local output = vim.trim(result.stdout or "")
	local mime = output:match("^([%w%-%+%./]+)")
	local charset = output:match("charset=([%w%-%.]+)")
	return mime, charset
end

---@param mime string
---@return boolean
local function is_media_mime(mime)
	mime = mime:lower()
	return MEDIA_MIME_TYPES[mime] == true or starts_with_any(mime, MEDIA_MIME_PREFIXES)
end

---@param path string
---@return boolean
local function has_media_extension(path)
	local ext = path:match("%.([^./\\]+)$")
	return ext ~= nil and MEDIA_EXTENSIONS[ext:lower()] == true
end

---@param path string
---@param opts { file_command?: boolean }|nil
---@return { text: boolean, media: boolean }
local function classify(path, opts)
	opts = opts or {}
	local stat = uv.fs_stat(path)
	if not stat or stat.type ~= "file" then
		return { text = false, media = false }
	end

	local mime, charset
	if opts.file_command ~= false then
		mime, charset = file_mime(path)
	end
	-- Si `file` ha hablado, su tipo manda y la extensión no vuelve a entrar.
	local media = mime ~= nil and is_media_mime(mime) or mime == nil and has_media_extension(path)

	local text
	if stat.size == 0 then
		text = true
	elseif charset and charset ~= "" then
		text = charset ~= "binary"
	else
		local sample = read_sample(path)
		text = sample ~= nil and sample_is_text(sample)
	end
	return { text = text, media = media }
end

---@param path string
---@param opts { file_command?: boolean }|nil
---@return boolean
function M.is_text(path, opts)
	return classify(path, opts).text
end

--- Texto o no, el archivo se ve mejor con su visor: SVG, EPS y cualquier tipo
--- MIME de imagen, audio o vídeo.
---@param path string
---@param opts { file_command?: boolean }|nil
---@return boolean
function M.is_media(path, opts)
	return classify(path, opts).media
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
---@param opts { schedule?: boolean, notify?: function, title?: string, file_command?: boolean }|nil
---@return boolean
function M.open_path(path, opts)
	opts = opts or {}
	local handled = true
	local function open()
		local kind = classify(path, opts)
		if kind.text and not kind.media then
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
