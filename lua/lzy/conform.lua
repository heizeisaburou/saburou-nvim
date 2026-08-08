-- lazy/l_conform

local M = {}

local line_length = 97
local scalafmt_fallback_dialect = "scala3"
local scalafmt_fallback_version = "3.10.6"
local indent = require "sabunv.indent"

local function indent_for(ctx)
  if ctx and ctx.buf then
    return indent.for_buffer(ctx.buf)
  end

  return indent.for_buffer()
end

local function filetype_for(ctx)
  if ctx and ctx.buf then
    return vim.bo[ctx.buf].filetype
  end

  return vim.bo.filetype
end

-- Plugins de Prettier que no están en Mason; se instalan global con npm
-- (`npm install -g ...`). Se resuelve su entrada desde el directorio global de
-- node_modules en runtime, como hace `prettier_svelte` con el plugin que sí
-- trae un paquete de Mason.
---@param relative string Ruta relativa dentro del node_modules global
local function global_prettier_plugin(relative)
  local root = vim.trim(vim.fn.system "npm root -g")

  if root ~= "" then
    local hit = vim.fn.glob(vim.fs.joinpath(root, relative), true, true)[1]

    if hit and hit ~= "" then
      return hit
    end
  end
end

local prettier_liquid_plugin = global_prettier_plugin(
  vim.fs.joinpath("@shopify", "prettier-plugin-liquid", "dist", "index.js")
)
local prettier_gotmpl_plugin = global_prettier_plugin(
  vim.fs.joinpath("prettier-plugin-go-template", "lib", "index.js")
)
-- [PRUEBA MasonInstallAll] Resolvers comentados junto a sus formatters (abajo).
-- El paquete npm es GLOBAL (no lo instala MasonInstallAll): para probar el
-- formatter de cada lenguaje hay que reinstalarlo con
-- `sudo npm install -g <paquete>` y descomentar el resolver + el formatter.
local prettier_jinja_plugin = global_prettier_plugin(
  vim.fs.joinpath("prettier-plugin-jinja-template", "lib", "index.js")
)
local prettier_handlebars_plugin = global_prettier_plugin(
  vim.fs.joinpath("prettier-plugin-handlebars", "src", "index.js")
)
local prettier_twig_plugin = global_prettier_plugin(
  vim.fs.joinpath("@zackad", "prettier-plugin-twig", "src", "index.js")
)
local prettier_pug_plugin = global_prettier_plugin(
  vim.fs.joinpath("@prettier", "plugin-pug", "dist", "index.js")
)

--- Escribe configuraciones pequeñas y deterministas para CLIs que sólo
--- permiten recibir las opciones de indentación mediante un archivo.
---@param name string
---@param contents string
---@param extension string
---@return string
local function cached_config(name, contents, extension)
  local directory = vim.fs.joinpath(vim.fn.stdpath "cache", "lzy", "conform")
  local path = vim.fs.joinpath(directory, name .. "-" .. vim.fn.sha256(contents):sub(1, 12) .. extension)

  if vim.fn.filereadable(path) == 0 then
    vim.fn.mkdir(directory, "p")
    vim.fn.writefile(vim.split(contents, "\n", { plain = true }), path)
  end

  return path
end

-- ----------------------------------------------------------------------------
-- Formateadores por filetype
-- ----------------------------------------------------------------------------
-- Reglas especiales:
--   - zsh: `shfmt` no funciona correctamente en este setup
local formatters_by_ft = {
  bash = { "shfmt" },
  c = { "clang_format" },
  cpp = { "clang_format" },
  css = { "prettier" },
  eelixir = { "mix" },
  elixir = { "mix" },
  gleam = { "gleam" },
  go = { "gofmt" },
  gotmpl = { "prettier_gotmpl" }, -- plantillas Go (.tmpl/.gotmpl/.gohtml)
  heex = { "mix" },
  html = { "prettier" },
  htmldjango = { "djlint" },
  -- [PRUEBA MasonInstallAll] Comentadas para probar MasonInstallAll uno a uno.
  -- Descomenta junto con su formatter y resolver (más abajo).
  handlebars = { "prettier_handlebars" },
  jinja = { "prettier_jinja" },
  javascript = { "prettier" },
  javascriptreact = { "prettier" },
  json = { "biome" },
  lua = { "stylua" },
  liquid = { "prettier_liquid" },
  -- Prettier imprime espacios para parte de la estructura Markdown incluso con
  -- useTabs. markdown_tabs normaliza esa sangría en una segunda pasada.
  markdown = { "prettier", "markdown_tabs" }, -- mdformat (bug con tablas grandes)
  php = { "php_cs_fixer" },
  plaintex = { "latexindent" },
  python = { "ruff_format" },
  pug = { "prettier_pug" }, -- [PRUEBA MasonInstallAll] descomentar con su formatter/resolver
  qml = { "qmlformat" }, -- externo
  rust = { "rustfmt" },
  scss = { "prettier" },
  surface = { "mix" },
  svelte = { "prettier_svelte" },
  tex = { "latexindent" },
  typescript = { "prettier" },
  typescriptreact = { "prettier" },
  twig = { "prettier_twig" }, -- [PRUEBA MasonInstallAll] descomentar con su formatter/resolver
  typst = { "typstyle" },
  vue = { "prettier" }, -- .vue (framework de javascript); [PRUEBA MasonInstallAll] descomentar
  yaml = { "yamlfmt" },
  zig = { "zigfmt" },

  -- NUEVOS (sin testear)
  clojure = { "zprint" }, -- activa edn también
  cs = { "csharpier" }, -- C#
  dart = { "dart_format" }, -- externo
  edn = { "zprint" }, -- .edn de Clojure
  fsharp = { "fantomas" }, -- F#
  haskell = { "fourmolu" },
  java = { "google-java-format" },
  kotlin = { "ktlint" },
  -- `lhaskell` es el filetype de `.lhs` (Literate Haskell). Fourmolu se
  -- activa por separado aunque comparta formatter con Haskell normal.
  lhaskell = { "fourmolu" }, -- .lhs de haskell
  ocaml = { "ocamlformat" },
  ocamlinterface = { "ocamlformat" },
  ruby = { "rubocop", timeout_ms = 10000 },
  scala = { "scalafmt", timeout_ms = 10000 },
  swift = { "swiftformat" },
  toml = { "taplo" },
}

-- ----------------------------------------------------------------------------
-- Definiciones de formateadores
-- ----------------------------------------------------------------------------
-- clang_format:
--   Se fuerza estilo inline para no depender de `.clang-format`.
--
-- prettier:
--   Se añaden parser explícito en algunos filetypes y opciones extra para
--   markdown.
--
-- rustfmt:
--   Se pasa la configuración por CLI para no depender de `rustfmt.toml`.
local formatters = {
  biome = {
    args = function(_, ctx)
      local config = indent_for(ctx)
      return {
        "format",
        "--stdin-file-path",
        "$FILENAME",
        "--indent-style=" .. (config.style == "tabs" and "tab" or "space"),
        "--indent-width=" .. tostring(config.width),
        "--line-width=" .. tostring(line_length),
      }
    end,
  },

  black = {
    append_args = { "--line-length=" .. line_length },
  },

  csharpier = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      local contents = vim.json.encode {
        printWidth = line_length,
        useTabs = config.style == "tabs",
        indentSize = config.width,
        endOfLine = "lf",
      }

      return { "--config-path", cached_config("csharpier", contents, ".json") }
    end,
  },

  clang_format = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)

      return {
        "-style="
          .. '{"IndentWidth":'
          .. tostring(config.width)
          .. ',"TabWidth":'
          .. tostring(config.width)
          .. ',"UseTab":"'
          .. (config.style == "tabs" and "Always" or "Never")
          .. '"'
          .. ',"AlignOperands":true'
          .. ',"PenaltyBreakAssignment":50'
          .. ',"AllowShortIfStatementsOnASingleLine":true'
          .. ',"PenaltyBreakBeforeFirstCallParameter":0'
          .. ',"ColumnLimit":'
          .. tostring(line_length)
          .. "}",
      }
    end,
  },

  dart_format = {
    -- Dart fija la indentación en dos espacios; la CLI sólo permite compartir
    -- el ancho de página con nuestra política general.
    args = { "format", "--page-width=" .. tostring(line_length), "$FILENAME" },
  },

  djlint = {
    -- djlint usa perfil `django` y comparte nuestra política de indentación y
    -- ancho. El builtin de Conform ya aporta `--reformat -`.
    prepend_args = function(_, ctx)
      local config = indent_for(ctx)
      return {
        "--profile",
        "django",
        "--indent",
        tostring(config.width),
        "--max-line-length",
        tostring(line_length),
      }
    end,
  },

  fourmolu = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      return {
        "--indentation=" .. tostring(config.width),
        "--column-limit=" .. tostring(line_length),
      }
    end,
  },

  ["google-java-format"] = {
    args = function(_, ctx)
      -- google-java-format es deliberadamente no configurable: Google Style
      -- usa dos espacios y AOSP es su única variante, con cuatro.
      return indent_for(ctx).width == 4 and { "--aosp", "-" } or { "-" }
    end,
  },

  ktlint = {
    prepend_args = function(_, ctx)
      local config = indent_for(ctx)
      local contents = table.concat({
        "[*.{kt,kts}]",
        "indent_style = " .. (config.style == "tabs" and "tab" or "space"),
        "indent_size = " .. tostring(config.width),
        "tab_width = " .. tostring(config.width),
        "max_line_length = " .. tostring(line_length),
      }, "\n")

      -- ktlint trata este archivo como valores por defecto: cualquier
      -- .editorconfig del proyecto conserva prioridad sobre ellos.
      return { "--editorconfig=" .. cached_config("ktlint", contents, ".editorconfig") }
    end,
  },

  prettier = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      -- Desde Prettier 3, el CLI usa `.gitignore` y `.prettierignore` por
      -- defecto. Un archivo no versionado sigue siendo formateable cuando el
      -- usuario lo pide explícitamente: sólo conservamos el ignore específico
      -- de Prettier, si existe.
      local prettier_ignore = vim.fs.find(".prettierignore", {
        path = ctx.dirname,
        upward = true,
        type = "file",
      })[1] or "/dev/null"
      local args = {
        "--print-width=" .. tostring(line_length),
        "--tab-width=" .. tostring(config.width),
        config.style == "tabs" and "--use-tabs" or "--no-use-tabs",
        "--ignore-path",
        prettier_ignore,
      }

      local ft = filetype_for(ctx)
      local parser_ft = { "css", "html", "json", "markdown", "scss" }

      if vim.tbl_contains(parser_ft, ft) then
        table.insert(args, "--parser")
        table.insert(args, ft)
      end

      if ft == "markdown" then
        table.insert(args, "--prose-wrap")
        table.insert(args, "always")
      end

      return args
    end,
  },

  prettier_svelte = {
    command = function()
      return hzsr.sys.executable.resolve "prettier"
    end,
    args = function(_, ctx)
      local config = indent_for(ctx)
      local plugin_pattern = vim.fs.joinpath(
        vim.fn.stdpath "data",
        "mason",
        "packages",
        "svelte-language-server",
        "**",
        "prettier-plugin-svelte",
        "plugin.js"
      )
      local plugin = vim.fn.glob(plugin_pattern, true, true)[1]

      if not plugin or plugin == "" then
        error "prettier-plugin-svelte no está instalado; ejecuta :MasonInstallAll"
      end

      return {
        "--plugin",
        plugin,
        "--print-width=" .. tostring(line_length),
        "--tab-width=" .. tostring(config.width),
        config.style == "tabs" and "--use-tabs" or "--no-use-tabs",
        "--parser",
        "svelte",
        "--stdin-filepath",
        "$FILENAME",
      }
    end,
  },

  prettier_liquid = {
    command = function()
      return hzsr.sys.executable.resolve "prettier"
    end,
    args = function(_, ctx)
      local config = indent_for(ctx)

      if not prettier_liquid_plugin then
        error "prettier-plugin-liquid no está instalado; ejecuta: npm install -g @shopify/prettier-plugin-liquid"
      end

      return {
        "--plugin",
        prettier_liquid_plugin,
        "--parser",
        "liquid-html",
        "--print-width=" .. tostring(line_length),
        "--tab-width=" .. tostring(config.width),
        config.style == "tabs" and "--use-tabs" or "--no-use-tabs",
        "--stdin-filepath",
        "$FILENAME",
      }
    end,
  },

  -- El plugin detecta el parser por la extensión del archivo, así que no se
  -- pasa `--parser` explícito.
  prettier_gotmpl = {
    command = function()
      return hzsr.sys.executable.resolve "prettier"
    end,
    args = function(_, ctx)
      local config = indent_for(ctx)

      if not prettier_gotmpl_plugin then
        error "prettier-plugin-go-template no está instalado; ejecuta: npm install -g prettier-plugin-go-template"
      end

      return {
        "--plugin",
        prettier_gotmpl_plugin,
        "--print-width=" .. tostring(line_length),
        "--tab-width=" .. tostring(config.width),
        config.style == "tabs" and "--use-tabs" or "--no-use-tabs",
        "--stdin-filepath",
        "$FILENAME",
      }
    end,
  },

  -- [PRUEBA MasonInstallAll] Formatters comentados; descomenta el del lenguaje
  -- que quieras probar junto con su entrada en formatters_by_ft y su resolver.
  --
  prettier_jinja = {
    command = function()
      return hzsr.sys.executable.resolve "prettier"
    end,
    args = function(_, ctx)
      local config = indent_for(ctx)

      if not prettier_jinja_plugin then
        error "prettier-plugin-jinja-template no está instalado; ejecuta: sudo npm install -g prettier-plugin-jinja-template"
      end

      return {
        "--plugin",
        prettier_jinja_plugin,
        "--parser",
        "jinja-template",
        "--print-width=" .. tostring(line_length),
        "--tab-width=" .. tostring(config.width),
        config.style == "tabs" and "--use-tabs" or "--no-use-tabs",
        "--stdin-filepath",
        "$FILENAME",
      }
    end,
  },

  -- El único plugin de prettier que funciona con prettier 3 para Handlebars es
  -- `prettier-plugin-handlebars` (fork del plugin de Glimmer/Ember); su parser
  -- se llama `glimmer`.
  prettier_handlebars = {
    command = function()
      return hzsr.sys.executable.resolve "prettier"
    end,
    args = function(_, ctx)
      local config = indent_for(ctx)

      if not prettier_handlebars_plugin then
        error "prettier-plugin-handlebars no está instalado; ejecuta: sudo npm install -g prettier-plugin-handlebars"
      end

      return {
        "--plugin",
        prettier_handlebars_plugin,
        "--parser",
        "glimmer",
        "--print-width=" .. tostring(line_length),
        "--tab-width=" .. tostring(config.width),
        config.style == "tabs" and "--use-tabs" or "--no-use-tabs",
        "--stdin-filepath",
        "$FILENAME",
      }
    end,
  },

  prettier_twig = {
    command = function()
      return hzsr.sys.executable.resolve "prettier"
    end,
    args = function(_, ctx)
      local config = indent_for(ctx)

      if not prettier_twig_plugin then
        error "@zackad/prettier-plugin-twig no está instalado; ejecuta: sudo npm install -g @zackad/prettier-plugin-twig"
      end

      return {
        "--plugin",
        prettier_twig_plugin,
        "--parser",
        "twig",
        "--print-width=" .. tostring(line_length),
        "--tab-width=" .. tostring(config.width),
        config.style == "tabs" and "--use-tabs" or "--no-use-tabs",
        "--stdin-filepath",
        "$FILENAME",
      }
    end,
  },

  prettier_pug = {
    command = function()
      return hzsr.sys.executable.resolve "prettier"
    end,
    args = function(_, ctx)
      local config = indent_for(ctx)

      if not prettier_pug_plugin then
        error "@prettier/plugin-pug no está instalado; ejecuta: sudo npm install -g @prettier/plugin-pug"
      end

      return {
        "--plugin",
        prettier_pug_plugin,
        "--parser",
        "pug",
        "--print-width=" .. tostring(line_length),
        "--tab-width=" .. tostring(config.width),
        config.style == "tabs" and "--use-tabs" or "--no-use-tabs",
        "--stdin-filepath",
        "$FILENAME",
      }
    end,
  },

  -- Segunda pasada porque el printer de Markdown de Prettier no respeta
  -- useTabs en listas y bloques. Es Lua puro para no depender de herramientas
  -- externas; con width = 4 conserva la semántica CommonMark.
  markdown_tabs = {
    format = function(_, ctx, lines, callback)
      local config = indent_for(ctx)
      local normalized = {}

      for index, line in ipairs(lines) do
        local leading = line:match "^[\t ]*" or ""
        local columns = 0

        for char in leading:gmatch "." do
          if char == "\t" then
            columns = columns + config.width - (columns % config.width)
          else
            columns = columns + 1
          end
        end

        local tabs = math.floor(columns / config.width)
        local spaces = columns % config.width
        normalized[index] = string.rep("\t", tabs)
          .. string.rep(" ", spaces)
          .. line:sub(#leading + 1)
      end

      callback(nil, normalized)
    end,
    condition = function(_, ctx)
      return indent_for(ctx).style == "tabs"
    end,
  },

  mdformat = {
    append_args = {
      "--wrap",
      tostring(line_length),
      "--end-of-line",
      "lf",
    },
  },

  ocamlformat = {
    -- OCamlFormat decide estructuralmente la sangría y usa espacios. Sí expone
    -- el margen, por lo que se mantiene el ancho compartido.
    args = {
      "--enable-outside-detected-project",
      "--margin",
      tostring(line_length),
      "--name",
      "$FILENAME",
      "-",
    },
  },

  php_cs_fixer = {
    append_args = {
      "--rules",
      '{"@PSR12":true,"indentation_type":true,"line_ending":true}',
    },
  },

  rubocop = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      local project_config = vim.fs.find({ ".rubocop.yml", ".rubocop.yaml" }, {
        path = ctx.dirname,
        upward = true,
        type = "file",
      })[1]
      local contents = vim.json.encode {
        inherit_from = project_config,
        ["Layout/IndentationStyle"] = {
          EnforcedStyle = config.style,
          IndentationWidth = config.width,
        },
        ["Layout/IndentationWidth"] = {
          Width = config.width,
        },
        ["Layout/LineLength"] = {
          Max = line_length,
        },
      }

      return { "--config", cached_config("rubocop", contents, ".yml") }
    end,
  },

  scalafmt = {
    args = function(_, ctx)
      local config = indent_for(ctx)
      local overrides = table.concat({
        "maxColumn = " .. tostring(line_length),
        "indent.main = " .. tostring(config.width),
        "indent.significant = " .. tostring(config.width),
        "indent.callSite = " .. tostring(config.width),
        "indent.defnSite = " .. tostring(config.width),
      }, "\n")
      local project_config = vim.fs.find(".scalafmt.conf", {
        path = ctx.dirname,
        upward = true,
        type = "file",
      })[1]

      -- Scala no admite tabs significativos. Si hay configuración de proyecto,
      -- se incluye primero para conservar versión y dialecto y luego se
      -- sobreescriben únicamente ancho e indentación.
      if project_config then
        local contents = "include " .. vim.json.encode(project_config) .. "\n" .. overrides
        return { "--stdin", "--config", cached_config("scalafmt", contents, ".conf") }
      end

      -- Scalafmt exige una versión incluso con configuración inline. La versión
      -- fija hace que el fallback sea reproducible; los proyectos con su propio
      -- `.scalafmt.conf` conservan la versión que hayan declarado.
      local dialect = vim.endswith(ctx.filename, ".sbt") and "sbt1" or scalafmt_fallback_dialect
      local fallback = table.concat({
        'version = "' .. scalafmt_fallback_version .. '"',
        "runner.dialect = " .. dialect,
        overrides,
      }, "\n")
      return { "--stdin", "--config-str", fallback }
    end,
  },

  ruff_format = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      return {
        "--line-length=" .. tostring(line_length),
        "--config",
        "indent-width = " .. tostring(config.width),
        "--config",
        'format.indent-style = "' .. (config.style == "tabs" and "tab" or "space") .. '"',
      }
    end,
  },

  rustfmt = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      return {
        "--config",
        "max_width=" .. tostring(line_length),
        "--config",
        "tab_spaces=" .. tostring(config.width),
        "--config",
        "hard_tabs=" .. tostring(config.style == "tabs"),
      }
    end,
  },

  shfmt = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      return { "-i", config.style == "tabs" and "0" or tostring(config.width) }
    end,
  },

  stylua = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      return {
        "--column-width=" .. tostring(line_length),
        "--line-endings=Unix",
        "--indent-type=" .. (config.style == "tabs" and "Tabs" or "Spaces"),
        "--indent-width=" .. tostring(config.width),
        "--quote-style=AutoPreferDouble",
        "--call-parentheses=None",
      }
    end,
  },

  swiftformat = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      return {
        "--indent",
        config.style == "tabs" and "tab" or tostring(config.width),
        "--tabwidth",
        tostring(config.width),
        "--maxwidth",
        tostring(line_length),
      }
    end,
  },

  taplo = {
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      local indent_string = config.style == "tabs" and "\t" or string.rep(" ", config.width)

      return {
        "--option",
        "column_width=" .. tostring(line_length),
        "--option",
        "indent_string=" .. indent_string,
      }
    end,
  },

  typstyle = {
    -- typstyle sólo soporta indentación con espacios; comparte el ancho de
    -- línea con la política general.
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      return {
        "--line-width=" .. tostring(line_length),
        "--tab-width=" .. tostring(config.width),
      }
    end,
  },

  qmlformat = {
    -- qmlformat pertenece a Qt, no a Mason. Se resuelve desde PATH y se acepta
    -- el alias qmlformat6 que usan algunas distribuciones. Conservamos los
    -- argumentos oficiales de Conform (`-i $FILENAME`): qmlformat no ofrece
    -- flags portables para ancho de sangría o columna entre versiones de Qt.
    command = function()
      return hzsr.sys.executable.resolve { "qmlformat", "qmlformat6" }
    end,
  },
  latexindent = {
    stdin = true,
    prepend_args = function(_, ctx)
      local config = indent_for(ctx)
      local indent_string = config.style == "tabs" and "\\t" or string.rep(" ", config.width)

      return {
        "-m",
        "-l",
        '-y=defaultIndent: "' .. indent_string .. '"',
      }
    end,
  },
  yamlfmt = {
    -- El builtin de Conform invoca `-in $FILENAME`, que no aplica los
    -- formateadores (no-op), así que se usa stdin. `include_document_start`
    -- conserva el `---` de los playbooks. YAML no admite tabs en la
    -- indentación; sí comparte el ancho de la política cuando el estilo es
    -- spaces.
    stdin = true,
    args = function(_, ctx)
      local config = indent_for(ctx)
      return {
        "-formatter",
        "retain_line_breaks_single=true",
        "-formatter",
        "indent=" .. tostring(config.width),
        "-formatter",
        "include_document_start=true",
        "-",
      }
    end,
  },

  zprint = {
    -- zprint alinea formas según la estructura de Clojure y no ofrece un
    -- estilo tabs/spaces global; se comparte el ancho máximo.
    append_args = { "{:width " .. tostring(line_length) .. "}" },
  },
}

-- Autoformat al guardar:
-- se mantiene desactivado; preferencia deliberada de formateo manual.
-- format_on_save = function(bufnr)
--   if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
--     return
--   end
--   return { timeout_ms = 500, lsp_fallback = true }
-- end,

M.opts = {
  formatters_by_ft = formatters_by_ft,
  formatters = formatters,
  log_level = vim.log.levels.DEBUG,
  -- Los mappings de abajo muestran el error concreto mediante el callback y
  -- evitan el aviso genérico duplicado de Conform.
  notify_on_error = false,
  notify_no_formatters = false,
}

local function notify(message, level)
  local ok, snacks = pcall(require, "snacks")
  local opts = { title = "Conform" }

  if ok and snacks.notifier and snacks.notifier.notify then
    snacks.notifier.notify(message, level, opts)
    return
  end

  vim.notify(message, level, opts)
end

local function format_buffer()
  require("conform").format({ lsp_format = "fallback" }, function(err, did_edit)
    if err then
      notify("No se pudo formatear:\n" .. err, vim.log.levels.ERROR)
    elseif did_edit then
      notify("Formato aplicado", vim.log.levels.INFO)
    else
      -- notify("El buffer ya estaba formateado (o `.prettierignore` lo excluye)", vim.log.levels.INFO)
    end
  end)
end

function M.setup()
  require("conform").setup(M.opts)

  local map = vim.keymap.set

  map({ "n", "x" }, "<leader>fm", format_buffer, { desc = "Conform: format file" })

  map("n", "<A-f>", format_buffer, { desc = "Conform: format file" })
end

return M
