local line_length = 111
local tab_width = 4

local opts = {
    -- Auto format on save (no lo recomiendo) [espacio fm] y no seas vago
    -- format_on_save = function(bufnr)
    --   -- Disable with a global or buffer-local variable
    --   if vim.g.disable_autoformat or vim.b[bufnr].disable_autoformat then
    --     return
    --   end
    --   return { timeout_ms = 500, lsp_fallback = true }
    -- end,
    formatters_by_ft = {
        c = { "clang-format" },
        cpp = { "clang-format" },
        python = { "ruff_format" },
        -- zsh = { "shfmt" },
        bash = { "shfmt" },
        css = { "prettier" },
        scss = { "prettier" },
        html = { "prettier" },
        javascript = { "prettier" },
        javascriptreact = { "prettier" },
        json = { "biome" },
        markdown = { "prettier" },
        typescript = { "prettier" },
        typescriptreact = { "prettier" },
        vue = { "prettier" },
        lua = { "stylua" },
        toml = { "taplo" }, -- [!] Bugea stylua
        yaml = { "yamlfmt" },
        go = { "gofmt" },
        gleam = { "gleam" }, -- [!] No está en MasonInstall, se instala a nivel de entorno.
        zig = { "zigfmt" },
    },

    formatters = {
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
        ruff_format = {
            append_args = { "--line-length=" .. line_length },
        },
        black = {
            append_args = { "--line-length=" .. line_length },
        },
        clang_format = {
            append_args = {
                "-style={IndentWidth: " .. tab_width .. ", TabWidth: " .. tab_width .. ", UseTab: Never,",
                "ColumnLimit: " .. line_length .. "}",
            },
        },
        stylua = {
            append_args = {
                "--column-width",
                tostring(line_length),
                "--line-endings",
                "Unix",
                "--indent-type",
                "Spaces",
                "--indent-width",
                tostring(tab_width),
                "--quote-style",
                "AutoPreferDouble",
                "--call-parentheses",
                "None",
            },
        },

        prettier = {
            append_args = { "--print-width", tostring(line_length), "--tab-width", tostring(tab_width) },
        },
        shfmt = {
            append_args = { "-i", tostring(tab_width) },
        },
    },
}

return opts
