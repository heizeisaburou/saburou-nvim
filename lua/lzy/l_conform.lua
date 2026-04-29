-- lazy/l_conform

local M = {}

local line_length = 120
local tab_width = 2

vim.g.conform_log_level = vim.log.levels.DEBUG

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
  gleam = { "gleam" },
  go = { "gofmt" },
  html = { "prettier" },
  javascript = { "prettier" },
  javascriptreact = { "prettier" },
  json = { "biome" },
  lua = { "stylua" },
  markdown = { "prettier" }, -- mdformat (bug con tablas grandes)
  python = { "ruff_format" },
  rust = { "rustfmt" },
  scss = { "prettier" },
  typescript = { "prettier" },
  typescriptreact = { "prettier" },
  vue = { "prettier" },
  yaml = { "yamlfmt" },
  zig = { "zigfmt" },
  elixir = { "mix" },
  eelixir = { "mix" },
  heex = { "mix" },
  surface = { "mix" },
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
  black = {
    append_args = { "--line-length=" .. line_length },
  },

  clang_format = {
    append_args = {
      "-style="
        .. '{"IndentWidth":'
        .. tostring(tab_width)
        .. ',"TabWidth":'
        .. tostring(tab_width)
        .. ',"UseTab":"Never"'
        .. ',"AlignOperands":true'
        .. ',"PenaltyBreakAssignment":50'
        .. ',"AllowShortIfStatementsOnASingleLine":true'
        .. ',"PenaltyBreakBeforeFirstCallParameter":0'
        .. ',"ColumnLimit":'
        .. tostring(line_length)
        .. "}",
    },
  },

  prettier = {
    append_args = function()
      local args = {
        "--print-width=" .. tostring(line_length),
        "--tab-width=" .. tostring(tab_width),
      }

      local ft = vim.bo.filetype
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

  mdformat = {
    append_args = {
      "--wrap",
      tostring(line_length),
      "--end-of-line",
      "lf",
    },
  },

  ruff_format = {
    append_args = { "--line-length=" .. line_length },
  },

  rustfmt = {
    append_args = {
      "--config",
      "max_width=" .. tostring(line_length),
      "--config",
      "tab_spaces=" .. tostring(tab_width),
      "--config",
      "hard_tabs=false",
    },
  },

  shfmt = {
    append_args = { "-i", tostring(tab_width) },
  },

  stylua = {
    append_args = {
      "--column-width=" .. tostring(line_length),
      "--line-endings=Unix",
      "--indent-type=Spaces",
      "--indent-width=" .. tostring(tab_width),
      "--quote-style=AutoPreferDouble",
      "--call-parentheses=None",
    },
  },

  taplo = {
    append_args = {
      "--option",
      "column_width=" .. tostring(line_length),
      "--option",
      "indent_string=" .. string.rep(" ", tab_width),
    },
  },

  yamlfmt = {
    append_args = { "-formatter", "retain_line_breaks_single=true" },
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
}

function M.setup()
  require("conform").setup(M.opts)

  local map = vim.keymap.set

  map({ "n", "x" }, "<leader>fm", function()
    require("conform").format { lsp_fallback = true }
  end, { desc = "Conform: format file" })

  map("n", "<A-f>", function()
    require("conform").format { lsp_fallback = true }
  end, { desc = "Conform: format file" })
end

return M
