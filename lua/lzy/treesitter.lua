-- lzy.l_treesitter

local M = {}

M.languages = {
  "bash",
  "c",
  "cmake",
  "cpp",
  "css",
  "elixir",
  "heex",
  "fish",
  "go",
  "gomod",
  "gosum",
  "gotmpl",
  "gowork",
  "html",
  "htmldjango",
  "javascript",
  "typescript",
  "tsx", -- typescriptreact
  "json",
  "json5",
  "lua",
  "luadoc",
  "make",
  "markdown",
  "markdown_inline",
  "printf",
  "python",
  "rust",
  "toml",
  "vim",
  "vimdoc",
  "yaml",
  "qmljs",
  "php",
  "svelte",

  -- NUEVOS (sin testear)
  "c_sharp",
  "clojure",
  "dart", -- externo
  "fsharp",
  "haskell",
  "java",
  "kotlin",
  "ocaml",
  "ocaml_interface",
  "ruby",
  "scala",
  "swift",
  "zig",
}

M.enabled_highlights = {
  bash = true,
  c = true,
  cmake = true,
  cpp = true,
  css = true,
  elixir = true,
  fish = true,
  go = true,
  gomod = true,
  gosum = true,
  gotmpl = true,
  gowork = true,
  html = true,
  htmldjango = true,
  javascript = true,
  typescript = true,
  typescriptreact = true,
  json = true,
  json5 = true,
  lua = true,
  luadoc = true,
  make = true,
  markdown = true,
  markdown_inline = true,
  printf = true,
  python = true,
  rust = true,
  toml = true,
  vim = true,
  vimdoc = true,
  yaml = true,
  qml = true,
  php = true,
  svelte = true,

  -- NUEVOS (sin testear)
  -- clojure = true,
  -- cs = true,
  -- dart = true,
  -- edn = true,
  -- fsharp = true,
  -- haskell = true,
  -- java = true,
  -- kotlin = true,
  -- lhaskell = true,
  -- ocaml = true,
  -- ocamlinterface = true,
  -- ruby = true,
  -- scala = true,
  -- swift = true,
  -- zig = true,
}

-- Algunos filetypes no comparten nombre con su parser. nvim-treesitter ya
-- registra `cs -> c_sharp` y `ocamlinterface -> ocaml_interface`; estos dos
-- alias adicionales pertenecen a los filetypes secundarios que añadimos.
M.language_aliases = {
  -- NUEVOS (sin testear)
  -- edn = "clojure",
  -- lhaskell = "haskell",
}

local function install_all()
  require("nvim-treesitter").install(M.languages)
end

local function start_for_buffer(bufnr)
  local ft = vim.bo[bufnr].filetype

  if not M.enabled_highlights[ft] then
    return
  end

  pcall(vim.treesitter.start, bufnr)
end

function M.setup()
  for filetype, language in pairs(M.language_aliases) do
    vim.treesitter.language.register(language, filetype)
  end

  vim.api.nvim_create_user_command("TSInstallAll", function()
    install_all()
  end, {})

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("lzy_treesitter_start", { clear = true }),
    callback = function(args)
      start_for_buffer(args.buf)
    end,
  })

  -- Opcional: intenta instalar parsers al cargar el módulo.
  -- install_all()
end

return M
