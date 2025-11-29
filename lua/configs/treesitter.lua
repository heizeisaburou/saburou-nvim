-- Lenguajes que quieres que SÍ tengan highlight
-- (Los que estilice mejor treesitter que LSP)
local enabled_highlights = {
    "bash",
    "python",
    "cpp",
}

-- Todos los lenguajes que usas (ensure_installed)
-- (Los que quieres instalar)
local all_languages = {
    "cmake",
    "go",
    "gomod",
    "gosum",
    "gotmpl",
    "gowork",
    "make",
    "fish",
    "lua",
    "luadoc",
    "printf",
    "toml",
    "vim",
    "vimdoc",
    "yaml",
    "html",
    "htmldjango",
    "css",
    "c",
    "cpp",
    "bash",
    "markdown",
    "javascript",
    "json",
    "json5",
    "python",
    "rust",
}

-- Generar automáticamente highlight.disable
local disable_list = {}
for _, lang in ipairs(all_languages) do
    local found = false
    for _, ok in ipairs(enabled_highlights) do
        if lang == ok then
            found = true
            break
        end
    end
    if not found then
        table.insert(disable_list, lang)
    end
end

local opts = {
    ensure_installed = all_languages,

    highlight = {
        enable = true,
        use_languagetree = true,
        disable = disable_list,
    },

    indent = { enable = true },
}

return opts
