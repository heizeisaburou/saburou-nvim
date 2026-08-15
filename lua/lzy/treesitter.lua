-- lzy.l_treesitter

local M = {}

local CURL_REVOCATION_ERROR = "CRYPT_E_NO_REVOCATION_CHECK"
local CURL_REVOCATION_FLAG = "--ssl-revoke-best-effort"
local install_running = false

M.languages = {
  "lua",
  "luadoc",
  "markdown_inline",
  "markdown",
  "powershell",
  "sql",
  --
  --
  --
  -- "bash",
  -- "c_sharp",
  -- "c",
  -- "clojure",
  -- "cmake",
  -- "cpp",
  -- "css",
  -- "dart", -- externo
  -- "elixir",
  -- "fish",
  -- "fsharp",
  -- "go",
  -- "gomod",
  -- "gosum",
  -- "gotmpl",
  -- "gowork",
  -- "haskell",
  -- "heex",
  -- "html",
  -- "htmldjango",
  -- "java",
  -- "javascript",
  -- "jinja", -- requiere jinja_inline (dependencia del parser)
  -- "json",
  -- "json5",
  -- "kotlin",
  -- "liquid",
  -- "make",
  -- "ocaml_interface",
  -- "ocaml",
  -- "php",
  -- "printf",
  -- "pug",
  -- "python",
  -- "qmljs",
  -- "ruby",
  -- "rust",
  -- "scala",
  -- "svelte",
  -- "swift",
  -- "toml",
  -- "tsx", -- typescriptreact
  -- "twig",
  -- "typescript",
  -- "typst",
  -- "vim",
  -- "vimdoc",
  -- "vue",
  -- "yaml",
  -- "zig",
  -- "zsh",
}

M.enabled_highlights = {
  bash = true,
  c = true,
  clojure = true,
  cmake = true,
  cpp = true,
  cs = true,
  css = true,
  dart = true,
  edn = true,
  elixir = true,
  fish = true,
  fsharp = true,
  go = true,
  gomod = true,
  gosum = true,
  gotmpl = true,
  gowork = true,
  haskell = true,
  html = true,
  htmldjango = true,
  java = true,
  javascript = true,
  jinja = true,
  json = true,
  json5 = true,
  kotlin = true,
  lhaskell = true, -- `.lhs`; requiere también el alias de M.language_aliases
  liquid = true,
  lua = true,
  luadoc = true,
  make = true,
  markdown = true,
  markdown_inline = true,
  ocaml = true,
  ocamlinterface = true,
  php = true,
  printf = true,
  ps1 = true, -- filetype de PowerShell; el parser se llama `powershell`
  pug = true,
  python = true,
  qml = true,
  ruby = true,
  rust = true,
  scala = true,
  sql = true,
  svelte = true,
  swift = true,
  toml = true,
  twig = true,
  typescript = true,
  typescriptreact = true,
  typst = true,
  vim = true,
  vimdoc = true,
  vue = true,
  yaml = true,
  zig = true,
  zsh = true,
}

-- Algunos filetypes no comparten nombre con su parser. nvim-treesitter ya
-- registra `cs -> c_sharp` y `ocamlinterface -> ocaml_interface`; estos alias
-- adicionales pertenecen a los filetypes secundarios que añadimos.
-- Filetypes que no comparten nombre con su parser. nvim-treesitter ya registra
-- los casos conocidos (cs -> c_sharp, ocamlinterface -> ocaml_interface). Sin
-- entradas por ahora; las plantillas Go usan directamente `gotmpl`.
M.language_aliases = {}

local function notify(message, level)
  vim.notify(message, level, { title = "TSInstallAll" })
end

local function stop_with_error(message)
  install_running = false
  notify(message, vim.log.levels.ERROR)
end

local function missing_languages()
  return require("nvim-treesitter.config").norm_languages(vim.deepcopy(M.languages), {
    installed = true,
    unsupported = true,
  })
end

local function archive_targets(languages)
  local parsers = require "nvim-treesitter.parsers"
  local targets = {}
  local seen = {}
  local pinned = true

  for _, language in ipairs(languages) do
    local parser = parsers[language]
    local info = parser and parser.install_info
    if info and not info.path and info.url then
      local revision = info.revision or info.branch or "main"
      local url = info.url:gsub("%.git$", "") .. "/archive/" .. revision .. ".tar.gz"

      if not seen[url] then
        seen[url] = true
        targets[#targets + 1] = url
      end

      if type(info.revision) ~= "string" or #info.revision ~= 40 or not info.revision:match "^%x+$" then
        pinned = false
      end
    end
  end

  return targets, pinned
end

local function is_windows()
  return vim.fn.has "win32" == 1 or vim.fn.has "win64" == 1
end

local function curl_command(url, best_effort)
  local command = { "curl" }
  if best_effort then
    command[#command + 1] = CURL_REVOCATION_FLAG
  end
  vim.list_extend(command, {
    "--head",
    "--location",
    "--silent",
    "--fail",
    "--show-error",
    url,
  })
  return command
end

local function probe_archive(url, best_effort, callback)
  local ok, err = pcall(
    vim.system,
    curl_command(url, best_effort),
    { text = true },
    vim.schedule_wrap(callback)
  )
  if not ok then
    vim.schedule(function()
      callback { code = 125, stderr = tostring(err) }
    end)
  end
end

local function is_curl(command)
  if type(command) ~= "table" or type(command[1]) ~= "string" then
    return false
  end
  local executable = command[1]:gsub("\\", "/"):match "([^/]+)$"
  executable = executable and executable:lower()
  return executable == "curl" or executable == "curl.exe"
end

local function with_revocation_best_effort(targets)
  local original_system = vim.system
  local allowed_urls = {}
  for _, url in ipairs(targets) do
    allowed_urls[url] = true
  end

  -- nvim-treesitter no permite añadir opciones a su curl. El wrapper solo
  -- reconoce los tarballs calculados arriba y se retira al terminar la tarea.
  local function wrapped_system(command, options, on_exit)
    if is_curl(command) then
      for _, argument in ipairs(command) do
        if allowed_urls[argument] then
          command = vim.deepcopy(command)
          table.insert(command, 2, CURL_REVOCATION_FLAG)
          break
        end
      end
    end
    return original_system(command, options, on_exit)
  end

  vim.system = wrapped_system
  return function()
    if vim.system == wrapped_system then
      vim.system = original_system
    end
  end
end

local function run_install(targets, best_effort)
  local restore_system = best_effort and with_revocation_best_effort(targets) or function() end
  local ok, task = pcall(require("nvim-treesitter").install, M.languages, { summary = true })

  if not ok or type(task) ~= "table" or type(task.await) ~= "function" then
    restore_system()
    stop_with_error("No se pudo iniciar la instalación de parsers:\n" .. tostring(task))
    return
  end

  local awaited, await_error = pcall(task.await, task, function(err, success)
    restore_system()
    install_running = false

    if err then
      vim.schedule(function()
        notify("La instalación de parsers terminó con un error:\n" .. tostring(err), vim.log.levels.ERROR)
      end)
    elseif success == false then
      vim.schedule(function()
        notify("No se pudieron instalar todos los parsers. Revisa :messages.", vim.log.levels.ERROR)
      end)
    end
  end)

  if not awaited then
    restore_system()
    stop_with_error("No se pudo supervisar la instalación de parsers:\n" .. tostring(await_error))
  end
end

local function probe_error(result)
  return vim.trim(table.concat({ result.stderr or "", result.stdout or "" }, "\n"))
end

local function preflight_windows(targets, pinned)
  -- Un HEAD sigue las mismas redirecciones HTTPS que la descarga, pero permite
  -- detectar el fallo de Schannel antes de iniciar parsers en paralelo.
  probe_archive(targets[1], false, function(result)
    if result.code == 0 then
      run_install(targets, false)
      return
    end

    local detail = probe_error(result)
    if detail:find(CURL_REVOCATION_ERROR, 1, true) then
      if not pinned then
        stop_with_error(
          "Schannel no puede comprobar la revocación TLS y al menos una descarga no usa un commit fijado; "
            .. "no se aplicará una excepción automática.\n"
            .. detail
        )
        return
      end

      local retry = "Reintentar solo esta vez"
      vim.ui.select({ retry, "Cancelar" }, {
        prompt = "Schannel no puede comprobar la revocación TLS. Los parsers usan commits fijados; "
          .. "¿continuar con comprobación best-effort?",
      }, function(choice)
        if choice ~= retry then
          install_running = false
          notify("Instalación cancelada; no se ha cambiado la configuración de curl.", vim.log.levels.INFO)
          return
        end

        notify(
          "Revocación TLS en modo best-effort solo durante esta ejecución de TSInstallAll.",
          vim.log.levels.WARN
        )
        run_install(targets, true)
      end)
      return
    end

    stop_with_error("curl no pudo comprobar la descarga; no se instalará ningún parser:\n" .. detail)
  end)
end

function M.install_all()
  if install_running then
    notify("Ya hay una instalación de parsers en curso.", vim.log.levels.WARN)
    return
  end
  install_running = true

  local languages = missing_languages()
  if #languages == 0 then
    run_install({}, false)
    return
  end

  if vim.fn.executable "tree-sitter" ~= 1 then
    stop_with_error(
      "No se encuentra tree-sitter-cli. Instala la versión 0.26.1 o superior, "
        .. "comprueba :checkhealth nvim-treesitter y vuelve a ejecutar :TSInstallAll."
    )
    return
  end

  local targets, pinned = archive_targets(languages)
  if #targets > 0 and vim.fn.executable "curl" ~= 1 then
    stop_with_error("No se encuentra curl en el PATH; no se puede ejecutar :TSInstallAll.")
    return
  end

  if is_windows() and #targets > 0 then
    preflight_windows(targets, pinned)
  else
    run_install(targets, false)
  end
end

local function start_for_buffer(bufnr)
  local ft = vim.bo[bufnr].filetype
  -- Los filetypes compuestos (p.ej. `yaml.ansible`) caen al base (`yaml`);
  -- `vim.treesitter.start` también resuelve el parser por el base.
  local base = vim.split(ft, ".", { plain = true })[1]

  if not (M.enabled_highlights[ft] or M.enabled_highlights[base]) then
    return
  end

  pcall(vim.treesitter.start, bufnr)
end

function M.setup()
  for filetype, language in pairs(M.language_aliases) do
    vim.treesitter.language.register(language, filetype)
  end

  vim.api.nvim_create_user_command("TSInstallAll", function()
    M.install_all()
  end, {})

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("lzy_treesitter_start", { clear = true }),
    callback = function(args)
      start_for_buffer(args.buf)
    end,
  })

  -- Opcional: intenta instalar parsers al cargar el módulo.
  -- M.install_all()
end

return M
