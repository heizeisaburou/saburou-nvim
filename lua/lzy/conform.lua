-- lazy/l_conform

local M = {}

local line_length = 97
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

-- ----------------------------------------------------------------------------
-- Formateadores por filetype
-- ----------------------------------------------------------------------------
-- Reglas especiales:
--   - zsh: `shfmt` no funciona correctamente en este setup
--   - toml: `taplo` quedó desactivado por supuesto conflicto con lua_ls, pendiente
--           de revisar
local formatters_by_ft = {
  bash = { "shfmt" },
  c = { "clang_format" },
  cpp = { "clang_format" },
  css = { "prettier" },
  eelixir = { "mix" },
  elixir = { "mix" },
  gleam = { "gleam" },
  go = { "gofmt" },
  heex = { "mix" },
  html = { "prettier" },
  javascript = { "prettier" },
  javascriptreact = { "prettier" },
  json = { "biome" },
  lua = { "stylua" },
  -- Prettier imprime espacios para parte de la estructura Markdown incluso con
  -- useTabs. markdown_tabs normaliza esa sangría en una segunda pasada.
  markdown = { "prettier", "markdown_tabs" }, -- mdformat (bug con tablas grandes)
  php = { "php_cs_fixer" },
  plaintex = { "latexindent" },
  python = { "ruff_format" },
  qml = { "qmlformat" },
  rust = { "rustfmt" },
  scss = { "prettier" },
  surface = { "mix" },
  svelte = { "prettier_svelte" },
  tex = { "latexindent" },
  typescript = { "prettier" },
  typescriptreact = { "prettier" },
  vue = { "prettier" },
  yaml = { "yamlfmt" },
  zig = { "zigfmt" },
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
        error("prettier-plugin-svelte no está instalado; ejecuta :MasonInstallAll")
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

  php_cs_fixer = {
    append_args = {
      "--rules",
      '{"@PSR12":true,"indentation_type":true,"line_ending":true}',
    },
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
    -- YAML no admite tabs en la indentación; sí comparte el ancho de la
    -- política cuando el estilo es spaces.
    append_args = function(_, ctx)
      local config = indent_for(ctx)
      return {
        "-formatter",
        "retain_line_breaks_single=true",
        "-formatter",
        "indent=" .. tostring(config.width),
      }
    end,
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
      notify("El buffer ya estaba formateado (o `.prettierignore` lo excluye)", vim.log.levels.INFO)
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
